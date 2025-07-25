# CommandLibraryScreen.ps1 - Command library management screen
# Browse, search, and manage reusable command strings with clipboard copy

class CommandLibraryScreen : Screen {
    [SearchableListBox]$CommandList
    [TextBox]$SearchBox
    [Button]$AddButton
    [Button]$EditButton
    [Button]$DeleteButton
    [Button]$HelpButton
    [CommandService]$CommandService
    
    CommandLibraryScreen() : base() {
        $this.Title = "Command Library"
        $this.DrawBackground = $true
    }
    
    [void] OnInitialize() {
        ([Screen]$this).OnInitialize()
        
        # Get services
        $this.CommandService = $this.ServiceContainer.GetService("CommandService")
        
        # Create search box
        $this.SearchBox = [TextBox]::new()
        $this.SearchBox.X = 2
        $this.SearchBox.Y = 2
        $this.SearchBox.Width = $this.Width - 20
        $this.SearchBox.Height = 3
        $this.SearchBox.Placeholder = "Search commands... (t:tag d:desc g:group +and |or)"
        $this.SearchBox.OnChange = { $this.FilterCommands() }
        $this.AddChild($this.SearchBox)
        
        # Create help button  
        $this.HelpButton = [Button]::new("?")
        $this.HelpButton.X = $this.Width - 15
        $this.HelpButton.Y = 2
        $this.HelpButton.Width = 5
        $this.HelpButton.Height = 3
        $this.HelpButton.OnClick = { $this.ShowSearchHelp() }
        $this.AddChild($this.HelpButton)
        
        # Create command list
        $this.CommandList = [SearchableListBox]::new()
        $this.CommandList.X = 2
        $this.CommandList.Y = 6
        $this.CommandList.Width = $this.Width - 4
        $this.CommandList.Height = $this.Height - 12
        $this.CommandList.ShowBorder = $true
        $this.CommandList.Title = "Commands"
        
        # Custom renderer for commands
        $this.CommandList.ItemRenderer = {
            param($command)
            if (-not $command) { return "" }
            
            $displayText = $command.GetDisplayText()
            
            # Add usage count if > 0
            if ($command.UseCount -gt 0) {
                $displayText += " ★$($command.UseCount)"
            }
            
            return $displayText
        }
        
        # Custom detail renderer
        $this.CommandList.DetailRenderer = {
            param($command)
            if (-not $command) { return "" }
            
            $details = @()
            
            if (-not [string]::IsNullOrWhiteSpace($command.Description)) {
                $details += $command.Description
            }
            
            if ($command.Tags -and $command.Tags.Count -gt 0) {
                $details += "Tags: $($command.Tags -join ', ')"
            }
            
            # Show command text (truncated if too long)
            $commandText = $command.CommandText
            if ($commandText.Length -gt 100) {
                $commandText = $commandText.Substring(0, 97) + "..."
            }
            $details += "Command: $commandText"
            
            return ($details -join " | ")
        }
        
        # Handle selection/copy
        $this.CommandList.OnSelectionChanged = {
            $this.UpdateButtons()
        }
        
        $this.AddChild($this.CommandList)
        
        # Create action buttons
        $buttonY = $this.Height - 5
        $buttonSpacing = 12
        $startX = 2
        
        $this.AddButton = [Button]::new("Add")
        $this.AddButton.X = $startX
        $this.AddButton.Y = $buttonY
        $this.AddButton.Width = 8
        $this.AddButton.OnClick = { $this.AddCommand() }
        $this.AddChild($this.AddButton)
        
        $this.EditButton = [Button]::new("Edit")
        $this.EditButton.X = $startX + $buttonSpacing
        $this.EditButton.Y = $buttonY
        $this.EditButton.Width = 8
        $this.EditButton.OnClick = { $this.EditCommand() }
        $this.AddChild($this.EditButton)
        
        $this.DeleteButton = [Button]::new("Delete")
        $this.DeleteButton.X = $startX + ($buttonSpacing * 2)
        $this.DeleteButton.Y = $buttonY
        $this.DeleteButton.Width = 8
        $this.DeleteButton.OnClick = { $this.DeleteCommand() }
        $this.AddChild($this.DeleteButton)
        
        # Load commands
        $this.LoadCommands()
        $this.UpdateButtons()
        
        # Set initial focus
        $this.SetFocus($this.SearchBox)
    }
    
    [void] LoadCommands() {
        $commands = $this.CommandService.GetAllCommands()
        $this.CommandList.SetItems($commands)
    }
    
    [void] FilterCommands() {
        $query = $this.SearchBox.Text
        $filteredCommands = $this.CommandService.SearchCommands($query)
        $this.CommandList.SetItems($filteredCommands)
        $this.UpdateButtons()
    }
    
    [void] UpdateButtons() {
        $hasSelection = $this.CommandList.GetSelectedItem() -ne $null
        # Buttons stay the same text, but could be disabled/enabled based on selection
        # For now, just keep them always enabled
    }
    
    [void] AddCommand() {
        try {
            $screen = $this.ScreenManager.GetScreen("CommandEditDialog")
            if (-not $screen) {
                $screen = [CommandEditDialog]::new()
                $screen.Initialize($this.ServiceContainer)
                $this.ScreenManager.RegisterScreen("CommandEditDialog", $screen)
            }
            
            $screen.SetCommand($null)  # New command
            $screen.OnSave = {
                param($command)
                $this.LoadCommands()
                $this.FilterCommands()
            }
            
            $this.ScreenManager.PushScreen($screen)
        } catch {
            if ($global:Logger) {
                $global:Logger.Error("CommandLibraryScreen.AddCommand: $($_.Exception.Message)")
            }
        }
    }
    
