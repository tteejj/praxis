# CommandService.ps1 - Service for managing command library
# Handles JSON storage, CRUD operations, and clipboard functionality

class CommandService {
    [string]$DataPath
    [string]$BackupDirectory
    [System.Collections.ArrayList]$Commands
    [int]$MaxBackups = 10
    
    CommandService() {
        $this.DataPath = Join-Path $PSScriptRoot "../Data/commands.json"
        $this.BackupDirectory = Join-Path $PSScriptRoot "../Data/backups"
        $this.Commands = [System.Collections.ArrayList]::new()
        $this.EnsureDataDirectory()
        $this.LoadCommands()
    }
    
    [void] EnsureDataDirectory() {
        $dataDir = Split-Path $this.DataPath -Parent
        if (-not (Test-Path $dataDir)) {
            New-Item -ItemType Directory -Path $dataDir -Force | Out-Null
        }
        
        # Ensure backup directory exists
        if (-not (Test-Path $this.BackupDirectory)) {
            New-Item -ItemType Directory -Path $this.BackupDirectory -Force | Out-Null
        }
    }
    
    # Load commands from JSON file
    [void] LoadCommands() {
        try {
            if (Test-Path $this.DataPath) {
                $jsonContent = Get-Content $this.DataPath -Raw | ConvertFrom-Json
                $this.Commands.Clear()
                
                foreach ($commandData in $jsonContent) {
                    # Convert PSCustomObject to hashtable
                    $hashtable = @{}
                    $commandData.PSObject.Properties | ForEach-Object {
                        $hashtable[$_.Name] = $_.Value
                    }
                    $command = [Command]::FromHashtable($hashtable)
                    $this.Commands.Add($command) | Out-Null
                }
                
                Write-Host "Loaded $($this.Commands.Count) commands" -ForegroundColor Green
            } else {
                Write-Host "No existing commands file found, creating default commands" -ForegroundColor Yellow
                $this.CreateDefaultCommands()
            }
        } catch {
            Write-Host "Failed to load commands: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    
    # Create default commands for new installations
    [void] CreateDefaultCommands() {
        # PowerShell commands
        $this.AddCommand("Get running processes", "Get-Process", "Shows all running processes", @("powershell", "system"), "PowerShell")
        $this.AddCommand("List files detailed", "Get-ChildItem -Force", "Lists all files including hidden ones", @("powershell", "files"), "PowerShell")
        $this.AddCommand("Check disk space", "Get-WmiObject -Class Win32_LogicalDisk | Select-Object DeviceID, Size, FreeSpace", "Shows disk usage for all drives", @("powershell", "system"), "PowerShell")
        
        # Git commands
        $this.AddCommand("Git status", "git status", "Shows git repository status", @("git", "version-control"), "Git")
        $this.AddCommand("Git log oneline", "git log --oneline -10", "Shows last 10 commits in one line format", @("git", "history"), "Git")
        $this.AddCommand("Git branch list", "git branch -a", "Lists all branches including remote", @("git", "branch"), "Git")
        
        # Docker commands
        $this.AddCommand("Docker containers", "docker ps -a", "Lists all containers", @("docker", "containers"), "Docker")
        $this.AddCommand("Docker images", "docker images", "Lists all images", @("docker", "images"), "Docker")
        $this.AddCommand("Docker system info", "docker system df", "Shows docker disk usage", @("docker", "system"), "Docker")
        
        # Network commands
        $this.AddCommand("Test connection", "Test-NetConnection google.com", "Tests network connectivity", @("network", "test"), "Network")
        $this.AddCommand("Get IP config", "Get-NetIPConfiguration", "Shows network configuration", @("network", "config"), "Network")
        
        $this.SaveCommands()
        Write-Host "Created $($this.Commands.Count) default commands" -ForegroundColor Green
    }
    
    # Atomic save commands to JSON file with backup
    [void] SaveCommands() {
        try {
            $hashtables = $this.Commands | ForEach-Object { $_.ToHashtable() }
            $json = $hashtables | ConvertTo-Json -Depth 10
            
            # Atomic save: write to temp file first
            $tempFile = "$($this.DataPath).tmp"
            
            # Create backup before save if file exists
            if (Test-Path $this.DataPath) {
                $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
                $backupFile = Join-Path $this.BackupDirectory "commands_backup_$timestamp.json"
                Copy-Item -Path $this.DataPath -Destination $backupFile -Force
                
                # Keep only last N backups
                $this.CleanupBackups()
            }
            
            # Write to temp file
            [System.IO.File]::WriteAllText($tempFile, $json)
            
            # Atomic move from temp to final location
            Move-Item -Path $tempFile -Destination $this.DataPath -Force
            
            if ($global:Debug) {
                Write-Host "Commands saved successfully with backup" -ForegroundColor Green
            }
        } catch {
            Write-Host "Failed to save commands: $($_.Exception.Message)" -ForegroundColor Red
            
            # Clean up temp file if it exists
            $tempFile = "$($this.DataPath).tmp"
            if (Test-Path $tempFile) {
                Remove-Item -Path $tempFile -Force -ErrorAction SilentlyContinue
            }
            throw
        }
    }
    
    # CRUD Operations
    [Command] AddCommand([string]$title, [string]$commandText, [string]$description = "", [string[]]$tags = @(), [string]$group = "") {
        $command = [Command]::new()
        $command.Title = $title
        $command.CommandText = $commandText
        $command.Description = $description
        $command.Tags = $tags
        $command.Group = $group
        
        $this.Commands.Add($command) | Out-Null
        $this.SaveCommands()
        return $command
    }
    
    [void] UpdateCommand([Command]$command) {
        $existing = $this.GetCommandById($command.Id)
        if ($existing) {
            $index = $this.Commands.IndexOf($existing)
            $this.Commands[$index] = $command
            $this.SaveCommands()
        }
    }
    
    [void] DeleteCommand([string]$commandId) {
        $command = $this.GetCommandById($commandId)
        if ($command) {
            $this.Commands.Remove($command) | Out-Null
            $this.SaveCommands()
        }
    }
    
    [Command] GetCommandById([string]$id) {
        return $this.Commands | Where-Object { $_.Id -eq $id } | Select-Object -First 1
    }
    
    [Command[]] GetAllCommands() {
        return $this.Commands.ToArray()
    }
    
    [Command[]] SearchCommands([string]$query) {
        if ([string]::IsNullOrWhiteSpace($query)) {
            return $this.GetAllCommands()
        }
        
        return $this.ParseAndSearchCommands($query)
    }
    
    # Advanced search with tag syntax: tag:name, group:name, #tag, etc.
    [Command[]] ParseAndSearchCommands([string]$query) {
        $query = $query.Trim()
        
        # Check for special syntax
        if ($query.StartsWith("tag:") -or $query.StartsWith("t:")) {
            $tagName = $query.Substring($query.IndexOf(':') + 1).Trim()
            return $this.GetCommandsByTag($tagName)
        }
        
        if ($query.StartsWith("group:") -or $query.StartsWith("g:")) {
            $groupName = $query.Substring($query.IndexOf(':') + 1).Trim()
            return $this.GetCommandsByGroup($groupName)
        }
        
        if ($query.StartsWith("#")) {
            $tagName = $query.Substring(1).Trim()
            return $this.GetCommandsByTag($tagName)
        }
        
        # Regular text search
        $query = $query.ToLower()
        return $this.Commands | Where-Object {
            $_.Title.ToLower().Contains($query) -or
            $_.Description.ToLower().Contains($query) -or
            $_.CommandText.ToLower().Contains($query) -or
            $_.Group.ToLower().Contains($query) -or
            ($_.Tags | Where-Object { $_.ToLower().Contains($query) }).Count -gt 0
        }
    }
    
    # Clipboard operations
    [void] CopyToClipboard([string]$commandId) {
        $command = $this.GetCommandById($commandId)
        if ($command) {
            # Copy command text to clipboard
            $command.CommandText | Set-Clipboard
            
            # Update usage statistics
            $command.RecordUsage()
            $this.SaveCommands()
            
            Write-Host "Copied to clipboard: $($command.CommandText)" -ForegroundColor Green
        }
    }
    
    [void] IncrementUseCount([string]$commandId) {
        $command = $this.GetCommandById($commandId)
        if ($command) {
            $command.RecordUsage()
            $this.SaveCommands()
        }
    }
    
    # Get commands by group
    [Command[]] GetCommandsByGroup([string]$group) {
        if ([string]::IsNullOrWhiteSpace($group)) {
            return @()
        }
        return $this.Commands | Where-Object { $_.Group -ieq $group }
    }
    
    # Get commands by tag
    [Command[]] GetCommandsByTag([string]$tag) {
        if ([string]::IsNullOrWhiteSpace($tag)) {
            return @()
        }
        return $this.Commands | Where-Object { 
            $_.Tags | Where-Object { $_ -ieq $tag } 
        }
    }
    
    # Get commands with multiple tags (AND operation)
    [Command[]] GetCommandsByTags([string[]]$tags) {
        if ($tags.Count -eq 0) {
            return $this.GetAllCommands()
        }
        
        return $this.Commands | Where-Object {
            $command = $_
            $hasAllTags = $true
            foreach ($tag in $tags) {
                if (-not ($command.Tags | Where-Object { $_ -ieq $tag })) {
                    $hasAllTags = $false
                    break
                }
            }
            $hasAllTags
        }
    }
    
    # Get all unique groups
    [string[]] GetGroups() {
        return ($this.Commands | Where-Object { -not [string]::IsNullOrWhiteSpace($_.Group) } | ForEach-Object { $_.Group } | Sort-Object -Unique)
    }
    
    # Get all unique tags
    [string[]] GetTags() {
        $allTags = @()
        $this.Commands | ForEach-Object { $allTags += $_.Tags }
        return ($allTags | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Sort-Object -Unique)
    }
    
    # Get tag statistics
    [hashtable] GetTagStatistics() {
        $tagStats = @{}
        
        foreach ($command in $this.Commands) {
            foreach ($tag in $command.Tags) {
                if (-not [string]::IsNullOrWhiteSpace($tag)) {
                    if ($tagStats.ContainsKey($tag)) {
                        $tagStats[$tag]++
                    } else {
                        $tagStats[$tag] = 1
                    }
                }
            }
        }
        
        return $tagStats
    }
    
    # Get popular tags (by usage count)
    [string[]] GetPopularTags([int]$count = 10) {
        $tagStats = $this.GetTagStatistics()
        return ($tagStats.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First $count | ForEach-Object { $_.Key })
    }
    
    # Clean up tags (remove empty, trim whitespace, deduplicate)
    [void] CleanupTags([Command]$command) {
        $cleanTags = @()
        foreach ($tag in $command.Tags) {
            $trimmedTag = $tag.Trim()
            if (-not [string]::IsNullOrWhiteSpace($trimmedTag) -and $cleanTags -notcontains $trimmedTag) {
                $cleanTags += $trimmedTag
            }
        }
        $command.Tags = $cleanTags
    }
    
    # Suggest tags based on command text and existing tags
    [string[]] SuggestTags([string]$commandText, [string]$title = "", [string]$description = "") {
        $suggestions = @()
        $text = ($commandText + " " + $title + " " + $description).ToLower()
        
        # Technology/tool suggestions
        $toolMappings = @{
            "git" = @("git", "version-control", "vcs")
            "docker" = @("docker", "container", "devops")
            "npm" = @("npm", "node", "javascript", "package-manager")
            "pip" = @("pip", "python", "package-manager")
            "yarn" = @("yarn", "node", "javascript", "package-manager")
            "kubectl" = @("kubernetes", "k8s", "devops", "container")
            "aws" = @("aws", "cloud", "amazon")
            "azure" = @("azure", "cloud", "microsoft")
            "gcp" = @("gcp", "cloud", "google")
            "terraform" = @("terraform", "infrastructure", "iac")
            "ansible" = @("ansible", "automation", "configuration")
            "grep" = @("search", "text", "unix")
            "sed" = @("text", "processing", "unix")
            "awk" = @("text", "processing", "unix")
            "curl" = @("http", "api", "network")
            "wget" = @("download", "network")
            "ssh" = @("network", "remote", "security")
            "scp" = @("network", "file-transfer", "security")
            "rsync" = @("file-transfer", "backup", "sync")
            "systemctl" = @("systemd", "service", "linux")
            "powershell" = @("powershell", "windows", "script")
            "bash" = @("bash", "shell", "script")
        }
        
        foreach ($tool in $toolMappings.Keys) {
            if ($text.Contains($tool)) {
                $suggestions += $toolMappings[$tool]
            }
        }
        
        # Operation suggestions
        if ($text -match "(list|ls|get|show|display)") { $suggestions += "list" }
        if ($text -match "(create|new|add|make)") { $suggestions += "create" }
        if ($text -match "(delete|remove|rm)") { $suggestions += "delete" }
        if ($text -match "(update|modify|edit|change)") { $suggestions += "update" }
        if ($text -match "(install|setup)") { $suggestions += "install" }
        if ($text -match "(start|run|execute)") { $suggestions += "run" }
        if ($text -match "(stop|kill|terminate)") { $suggestions += "stop" }
        if ($text -match "(status|info|information)") { $suggestions += "info" }
        if ($text -match "(test|check|verify)") { $suggestions += "test" }
        if ($text -match "(deploy|deployment)") { $suggestions += "deploy" }
        if ($text -match "(backup|archive)") { $suggestions += "backup" }
        if ($text -match "(restore|recover)") { $suggestions += "restore" }
        if ($text -match "(monitor|watch|tail)") { $suggestions += "monitor" }
        if ($text -match "(search|find|grep)") { $suggestions += "search" }
        if ($text -match "(copy|cp|duplicate)") { $suggestions += "copy" }
        if ($text -match "(move|mv|rename)") { $suggestions += "move" }
        
        # Remove duplicates and return
        return ($suggestions | Sort-Object -Unique)
    }
    
    # Backup management
    [void] CleanupBackups() {
        try {
            $backups = Get-ChildItem -Path $this.BackupDirectory -Filter "commands_backup_*.json" | 
                       Sort-Object CreationTime -Descending
            
            if ($backups.Count -gt $this.MaxBackups) {
                $backupsToDelete = $backups | Select-Object -Skip $this.MaxBackups
                foreach ($backup in $backupsToDelete) {
                    Remove-Item -Path $backup.FullName -Force
                    if ($global:Debug) {
                        Write-Host "Removed old backup: $($backup.Name)" -ForegroundColor Yellow
                    }
                }
            }
        } catch {
            Write-Warning "Failed to cleanup backups: $($_.Exception.Message)"
        }
    }
    
    # Get available backups
    [object[]] GetBackups() {
        try {
            $backups = Get-ChildItem -Path $this.BackupDirectory -Filter "commands_backup_*.json" | 
                       Sort-Object CreationTime -Descending
            
            return $backups | ForEach-Object {
                @{
                    Name = $_.Name
                    Path = $_.FullName
                    Created = $_.CreationTime
                    Size = $_.Length
                }
            }
        } catch {
            return @()
        }
    }
    
    # Restore from backup
    [bool] RestoreFromBackup([string]$backupPath) {
        try {
            if (-not (Test-Path $backupPath)) {
                Write-Host "Backup file not found: $backupPath" -ForegroundColor Red
                return $false
            }
            
            # Create current backup before restore
            if (Test-Path $this.DataPath) {
                $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
                $preRestoreBackup = Join-Path $this.BackupDirectory "commands_pre_restore_$timestamp.json"
                Copy-Item -Path $this.DataPath -Destination $preRestoreBackup -Force
            }
            
            # Restore from backup
            Copy-Item -Path $backupPath -Destination $this.DataPath -Force
            
            # Reload commands
            $this.LoadCommands()
            
            Write-Host "Successfully restored from backup: $(Split-Path $backupPath -Leaf)" -ForegroundColor Green
            return $true
        } catch {
            Write-Host "Failed to restore from backup: $($_.Exception.Message)" -ForegroundColor Red
            return $false
        }
    }
    
    # Export commands to file
    [bool] ExportCommands([string]$exportPath) {
        try {
            $hashtables = $this.Commands | ForEach-Object { $_.ToHashtable() }
            $json = $hashtables | ConvertTo-Json -Depth 10
            
            # Use atomic save for export as well
            $tempFile = "$exportPath.tmp"
            [System.IO.File]::WriteAllText($tempFile, $json)
            Move-Item -Path $tempFile -Destination $exportPath -Force
            
            Write-Host "Commands exported to: $exportPath" -ForegroundColor Green
            return $true
        } catch {
            Write-Host "Failed to export commands: $($_.Exception.Message)" -ForegroundColor Red
            
            # Clean up temp file
            $tempFile = "$exportPath.tmp"
            if (Test-Path $tempFile) {
                Remove-Item -Path $tempFile -Force -ErrorAction SilentlyContinue
            }
            return $false
        }
    }
    
    # Import commands from file
    [bool] ImportCommands([string]$importPath, [bool]$merge = $true) {
        try {
            if (-not (Test-Path $importPath)) {
                Write-Host "Import file not found: $importPath" -ForegroundColor Red
                return $false
            }
            
            $jsonContent = Get-Content $importPath -Raw | ConvertFrom-Json
            $importedCommands = [System.Collections.ArrayList]::new()
            
            foreach ($commandData in $jsonContent) {
                # Convert PSCustomObject to hashtable
                $hashtable = @{}
                $commandData.PSObject.Properties | ForEach-Object {
                    $hashtable[$_.Name] = $_.Value
                }
                $command = [Command]::FromHashtable($hashtable)
                
                # Check for duplicates if merging
                if ($merge) {
                    $existing = $this.Commands | Where-Object { $_.CommandText -eq $command.CommandText }
                    if (-not $existing) {
                        $importedCommands.Add($command) | Out-Null
                    }
                } else {
                    $importedCommands.Add($command) | Out-Null
                }
            }
            
            if (-not $merge) {
                # Replace all commands
                $this.Commands.Clear()
            }
            
            # Add imported commands
            foreach ($command in $importedCommands) {
                $this.Commands.Add($command) | Out-Null
            }
            
            $this.SaveCommands()
            
            $action = if ($merge) { "merged" } else { "replaced" }
            Write-Host "Successfully imported $($importedCommands.Count) commands ($action)" -ForegroundColor Green
            return $true
        } catch {
            Write-Host "Failed to import commands: $($_.Exception.Message)" -ForegroundColor Red
            return $false
        }
    }
}