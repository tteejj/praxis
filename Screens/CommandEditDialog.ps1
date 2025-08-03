# CommandEditDialog.ps1 - Dialog for creating and editing commands using UnifiedDialog

class CommandEditDialog : UnifiedDialog {
    [Command]$Command
    [scriptblock]$OnSave
    
    CommandEditDialog() : base("Command Editor", 70, 18) {
        $this.InitializeFields()
    }
    
    CommandEditDialog([Command]$command) : base("Command Editor", 70, 18) {
        $this.Command = $command
        $this.InitializeFields()
    }
    
    [void] InitializeFields() {
        # Set default values based on whether we're editing or creating
        $defaultTitle = ""
        $defaultDescription = ""
        $defaultTags = ""
        $defaultGroup = ""
        $defaultCommand = ""
        
        if ($this.Command) {
            # Editing existing command
            $defaultTitle = $this.Command.Title
            $defaultDescription = $this.Command.Description
            $defaultTags = ($this.Command.Tags -join ", ")
            $defaultGroup = $this.Command.Group
            $defaultCommand = $this.Command.CommandText
        }
        
        # Add fields using simplified UnifiedDialog API
        $this.AddField("title", "Title (Optional)", $defaultTitle)
        $this.AddField("description", "Description (Optional)", $defaultDescription)
        $this.AddField("tags", "Tags (Optional, comma-separated)", $defaultTags)
        $this.AddField("group", "Group (Optional)", $defaultGroup)
        $this.AddField("command", "Command (Required)", $defaultCommand)
        
        # Set button labels
        $this.SetButtons("Save", "Cancel")
        
        # Set up submit handler with proper closure
        $dialog = $this
        $this.OnSubmit = { $dialog.SaveCommand() }.GetNewClosure()
    }
    
    [void] SaveCommand() {
        # Get command text and validate
        $commandText = $this.GetFieldValue("command").Trim()
        if ([string]::IsNullOrWhiteSpace($commandText)) {
            # Command text is required - for now just return
            return
        }
        
        # Get command service
        $commandService = $this.GetService("CommandService")
        if (-not $commandService) {
            return
        }
        
        try {
            # Parse tags
            $tagsText = $this.GetFieldValue("tags").Trim()
            $tags = @()
            if (-not [string]::IsNullOrWhiteSpace($tagsText)) {
                $tags = $tagsText -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' }
            }
            
            if ($this.Command) {
                # Update existing command
                $this.Command.Title = $this.GetFieldValue("title").Trim()
                $this.Command.Description = $this.GetFieldValue("description").Trim()
                $this.Command.Tags = $tags
                $this.Command.Group = $this.GetFieldValue("group").Trim()
                $this.Command.CommandText = $commandText
                
                $success = $commandService.UpdateCommand($this.Command)
                if (-not $success) {
                    if ($global:Logger) {
                        $global:Logger.Error("Failed to update command")
                    }
                    return
                }
            } else {
                # Create new command
                $this.Command = $commandService.AddCommand(
                    $this.GetFieldValue("title").Trim(),
                    $this.GetFieldValue("description").Trim(),
                    $tags,
                    $this.GetFieldValue("group").Trim(),
                    $commandText
                )
            }
            
            # Call save callback
            if ($this.OnSave) {
                & $this.OnSave $this.Command
            }
            
            # Manually refresh the command library screen instead of using events
            # Find the CommandLibraryScreen by type name to avoid loading order issues
            if ($global:ScreenManager -and $global:ScreenManager.Screens.Count -gt 0) {
                foreach ($screen in $global:ScreenManager.Screens) {
                    if ($screen.GetType().Name -eq "CommandLibraryScreen") {
                        $screen.LoadData()
                        break
                    }
                }
            }
            
            # Close dialog
            $this.Close()
            
        } catch {
            if ($global:Logger) {
                $global:Logger.Error("Failed to save command: $_")
            }
        }
    }
    
    # Override HandleScreenInput to add Ctrl+S shortcut
    [bool] HandleScreenInput([System.ConsoleKeyInfo]$key) {
        # Let base class handle standard dialog shortcuts first
        if (([UnifiedDialog]$this).HandleScreenInput($key)) {
            return $true
        }
        
        # Add Ctrl+S shortcut for save
        if ($key.Key -eq [System.ConsoleKey]::S -and ($key.Modifiers -band [ConsoleModifiers]::Control)) {
            $this.SaveCommand()
            return $true
        }
        
        return $false
    }
}