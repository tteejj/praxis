# StateManager.ps1 - Fast, robust, PowerShell-native state management
# Based on AxiomPhoenix patterns with PRAXIS optimizations

class StateManager {
    # Core state storage - PowerShell hashtables for maximum speed
    hidden [hashtable]$_state = @{}
    hidden [hashtable]$_subscribers = @{}
    hidden [hashtable]$_indexes = @{}
    
    # Performance optimization
    hidden [System.Collections.Generic.Dictionary[string, object]]$_fastIndex
    hidden [bool]$_isDirty = $false
    hidden [datetime]$_lastSave = [datetime]::MinValue
    
    # Transaction support
    hidden [int]$_transactionDepth = 0
    hidden [bool]$_pendingSave = $false
    hidden [hashtable]$_transactionChanges = @{}
    
    # Event integration
    [EventBus]$EventBus
    [Logger]$Logger
    
    # Configuration
    [string]$StatePath = ""
    [bool]$AutoSave = $true
    [int]$AutoSaveIntervalMs = 5000
    [int]$MaxBackups = 5
    [bool]$EnableCompression = $true
    
    # Performance metrics
    hidden [int]$_getOperations = 0
    hidden [int]$_setOperations = 0
    hidden [datetime]$_lastStatsReset = [datetime]::Now
    
    StateManager() {
        $this._fastIndex = [System.Collections.Generic.Dictionary[string, object]]::new()
        $this.InitializeDefaultState()
    }
    
    [void] Initialize([ServiceContainer]$services) {
        try {
            # Get required services
            $this.EventBus = $services.GetService("EventBus")
            $this.Logger = $services.GetService("Logger")
            
            # Set default state path
            if ([string]::IsNullOrEmpty($this.StatePath)) {
                $praxisRoot = if ($global:PraxisRoot) { $global:PraxisRoot } else { $PWD }
                $this.StatePath = Join-Path $praxisRoot "_State/application.json"
            }
            
            # Ensure state directory exists
            $stateDir = Split-Path $this.StatePath -Parent
            if (-not (Test-Path $stateDir)) {
                New-Item -ItemType Directory -Path $stateDir -Force | Out-Null
            }
            
            # Load existing state
            $this.LoadState()
            
            # Start auto-save if enabled
            if ($this.AutoSave) {
                $this.StartAutoSave()
            }
            
            if ($this.Logger) {
                $this.Logger.Info("StateManager initialized: Path=$($this.StatePath), AutoSave=$($this.AutoSave)")
            }
            
        } catch {
            $this.LogError("StateManager initialization failed", @{ Error = $_.Exception.Message })
            throw
        }
    }
    
    # ==================== CORE STATE OPERATIONS ====================
    
    # FAST: Direct hashtable access with error handling
    [object] GetState([string]$key) {
        return $this.GetState($key, $null)
    }
    
    [object] GetState([string]$key, [object]$defaultValue) {
        if ([string]::IsNullOrEmpty($key)) {
            return $defaultValue
        }
        
        try {
            $this._getOperations++
            
            # Try fast index first (Dictionary lookup - microseconds)
            if ($this._fastIndex.ContainsKey($key)) {
                return $this._fastIndex[$key]
            }
            
            # Fall back to dot-notation path traversal
            $keys = $key -split '\.'
            $current = $this._state
            
            foreach ($k in $keys) {
                if ($current -eq $null -or -not $current.ContainsKey($k)) {
                    return $defaultValue
                }
                $current = $current[$k]
            }
            
            # Cache in fast index for next time
            $this._fastIndex[$key] = $current
            
            return if ($current -eq $null) { $defaultValue } else { $current }
            
        } catch {
            $this.LogError("GetState failed", @{ Key = $key; Error = $_.Exception.Message })
            return $defaultValue
        }
    }
    
    # FAST: Direct state updates with smart change detection
    [void] SetState([string]$key, [object]$value) {
        $this.SetState($key, $value, $true)
    }
    
