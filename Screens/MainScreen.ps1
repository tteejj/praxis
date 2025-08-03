# MainScreen.ps1 - Main screen with persistent menu navigation

class MainScreen : Screen {
    [Screen]$CurrentScreen
    [MinimalStatusBar]$StatusBar
    [EventBus]$EventBus
    [ContextPopup]$ActionPopup
    
    # Menu items in fixed order - using ordered hashtable for consistent display
    hidden [System.Collections.Specialized.OrderedDictionary]$MenuItems = [ordered]@{
        "Projects" = [ProjectsScreen]
        "Tasks" = [TaskScreen] 
        "Time Entry" = [TimeEntryScreen]
        "Files" = [FileBrowserScreen]
        "Commands" = [CommandLibraryScreen]
        "Macro Factory" = [VisualMacroFactoryScreen]
        "Settings" = [SettingsScreen]
    }
    
    hidden [hashtable]$ScreenInstances = @{}
    hidden [string]$CurrentScreenName = "Projects"
    
    MainScreen() : base() {
        $this.Title = "PRAXIS"
    }
    
    [void] OnInitialize() {
        if ($global:Logger) {
            $global:Logger.Debug("MainScreen.OnInitialize: Starting full-screen initialization")
        }
        
        # Create status bar
        $this.StatusBar = [MinimalStatusBar]::new()
        $this.StatusBar.Height = 1
        $this.AddChild($this.StatusBar)
        
        # Create action popup (but don't add as child yet)
        try {
            $this.ActionPopup = [ContextPopup]::new()
            if ($global:Logger) {
                $global:Logger.Debug("MainScreen.OnInitialize: ActionPopup created")
            }
            $this.ActionPopup.Initialize($this.ServiceContainer)
            if ($global:Logger) {
                $global:Logger.Debug("MainScreen.OnInitialize: ActionPopup initialized")
            }
        }
        catch {
            if ($global:Logger) {
                $global:Logger.Error("MainScreen.OnInitialize: Error creating ActionPopup: $_")
            }
        }
        
        # Initialize with first screen
        $this.SwitchToScreen("Projects")
        
        if ($global:Logger) {
            $global:Logger.Debug("MainScreen.OnInitialize: Full-screen initialization complete")
        }
    }
    
    [void] OnBoundsChanged() {
        if (-not $this.StatusBar) { return }
        
        # Full screen layout - no left panel
        $contentHeight = $this.Height - 1  # Reserve 1 line for status
        
        # Position current screen (full width)
        if ($this.CurrentScreen) {
            $this.CurrentScreen.SetBounds($this.X, $this.Y, $this.Width, $contentHeight)
        }
        
        # Position status bar (bottom)
        $this.StatusBar.SetBounds($this.X, $this.Y + $this.Height - 1, $this.Width, 1)
        
        ([Screen]$this).OnBoundsChanged()
    }
    
    [void] SwitchToScreen([string]$screenName) {
        if (-not $this.MenuItems.Contains($screenName)) {
            if ($global:Logger) {
                $global:Logger.Warning("MainScreen.SwitchToScreen: Unknown screen '$screenName'")
            }
            return
        }
        
        # Deactivate current screen
        if ($this.CurrentScreen) {
            $this.CurrentScreen.OnDeactivated()
            $this.RemoveChild($this.CurrentScreen)
        }
        
        # Get or create screen instance
        if (-not $this.ScreenInstances.ContainsKey($screenName)) {
            $screenType = $this.MenuItems[$screenName]
            $this.ScreenInstances[$screenName] = $screenType::new()
            $this.ScreenInstances[$screenName].Initialize($this.ServiceContainer)
        }
        
        # Activate new screen
        $this.CurrentScreen = $this.ScreenInstances[$screenName]
        $this.CurrentScreenName = $screenName
        $this.AddChild($this.CurrentScreen)
        
        # Update bounds and activate
        $this.OnBoundsChanged()
        $this.CurrentScreen.OnActivated()
        
        
        # Update status
        $this.UpdateStatusBar()
        
        if ($global:Logger) {
            $global:Logger.Debug("MainScreen.SwitchToScreen: Switched to '$screenName'")
        }
    }
    
