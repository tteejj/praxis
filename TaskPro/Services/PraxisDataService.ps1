# PraxisDataService.ps1 - Unified data management for all Praxis apps
# Single-user, single-process data consolidation with safety

class PraxisDataService {
    # Static properties for single-process caching
    static [string]$DataFile = ""
    static [string]$BackupDir = ""
    static [object]$CachedData = $null
    static [bool]$DataLoaded = $false
    static [bool]$IsInitialized = $false
    
    # Initialize the service with data directory
    static [void] Initialize([string]$dataPath) {
        if ([PraxisDataService]::IsInitialized) { return }
        
        [PraxisDataService]::DataFile = Join-Path $dataPath "praxis-unified.json"
        [PraxisDataService]::BackupDir = Join-Path $dataPath "backups"
        
        # Ensure directories exist
        if (-not (Test-Path $dataPath)) {
            New-Item -ItemType Directory -Path $dataPath -Force | Out-Null
        }
        $backupDirPath = [PraxisDataService]::BackupDir
        if (-not (Test-Path $backupDirPath)) {
            New-Item -ItemType Directory -Path $backupDirPath -Force | Out-Null
        }
        
        [PraxisDataService]::IsInitialized = $true
        Write-Host "PraxisDataService initialized: $([PraxisDataService]::DataFile)" -ForegroundColor DarkGray
    }
    
    # Get unified data (load once, cache in memory)
    static [object] GetData() {
        if (-not [PraxisDataService]::IsInitialized) {
            throw "PraxisDataService not initialized. Call Initialize() first."
        }
        
        if (-not [PraxisDataService]::DataLoaded) {
            [PraxisDataService]::LoadData()
        }
        return [PraxisDataService]::CachedData
    }
    
    # Load data from file with recovery prompting
    static [void] LoadData() {
        Write-Host "Loading unified data..." -ForegroundColor DarkGray
        
        try {
            if (-not (Test-Path [PraxisDataService]::DataFile)) {
                Write-Host "No unified data file found, creating default structure..." -ForegroundColor Yellow
                [PraxisDataService]::CreateDefaultData()
                return
            }
            
            $content = Get-Content [PraxisDataService]::DataFile -Raw -ErrorAction Stop
            $data = $content | ConvertFrom-Json -ErrorAction Stop
            
            # Basic structure validation (no user data validation)
            if (-not $data.projects -or -not $data.tasks -or -not $data.timeEntries -or -not $data.commands) {
                throw "Invalid data structure: missing required sections"
            }
            
            [PraxisDataService]::CachedData = $data
            [PraxisDataService]::DataLoaded = $true
            Write-Host "✓ Unified data loaded successfully" -ForegroundColor Green
            
        } catch {
            Write-Host "✗ Main data file corrupted or unreadable: $_" -ForegroundColor Red
            [PraxisDataService]::PromptForRecovery()
        }
    }
    
    # Prompt user for recovery options
    static [void] PromptForRecovery() {
        Write-Host ""
        Write-Host "Data Recovery Options:" -ForegroundColor Yellow
        Write-Host "1. Try immediate backup (.backup file)" -ForegroundColor White
        Write-Host "2. Browse timestamped backups" -ForegroundColor White  
        Write-Host "3. Create fresh data (LOSE ALL DATA)" -ForegroundColor Red
        Write-Host "4. Exit and fix manually" -ForegroundColor White
        Write-Host ""
        
        do {
            $choice = Read-Host "Choose recovery option (1-4)"
            switch ($choice) {
                "1" { 
                    if ([PraxisDataService]::TryLoadBackup()) { return }
                    Write-Host "Immediate backup also corrupted." -ForegroundColor Red
                }
                "2" { 
                    if ([PraxisDataService]::BrowseBackups()) { return }
                    Write-Host "No valid backups found." -ForegroundColor Red
                }
                "3" {
                    $confirm = Read-Host "Type 'RESET' to confirm data loss"
                    if ($confirm -eq "RESET") {
                        [PraxisDataService]::CreateDefaultData()
                        return
                    }
                }
                "4" { 
                    Write-Host "Exiting for manual recovery..." -ForegroundColor Yellow
                    exit 1 
                }
                default { Write-Host "Invalid choice. Enter 1-4." -ForegroundColor Red }
            }
        } while ($true)
    }
    
