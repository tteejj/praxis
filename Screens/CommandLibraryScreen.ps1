# CommandLibraryScreen.ps1 - Command library management screen
# Browse, search, and manage reusable command strings with clipboard copy

class CommandLibraryScreen : Screen {
    [SearchableListBox]$CommandList
    [CommandService]$CommandService
    [EventBus]$EventBus
    hidden [hashtable]$EventSubscriptions = @{}
    
    CommandLibraryScreen() : base() {
        $this.Title = "Command Library"
        $this.DrawBackground = $true
    }
    
    [void] OnInitialize() {
        # Get services
        $this.CommandService = $this.ServiceContainer.GetService("CommandService")
        $this.EventBus = $this.ServiceContainer.GetService('EventBus')
        
        # Create command list using SearchableListBox
        $this.CommandList = [SearchableListBox]::new()
        $this.CommandList.Title = "Commands"
        $this.CommandList.ShowBorder = $true
        $this.CommandList.SearchPrompt = "Search commands... (t:tag d:desc g:group +and |or)"
        
        # Set custom search filter for advanced syntax
        $service = $this.CommandService
        $this.CommandList.SearchFilter = {
            param($command, $query)
            $searchResults = $service.SearchCommands($query)
            return $searchResults -contains $command
        }.GetNewClosure()
        
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
        
        # Handle selection changes
        $this.CommandList.OnSelectionChanged = {
            # Could update UI state here if needed
        }
        
        $this.CommandList.Initialize($this.ServiceContainer)
        $this.AddChild($this.CommandList)
        
        # Load commands
        $this.LoadCommands()
        
        # Register shortcuts
        $this.RegisterShortcuts()
        
        # Set initial focus to command list
        if ($this.CommandList) {
            $this.CommandList.Focus()
        }
    }
    
    [void] LoadCommands() {
        $commands = $this.CommandService.GetAllCommands()
        $this.CommandList.SetItems($commands)
    }
    
    [void] FilterCommands() {
        # Apply any active search filter
        # SearchableListBox handles its own filtering, so this is just for refresh
        $this.CommandList.Invalidate()
    }
    
    [void] RegisterShortcuts() {
        $shortcutManager = $this.ServiceContainer.GetService('ShortcutManager')
        if (-not $shortcutManager) { 
            if ($global:Logger) {
                $global:Logger.Warning("CommandLibraryScreen: ShortcutManager not found in ServiceContainer")
            }
            return 
        }
        
        # Register screen-specific shortcuts
        $screen = $this
        
        $shortcutManager.RegisterShortcut(@{
            Id = "commands.new"
            Name = "New Command"
            Description = "Create a new command"
            KeyChar = 'n'
            Scope = [ShortcutScope]::Screen
            ScreenType = "CommandLibraryScreen"
            Priority = 50
            Action = { $screen.NewCommand() }.GetNewClosure()
        })
        
        $shortcutManager.RegisterShortcut(@{
            Id = "commands.edit"
            Name = "Edit Command"
            Description = "Edit the selected command"
            KeyChar = 'e'
            Scope = [ShortcutScope]::Screen
            ScreenType = "CommandLibraryScreen"
            Priority = 50
            Action = { $screen.EditCommand() }.GetNewClosure()
        })
        
        $shortcutManager.RegisterShortcut(@{
            Id = "commands.delete"
            Name = "Delete Command"
            Description = "Delete the selected command"
            KeyChar = 'd'
            Scope = [ShortcutScope]::Screen
            ScreenType = "CommandLibraryScreen"
            Priority = 50
            Action = { $screen.DeleteCommand() }.GetNewClosure()
        })
        
        $shortcutManager.RegisterShortcut(@{
            Id = "commands.copy"
            Name = "Copy Command"
            Description = "Copy selected command to clipboard"
            Key = [System.ConsoleKey]::Enter
            Scope = [ShortcutScope]::Screen
            ScreenType = "CommandLibraryScreen"
            Priority = 50
            Action = { $screen.CopySelectedCommand() }.GetNewClosure()
        })
    }
    
    [void] NewCommand() {
        if ($global:Logger) {
            $global:Logger.Info("CommandLibraryScreen.NewCommand: Called via shortcut")
        }
        try {
            $screen = [CommandEditDialog]::new()
            $screen.Initialize($this.ServiceContainer)
            
            $screen.SetCommand($null)  # New command
            $parentScreen = $this
            $screen.OnSave = {
                param($command)
                $parentScreen.LoadCommands()
                $parentScreen.FilterCommands()
            }.GetNewClosure()
            
            $global:ScreenManager.Push($screen)
        } catch {
            if ($global:Logger) {
                $global:Logger.Error("CommandLibraryScreen.NewCommand: $($_.Exception.Message)")
            }
        }
    }
    
