# CommandLibraryScreen.ps1 - Command library management screen using CRUDScreen base class

class CommandLibraryScreen : CRUDScreen {
    CommandLibraryScreen() : base("CommandService", "Command") {
        $this.Title = "Command Library"
    }
    
    # Override SetupDataGrid to use SearchableListBox instead of standard grid
    [void] SetupDataGrid() {
        # Create SearchableListBox for better command browsing
        $this.DataGrid = [SearchableListBox]::new()
        $this.DataGrid.Title = ""  # Don't show title in grid since screen has title
        $this.DataGrid.ShowBorder = $false   # Remove borders per requirements
        $this.DataGrid.SearchPrompt = "Search commands... (t:tag d:desc g:group +and |or)"
        
        # Set custom search filter for advanced syntax
        $service = $this.DataService
        $this.DataGrid.SearchFilter = {
            param($command, $query)
            $searchResults = $service.SearchCommands($query)
            return $searchResults -contains $command
        }.GetNewClosure()
        
        # Custom renderer for commands
        $this.DataGrid.ItemRenderer = {
            param($command)
            if (-not $command) { return "" }
            
            $displayText = $command.GetDisplayText()
            
            # Add usage count if > 0
            if ($command.UseCount -gt 0) {
                $displayText += " ★$($command.UseCount)"
            }
            
            return $displayText
        }
        
        # Handle selection changes (Enter key)
        $screen = $this
        $this.DataGrid.OnSelectionChanged = {
            $screen.CopySelectedCommand()
        }.GetNewClosure()
        
        $this.DataGrid.Initialize($global:ServiceContainer)
        $this.AddChild($this.DataGrid)
    }
    
    # Override LoadData to load commands
    [void] LoadData() {
        $commands = $this.DataService.GetAllCommands()
        $this.DataGrid.SetItems($commands)
        $this.DataGrid.Invalidate()
        $this.Invalidate()
    }
    
    # Override CRUD operations for command-specific behavior
    [void] NewItem() {
        try {
            $dialog = [CommandEditDialog]::new()
            $dialog.Initialize($this.ServiceContainer)
            
            $dialog.SetCommand($null)  # New command
            $global:ScreenManager.Push($dialog)
        } catch {
            if ($global:Logger) {
                $global:Logger.Error("CommandLibraryScreen.NewItem: $($_.Exception.Message)")
            }
        }
    }
    
    [void] EditItem() {
        $selectedCommand = $this.GetSelectedItem()
        if (-not $selectedCommand) { 
            if ($global:Logger) {
                $global:Logger.Warning("CommandLibraryScreen.EditItem: No command selected")
            }
            return 
        }
        
        try {
            $dialog = [CommandEditDialog]::new()
            $dialog.Initialize($this.ServiceContainer)
            
            $dialog.SetCommand($selectedCommand)
            $global:ScreenManager.Push($dialog)
        } catch {
            if ($global:Logger) {
                $global:Logger.Error("CommandLibraryScreen.EditItem: $($_.Exception.Message)")
            }
        }
    }
    
    # Override PerformDelete for command-specific behavior
    [void] PerformDelete($itemId) {
        $this.DataService.DeleteCommand($itemId)
    }
    
    # Command-specific methods
    [void] CopySelectedCommand() {
        $selectedCommand = $this.GetSelectedItem()
        if ($selectedCommand) {
            try {
                $this.DataService.CopyToClipboard($selectedCommand.Id)
                
                # Show toast notification
                $toastService = $this.ServiceContainer.GetService('ToastService')
                if ($toastService) {
                    $toastService.Show("Command copied to clipboard!", [ToastType]::Success, 2000)
                }
                
                if ($global:Logger) {
                    $global:Logger.Info("Copied to clipboard: $($selectedCommand.GetDisplayText())")
                }
                
                # Refresh the list to show updated usage count
                $this.LoadData()
            } catch {
                # Show error toast
                $toastService = $this.ServiceContainer.GetService('ToastService')
                if ($toastService) {
                    $toastService.Show("Failed to copy command", [ToastType]::Error, 3000)
                }
                
                if ($global:Logger) {
                    $global:Logger.Error("Failed to copy command: $($_.Exception.Message)")
                }
            }
        }
    }
    