    # Try loading immediate backup
    static [bool] TryLoadBackup() {
        $backupFile = [PraxisDataService]::DataFile + ".backup"
        if (-not (Test-Path $backupFile)) {
            Write-Host "No immediate backup found." -ForegroundColor Red
            return $false
        }
        
        try {
            $content = Get-Content $backupFile -Raw -ErrorAction Stop
            $data = $content | ConvertFrom-Json -ErrorAction Stop
            
            if (-not $data.projects -or -not $data.tasks -or -not $data.timeEntries -or -not $data.commands) {
                throw "Invalid backup structure"
            }
            
            [PraxisDataService]::CachedData = $data
            [PraxisDataService]::DataLoaded = $true
            Write-Host "✓ Recovered from immediate backup" -ForegroundColor Green
            return $true
            
        } catch {
            Write-Host "✗ Immediate backup corrupted: $_" -ForegroundColor Red
            return $false
        }
    }
    
    # Browse timestamped backups
    static [bool] BrowseBackups() {
        $backupFiles = Get-ChildItem [PraxisDataService]::BackupDir -Filter "praxis-unified_*.json" | Sort-Object LastWriteTime -Descending
        
        if ($backupFiles.Count -eq 0) {
            return $false
        }
        
        Write-Host ""
        Write-Host "Available backups:" -ForegroundColor Yellow
        for ($i = 0; $i -lt $backupFiles.Count; $i++) {
            $file = $backupFiles[$i]
            Write-Host "$($i + 1). $($file.Name) ($(Get-Date $file.LastWriteTime -Format 'yyyy-MM-dd HH:mm:ss'))" -ForegroundColor White
        }
        Write-Host ""
        
        do {
            $choice = Read-Host "Select backup number (1-$($backupFiles.Count)) or 0 to cancel"
            if ($choice -eq "0") { return $false }
            
            $index = [int]$choice - 1
            if ($index -ge 0 -and $index -lt $backupFiles.Count) {
                return [PraxisDataService]::LoadSpecificBackup($backupFiles[$index].FullName)
            }
            Write-Host "Invalid selection." -ForegroundColor Red
        } while ($true)
        
        return $false
    }
    
    # Load specific backup file
    static [bool] LoadSpecificBackup([string]$backupPath) {
        try {
            $content = Get-Content $backupPath -Raw -ErrorAction Stop
            $data = $content | ConvertFrom-Json -ErrorAction Stop
            
            if (-not $data.projects -or -not $data.tasks -or -not $data.timeEntries -or -not $data.commands) {
                throw "Invalid backup structure"
            }
            
            [PraxisDataService]::CachedData = $data
            [PraxisDataService]::DataLoaded = $true
            Write-Host "✓ Recovered from backup: $(Split-Path $backupPath -Leaf)" -ForegroundColor Green
            return $true
            
        } catch {
            Write-Host "✗ Selected backup corrupted: $_" -ForegroundColor Red
            return $false
        }
    }
    
    # Create default data structure
    static [void] CreateDefaultData() {
        $defaultData = @{
            metadata = @{
                version = "1.0.0"
                created = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssZ")
                lastModified = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssZ")
                description = "Praxis unified data file"
            }
            projects = @()
            tasks = @()
            timeEntries = @()
            commands = @()
            themes = @{
                current = "default"
                settings = @{}
            }
            appStates = @{
                taskpro = @{
                    selectedTaskId = $null
                    scrollPosition = 0
                }
                timetracker = @{
                    currentWeek = (Get-Date).ToString("yyyyMMdd")
                    selectedEntry = $null
                }
                commandlibrary = @{
                    lastSearch = ""
                    selectedCommand = $null
                }
            }
        }
        
        [PraxisDataService]::CachedData = $defaultData
        [PraxisDataService]::DataLoaded = $true
        [PraxisDataService]::SaveData("CreateDefaultData")
        Write-Host "✓ Created default data structure" -ForegroundColor Green
    }
    
