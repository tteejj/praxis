# BackupService.ps1 - Backup and restore functionality

class BackupService {
    hidden [string]$BackupPath
    hidden [Logger]$Logger
    hidden [int]$MaxBackups = 10
    
    BackupService() {
        $this.BackupPath = Join-Path $global:PraxisRoot "_Backup"
        $this.Logger = $global:Logger
        
        # Ensure backup directory exists
        if (-not (Test-Path $this.BackupPath)) {
            New-Item -ItemType Directory -Path $this.BackupPath -Force | Out-Null
        }
    }
    
    # Create a full backup of all data and settings
    [string] CreateBackup() {
        return $this.CreateBackup("Manual backup")
    }
    
    [string] CreateBackup([string]$description) {
        try {
            # Create timestamp-based backup folder
            $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
            $backupFolder = Join-Path $this.BackupPath $timestamp
            New-Item -ItemType Directory -Path $backupFolder -Force | Out-Null
            
            # Backup all data directories
            $this.BackupDirectory("_ProjectData", $backupFolder)
            $this.BackupDirectory("_Config", $backupFolder)
            $this.BackupDirectory("_Logs", $backupFolder)
            
            # Create backup metadata
            $metadata = @{
                Timestamp = Get-Date -Format "o"
                Description = $description
                PraxisVersion = "1.0.0"
                Files = @()
            }
            
            # List all backed up files
            Get-ChildItem -Path $backupFolder -Recurse -File | ForEach-Object {
                $metadata.Files += @{
                    Path = $_.FullName.Replace($backupFolder, "").TrimStart("\", "/")
                    Size = $_.Length
                    LastModified = $_.LastWriteTime.ToString("o")
                }
            }
            
            # Save metadata
            $metadataPath = Join-Path $backupFolder "backup-metadata.json"
            $metadata | ConvertTo-Json -Depth 10 | Set-Content -Path $metadataPath
            
            # Clean up old backups
            $this.CleanupOldBackups()
            
            if ($this.Logger) {
                $this.Logger.Info("Backup created: $backupFolder")
            }
            
            return $backupFolder
        }
        catch {
            if ($this.Logger) {
                $this.Logger.Error("Backup failed: $_")
            }
            throw
        }
    }
    
    # Backup a specific directory
    hidden [void] BackupDirectory([string]$dirName, [string]$backupFolder) {
        $sourcePath = Join-Path $global:PraxisRoot $dirName
        if (Test-Path $sourcePath) {
            $destPath = Join-Path $backupFolder $dirName
            Copy-Item -Path $sourcePath -Destination $destPath -Recurse -Force
        }
    }
    
    # List available backups
    [hashtable[]] ListBackups() {
        $backups = @()
        
        Get-ChildItem -Path $this.BackupPath -Directory | Sort-Object Name -Descending | ForEach-Object {
            $metadataPath = Join-Path $_.FullName "backup-metadata.json"
            if (Test-Path $metadataPath) {
                try {
                    $metadata = Get-Content -Path $metadataPath -Raw | ConvertFrom-Json -AsHashtable
                    $backups += @{
                        Name = $_.Name
                        Path = $_.FullName
                        Timestamp = $metadata.Timestamp
                        Description = $metadata.Description
                        FileCount = $metadata.Files.Count
                        Size = ($metadata.Files | Measure-Object -Property Size -Sum).Sum
                    }
                }
                catch {
                    # Fallback for corrupted metadata
                    $backups += @{
                        Name = $_.Name
                        Path = $_.FullName
                        Timestamp = $_.CreationTime.ToString("o")
                        Description = "Unknown"
                        FileCount = (Get-ChildItem -Path $_.FullName -Recurse -File).Count
                        Size = 0
                    }
                }
            }
        }
        
        return $backups
    }
    
    # Restore from backup
    [void] RestoreBackup([string]$backupName) {
        $backupFullPath = Join-Path $this.BackupPath $backupName
        if (-not (Test-Path $backupFullPath)) {
            throw "Backup not found: $backupName"
        }
        
        try {
            # Create pre-restore backup
            $this.CreateBackup("Pre-restore backup")
            
            # Restore each directory
            @("_ProjectData", "_Config", "_Logs") | ForEach-Object {
                $sourcePath = Join-Path $backupFullPath $_
                if (Test-Path $sourcePath) {
                    $destPath = Join-Path $global:PraxisRoot $_
                    
                    # Remove existing directory
                    if (Test-Path $destPath) {
                        Remove-Item -Path $destPath -Recurse -Force
                    }
                    
                    # Copy from backup
                    Copy-Item -Path $sourcePath -Destination $destPath -Recurse -Force
                }
            }
            
            if ($this.Logger) {
                $this.Logger.Info("Restored from backup: $backupName")
            }
        }
        catch {
            if ($this.Logger) {
                $this.Logger.Error("Restore failed: $_")
            }
            throw
        }
    }
    
    # Export backup to zip file
    [void] ExportBackup([string]$backupName, [string]$exportPath) {
        $backupFullPath = Join-Path $this.BackupPath $backupName
        if (-not (Test-Path $backupFullPath)) {
            throw "Backup not found: $backupName"
        }
        
        try {
            # Ensure export directory exists
            $exportDir = Split-Path -Parent $exportPath
            if (-not (Test-Path $exportDir)) {
                New-Item -ItemType Directory -Path $exportDir -Force | Out-Null
            }
            
            # Compress backup
            Compress-Archive -Path "$backupFullPath\*" -DestinationPath $exportPath -Force
            
            if ($this.Logger) {
                $this.Logger.Info("Backup exported to: $exportPath")
            }
        }
        catch {
            if ($this.Logger) {
                $this.Logger.Error("Export failed: $_")
            }
            throw
        }
    }
    
    # Import backup from zip file
    [string] ImportBackup([string]$zipPath) {
        if (-not (Test-Path $zipPath)) {
            throw "Zip file not found: $zipPath"
        }
        
        try {
            # Create timestamp-based folder for import
            $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
            $importFolder = Join-Path $this.BackupPath "imported_$timestamp"
            
            # Extract zip
            Expand-Archive -Path $zipPath -DestinationPath $importFolder -Force
            
            # Verify it's a valid backup
            $metadataPath = Join-Path $importFolder "backup-metadata.json"
            if (-not (Test-Path $metadataPath)) {
                Remove-Item -Path $importFolder -Recurse -Force
                throw "Invalid backup: metadata not found"
            }
            
            if ($this.Logger) {
                $this.Logger.Info("Backup imported: imported_$timestamp")
            }
            
            return "imported_$timestamp"
        }
        catch {
            if ($this.Logger) {
                $this.Logger.Error("Import failed: $_")
            }
            throw
        }
    }
    
    # Clean up old backups
    hidden [void] CleanupOldBackups() {
        $backups = Get-ChildItem -Path $this.BackupPath -Directory | Sort-Object Name -Descending
        
        if ($backups.Count -gt $this.MaxBackups) {
            $toDelete = $backups | Select-Object -Skip $this.MaxBackups
            
            foreach ($backup in $toDelete) {
                try {
                    Remove-Item -Path $backup.FullName -Recurse -Force
                    if ($this.Logger) {
                        $this.Logger.Debug("Deleted old backup: $($backup.Name)")
                    }
                }
                catch {
                    if ($this.Logger) {
                        $this.Logger.Warning("Failed to delete backup: $($backup.Name) - $_")
                    }
                }
            }
        }
    }
    
    # Get backup size
    [long] GetBackupSize([string]$backupName) {
        $backupFullPath = Join-Path $this.BackupPath $backupName
        if (-not (Test-Path $backupFullPath)) {
            return 0
        }
        
        return (Get-ChildItem -Path $backupFullPath -Recurse -File | Measure-Object -Property Length -Sum).Sum
    }
}