    [void] SetState([string]$key, [object]$value, [bool]$publishEvents) {
        if ([string]::IsNullOrEmpty($key)) {
            return
        }
        
        try {
            $this._setOperations++
            
            # Fast equality check to avoid unnecessary updates
            $currentValue = $this.GetState($key)
            if ($this.AreEqual($currentValue, $value)) {
                return  # No change, skip update
            }
            
            # Store old value for events
            $oldValue = $currentValue
            
            # Update both storage mechanisms
            $this.SetStateInternal($key, $value)
            $this._fastIndex[$key] = $value
            
            # Track transaction changes
            if ($this._transactionDepth -gt 0) {
                $this._transactionChanges[$key] = @{ 
                    NewValue = $value
                    OldValue = $oldValue 
                }
            }
            
            # Mark as dirty and trigger save
            $this.MarkDirty()
            
            # Publish change events
            if ($publishEvents -and $this.EventBus) {
                $this.PublishStateChange($key, $value, $oldValue)
            }
            
        } catch {
            $this.LogError("SetState failed", @{ Key = $key; Error = $_.Exception.Message })
            throw
        }
    }
    
    # ==================== TRANSACTION SUPPORT ====================
    
    [void] BeginTransaction() {
        $this._transactionDepth++
        if ($this._transactionDepth -eq 1) {
            $this._transactionChanges.Clear()
            if ($this.Logger) {
                $this.Logger.Debug("StateManager: Transaction started")
            }
        }
    }
    
    [void] EndTransaction() {
        if ($this._transactionDepth -gt 0) {
            $this._transactionDepth--
            
            # Process all changes when transaction completes
            if ($this._transactionDepth -eq 0) {
                try {
                    # Batch save
                    if ($this._pendingSave) {
                        $this.SaveState()
                        $this._pendingSave = $false
                    }
                    
                    # Batch event publishing
                    if ($this._transactionChanges.Count -gt 0 -and $this.EventBus) {
                        $this.EventBus.Publish("State.TransactionComplete", @{
                            Changes = $this._transactionChanges
                            ChangeCount = $this._transactionChanges.Count
                        })
                    }
                    
                    if ($this.Logger) {
                        $this.Logger.Debug("StateManager: Transaction completed with $($this._transactionChanges.Count) changes")
                    }
                    
                } catch {
                    $this.LogError("Transaction completion failed", @{ Error = $_.Exception.Message })
                    throw
                } finally {
                    $this._transactionChanges.Clear()
                }
            }
        }
    }
    
    [void] RollbackTransaction() {
        if ($this._transactionDepth -gt 0) {
            try {
                # Restore all changed values to their original state
                foreach ($change in $this._transactionChanges.GetEnumerator()) {
                    $key = $change.Key
                    $oldValue = $change.Value.OldValue
                    
                    # Directly restore without triggering events or new transaction tracking
                    $this.SetStateInternal($key, $oldValue)
                    $this._fastIndex[$key] = $oldValue
                }
                
                if ($this.Logger) {
                    $this.Logger.Debug("StateManager: Transaction rolled back, $($this._transactionChanges.Count) changes reverted")
                }
                
            } catch {
                $this.LogError("Transaction rollback failed", @{ Error = $_.Exception.Message })
                throw
            } finally {
                $this._transactionChanges.Clear()
                $this._transactionDepth = 0
                $this._pendingSave = $false
            }
        }
    }
    
    # ==================== PERSISTENCE ====================
    
