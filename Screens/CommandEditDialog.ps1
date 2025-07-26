# CommandEditDialog.ps1 - Dialog for creating and editing commands
# Handles all CRUD operations for command library entries

class CommandEditDialog : Screen {
    [MinimalTextBox]$TitleBox
    [MinimalTextBox]$DescriptionBox
    [MinimalTextBox]$TagsBox
    [MinimalTextBox]$GroupBox
    [MinimalTextBox]$CommandBox
    [MinimalButton]$SaveButton
    [MinimalButton]$CancelButton
    [Command]$Command
    [CommandService]$CommandService
    [scriptblock]$OnSave
    
    CommandEditDialog() : base() {
        $this.Title = "Command Editor"
        $this.DrawBackground = $true
    }
    
    [void] OnInitialize() {
        # Get services
        $this.CommandService = $this.ServiceContainer.GetService("CommandService")
        
        # Create title field
        $this.TitleBox = [MinimalTextBox]::new()
        $this.TitleBox.Placeholder = "Optional: Display name for the command"
        $this.TitleBox.Initialize($global:ServiceContainer)
        $this.AddChild($this.TitleBox)
        
        # Create description field
        $this.DescriptionBox = [MinimalTextBox]::new()
        $this.DescriptionBox.Placeholder = "Optional: What this command does"
        $this.DescriptionBox.Initialize($global:ServiceContainer)
        $this.AddChild($this.DescriptionBox)
        
        # Create tags field
        $this.TagsBox = [MinimalTextBox]::new()
        $this.TagsBox.Placeholder = "Optional: Comma-separated tags (git, powershell, etc.)"
        $this.TagsBox.Initialize($global:ServiceContainer)
        $this.AddChild($this.TagsBox)
        
        # Create group field
        $this.GroupBox = [MinimalTextBox]::new()
        $this.GroupBox.Placeholder = "Optional: Category/group name"
        $this.GroupBox.Initialize($global:ServiceContainer)
        $this.AddChild($this.GroupBox)
        
        # Create command field
        $this.CommandBox = [MinimalTextBox]::new()
        $this.CommandBox.Placeholder = "REQUIRED: The command text to copy to clipboard"
        $this.CommandBox.Initialize($global:ServiceContainer)
        $this.AddChild($this.CommandBox)
        
        # Create buttons
        $this.SaveButton = [MinimalButton]::new("Save")
        $dialog = $this
        $this.SaveButton.OnClick = { $dialog.SaveCommand() }.GetNewClosure()
        $this.SaveButton.Initialize($global:ServiceContainer)
        $this.AddChild($this.SaveButton)
        
        $this.CancelButton = [MinimalButton]::new("Cancel")
        $this.CancelButton.OnClick = { $dialog.Cancel() }.GetNewClosure()
        $this.CancelButton.Initialize($global:ServiceContainer)
        $this.AddChild($this.CancelButton)
        
        # Set initial focus
        $this.TitleBox.Focus()
    }
    
    [void] OnBoundsChanged() {
        if ($this.Width -le 0 -or $this.Height -le 0) { return }
        
        # Position components vertically with some spacing
        $margin = 2
        $fieldHeight = 3
        $spacing = 1
        $currentY = $margin
        
        # Title field
        if ($this.TitleBox) {
            $this.TitleBox.SetBounds($margin, $currentY, $this.Width - $margin * 2, $fieldHeight)
            $currentY += $fieldHeight + $spacing
        }
        
        # Description field
        if ($this.DescriptionBox) {
            $this.DescriptionBox.SetBounds($margin, $currentY, $this.Width - $margin * 2, $fieldHeight)
            $currentY += $fieldHeight + $spacing
        }
        
        # Tags field
        if ($this.TagsBox) {
            $this.TagsBox.SetBounds($margin, $currentY, $this.Width - $margin * 2, $fieldHeight)
            $currentY += $fieldHeight + $spacing
        }
        
        # Group field
        if ($this.GroupBox) {
            $this.GroupBox.SetBounds($margin, $currentY, $this.Width - $margin * 2, $fieldHeight)
            $currentY += $fieldHeight + $spacing
        }
        
        # Command field
        if ($this.CommandBox) {
            $this.CommandBox.SetBounds($margin, $currentY, $this.Width - $margin * 2, $fieldHeight)
            $currentY += $fieldHeight + $spacing * 2
        }
        
        # Buttons at bottom
        $buttonWidth = 10
        $buttonHeight = 3
        $buttonY = $this.Height - $buttonHeight - 1
        
        if ($this.SaveButton) {
            $this.SaveButton.SetBounds($this.Width - $buttonWidth * 2 - 3, $buttonY, $buttonWidth, $buttonHeight)
        }
        
        if ($this.CancelButton) {
            $this.CancelButton.SetBounds($this.Width - $buttonWidth - 1, $buttonY, $buttonWidth, $buttonHeight)
        }
    }
    
