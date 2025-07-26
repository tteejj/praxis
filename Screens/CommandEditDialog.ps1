# CommandEditDialog.ps1 - Dialog for creating and editing commands
# Handles all CRUD operations for command library entries

class CommandEditDialog : BaseDialog {
    [TextBox]$TitleBox
    [TextBox]$DescriptionBox
    [TextBox]$TagsBox
    [TextBox]$GroupBox
    [TextBox]$CommandBox
    [Command]$Command
    [CommandService]$CommandService
    [scriptblock]$OnSave
    
    CommandEditDialog() : base("Command Editor", 80, 25) {
        # Constructor uses BaseDialog(title, width, height)
    }
    
    [void] OnInitialize() {
        ([BaseDialog]$this).OnInitialize()
        
        # Get services
        $this.CommandService = $this.ServiceContainer.GetService("CommandService")
        
        # Calculate positions
        $labelWidth = 12
        $fieldX = $labelWidth + 3
        $fieldWidth = $this.DialogWidth - $fieldX - 3
        $currentY = 3
        
        # Title field
        $this.CreateLabel("Title:", 2, $currentY)
        $this.TitleBox = [TextBox]::new()
        $this.TitleBox.X = $fieldX
        $this.TitleBox.Y = $currentY
        $this.TitleBox.Width = $fieldWidth
        $this.TitleBox.Placeholder = "Optional: Display name for the command"
        $this.AddChild($this.TitleBox)
        $currentY += 4
        
        # Description field
        $this.CreateLabel("Description:", 2, $currentY)
        $this.DescriptionBox = [TextBox]::new()
        $this.DescriptionBox.X = $fieldX
        $this.DescriptionBox.Y = $currentY
        $this.DescriptionBox.Width = $fieldWidth
        $this.DescriptionBox.Placeholder = "Optional: What this command does"
        $this.AddChild($this.DescriptionBox)
        $currentY += 4
        
        # Tags field
        $this.CreateLabel("Tags:", 2, $currentY)
        $this.TagsBox = [TextBox]::new()
        $this.TagsBox.X = $fieldX
        $this.TagsBox.Y = $currentY
        $this.TagsBox.Width = $fieldWidth
        $this.TagsBox.Placeholder = "Optional: Comma-separated tags (git, powershell, etc.)"
        $this.AddChild($this.TagsBox)
        $currentY += 4
        
        # Group field
        $this.CreateLabel("Group:", 2, $currentY)
        $this.GroupBox = [TextBox]::new()
        $this.GroupBox.X = $fieldX
        $this.GroupBox.Y = $currentY
        $this.GroupBox.Width = $fieldWidth
        $this.GroupBox.Placeholder = "Optional: Category/group name"
        $this.AddChild($this.GroupBox)
        $currentY += 4
        
        # Command field (required)
        $this.CreateLabel("Command:", 2, $currentY)
        $this.CommandBox = [TextBox]::new()
        $this.CommandBox.X = $fieldX
        $this.CommandBox.Y = $currentY
        $this.CommandBox.Width = $fieldWidth
        $this.CommandBox.Placeholder = "REQUIRED: The command text to copy to clipboard"
        $this.AddChild($this.CommandBox)
        $currentY += 4
        
        # Configure BaseDialog buttons
        $this.PrimaryButtonText = "Save"
        $this.SecondaryButtonText = "Cancel"
        $this.OnPrimary = { $this.SaveCommand() }
        $this.OnSecondary = { $this.Cancel() }
        
        # Set initial focus
        $this.TitleBox.Focus()
    }
    
    [void] CreateLabel([string]$text, [int]$x, [int]$y) {
        # Helper method to create labels - could be implemented as a simple text render
        # For now, we'll handle this in the rendering
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
            $this.ScreenManager.PopScreen()
            
        } catch {
            if ($global:Logger) {
                $global:Logger.Error("CommandEditDialog.SaveCommand: $($_.Exception.Message)")
            }
        }
    }
    
    [void] Cancel() {
        $this.ScreenManager.PopScreen()
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
        
        return ([BaseDialog]$this).HandleInput($key)
    }
    
    # Override OnRender to draw labels
    [string] OnRender() {
        $baseRender = ([BaseDialog]$this).OnRender()
        
        # Add labels - this is a simple approach
        # In a more sophisticated implementation, labels would be proper UI elements
        $sb = [System.Text.StringBuilder]::new()
        $sb.Append($baseRender)
        
        # Get theme colors
        $theme = $this.ServiceContainer.GetService("ThemeManager")
        if ($theme) {
            $labelColor = $theme.GetColor("foreground")
            $requiredColor = $theme.GetColor("accent")
            
            # Draw labels
            $sb.Append([VT]::MoveTo($this.X + 2, $this.Y + 3))
            $sb.Append($labelColor)
            $sb.Append("Title:")
            
            $sb.Append([VT]::MoveTo($this.X + 2, $this.Y + 7))
            $sb.Append($labelColor)
            $sb.Append("Description:")
            
            $sb.Append([VT]::MoveTo($this.X + 2, $this.Y + 11))
            $sb.Append($labelColor)
            $sb.Append("Tags:")
            
            $sb.Append([VT]::MoveTo($this.X + 2, $this.Y + 15))
            $sb.Append($labelColor)
            $sb.Append("Group:")
            
            $sb.Append([VT]::MoveTo($this.X + 2, $this.Y + 19))
            $sb.Append($requiredColor)
            $sb.Append("Command:")
            
            $sb.Append([VT]::Reset())
        }
        
        return $sb.ToString()
    }
    
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