    [void] LoadState() {
        if (-not (Test-Path $this.StatePath)) {
            if ($this.Logger) {
                $this.Logger.Info("StateManager: No existing state file, using defaults")
            }
            return
        }
        
        try {
            $json = Get-Content $this.StatePath -Raw -ErrorAction Stop
            if ([string]::IsNullOrEmpty($json)) {
                return
            }
            
            $data = $json | ConvertFrom-Json -AsHashtable -ErrorAction Stop
            if ($data -and $data.ContainsKey("State")) {
                $this._state = $data.State
                $this.RebuildFastIndex()
            }
            
            if ($this.Logger) {
                $this.Logger.Info("StateManager: State loaded successfully from $($this.StatePath)")
            }
            
        } catch {
            $this.LogError("Failed to load state", @{ Path = $this.StatePath; Error = $_.Exception.Message })
            
            # Try to load from backup
            $this.LoadFromBackup()
        }
    }
    
    [void] SaveState() {
        if (-not $this._isDirty) {
            return
        }
        
        try {
            # Create backup before save
            $this.CreateBackup()
            
            # Prepare data for serialization
            $data = @{
                State = $this._state
                Metadata = @{
                    Version = "1.0.0"
                    SavedAt = [datetime]::Now.ToString('o')
                    StateKeys = @($this._state.Keys)
                    FastIndexKeys = @($this._fastIndex.Keys) 
                    Stats = @{
                        GetOperations = $this._getOperations
                        SetOperations = $this._setOperations
                    }
                }
            }
            
            # Convert to JSON with compression option
            $jsonParams = @{
                Depth = 10
                Compress = $this.EnableCompression
            }
            $json = $data | ConvertTo-Json @jsonParams
            
            # Atomic write (write to temp file, then replace)
            $tempPath = "$($this.StatePath).tmp"
            [System.IO.File]::WriteAllText($tempPath, $json, [System.Text.Encoding]::UTF8)
            Move-Item $tempPath $this.StatePath -Force
            
            # Update tracking
            $this._isDirty = $false
            $this._lastSave = [datetime]::Now
            
            # Publish save event
            if ($this.EventBus) {
                $this.EventBus.Publish("State.Saved", @{
                    Path = $this.StatePath
                    StateKeyCount = $data.Metadata.StateKeys.Count
                    SaveTime = $this._lastSave
                })
            }
            
            if ($this.Logger) {
                $this.Logger.Debug("StateManager: State saved to $($this.StatePath)")
            }
            
        } catch {
            $this.LogError("Failed to save state", @{ Path = $this.StatePath; Error = $_.Exception.Message })
            throw
        }
    }
    
    # ==================== PERFORMANCE OPTIMIZATIONS ====================
    
    [void] RebuildFastIndex() {
        try {
            $this._fastIndex.Clear()
            $this.BuildFastIndexRecursive("", $this._state)
            
            if ($this.Logger) {
                $this.Logger.Debug("StateManager: Fast index rebuilt with $($this._fastIndex.Count) entries")
            }
            
        } catch {
            $this.LogError("Fast index rebuild failed", @{ Error = $_.Exception.Message })
        }
    }
    
    hidden [void] BuildFastIndexRecursive([string]$prefix, [hashtable]$data) {
        foreach ($key in $data.Keys) {
            $fullKey = if ($prefix) { "$prefix.$key" } else { $key }
            $value = $data[$key]
            
            # Add to fast index
            $this._fastIndex[$fullKey] = $value
            
            # Recurse into nested hashtables
            if ($value -is [hashtable]) {
                $this.BuildFastIndexRecursive($fullKey, $value)
            }
        }
    }
    
    [bool] AreEqual([object]$a, [object]$b) {
        # Fast reference equality check first
        if ([object]::ReferenceEquals($a, $b)) {
            return $true
        }
        
        # Null checks
        if ($a -eq $null -or $b -eq $null) {
            return ($a -eq $null -and $b -eq $null)
        }
        
        # Use PowerShell's efficient comparison
        try {
            # For complex objects, try Equals method first
            if ($a.GetType().GetMethod("Equals", @([object]))) {
                return $a.Equals($b)
            }
            
            # Fall back to PowerShell comparison
            return $a -eq $b
            
        } catch {
            # If comparison fails, assume not equal
            return $false
        }
    }
    
    # ==================== EVENT SYSTEM ====================
    