    [void] RunCommand() {
        $selectedCommand = $this.GetSelectedItem()
        if (-not $selectedCommand) { 
            if ($global:Logger) {
                $global:Logger.Warning("CommandLibraryScreen.RunCommand: No command selected")
            }
            return 
        }
        
        try {
            # Execute the command
            if ($global:Logger) {
                $global:Logger.Debug("CommandLibraryScreen.RunCommand: Executing command '$($selectedCommand.Name)'")
            }
            
            # Commands in the library are typically stored as strings
            # We'll invoke them using Invoke-Expression
            $result = Invoke-Expression -Command $selectedCommand.Command
            
            # Show success toast
            $toastService = $this.ServiceContainer.GetService('ToastService')
            if ($toastService) {
                $toastService.Show("Command executed successfully!", [ToastType]::Success, 2000)
            }
            
            # Update usage count
            $this.DataService.IncrementUseCount($selectedCommand.Id)
            
            # Refresh the list to show updated usage count
            $this.LoadData()
            
        } catch {
            # Show error toast
            $toastService = $this.ServiceContainer.GetService('ToastService')
            if ($toastService) {
                $toastService.Show("Command failed: $($_.Exception.Message)", [ToastType]::Error, 3000)
            }
            
            if ($global:Logger) {
                $global:Logger.Error("CommandLibraryScreen.RunCommand: Error executing command '$($selectedCommand.Name)': $_")
            }
        }
    }
    
    # Override custom input handling for command-specific shortcuts
    [bool] HandleCustomInput([System.ConsoleKeyInfo]$keyInfo) {
        # Command library specific shortcuts
        switch ($keyInfo.KeyChar) {
            'r' { $this.RunCommand(); return $true }
        }
        
        # Override Enter to copy command instead of edit
        if ($keyInfo.Key -eq [System.ConsoleKey]::Enter) {
            $this.CopySelectedCommand()
            return $true
        }
        
        return $false  # Not handled
    }
    
    # Override DeleteItem to use UnifiedDialog
    [void] DeleteItem() {
        $selectedCommand = $this.GetSelectedItem()
        if (-not $selectedCommand) { 
            if ($global:Logger) {
                $global:Logger.Warning("CommandLibraryScreen.DeleteItem: No command selected")
            }
            return 
        }
        
        try {
            # Show confirmation dialog using UnifiedDialog
            $message = "Are you sure you want to delete this command?`n`n$($selectedCommand.GetDisplayText())"
            $dialog = [UnifiedDialog]::new("Delete Command", 60, 12)
            $dialog.AddField("message", "", $message)
            $dialog.SetReadOnlyField("message", $true)
            $dialog.SetButtons("Delete", "Cancel")
            
            $screen = $this
            $commandId = $selectedCommand.Id
            
            $dialog.OnPrimary = {
                $screen.PerformDelete($commandId)
                $screen.RefreshItems()
            }.GetNewClosure()
            
            if ($global:ScreenManager) {
                $global:ScreenManager.Push($dialog)
            }
        } catch {
            if ($global:Logger) {
                $global:Logger.Error("CommandLibraryScreen.DeleteItem: $($_.Exception.Message)")
            }
        }
    }
    
    # Compatibility methods
    [void] NewCommand() { $this.NewItem() }
    [void] EditCommand() { $this.EditItem() }
    [void] DeleteCommand() { $this.DeleteItem() }
    [void] LoadCommands() { $this.LoadData() }
    [void] FilterCommands() { $this.DataGrid.Invalidate() }
}