    # Save data with atomic write (called on app close)
    static [void] SaveData([string]$operation) {
        if (-not [PraxisDataService]::DataLoaded) {
            Write-Host "No data to save" -ForegroundColor Yellow
            return
        }
        
        try {
            # Update metadata
            [PraxisDataService]::CachedData.metadata.lastModified = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssZ")
            
            # Backup current file (immediate backup)
            if (Test-Path [PraxisDataService]::DataFile) {
                Copy-Item [PraxisDataService]::DataFile "$([PraxisDataService]::DataFile).backup" -Force
            }
            
            # Atomic write via temp file
            $tempFile = [PraxisDataService]::DataFile + ".tmp"
            $jsonContent = [PraxisDataService]::CachedData | ConvertTo-Json -Depth 10
            Set-Content -Path $tempFile -Value $jsonContent -Encoding UTF8
            
            # Atomic move (OS guarantees atomicity)
            $dataFilePath = [PraxisDataService]::DataFile
            Move-Item $tempFile $dataFilePath -Force
            
            Write-Host "✓ Unified data saved: $operation" -ForegroundColor DarkGreen
            
        } catch {
            Write-Host "✗ Failed to save data: $_" -ForegroundColor Red
            throw
        }
    }
    
    # Create timestamped backup and cleanup old ones (called on app close)
    static [void] CreateTimestampedBackup() {
        if (-not (Test-Path [PraxisDataService]::DataFile)) {
            return
        }
        
        try {
            # Create timestamped backup
            $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
            $backupFile = Join-Path [PraxisDataService]::BackupDir "praxis-unified_$timestamp.json"
            Copy-Item [PraxisDataService]::DataFile $backupFile
            
            # Cleanup old backups (keep last 3)
            $backups = Get-ChildItem [PraxisDataService]::BackupDir -Filter "praxis-unified_*.json" | Sort-Object LastWriteTime -Descending
            if ($backups.Count -gt 3) {
                $toDelete = $backups | Select-Object -Skip 3
                foreach ($backup in $toDelete) {
                    Remove-Item $backup.FullName -Force
                    Write-Host "  Cleaned up old backup: $($backup.Name)" -ForegroundColor DarkGray
                }
            }
            
            Write-Host "✓ Created timestamped backup: $(Split-Path $backupFile -Leaf)" -ForegroundColor DarkGreen
            
        } catch {
            Write-Host "✗ Failed to create backup: $_" -ForegroundColor Red
        }
    }
    
    # Convenience methods for app data access
    static [object[]] GetProjects() { 
        return [PraxisDataService]::GetData().projects 
    }
    
    static [object[]] GetTasks() { 
        return [PraxisDataService]::GetData().tasks 
    }
    
    static [object[]] GetTimeEntries() { 
        return [PraxisDataService]::GetData().timeEntries 
    }
    
    static [object[]] GetCommands() { 
        return [PraxisDataService]::GetData().commands 
    }
    
    static [object] GetThemes() { 
        return [PraxisDataService]::GetData().themes 
    }
    
    static [object] GetAppState([string]$appName) {
        $data = [PraxisDataService]::GetData()
        if ($data.appStates.PSObject.Properties.Name -contains $appName) {
            return $data.appStates.$appName
        }
        return @{}
    }
    
    # Convenience methods for data updates
    static [void] UpdateProjects([object[]]$projects) {
        $data = [PraxisDataService]::GetData()
        $data.projects = $projects
    }
    
    static [void] UpdateTasks([object[]]$tasks) {
        $data = [PraxisDataService]::GetData()
        $data.tasks = $tasks
    }
    
    static [void] UpdateTimeEntries([object[]]$timeEntries) {
        $data = [PraxisDataService]::GetData()
        $data.timeEntries = $timeEntries
    }
    
    static [void] UpdateCommands([object[]]$commands) {
        $data = [PraxisDataService]::GetData()
        $data.commands = $commands
    }
    
    static [void] UpdateAppState([string]$appName, [object]$state) {
        $data = [PraxisDataService]::GetData()
        $data.appStates.$appName = $state
    }
    
    # Called when app closes (backup + save)
    static [void] Shutdown([string]$appName) {
        if ([PraxisDataService]::DataLoaded) {
            Write-Host "Shutting down PraxisDataService from $appName..." -ForegroundColor DarkGray
            [PraxisDataService]::CreateTimestampedBackup()
            [PraxisDataService]::SaveData("Shutdown from $appName")
            Write-Host "✓ Data safely persisted with backup" -ForegroundColor Green
        }
    }
}