    [void] OnStateChanged([string]$pattern, [scriptblock]$handler) {
        if ([string]::IsNullOrEmpty($pattern) -or $handler -eq $null) {
            return
        }
        
        try {
            if (-not $this._subscribers.ContainsKey($pattern)) {
                $this._subscribers[$pattern] = @()
            }
            
            $this._subscribers[$pattern] += $handler
            
            if ($this.Logger) {
                $this.Logger.Debug("StateManager: Subscriber added for pattern '$pattern'")
            }
            
        } catch {
            $this.LogError("Failed to add state subscriber", @{ Pattern = $pattern; Error = $_.Exception.Message })
        }
    }
    
    hidden [void] PublishStateChange([string]$key, [object]$newValue, [object]$oldValue) {
        if ($this._transactionDepth -gt 0) {
            return  # Don't publish during transactions
        }
        
        try {
            # Publish to EventBus
            if ($this.EventBus) {
                $this.EventBus.Publish("State.Changed", @{
                    Key = $key
                    NewValue = $newValue
                    OldValue = $oldValue
                    Timestamp = [datetime]::Now
                })
            }
            
            # Publish to pattern subscribers
            foreach ($pattern in $this._subscribers.Keys) {
                if ($this.MatchesPattern($key, $pattern)) {
                    foreach ($handler in $this._subscribers[$pattern]) {
                        try {
                            & $handler @{
                                Key = $key
                                NewValue = $newValue
                                OldValue = $oldValue
                            }
                        } catch {
                            $this.LogError("State subscriber handler failed", @{ 
                                Pattern = $pattern
                                Key = $key
                                Error = $_.Exception.Message 
                            })
                        }
                    }
                }
            }
            
        } catch {
            $this.LogError("Failed to publish state change", @{ Key = $key; Error = $_.Exception.Message })
        }
    }
    
    [bool] MatchesPattern([string]$key, [string]$pattern) {
        # Simple wildcard pattern matching
        if ($pattern -eq "*") {
            return $true
        }
        
        if ($pattern.EndsWith("*")) {
            $prefix = $pattern.Substring(0, $pattern.Length - 1)
            return $key.StartsWith($prefix)
        }
        
        return $key -eq $pattern
    }
    
    # ==================== INTERNAL HELPERS ====================
    
    [void] InitializeDefaultState() {
        $this._state = @{
            app = @{
                version = "1.0.0"
                startTime = [datetime]::Now
                sessionId = [System.Guid]::NewGuid().ToString()
            }
            ui = @{
                currentScreen = ""
                selectedItems = @{}
                viewStates = @{}
            }
            data = @{
                projects = @{}
                tasks = @{}
                config = @{}
            }
        }
        
        $this.RebuildFastIndex()
    }
    
    hidden [void] SetStateInternal([string]$key, [object]$value) {
        $keys = $key -split '\.'
        $current = $this._state
        
        # Navigate to parent container
        for ($i = 0; $i -lt $keys.Count - 1; $i++) {
            $k = $keys[$i]
            if (-not $current.ContainsKey($k)) {
                $current[$k] = @{}
            }
            $current = $current[$k]
        }
        
        # Set the final value
        $finalKey = $keys[-1]
        $current[$finalKey] = $value
    }
    
    [void] MarkDirty() {
        $this._isDirty = $true
        
        if ($this._transactionDepth -gt 0) {
            $this._pendingSave = $true
        } elseif ($this.AutoSave) {
            # Immediate save for non-transaction updates
            $this.SaveState()
        }
    }
    
    hidden [void] CreateBackup() {
        if (-not (Test-Path $this.StatePath)) {
            return
        }
        
        try {
            $backupDir = Join-Path (Split-Path $this.StatePath -Parent) "Backups"
            if (-not (Test-Path $backupDir)) {
                New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
            }
            
            $timestamp = [datetime]::Now.ToString("yyyyMMdd_HHmmss")
            $backupPath = Join-Path $backupDir "application_$timestamp.json"
            
            Copy-Item $this.StatePath $backupPath
            
            # Clean old backups
            $this.CleanOldBackups($backupDir)
            
        } catch {
            $this.LogError("Backup creation failed", @{ Error = $_.Exception.Message })
        }
    }
    
