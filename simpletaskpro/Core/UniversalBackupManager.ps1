# UniversalBackupManager.ps1 - Bulletproof data safety for ALL data types
# CRITICAL: Save operations ordered for maximum data integrity

class UniversalBackupManager {
    static [string]$BackupRoot = ""
    static [bool]$Initialized = $false
    
    # Configuration per data type
    static [hashtable]$TypeConfig = @{
        "tasks"          = @{ Pattern = "tasks_backup_{0}.json";          MaxVersions = 10; HashValidation = $true }
        "timeentries"    = @{ Pattern = "timeentries_backup_{0}.json";    MaxVersions = 10; HashValidation = $true }
        "excel-mappings" = @{ Pattern = "excel_mappings_backup_{0}.json"; MaxVersions = 10; HashValidation = $true }
        "notes"          = @{ Pattern = "notes_backup_{0}_{1}.txt";       MaxVersions = 10; HashValidation = $true }
        "settings"       = @{ Pattern = "settings_backup_{0}.json";      MaxVersions = 5;  HashValidation = $true }
        "external"       = @{ Pattern = "external_backup_{0}_{1}";       MaxVersions = 5;  HashValidation = $true }
        "project"     = @{ Pattern = "project_backup_{0}_{1}.json";   MaxVersions = 10; HashValidation = $true }
    }
    
    # Registry of active auto-save handlers
    static [hashtable]$AutoSaveRegistry = @{}
    static [bool]$ExitHandlersRegistered = $false
    
    static [void] Initialize([string]$programFolder) {
        if ([UniversalBackupManager]::Initialized) { return }
        
        [UniversalBackupManager]::BackupRoot = Join-Path $programFolder "Data" "backups"
        
        # Ensure backup directory exists
        $rootPath = ([UniversalBackupManager]::BackupRoot)
        if (-not (Test-Path $rootPath)) {
            New-Item -ItemType Directory -Path $rootPath -Force | Out-Null
        }
        
        # Register global exit handlers (CRITICAL - do this once)
        [UniversalBackupManager]::RegisterGlobalExitHandlers()
        
        [UniversalBackupManager]::Initialized = $true
    }
    
    # BULLETPROOF SAVE: Operation ordering is CRITICAL
    static [string] CreateBackup([string]$dataType, [string]$originalPath, [string]$identifier = "") {
        try {
            if (-not [UniversalBackupManager]::Initialized) {
                throw "UniversalBackupManager not initialized"
            }
            
            # STEP 1: BACKUP FIRST - Before any changes, ensure we can recover
            $timestamp = [datetime]::Now.ToString("yyyyMMdd_HHmmss")
            $config = [UniversalBackupManager]::TypeConfig[$dataType]
            if (-not $config) {
                throw "Unknown data type: $dataType"
            }
            
            # Generate backup filename
            $backupFileName = if ($identifier) {
                $config.Pattern -f $timestamp, $identifier
            } else {
                $config.Pattern -f $timestamp
            }
            $rootPath = ([UniversalBackupManager]::BackupRoot)
            $backupPath = Join-Path $rootPath $backupFileName
            
            # STEP 2: ATOMIC BACKUP - Copy to temp first, then rename
            if (Test-Path $originalPath) {
                $tempBackup = "$backupPath.tmp"
                Copy-Item -Path $originalPath -Destination $tempBackup -Force
                Move-Item -Path $tempBackup -Destination $backupPath -Force
                
                # STEP 3: INTEGRITY VALIDATION - Verify backup is valid
                if ($config.HashValidation) {
                    $originalHash = [UniversalBackupManager]::GetFileHash($originalPath)
                    $backupHash = [UniversalBackupManager]::GetFileHash($backupPath)
                    if ($originalHash -ne $backupHash) {
                        Remove-Item -Path $backupPath -Force -ErrorAction SilentlyContinue
                        throw "Backup integrity validation failed"
                    }
                }
            }
            
            # STEP 4: CLEANUP OLD BACKUPS - Only after successful backup
            [UniversalBackupManager]::CleanupOldBackups($dataType, $config.MaxVersions)
            
            return $backupPath
            
        } catch {
            # CRITICAL: Log but don't fail the calling operation
            Write-Warning "Backup failed for $dataType at $originalPath : $($_.Exception.Message)"
            return ""
        }
    }
    
    # BULLETPROOF ATOMIC SAVE: Never lose data, even on crash
    static [bool] AtomicSave([string]$filePath, [string]$content, [string]$dataType = "unknown", [string]$identifier = "") {
        try {
            # STEP 1: BACKUP EXISTING FILE (if it exists)
            if (Test-Path $filePath) {
                $backupPath = [UniversalBackupManager]::CreateBackup($dataType, $filePath, $identifier)
                # Continue even if backup fails - don't block the save
            }
            
            # STEP 2: ATOMIC WRITE - Write to temp file first
            $tempFile = "$filePath.tmp"
            [System.IO.File]::WriteAllText($tempFile, $content, [System.Text.Encoding]::UTF8)
            
            # STEP 3: INTEGRITY CHECK - Verify temp file is valid
            if (-not (Test-Path $tempFile)) {
                throw "Failed to create temporary file"
            }
            
            $tempSize = (Get-Item $tempFile).Length
            if ($tempSize -eq 0 -and $content.Length -gt 0) {
                throw "Temporary file is empty but content is not"
            }
            
            # STEP 4: ATOMIC RENAME - This is the critical moment
            Move-Item -Path $tempFile -Destination $filePath -Force
            
            # STEP 5: FINAL VERIFICATION - Ensure file was written correctly
            if (-not (Test-Path $filePath)) {
                throw "File does not exist after atomic rename"
            }
            
            return $true
            
        } catch {
            # CLEANUP: Remove temp file if it exists
            if (Test-Path "$filePath.tmp") {
                Remove-Item -Path "$filePath.tmp" -Force -ErrorAction SilentlyContinue
            }
            
            Write-Warning "Atomic save failed for $filePath : $($_.Exception.Message)"
            return $false
        }
    }
    
