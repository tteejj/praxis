# CommandService.ps1 - Command storage with group/command support
# NOTE: UniversalBackupManager is loaded by main SimpleTaskPro.ps1

class CommandService {
    [string]$DataFile
    [System.Collections.Generic.List[Command]]$Groups
    
    CommandService() {
        $this.DataFile = Join-Path $PSScriptRoot "../Data/commands.json"
        $this.Groups = [System.Collections.Generic.List[Command]]::new()
        $this.EnsureDataDirectory()
        
        # Initialize universal backup system
        [UniversalBackupManager]::Initialize((Join-Path $PSScriptRoot ".."))
        
        # Register auto-save for critical data protection
        $serviceInstance = $this  # Capture the current instance
        [UniversalBackupManager]::RegisterAutoSave(
            "commands", 
            $this.DataFile, 
            { $serviceInstance.Save() }.GetNewClosure(),
            "commands"
        )
        
        $this.Load()
    }
    
    [void] EnsureDataDirectory() {
        $dataDir = Split-Path $this.DataFile -Parent
        if (-not (Test-Path $dataDir)) {
            New-Item -ItemType Directory -Path $dataDir -Force | Out-Null
        }
    }
    
    [void] Load() {
        if (Test-Path $this.DataFile) {
            try {
                $json = Get-Content $this.DataFile -Raw
                $data = ConvertFrom-Json $json
                
                $this.Groups.Clear()
                
                # First pass: Load all groups and commands
                $groupMap = @{}
                foreach ($groupData in $data) {
                    $group = [Command]::new()
                    $group.Id = $groupData.Id
                    $group.Title = $groupData.Title
                    $group.Description = if ($groupData.Description) { $groupData.Description } else { "" }
                    $group.CommandText = if ($groupData.CommandText) { $groupData.CommandText } else { "" }
                    $group.GroupId = if ($groupData.GroupId) { $groupData.GroupId } else { "" }
                    $group.CommandsCollapsed = if ($groupData.CommandsCollapsed -ne $null) { $groupData.CommandsCollapsed } else { $false }
                    $group.SortOrder = if ($groupData.SortOrder -ne $null) { $groupData.SortOrder } else { 0 }
                    $group.Tags = if ($groupData.Tags) { $groupData.Tags } else { @() }
                    
                    if ($groupData.CreatedDate) {
                        $group.CreatedDate = [datetime]$groupData.CreatedDate
                    }
                    if ($groupData.ModifiedDate) {
                        $group.ModifiedDate = [datetime]$groupData.ModifiedDate
                    }
                    
                    $groupMap[$group.Id] = $group
                }
                
                # Second pass: Build hierarchy
                foreach ($group in $groupMap.Values) {
                    if ($group.IsGroup()) {
                        $this.Groups.Add($group)
                    } else {
                        # This is a command, find its parent group
                        $parentGroup = $groupMap[$group.GroupId]
                        if ($parentGroup) {
                            $parentGroup.Commands.Add($group)
                        }
                    }
                }
                
                # Sort groups and commands
                $this.SortGroups()
                
            } catch {
                Write-Warning "Failed to load commands: $_"
                $this.CreateDefaultGroups()
            }
        } else {
            $this.CreateDefaultGroups()
        }
    }
    