    [bool] HandleScreenInput([System.ConsoleKeyInfo]$keyInfo) {
        # No menu navigation - just return false to let content handle input
        return $false
    }
    
    
    # FindFirstFocusable method removed - now using FocusManager.FocusFirst() for consistency

    [void] ShowActionPopup() {
        if ($global:Logger) {
            $global:Logger.Debug("MainScreen.ShowActionPopup: Showing action popup")
        }
        
        # Check if ActionPopup exists
        if (-not $this.ActionPopup) {
            if ($global:Logger) {
                $global:Logger.Error("MainScreen.ShowActionPopup: ActionPopup is null")
            }
            return
        }
        
        # Clear existing items and ensure popup is properly reset
        if ($this.ActionPopup.Items) {
            $this.ActionPopup.Items.Clear()
        }
        $this.ActionPopup.Title = "$($this.CurrentScreenName) Actions"
        $this.ActionPopup.SelectedIndex = 0
        
        # Ensure popup is not already a child before adding
        if ($this.Children.Contains($this.ActionPopup)) {
            $this.RemoveChild($this.ActionPopup)
            if ($global:Logger) {
                $global:Logger.Debug("MainScreen.ShowActionPopup: Removed existing ActionPopup from children")
            }
        }
        
        # Position popup near current focus (center-ish)
        $this.ActionPopup.X = [int]($this.Width * 0.4)
        $this.ActionPopup.Y = [int]($this.Height * 0.3)
        
        # Add ONLY screen-specific CRUD actions - no navigation fluff
        # Capture MainScreen reference for closures
        $mainScreen = $this
        
        switch ($this.CurrentScreenName) {
            "Projects" {
                $this.ActionPopup.AddItem("New Project (n)", { 
                    if ($global:Logger) { $global:Logger.Debug("MainScreen.ShowActionPopup: New Project action called") }
                    try {
                        $mainScreen.CurrentScreen.NewProject() 
                    } catch {
                        if ($global:Logger) { $global:Logger.Error("Error calling NewProject: $_") }
                    }
                }.GetNewClosure())
                $this.ActionPopup.AddItem("Edit Project (e)", { 
                    if ($global:Logger) { $global:Logger.Debug("MainScreen.ShowActionPopup: Edit Project action called") }
                    $mainScreen.CurrentScreen.EditProject() 
                }.GetNewClosure())
                $this.ActionPopup.AddItem("Delete Project (d)", { 
                    if ($global:Logger) { $global:Logger.Debug("MainScreen.ShowActionPopup: Delete Project action called") }
                    $mainScreen.CurrentScreen.DeleteProject() 
                }.GetNewClosure())
                $this.ActionPopup.AddItem("View Details (v)", { 
                    if ($global:Logger) { $global:Logger.Debug("MainScreen.ShowActionPopup: View Details action called") }
                    $mainScreen.CurrentScreen.ViewProjectDetails() 
                }.GetNewClosure())
            }
            "Time Entry" {
                $this.ActionPopup.AddItem("New Entry (n)", { 
                    $mainScreen.CurrentScreen.NewTimeEntry() 
                }.GetNewClosure())
                $this.ActionPopup.AddItem("Edit Entry (e)", { 
                    $mainScreen.CurrentScreen.EditSelectedEntry() 
                }.GetNewClosure())
                $this.ActionPopup.AddItem("Delete Entry (d)", { 
                    $mainScreen.CurrentScreen.DeleteSelectedEntry() 
                }.GetNewClosure())
                $this.ActionPopup.AddItem("Quick Entry (q)", { 
                    $mainScreen.CurrentScreen.ShowQuickEntry() 
                }.GetNewClosure())
            }
            "Tasks" {
                $this.ActionPopup.AddItem("New Task (n)", { 
                    $mainScreen.CurrentScreen.NewTask() 
                }.GetNewClosure())
                $this.ActionPopup.AddItem("Edit Task (e)", { 
                    $mainScreen.CurrentScreen.EditTask() 
                }.GetNewClosure())
                $this.ActionPopup.AddItem("Delete Task (d)", { 
                    $mainScreen.CurrentScreen.DeleteTask() 
                }.GetNewClosure())
                $this.ActionPopup.AddItem("Add Subtask (a)", { 
                    $mainScreen.CurrentScreen.AddSubtask() 
                }.GetNewClosure())
            }
            "Files" {
                $this.ActionPopup.AddItem("New File (n)", { 
                    $mainScreen.CurrentScreen.NewFile() 
                }.GetNewClosure())
                $this.ActionPopup.AddItem("Edit File (e)", { 
                    $mainScreen.CurrentScreen.EditFile() 
                }.GetNewClosure())
                $this.ActionPopup.AddItem("Delete File (d)", { 
                    $mainScreen.CurrentScreen.DeleteFile() 
                }.GetNewClosure())
                $this.ActionPopup.AddItem("Refresh (r)", { 
                    $mainScreen.CurrentScreen.RefreshFiles() 
                }.GetNewClosure())
            }
            "Commands" {
                $this.ActionPopup.AddItem("New Command (n)", { 
                    $mainScreen.CurrentScreen.NewCommand() 
                }.GetNewClosure())
                $this.ActionPopup.AddItem("Edit Command (e)", { 
                    $mainScreen.CurrentScreen.EditCommand() 
                }.GetNewClosure())
                $this.ActionPopup.AddItem("Delete Command (d)", { 
                    $mainScreen.CurrentScreen.DeleteCommand() 
                }.GetNewClosure())
                $this.ActionPopup.AddItem("Run Command (r)", { 
                    $mainScreen.CurrentScreen.RunCommand() 
                }.GetNewClosure())
            }
            "Macro Factory" {
                $this.ActionPopup.AddItem("New Macro (n)", { 
                    $mainScreen.CurrentScreen.NewMacro() 
                }.GetNewClosure())
                $this.ActionPopup.AddItem("Edit Macro (e)", { 
                    $mainScreen.CurrentScreen.EditMacro() 
                }.GetNewClosure())
                $this.ActionPopup.AddItem("Delete Macro (d)", { 
                    $mainScreen.CurrentScreen.DeleteMacro() 
                }.GetNewClosure())
                $this.ActionPopup.AddItem("Test Macro (t)", { 
                    $mainScreen.CurrentScreen.TestMacro() 
                }.GetNewClosure())
            }
            "Settings" {
                $this.ActionPopup.AddItem("Theme (t)", { 
                    $mainScreen.CurrentScreen.ChangeTheme() 
                }.GetNewClosure())
                $this.ActionPopup.AddItem("Export (e)", { 
                    $mainScreen.CurrentScreen.ExportSettings() 
                }.GetNewClosure())
                $this.ActionPopup.AddItem("Import (i)", { 
                    $mainScreen.CurrentScreen.ImportSettings() 
                }.GetNewClosure())
                $this.ActionPopup.AddItem("Reset (r)", { 
                    $mainScreen.CurrentScreen.ResetSettings() 
                }.GetNewClosure())
            }
            default {
                $this.ActionPopup.AddItem("No actions", {})
            }
        }
        
        # Handle popup events
        $this.ActionPopup.OnSelect = {
            param($selectedItem)
            # Action was already executed by popup
            if ($global:Logger) {
                $global:Logger.Debug("MainScreen.OnSelect: Item '$($selectedItem.Text)' was selected")
            }
            # Remove popup from children and restore focus using memory system
            $mainScreen.RemoveChild($mainScreen.ActionPopup)
            $focusManager = $mainScreen.ServiceContainer.GetService('FocusManager')
            if ($focusManager -and -not $focusManager.RestoreFocusContext()) {
                # Fallback if focus memory fails
                $mainScreen.SwitchFocusToContent()
            }
        }.GetNewClosure()
        
        $this.ActionPopup.OnCancel = {
            # Remove popup from children and restore focus using memory system
            $mainScreen.RemoveChild($mainScreen.ActionPopup)
            $focusManager = $mainScreen.ServiceContainer.GetService('FocusManager')
            if ($focusManager -and -not $focusManager.RestoreFocusContext()) {
                # Fallback if focus memory fails
                $mainScreen.SwitchFocusToContent()
            }
        }.GetNewClosure()
        
        # Save current focus context before showing popup
        $focusManager = $this.ServiceContainer.GetService('FocusManager')
        if ($focusManager) {
            $focusManager.SaveFocusContext("ActionPopup")
        }
        
        # Show the popup by adding it as a child and making it visible
        if (-not $this.Children.Contains($this.ActionPopup)) {
            $this.AddChild($this.ActionPopup)
        }
        $this.ActionPopup.Show()
        
        # Give focus to the popup so it can handle input
        if ($focusManager) {
            $focusManager.SetFocus($this.ActionPopup)
        }
        
        if ($global:Logger) {
            $global:Logger.Debug("MainScreen.ShowActionPopup: Action popup shown for '$($this.CurrentScreenName)'")
        }
    }
    