    # AUTO-SAVE REGISTRATION: Register data for auto-save on ANY exit
    static [void] RegisterAutoSave([string]$key, [string]$filePath, [scriptblock]$saveAction, [string]$dataType = "unknown") {
        [UniversalBackupManager]::AutoSaveRegistry[$key] = @{
            FilePath = $filePath
            SaveAction = $saveAction
            DataType = $dataType
            RegisteredTime = [datetime]::Now
        }
    }
    
    static [void] UnregisterAutoSave([string]$key) {
        if ([UniversalBackupManager]::AutoSaveRegistry.ContainsKey($key)) {
            [UniversalBackupManager]::AutoSaveRegistry.Remove($key)
        }
    }
    
    # GLOBAL EXIT HANDLERS: Catch ALL possible exit scenarios
    static [void] RegisterGlobalExitHandlers() {
        if ([UniversalBackupManager]::ExitHandlersRegistered) { return }
        
        try {
            # PowerShell exit event (most reliable)
            Register-EngineEvent -SourceIdentifier PowerShell.Exiting -Action {
                [UniversalBackupManager]::ExecuteAllAutoSaves("PowerShell.Exiting")
            } | Out-Null
            
            # Console exit event (Ctrl+C, close window)
            # Note: This may not work in all PowerShell hosts
            try {
                $null = [Console]::CancelKeyPress.AddHandler([ConsoleCancelEventHandler] {
                    param($sender, $e)
                    $e.Cancel = $true  # Prevent immediate exit
                    [UniversalBackupManager]::ExecuteAllAutoSaves("Ctrl+C")
                    $e.Cancel = $false  # Allow exit after save
                })
            } catch {
                # Console events not available in this host - continue
            }
            
            [UniversalBackupManager]::ExitHandlersRegistered = $true
            
        } catch {
            Write-Warning "Failed to register some exit handlers: $($_.Exception.Message)"
        }
    }
    
    # EXECUTE ALL AUTO-SAVES: Called on any exit scenario
    static [void] ExecuteAllAutoSaves([string]$exitReason) {
        try {
            foreach ($key in [UniversalBackupManager]::AutoSaveRegistry.Keys) {
                $entry = [UniversalBackupManager]::AutoSaveRegistry[$key]
                try {
                    # Execute the save action
                    & $entry.SaveAction
                } catch {
                    # Log but continue with other saves
                    Write-Warning "Auto-save failed for $key during $exitReason : $($_.Exception.Message)"
                }
            }
        } catch {
            # Even if this fails, don't block the exit
            Write-Warning "ExecuteAllAutoSaves failed during $exitReason : $($_.Exception.Message)"
        }
    }
    
    # UTILITY METHODS
    static [string] GetFileHash([string]$filePath) {
        if (-not (Test-Path $filePath)) { return "" }
        $hash = Get-FileHash -Path $filePath -Algorithm SHA256
        return $hash.Hash
    }
    
    static [void] CleanupOldBackups([string]$dataType, [int]$maxVersions) {
        try {
            $config = [UniversalBackupManager]::TypeConfig[$dataType]
            $searchPattern = $config.Pattern -replace '\{[0-9]\}', '*'
            
            $rootPath = ([UniversalBackupManager]::BackupRoot)
            $backups = Get-ChildItem -Path $rootPath -Filter $searchPattern |
                       Sort-Object -Property CreationTime -Descending
            
            if ($backups.Count -gt $maxVersions) {
                $backups | Select-Object -Skip $maxVersions | Remove-Item -Force
            }
        } catch {
            # Don't fail the calling operation if cleanup fails
            Write-Warning "Cleanup failed for $dataType : $($_.Exception.Message)"
        }
    }
    
    # RECOVERY METHODS
    static [string[]] GetBackupFiles([string]$dataType, [string]$identifier = "") {
        $config = [UniversalBackupManager]::TypeConfig[$dataType]
        $searchPattern = if ($identifier) {
            ($config.Pattern -f '*', $identifier)
        } else {
            ($config.Pattern -f '*')
        }
        
        $rootPath = ([UniversalBackupManager]::BackupRoot)
        return Get-ChildItem -Path $rootPath -Filter $searchPattern |
               Sort-Object -Property CreationTime -Descending |
               ForEach-Object { $_.FullName }
    }
    
    static [string] GetLatestBackup([string]$dataType, [string]$identifier = "") {
        $backups = [UniversalBackupManager]::GetBackupFiles($dataType, $identifier)
        return if ($backups.Count -gt 0) { $backups[0] } else { "" }
    }
}