    [void] CreateDefaultGroups() {
        # Create some default groups and commands
        $gitGroup = [Command]::new("Git")
        $gitGroup.Description = "Git version control commands"
        
        $statusCmd = [Command]::new("Git Status")
        $statusCmd.CommandText = "git status"
        $statusCmd.Description = "Show working tree status"
        $statusCmd.Tags = @("git", "status")
        $gitGroup.AddCommand($statusCmd)
        
        $logCmd = [Command]::new("Git Log")
        $logCmd.CommandText = "git log --oneline -10"
        $logCmd.Description = "Show recent commits"
        $logCmd.Tags = @("git", "log", "history")
        $gitGroup.AddCommand($logCmd)
        
        $this.Groups.Add($gitGroup)
        
        $psGroup = [Command]::new("PowerShell")
        $psGroup.Description = "PowerShell system commands"
        
        $procCmd = [Command]::new("Get Processes")
        $procCmd.CommandText = "Get-Process | Sort-Object CPU -Descending | Select-Object -First 10"
        $procCmd.Description = "Show top CPU processes"
        $procCmd.Tags = @("powershell", "system", "processes")
        $psGroup.AddCommand($procCmd)
        
        $diskCmd = [Command]::new("Disk Usage")
        $diskCmd.CommandText = "Get-WmiObject -Class Win32_LogicalDisk | Select-Object DeviceID,Size,FreeSpace"
        $diskCmd.Description = "Show disk space usage"
        $diskCmd.Tags = @("powershell", "system", "disk")
        $psGroup.AddCommand($diskCmd)
        
        $this.Groups.Add($psGroup)
        
        $this.Save()
    }
    
    [void] Save() {
        try {
            # Flatten hierarchy for JSON storage
            $allItems = @()
            
            foreach ($group in $this.Groups) {
                $allItems += $group
                foreach ($command in $group.Commands) {
                    $allItems += $command
                }
            }
            
            $json = ConvertTo-Json $allItems -Depth 10
            Set-Content -Path $this.DataFile -Value $json -Encoding UTF8
            
        } catch {
            Write-Warning "Failed to save commands: $_"
        }
    }
    
    [void] SortGroups() {
        # Sort groups by SortOrder, then by Title
        $sortedGroups = $this.Groups | Sort-Object SortOrder, Title
        $this.Groups.Clear()
        foreach ($group in $sortedGroups) {
            $this.Groups.Add($group)
            
            # Sort commands within each group
            $sortedCommands = $group.Commands | Sort-Object SortOrder, Title
            $group.Commands.Clear()
            foreach ($command in $sortedCommands) {
                $group.Commands.Add($command)
            }
        }
    }
    
    # CRUD Operations
    [void] AddGroup([Command]$group) {
        if ($group.IsGroup()) {
            $this.Groups.Add($group)
            $this.SortGroups()
            $this.Save()
        }
    }
    
    [void] AddCommand([Command]$command, [string]$groupId) {
        "DEBUG: CommandService.AddCommand - Looking for group: $groupId" | Out-File -FilePath "./startup-debug.log" -Append
        $group = $this.GetGroup($groupId)
        if ($group) {
            "DEBUG: Found group: $($group.Title), adding command: $($command.Title)" | Out-File -FilePath "./startup-debug.log" -Append
            $group.AddCommand($command)
            "DEBUG: Command added to group, commands count now: $($group.Commands.Count)" | Out-File -FilePath "./startup-debug.log" -Append
            $this.SortGroups()
            $this.Save()
            "DEBUG: Saved commands to file" | Out-File -FilePath "./startup-debug.log" -Append
        } else {
            "DEBUG: ERROR - Group not found: $groupId" | Out-File -FilePath "./startup-debug.log" -Append
        }
    }
    
    [void] UpdateGroup([Command]$group) {
        $existing = $this.GetGroup($group.Id)
        if ($existing) {
            $existing.Title = $group.Title
            $existing.Description = $group.Description
            $existing.Tags = $group.Tags
            $existing.ModifiedDate = Get-Date
            $this.Save()
        }
    }
    
    [void] UpdateCommand([Command]$command) {
        $group = $this.GetGroup($command.GroupId)
        if ($group) {
            $existing = $group.Commands | Where-Object { $_.Id -eq $command.Id } | Select-Object -First 1
            if ($existing) {
                $existing.Title = $command.Title
                $existing.CommandText = $command.CommandText
                $existing.Description = $command.Description
                $existing.Tags = $command.Tags
                $existing.ModifiedDate = Get-Date
                $this.Save()
            }
        }
    }
    