    [void] ShowScreenNavigationPopup() {
        if ($global:Logger) {
            $global:Logger.Debug("MainScreen.ShowScreenNavigationPopup: Creating screen navigation popup")
        }
        
        # Create new popup for screen navigation
        $this.ActionPopup = [ContextPopup]::new()
        $this.ActionPopup.Initialize($this.ServiceContainer)
        $this.ActionPopup.Title = "Navigate to Screen"
        
        # Store reference for closure
        $mainScreen = $this
        
        # Add menu items for screen navigation
        $index = 1
        foreach ($screenName in $this.MenuItems.Keys) {
            $displayName = "$index. $screenName"
            # Capture screen name in closure
            $targetScreenName = $screenName
            $this.ActionPopup.AddItem($displayName, {
                if ($global:Logger) {
                    $global:Logger.Debug("MainScreen.ShowScreenNavigationPopup: Navigating to '$targetScreenName'")
                }
                $mainScreen.SwitchToScreen($targetScreenName)
            }.GetNewClosure())
            $index++
        }
        
        # Handle popup events
        $this.ActionPopup.OnSelect = {
            param($selectedItem)
            # Action was already executed by popup
            if ($global:Logger) {
                $global:Logger.Debug("MainScreen.OnSelect: Screen '$($selectedItem.Text)' was selected")
            }
            # Remove popup from children and restore focus
            $mainScreen.RemoveChild($mainScreen.ActionPopup)
            $focusManager = $mainScreen.ServiceContainer.GetService('FocusManager')
            if ($focusManager -and -not $focusManager.RestoreFocusContext()) {
                # Fallback if focus memory fails
                $mainScreen.SwitchFocusToContent()
            }
        }.GetNewClosure()
        
        $this.ActionPopup.OnCancel = {
            # Remove popup from children and restore focus
            $mainScreen.RemoveChild($mainScreen.ActionPopup)
            $focusManager = $mainScreen.ServiceContainer.GetService('FocusManager')
            if ($focusManager -and -not $focusManager.RestoreFocusContext()) {
                # Fallback if focus memory fails
                $mainScreen.SwitchFocusToContent()
            }
        }.GetNewClosure()
        
        # Save current focus context before showing popup
        $focusManager = $this.ServiceContainer.GetService('FocusManager')
        if ($focusManager) {
            $focusManager.SaveFocusContext("ScreenNavigationPopup")
        }
        
        # Show the popup by adding it as a child and making it visible
        if (-not $this.Children.Contains($this.ActionPopup)) {
            $this.AddChild($this.ActionPopup)
        }
        $this.ActionPopup.Show()
        
        # Give focus to the popup so it can handle input
        if ($focusManager) {
            $focusManager.SetFocus($this.ActionPopup)
        }
        
        if ($global:Logger) {
            $global:Logger.Debug("MainScreen.ShowScreenNavigationPopup: Screen navigation popup shown")
        }
    }
    