    [void] SetCommand([Command]$command) {
        $this.Command = $command
        
        if ($command) {
            # Editing existing command
            $this.Title = "Edit Command"
            $this.TitleBox.SetText($command.Title)
            $this.DescriptionBox.SetText($command.Description)
            $this.TagsBox.SetText(($command.Tags -join ", "))
            $this.GroupBox.SetText($command.Group)
            $this.CommandBox.SetText($command.CommandText)
        } else {
            # Creating new command
            $this.Title = "Add Command"
            $this.TitleBox.SetText("")
            $this.DescriptionBox.SetText("")
            $this.TagsBox.SetText("")
            $this.GroupBox.SetText("")
            $this.CommandBox.SetText("")
        }
    }
    
    [void] SaveCommand() {
        try {
            # Check if required components are initialized
            if (-not $this.CommandBox) {
                if ($global:Logger) {
                    $global:Logger.Error("CommandBox is null")
                }
                return
            }
            
            if (-not $this.CommandService) {
                if ($global:Logger) {
                    $global:Logger.Error("CommandService is null")
                }
                return
            }
            
            # Validate required field
            $commandText = $this.CommandBox.Text.Trim()
            if ([string]::IsNullOrWhiteSpace($commandText)) {
                # Show error or just return - command text is required
                if ($global:Logger) {
                    $global:Logger.Warning("Command text is required")
                }
                return
            }
            
            # Parse tags
            $tagsText = $this.TagsBox.Text.Trim()
            $tags = @()
            if (-not [string]::IsNullOrWhiteSpace($tagsText)) {
                $tags = $tagsText -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' }
            }
            
            if ($this.Command) {
                # Update existing command
                $this.Command.Title = $this.TitleBox.Text.Trim()
                $this.Command.Description = $this.DescriptionBox.Text.Trim()
                $this.Command.Tags = $tags
                $this.Command.Group = $this.GroupBox.Text.Trim()
                $this.Command.CommandText = $commandText
                
                $success = $this.CommandService.UpdateCommand($this.Command)
                if (-not $success) {
                    if ($global:Logger) {
                        $global:Logger.Error("Failed to update command")
                    }
                    return
                }
            } else {
                # Create new command
                $this.Command = $this.CommandService.AddCommand(
                    $this.TitleBox.Text.Trim(),
                    $this.DescriptionBox.Text.Trim(),
                    $tags,
                    $this.GroupBox.Text.Trim(),
                    $commandText
                )
            }
            
            # Call save callback
            if ($this.OnSave) {
                & $this.OnSave $this.Command
            }
            
            # Close dialog
            if ($global:ScreenManager) {
                $global:ScreenManager.Pop()
            }
            
        } catch {
            if ($global:Logger) {
                $global:Logger.Error("CommandEditDialog.SaveCommand: $($_.Exception.Message)")
            }
        }
    }
    
    [void] Cancel() {
        # Close dialog by popping from screen stack
        if ($global:ScreenManager) {
            $global:ScreenManager.Pop()
        }
    }
    
    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        # Handle Ctrl+S to save
        if ($key.Key -eq [System.ConsoleKey]::S -and $key.Modifiers -band [System.ConsoleModifiers]::Control) {
            $this.SaveCommand()
            return $true
        }
        
        # Handle Escape to cancel
        if ($key.Key -eq [System.ConsoleKey]::Escape) {
            $this.Cancel()
            return $true
        }
        
        return $false
    }
    
    # Labels will be shown via placeholder text for now
    
    [string] GetHelpText() {
        return @"
Command Editor Help:

Ctrl+S    - Save command
Escape    - Cancel and close
Tab       - Navigate between fields

Fields:
- Title: Optional display name
- Description: Optional description  
- Tags: Optional comma-separated tags
- Group: Optional category/group
- Command: REQUIRED - text to copy to clipboard

Only the Command field is required. All others are optional.
"@
    }
}