    [void] DeleteGroup([string]$groupId) {
        $group = $this.GetGroup($groupId)
        if ($group) {
            $this.Groups.Remove($group)
            $this.Save()
        }
    }
    
    [void] DeleteCommand([string]$commandId) {
        foreach ($group in $this.Groups) {
            $command = $group.Commands | Where-Object { $_.Id -eq $commandId } | Select-Object -First 1
            if ($command) {
                $group.RemoveCommand($command)
                $this.Save()
                return
            }
        }
    }
    
    # Getters
    [Command] GetGroup([string]$groupId) {
        return $this.Groups | Where-Object { $_.Id -eq $groupId } | Select-Object -First 1
    }
    
    [Command] GetCommand([string]$commandId) {
        foreach ($group in $this.Groups) {
            $command = $group.Commands | Where-Object { $_.Id -eq $commandId } | Select-Object -First 1
            if ($command) {
                return $command
            }
        }
        return $null
    }
    
    [System.Collections.Generic.List[Command]] GetAllGroups() {
        return $this.Groups
    }
    
    # Movement operations (like TaskService)
    [void] MoveGroupUp([string]$groupId) {
        $group = $this.GetGroup($groupId)
        if ($group) {
            $index = $this.Groups.IndexOf($group)
            if ($index -gt 0) {
                $this.Groups.RemoveAt($index)
                $this.Groups.Insert($index - 1, $group)
                $this.UpdateSortOrders()
                $this.Save()
            }
        }
    }
    
    [void] MoveGroupDown([string]$groupId) {
        $group = $this.GetGroup($groupId)
        if ($group) {
            $index = $this.Groups.IndexOf($group)
            if ($index -ge 0 -and $index -lt ($this.Groups.Count - 1)) {
                $this.Groups.RemoveAt($index)
                $this.Groups.Insert($index + 1, $group)
                $this.UpdateSortOrders()
                $this.Save()
            }
        }
    }
    
    [void] MoveCommandUp([string]$commandId) {
        foreach ($group in $this.Groups) {
            $command = $group.Commands | Where-Object { $_.Id -eq $commandId } | Select-Object -First 1
            if ($command) {
                $index = $group.Commands.IndexOf($command)
                if ($index -gt 0) {
                    $group.Commands.RemoveAt($index)
                    $group.Commands.Insert($index - 1, $command)
                    $this.UpdateCommandSortOrders($group)
                    $this.Save()
                }
                return
            }
        }
    }
    
    [void] MoveCommandDown([string]$commandId) {
        foreach ($group in $this.Groups) {
            $command = $group.Commands | Where-Object { $_.Id -eq $commandId } | Select-Object -First 1
            if ($command) {
                $index = $group.Commands.IndexOf($command)
                if ($index -ge 0 -and $index -lt ($group.Commands.Count - 1)) {
                    $group.Commands.RemoveAt($index)
                    $group.Commands.Insert($index + 1, $command)
                    $this.UpdateCommandSortOrders($group)
                    $this.Save()
                }
                return
            }
        }
    }
    
    [void] UpdateSortOrders() {
        for ($i = 0; $i -lt $this.Groups.Count; $i++) {
            $this.Groups[$i].SortOrder = $i * 10
        }
    }
    
    [void] UpdateCommandSortOrders([Command]$group) {
        for ($i = 0; $i -lt $group.Commands.Count; $i++) {
            $group.Commands[$i].SortOrder = $i * 10
        }
    }
    
    # Clipboard operations
    [void] CopyToClipboard([string]$commandId) {
        $command = $this.GetCommand($commandId)
        if ($command -and $command.IsCommand()) {
            try {
                # Try to use system clipboard
                if ([System.Environment]::OSVersion.Platform -eq [System.PlatformID]::Win32NT) {
                    $command.CommandText | Set-Clipboard
                } else {
                    # Linux/Mac fallback
                    $command.CommandText | xclip -selection clipboard 2>$null
                }
            } catch {
                Write-Warning "Failed to copy to clipboard: $_"
            }
        }
    }
}