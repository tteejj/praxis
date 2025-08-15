# CommandEditDialog.ps1 - Dialog for creating and editing commands

class CommandEditDialog : SimpleDialog {
    [Command]$Command
    [CommandService]$CommandService
    [scriptblock]$OnSave
    
    CommandEditDialog([CommandService]$commandService) : base("Command Editor", 70, 20) {
        $this.CommandService = $commandService
        $this.InitializeFields()
    }
    
    CommandEditDialog([CommandService]$commandService, [Command]$command) : base("Command Editor", 70, 20) {
        $this.CommandService = $commandService
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
        
        # Add fields
        $this.AddField("title", "Title (Optional)", $defaultTitle)
        $this.AddField("description", "Description (Optional)", $defaultDescription)
        $this.AddField("tags", "Tags (comma-separated, #tag format)", $defaultTags)
        $this.AddField("group", "Group (Optional)", $defaultGroup)
        $this.AddField("command", "Command (Required)", $defaultCommand)
        
        # Show tag suggestions if creating new command
        if (-not $this.Command) {
            $this.AddField("suggestions", "Tag Suggestions (read-only)", "")
            $this.SetFieldReadOnly("suggestions", $true)
        }
        
        # Set button labels
        $this.SetButtons("Save", "Cancel")
        
        # Set up submit handler
        $dialog = $this
        $this.OnSubmit = { $dialog.SaveCommand() }.GetNewClosure()
    }
    
    [void] SaveCommand() {
        # Get command text and validate
        $commandText = $this.GetFieldValue("command").Trim()
        
        if ([string]::IsNullOrWhiteSpace($commandText)) {
            # Could show error message here
            return
        }
        
        # Create or update command
        if ($this.Command) {
            # Update existing command
            $this.Command.Title = $this.GetFieldValue("title").Trim()
            $this.Command.Description = $this.GetFieldValue("description").Trim()
            $this.Command.Group = $this.GetFieldValue("group").Trim()
            $this.Command.CommandText = $commandText
            
            # Parse tags
            $tagsText = $this.GetFieldValue("tags").Trim()
            if (-not [string]::IsNullOrWhiteSpace($tagsText)) {
                $this.Command.Tags = $tagsText -split "," | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }
            } else {
                $this.Command.Tags = @()
            }
            
            $this.CommandService.UpdateCommand($this.Command)
        } else {
            # Create new command
            $title = $this.GetFieldValue("title").Trim()
            $description = $this.GetFieldValue("description").Trim()
            $group = $this.GetFieldValue("group").Trim()
            
            # Parse tags
            $tagsText = $this.GetFieldValue("tags").Trim()
            $tags = @()
            if (-not [string]::IsNullOrWhiteSpace($tagsText)) {
                $tags = $tagsText -split "," | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }
            }
            
            $this.Command = $this.CommandService.AddCommand($title, $commandText, $description, $tags, $group)
        }
        
        # Clean up tags
        $this.CommandService.CleanupTags($this.Command)
        
        # Call callback if provided
        if ($this.OnSave) {
            $this.OnSave.Invoke($this.Command)
        }
    }
    
    # Update tag suggestions when command text changes
    [void] UpdateTagSuggestions() {
        if ($this.Command) { return }  # Only for new commands
        
        $commandText = $this.GetFieldValue("command")
        $title = $this.GetFieldValue("title")
        $description = $this.GetFieldValue("description")
        
        if (-not [string]::IsNullOrWhiteSpace($commandText)) {
            $suggestions = $this.CommandService.SuggestTags($commandText, $title, $description)
            if ($suggestions.Count -gt 0) {
                $suggestionText = "#" + ($suggestions -join " #")
                $this.SetFieldValue("suggestions", $suggestionText)
            }
        }
    }
    
    [void] SetCommand([Command]$command) {
        $this.Command = $command
        
        if ($command) {
            $this.SetFieldValue("title", $command.Title)
            $this.SetFieldValue("description", $command.Description)
            $this.SetFieldValue("tags", ($command.Tags -join ", "))
            $this.SetFieldValue("group", $command.Group)
            $this.SetFieldValue("command", $command.CommandText)
        }
    }
}