    [void] UpdateStatusBar() {
        if ($this.StatusBar) {
            $this.StatusBar.LeftText = $this.CurrentScreenName
            $this.StatusBar.CenterText = "/ actions | ? screens | Navigation keys available"
            $this.StatusBar.RightText = Get-Date -Format "HH:mm"
        }
    }
    
    [void] OnActivated() {
        ([Screen]$this).OnActivated()
        
        # Set initial focus to current screen
        if ($this.CurrentScreen) {
            $focusManager = $this.ServiceContainer.GetService('FocusManager')
            if ($focusManager) {
                $focusManager.FocusFirst($this.CurrentScreen)
            }
        }
        
        $this.UpdateStatusBar()
        
        if ($global:Logger) {
            $global:Logger.Debug("MainScreen.OnActivated: Full-screen MainScreen activated")
        }
    }
    
    # Override to handle focus delegation properly following island architecture
    [bool] HandleInput([System.ConsoleKeyInfo]$keyInfo) {
        # Priority 0: Action popup gets absolute priority when visible
        if ($this.ActionPopup -and $this.ActionPopup.IsVisible) {
            if ($global:Logger) {
                $global:Logger.Debug("MainScreen.HandleInput: ActionPopup is visible, delegating key '$($keyInfo.KeyChar)' to popup")
            }
            $handled = $this.ActionPopup.HandleInput($keyInfo)
            if ($handled) {
                return $true
            }
            # If popup didn't handle it (e.g., letter key), it's now hidden
            # Continue processing the key
        }
        
        # Priority 1: Handle global shortcuts (like / for action popup)
        if ($keyInfo.KeyChar -eq '/' -and $this.CurrentScreen) {
            if ($global:Logger) {
                $global:Logger.Debug("MainScreen.HandleInput: / key pressed, calling ShowActionPopup")
            }
            $this.ShowActionPopup()
            $this.UpdateStatusBar()
            return $true
        }
        
        # Handle ? (Shift+/) for screen navigation
        if ($keyInfo.KeyChar -eq '?') {
            if ($global:Logger) {
                $global:Logger.Debug("MainScreen.HandleInput: ? key pressed, calling ShowScreenNavigationPopup")
            }
            $this.ShowScreenNavigationPopup()
            $this.UpdateStatusBar()
            return $true
        }
        
        if ($keyInfo.Key -eq [System.ConsoleKey]::Escape) {
            # If ActionPopup is visible, let it handle Escape first
            if ($this.ActionPopup -and $this.ActionPopup.IsVisible) {
                # The popup will handle Escape and call OnCancel which removes it
                return $false  # Let popup handle it
            }
            # No menu to switch to - let content handle escape
            return $false
        }
        
        # Priority 2: The single focused component gets the first chance to handle the key
        $focusManager = $this.ServiceContainer.GetService('FocusManager')
        $focused = $focusManager.GetFocused()
        
        if ($focused -and $this.ContainsElement($focused) -and $focused.HandleInput($keyInfo)) {
            $this.UpdateStatusBar()
            return $true # The focused component handled it. We are done.
        }
        
        # Priority 3: If the component ignored it, check for screen-level shortcuts
        if ($this.HandleScreenInput($keyInfo)) {
            $this.UpdateStatusBar()
            return $true # The screen's shortcut handled it. We are done.
        }
        
        # Priority 4: Delegate to current screen
        if ($global:Logger) {
            $global:Logger.Debug("MainScreen.HandleInput: CurrentScreen=$($this.CurrentScreen -ne $null), Key='$($keyInfo.KeyChar)'")
        }
        if ($this.CurrentScreen) {
            # First try the screen's HandleScreenInput method (for shortcuts like n, e, d)
            if ($this.CurrentScreen.PSObject.Methods['HandleScreenInput']) {
                if ($global:Logger) {
                    $global:Logger.Debug("MainScreen.HandleInput: Delegating '$($keyInfo.KeyChar)' to $($this.CurrentScreenName).HandleScreenInput()")
                }
                $handled = $this.CurrentScreen.HandleScreenInput($keyInfo)
                if ($handled) {
                    if ($global:Logger) {
                        $global:Logger.Debug("MainScreen.HandleInput: $($this.CurrentScreenName).HandleScreenInput() handled the key")
                    }
                    $this.UpdateStatusBar()
                    return $true
                }
            }
            
            # Then try the screen's general HandleInput method
            $handled = $this.CurrentScreen.HandleInput($keyInfo)
            if ($handled) {
                $this.UpdateStatusBar()
                return $true
            }
        }
        
        return $false
    }
    
    [bool] ContainsElement($element) {
        # Check if element is in current screen
        if ($this.CurrentScreen -and $this.IsElementInScreen($element, $this.CurrentScreen)) { return $true }
        return $false
    }
    
    [bool] IsElementInScreen($element, $screen) {
        if ($element -eq $screen) { return $true }
        if ($screen.PSObject.Properties['Children']) {
            foreach ($child in $screen.Children) {
                if ($this.IsElementInScreen($element, $child)) { return $true }
            }
        }
        return $false
    }
}