    [void] EditCommand() {
        if ($global:Logger) {
            $global:Logger.Info("CommandLibraryScreen.EditCommand: Called via shortcut")
        }
        $selectedCommand = $this.CommandList.GetSelectedItem()
        if (-not $selectedCommand) { 
            if ($global:Logger) {
                $global:Logger.Warning("CommandLibraryScreen.EditCommand: No command selected")
            }
            return 
        }
        
        try {
            $screen = [CommandEditDialog]::new()
            $screen.Initialize($this.ServiceContainer)
            
            $screen.SetCommand($selectedCommand)
            $parentScreen = $this
            $screen.OnSave = {
                param($command)
                $parentScreen.LoadCommands()
                $parentScreen.FilterCommands()
            }.GetNewClosure()
            
            $global:ScreenManager.Push($screen)
        } catch {
            if ($global:Logger) {
                $global:Logger.Error("CommandLibraryScreen.EditCommand: $($_.Exception.Message)")
            }
        }
    }
    
    [void] DeleteCommand() {
        if ($global:Logger) {
            $global:Logger.Info("CommandLibraryScreen.DeleteCommand: Called via shortcut")
        }
        $selectedCommand = $this.CommandList.GetSelectedItem()
        if (-not $selectedCommand) { 
            if ($global:Logger) {
                $global:Logger.Warning("CommandLibraryScreen.DeleteCommand: No command selected")
            }
            return 
        }
        
        try {
            # Show confirmation dialog
            $message = "Are you sure you want to delete this command?`n`n$($selectedCommand.GetDisplayText())"
            $confirmScreen = [ConfirmationDialog]::new($message)
            $confirmScreen.Title = "Delete Command"
            $confirmScreen.Initialize($this.ServiceContainer)
            $confirmScreen.OnPrimary = {
                $this.CommandService.DeleteCommand($selectedCommand.Id)
                $this.LoadCommands()
                $this.FilterCommands()
            }.GetNewClosure()
            
            $global:ScreenManager.Push($confirmScreen)
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
                
                # Show toast notification
                $toastService = $this.ServiceContainer.GetService('ToastService')
                if ($toastService) {
                    $toastService.ShowToast("Command copied to clipboard!", [ToastType]::Success, 2000)
                }
                
                if ($global:Logger) {
                    $global:Logger.Info("Copied to clipboard: $($selectedCommand.GetDisplayText())")
                }
                
                # Refresh the list to show updated usage count
                $this.LoadCommands()
                $this.FilterCommands()
            } catch {
                # Show error toast
                $toastService = $this.ServiceContainer.GetService('ToastService')
                if ($toastService) {
                    $toastService.ShowToast("Failed to copy command", [ToastType]::Error, 3000)
                }
                
                if ($global:Logger) {
                    $global:Logger.Error("Failed to copy command: $($_.Exception.Message)")
                }
            }
        }
    }
    
    # Search help removed - SearchableListBox should handle this
    
    # HandleInput removed - using ShortcutManager instead
    
    [void] OnBoundsChanged() {
        if ($this.Width -le 0 -or $this.Height -le 0) { return }
        
        # CommandLibraryScreen has a single CommandList that takes the full area
        if ($this.CommandList) {
            $this.CommandList.SetBounds(0, 0, $this.Width, $this.Height)
        }
    }
    
    [void] OnActivated() {
        # Set focus when screen becomes active
        if ($this.CommandList) {
            $this.CommandList.Focus()
        }
    }
    
    [bool] HandleScreenInput([System.ConsoleKeyInfo]$keyInfo) {
        # Route to ShortcutManager for screen-specific shortcuts
        $shortcutManager = $this.ServiceContainer.GetService('ShortcutManager')
        if ($shortcutManager) {
            return $shortcutManager.HandleKeyPress($keyInfo, $this.GetType().Name, "")
        }
        return $false
    }
    
    [string] GetHelpText() {
        return @"
# Command Library Help

Store and manage reusable IDEA commands and scripts.

## Navigation
Tab               - Navigate between elements
Arrow Keys        - Browse commands
Enter             - Copy command to clipboard

## Actions
n                 - Add new command
e                 - Edit selected command  
d                 - Delete selected command
Escape            - Return to main menu

## Search Syntax
The search box supports advanced filtering:

Basic search      - Type any text to search all fields
t:tag             - Search by tag (e.g., t:export)
d:description     - Search in descriptions
g:group           - Filter by group
+                 - AND operator (all terms must match)
|                 - OR operator (any term matches)

## Examples
t:export          - Find all export commands
g:analysis +sum   - Analysis group AND contains "sum"
t:idea|script     - Tagged as "idea" OR "script"

## Usage Count
★                 - Shows how many times used

---
Press ESC to close help
"@
    }
}