    [void] EditCommand() {
        $selectedCommand = $this.CommandList.GetSelectedItem()
        if (-not $selectedCommand) { return }
        
        try {
            $screen = $this.ScreenManager.GetScreen("CommandEditDialog")
            if (-not $screen) {
                $screen = [CommandEditDialog]::new()
                $screen.Initialize($this.ServiceContainer)
                $this.ScreenManager.RegisterScreen("CommandEditDialog", $screen)
            }
            
            $screen.SetCommand($selectedCommand)
            $screen.OnSave = {
                param($command)
                $this.LoadCommands()
                $this.FilterCommands()
            }
            
            $this.ScreenManager.PushScreen($screen)
        } catch {
            if ($global:Logger) {
                $global:Logger.Error("CommandLibraryScreen.EditCommand: $($_.Exception.Message)")
            }
        }
    }
    
    [void] DeleteCommand() {
        $selectedCommand = $this.CommandList.GetSelectedItem()
        if (-not $selectedCommand) { return }
        
        try {
            # Show confirmation dialog
            $confirmScreen = [ConfirmationDialog]::new()
            $confirmScreen.Initialize($this.ServiceContainer)
            $confirmScreen.SetTitle("Delete Command")
            $confirmScreen.SetMessage("Are you sure you want to delete this command?`n`n$($selectedCommand.GetDisplayText())")
            $confirmScreen.OnConfirm = {
                $this.CommandService.DeleteCommand($selectedCommand.Id)
                $this.LoadCommands()
                $this.FilterCommands()
            }
            
            $this.ScreenManager.PushScreen($confirmScreen)
        } catch {
            if ($global:Logger) {
                $global:Logger.Error("CommandLibraryScreen.DeleteCommand: $($_.Exception.Message)")
            }
        }
    }
    
    [void] CopySelectedCommand() {
        $selectedCommand = $this.CommandList.GetSelectedItem()
        if ($selectedCommand) {
            try {
                $this.CommandService.CopyToClipboard($selectedCommand.Id)
                
                # Show brief confirmation (could be a toast notification)
                if ($global:Logger) {
                    $global:Logger.Info("Copied to clipboard: $($selectedCommand.GetDisplayText())")
                }
                
                # Refresh the list to show updated usage count
                $this.LoadCommands()
                $this.FilterCommands()
            } catch {
                if ($global:Logger) {
                    $global:Logger.Error("Failed to copy command: $($_.Exception.Message)")
                }
            }
        }
    }
    
    [void] ShowSearchHelp() {
        $helpText = @"
Search Syntax Help:

Basic Search:
  git status          - Search titles (default)

Specific Fields:
  t:powershell        - Search tags only
  d:database          - Search descriptions only  
  g:scripts           - Search groups only

OR Logic (|):
  t:git|powershell    - Tags: git OR powershell
  d:query|select      - Description: query OR select

AND Logic (+):
  +t:git +d:status    - Tags: git AND description: status
  +g:scripts +t:ps    - Group: scripts AND tags: ps

Mixed:
  +g:database t:sql|mysql  - Group: database AND (tags: sql OR mysql)

Examples:
  git                 - Find commands with 'git' in title
  t:powershell        - Find commands tagged 'powershell'
  +g:database +t:sql  - Find database commands tagged 'sql'
  d:backup|restore    - Find commands with 'backup' or 'restore' in description
"@
        
        # Show help dialog (could create a simple text dialog)
        try {
            $helpScreen = [TextInputDialog]::new()
            $helpScreen.Initialize($this.ServiceContainer)
            $helpScreen.SetTitle("Search Syntax Help")
            $helpScreen.SetText($helpText)
            $helpScreen.ReadOnly = $true
            
            $this.ScreenManager.PushScreen($helpScreen)
        } catch {
            if ($global:Logger) {
                $global:Logger.Error("CommandLibraryScreen.ShowSearchHelp: $($_.Exception.Message)")
            }
        }
    }
    
    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        # Handle Enter to copy selected command
        if ($key.Key -eq [System.ConsoleKey]::Enter) {
            if ($this.CommandList.IsFocused) {
                $this.CopySelectedCommand()
                return $true
            }
        }
        
        # Handle Ctrl+C to copy
        if ($key.Key -eq [System.ConsoleKey]::C -and $key.Modifiers -band [System.ConsoleModifiers]::Control) {
            $this.CopySelectedCommand()
            return $true
        }
        
        # Handle F1 for help
        if ($key.Key -eq [System.ConsoleKey]::F1) {
            $this.ShowSearchHelp()
            return $true
        }
        
        # Handle Ctrl+N for new command
        if ($key.Key -eq [System.ConsoleKey]::N -and $key.Modifiers -band [System.ConsoleModifiers]::Control) {
            $this.AddCommand()
            return $true
        }
        
        # Handle Delete key
        if ($key.Key -eq [System.ConsoleKey]::Delete) {
            if ($this.CommandList.IsFocused) {
                $this.DeleteCommand()
                return $true
            }
        }
        
        # Handle F2 for edit
        if ($key.Key -eq [System.ConsoleKey]::F2) {
            $this.EditCommand()
            return $true
        }
        
        return ([Screen]$this).HandleInput($key)
    }
    
    [string] GetHelpText() {
        return @"
Command Library Help:

Enter/Ctrl+C  - Copy selected command to clipboard
Ctrl+N        - Add new command
F2            - Edit selected command  
Delete        - Delete selected command
F1            - Show search syntax help
Escape        - Return to main menu
Tab           - Navigate between elements

Search supports advanced syntax - press '?' for details.
"@
    }
}