    hidden [void] CleanOldBackups([string]$backupDir) {
        try {
            $backups = Get-ChildItem $backupDir -Filter "application_*.json" | Sort-Object CreationTime -Descending
            
            if ($backups.Count -gt $this.MaxBackups) {
                $toDelete = $backups | Select-Object -Skip $this.MaxBackups
                foreach ($file in $toDelete) {
                    Remove-Item $file.FullName -Force
                }
            }
            
        } catch {
            $this.LogError("Backup cleanup failed", @{ Error = $_.Exception.Message })
        }
    }
    
    hidden [void] LoadFromBackup() {
        try {
            $backupDir = Join-Path (Split-Path $this.StatePath -Parent) "Backups"
            if (-not (Test-Path $backupDir)) {
                return
            }
            
            $latestBackup = Get-ChildItem $backupDir -Filter "application_*.json" | Sort-Object CreationTime -Descending | Select-Object -First 1
            
            if ($latestBackup) {
                $json = Get-Content $latestBackup.FullName -Raw
                $data = $json | ConvertFrom-Json -AsHashtable
                
                if ($data -and $data.ContainsKey("State")) {
                    $this._state = $data.State
                    $this.RebuildFastIndex()
                    
                    if ($this.Logger) {
                        $this.Logger.Info("StateManager: Recovered from backup: $($latestBackup.Name)")
                    }
                }
            }
            
        } catch {
            $this.LogError("Backup recovery failed", @{ Error = $_.Exception.Message })
        }
    }
    
    hidden [void] StartAutoSave() {
        # Note: PowerShell doesn't have great built-in timer support
        # This could be enhanced with System.Timers.Timer if needed
        # For now, auto-save happens on each SetState call
    }
    
    hidden [void] LogError([string]$message, [hashtable]$context = @{}) {
        if ($this.Logger) {
            $this.Logger.Error("$message - Context: $($context | ConvertTo-Json -Compress)")
        }
    }
    
    # ==================== PUBLIC API METHODS ====================
    
    [hashtable] GetPerformanceStats() {
        $uptime = [datetime]::Now - $this._lastStatsReset
        
        return @{
            GetOperations = $this._getOperations
            SetOperations = $this._setOperations
            FastIndexSize = $this._fastIndex.Count
            StateKeyCount = $this._state.Keys.Count
            TransactionDepth = $this._transactionDepth
            IsDirty = $this._isDirty
            LastSave = $this._lastSave
            Uptime = $uptime.ToString()
            OperationsPerSecond = if ($uptime.TotalSeconds -gt 0) { ($this._getOperations + $this._setOperations) / $uptime.TotalSeconds } else { 0 }
        }
    }
    
    [void] ResetPerformanceStats() {
        $this._getOperations = 0
        $this._setOperations = 0
        $this._lastStatsReset = [datetime]::Now
    }
    
    [void] ClearState() {
        $this.BeginTransaction()
        try {
            $this._state.Clear()
            $this._fastIndex.Clear()
            $this.InitializeDefaultState()
            
            if ($this.EventBus) {
                $this.EventBus.Publish("State.Cleared", @{ Timestamp = [datetime]::Now })
            }
            
        } finally {
            $this.EndTransaction()
        }
    }
    
    [void] Cleanup() {
        try {
            if ($this._isDirty) {
                $this.SaveState()
            }
            
            $this._subscribers.Clear()
            $this._fastIndex.Clear()
            
            if ($this.Logger) {
                $this.Logger.Info("StateManager cleanup completed")
            }
            
        } catch {
            $this.LogError("Cleanup failed", @{ Error = $_.Exception.Message })
        }
    }
}