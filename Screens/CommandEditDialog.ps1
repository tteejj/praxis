# CommandEditDialog.ps1 - Dialog for creating and editing commands
# Handles all CRUD operations for command library entries

class CommandEditDialog : BaseDialog {
    [MinimalTextBox]$TitleBox
    [MinimalTextBox]$DescriptionBox
    [MinimalTextBox]$TagsBox
    [MinimalTextBox]$GroupBox
    [MinimalTextBox]$CommandBox
    [Command]$Command
    [CommandService]$CommandService
    [scriptblock]$OnSave
    
    CommandEditDialog() : base("Command Editor") {
        $this.DialogWidth = 70
        $this.DialogHeight = 20
        $this.PrimaryButtonText = "Save"
        $this.SecondaryButtonText = "Cancel"
    }
    
    [void] InitializeContent() {
        # Get services
        $this.CommandService = $this.ServiceContainer.GetService("CommandService")
        
        # Create title field
        $this.TitleBox = [MinimalTextBox]::new()
        $this.TitleBox.Placeholder = "Optional: Display name for the command"
        $this.TitleBox.ShowBorder = $false  # Dialog provides the border
        $this.TitleBox.Height = 1
        $this.AddContentControl($this.TitleBox, 1)
        
        # Create description field
        $this.DescriptionBox = [MinimalTextBox]::new()
        $this.DescriptionBox.Placeholder = "Optional: What this command does"
        $this.DescriptionBox.ShowBorder = $false  # Dialog provides the border
        $this.DescriptionBox.Height = 1
        $this.AddContentControl($this.DescriptionBox, 1)
        
        # Create tags field
        $this.TagsBox = [MinimalTextBox]::new()
        $this.TagsBox.Placeholder = "Optional: Comma-separated tags (git, powershell, etc.)"
        $this.TagsBox.ShowBorder = $false  # Dialog provides the border
        $this.TagsBox.Height = 1
        $this.AddContentControl($this.TagsBox, 1)
        
        # Create group field
        $this.GroupBox = [MinimalTextBox]::new()
        $this.GroupBox.Placeholder = "Optional: Category/group name"
        $this.GroupBox.ShowBorder = $false  # Dialog provides the border
        $this.GroupBox.Height = 1
        $this.AddContentControl($this.GroupBox, 1)
        
        # Create command field
        $this.CommandBox = [MinimalTextBox]::new()
        $this.CommandBox.Placeholder = "REQUIRED: The command text to copy to clipboard"
        $this.CommandBox.ShowBorder = $false  # Dialog provides the border
        $this.CommandBox.Height = 3  # Multi-line for commands
        $this.AddContentControl($this.CommandBox, 3)
        
        # Set up primary action handler
        $dialog = $this
        $this.OnPrimary = {
            $dialog.SaveCommand()
        }.GetNewClosure()
        
        # OnCancel is automatically handled by BaseDialog's OnSecondary
    }
    
    [void] PositionContentControls([int]$dialogX, [int]$dialogY) {
        # Position fields vertically
        $padding = $this.DialogPadding
        $currentY = $dialogY + 2  # Start after title
        $inputWidth = $this.DialogWidth - ($padding * 2)
        
        # Title field
        $currentY += 1
        $this.TitleBox.SetBounds(
            $dialogX + $padding,
            $currentY,
            $inputWidth,
            1
        )
        $currentY += 2
        
        # Description field
        $currentY += 1
        $this.DescriptionBox.SetBounds(
            $dialogX + $padding,
            $currentY,
            $inputWidth,
            1
        )
        $currentY += 2
        
        # Tags field
        $currentY += 1
        $this.TagsBox.SetBounds(
            $dialogX + $padding,
            $currentY,
            $inputWidth,
            1
        )
        $currentY += 2
        
        # Group field
        $currentY += 1
        $this.GroupBox.SetBounds(
            $dialogX + $padding,
            $currentY,
            $inputWidth,
            1
        )
        $currentY += 2
        
        # Command field (multi-line)
        $currentY += 1
        $this.CommandBox.SetBounds(
            $dialogX + $padding,
            $currentY,
            $inputWidth,
            3
        )
    }
    
    [void] SetCommand([Command]$command) {
        $this.Command = $command
        
        if ($command) {
            # Editing existing command
            # Title is already set in dialog title
            $this.TitleBox.SetText($command.Title)
            $this.DescriptionBox.SetText($command.Description)
            $this.TagsBox.SetText(($command.Tags -join ", "))
            $this.GroupBox.SetText($command.Group)
            $this.CommandBox.SetText($command.CommandText)
        } else {
            # Creating new command
            # Title is already set in dialog title
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
            $this.CloseDialog()
            
        } catch {
            if ($global:Logger) {
                $global:Logger.Error("CommandEditDialog.SaveCommand: $($_.Exception.Message)")
            }
        }
    }
    
    # Override HandleScreenInput to add Ctrl+S shortcut
    [bool] HandleScreenInput([System.ConsoleKeyInfo]$key) {
        # Let base class handle standard dialog shortcuts first
        if (([BaseDialog]$this).HandleScreenInput($key)) {
            return $true
        }
        
        # Add Ctrl+S shortcut for save
        if ($key.Key -eq [System.ConsoleKey]::S -and ($key.Modifiers -band [ConsoleModifiers]::Control)) {
            $this.SaveCommand()
            return $true
        }
        
        return $false
    }
    
    [string] OnRender() {
        $sb = Get-PooledStringBuilder 2048
        
        # First render the base dialog
        $baseRender = ([BaseDialog]$this).OnRender()
        $sb.Append($baseRender)
        
        # Render field labels
        $labelColor = $this.Theme.GetColor("dialog.title")
        $padding = $this.DialogPadding
        
        # Title label
        $sb.Append([VT]::MoveTo($this._dialogBounds.X + $padding, $this.TitleBox.Y - 1))
        $sb.Append($labelColor)
        $sb.Append("Title:")
        $sb.Append([VT]::Reset())
        
        # Description label
        $sb.Append([VT]::MoveTo($this._dialogBounds.X + $padding, $this.DescriptionBox.Y - 1))
        $sb.Append($labelColor)
        $sb.Append("Description:")
        $sb.Append([VT]::Reset())
        
        # Tags label
        $sb.Append([VT]::MoveTo($this._dialogBounds.X + $padding, $this.TagsBox.Y - 1))
        $sb.Append($labelColor)
        $sb.Append("Tags:")
        $sb.Append([VT]::Reset())
        
        # Group label
        $sb.Append([VT]::MoveTo($this._dialogBounds.X + $padding, $this.GroupBox.Y - 1))
        $sb.Append($labelColor)
        $sb.Append("Group:")
        $sb.Append([VT]::Reset())
        
        # Command label
        $sb.Append([VT]::MoveTo($this._dialogBounds.X + $padding, $this.CommandBox.Y - 1))
        $sb.Append($labelColor)
        $sb.Append("Command (Required):")
        $sb.Append([VT]::Reset())
        
        $result = $sb.ToString()
        Return-PooledStringBuilder $sb
        return $result
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