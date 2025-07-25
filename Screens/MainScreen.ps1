# MainScreen.ps1 - Main screen with tab container

class MainScreen : Screen {
    [TabContainer]$TabContainer
    [CommandPalette]$CommandPalette
    [EventBus]$EventBus
    hidden [string]$TabChangedSubscription
    
    MainScreen() : base() {
        $this.Title = "PRAXIS"
    }
    
    [void] OnInitialize() {
        # Get EventBus
        $this.EventBus = $global:ServiceContainer.GetService('EventBus')
        
        # Subscribe to tab change events  
        if ($this.EventBus) {
            # Use string directly to avoid potential class loading issues
            $this.TabChangedSubscription = $this.EventBus.Subscribe('navigation.tabChanged', {
                param($sender, $eventData)
                if ($eventData.TabIndex -ne $null -and $this.TabContainer) {
                    $this.TabContainer.ActivateTab($eventData.TabIndex)
                    $this.RequestRender()
                }
            }.GetNewClosure())
        }
        
        # Create tab container
        $this.TabContainer = [TabContainer]::new()
        $this.TabContainer.Initialize($global:ServiceContainer)
        $this.AddChild($this.TabContainer)
        
        # Add real screens as tabs
        if ($global:Logger) {
            $global:Logger.Debug("MainScreen: Adding tabs to TabContainer")
        }
        
        $projectsScreen = [ProjectsScreen]::new()
        $this.TabContainer.AddTab("Projects", $projectsScreen)
        
        $taskScreen = [TaskScreen]::new()
        $this.TabContainer.AddTab("Tasks", $taskScreen)
        
        $timeEntryScreen = [TimeEntryScreen]::new()
        $this.TabContainer.AddTab("Time", $timeEntryScreen)
        
        $fileBrowserScreen = [FileBrowserScreen]::new()
        $this.TabContainer.AddTab("Files", $fileBrowserScreen)
        
        $textEditorScreen = [TextEditorScreenNew]::new()
        $this.TabContainer.AddTab("Editor", $textEditorScreen)
        
        $commandLibraryScreen = [CommandLibraryScreen]::new()
        $this.TabContainer.AddTab("Commands", $commandLibraryScreen)
        
        $macroFactoryScreen = [VisualMacroFactoryScreen]::new()
        $this.TabContainer.AddTab("Macro Factory", $macroFactoryScreen)
        
        $settingsScreen = [SettingsScreen]::new()
        $this.TabContainer.AddTab("Settings", $settingsScreen)
        
        if ($global:Logger) {
            $global:Logger.Debug("MainScreen: Added $($this.TabContainer.Tabs.Count) tabs")
        }
        
        # Create command palette (overlay)
        $this.CommandPalette = [CommandPalette]::new()
        $this.CommandPalette.Initialize($global:ServiceContainer)
        $this.AddChild($this.CommandPalette)
        
        # Ensure bounds are set if we already have them
        if ($this.Width -gt 0 -and $this.Height -gt 0) {
            $this.OnBoundsChanged()
        }
        
        # Key bindings now handled by GetShortcutBindings() method
    }
    
    
    [void] OnBoundsChanged() {
        if ($this.TabContainer) {
            # Leave space for border
            $this.TabContainer.SetBounds($this.X + 1, $this.Y + 1, $this.Width - 2, $this.Height - 2)
        }
        if ($this.CommandPalette) {
            # Command palette uses full screen for centering
            $this.CommandPalette.SetBounds($this.X, $this.Y, $this.Width, $this.Height)
        }
    }
    
    [void] OnActivated() {
        # Call base to trigger render
        ([Screen]$this).OnActivated()
        
        # Make sure bounds are set
        if ($this.Width -eq 0 -or $this.Height -eq 0) {
            $this.SetBounds(0, 0, [Console]::WindowWidth, [Console]::WindowHeight)
        }
        
        # Activate the active tab's content screen
        if ($this.TabContainer) {
            $activeTab = $this.TabContainer.GetActiveTab()
            if ($activeTab -and $activeTab.Content) {
                # Screens are not focusable - call OnActivated instead
                if ($activeTab.Content -is [Screen]) {
                    $activeTab.Content.OnActivated()
                } else {
                    $activeTab.Content.Focus()
                }
            }
        }
    }
    
    # Override to handle global shortcuts
    [bool] HandleScreenInput([System.ConsoleKeyInfo]$keyInfo) {
        # Global shortcuts
        switch ($keyInfo.Key) {
            ([System.ConsoleKey]::Q) {
                # Only handle Q for quit if Ctrl is pressed
                # This prevents conflict with child screens using 'q'
                if ($keyInfo.Modifiers -eq [System.ConsoleModifiers]::Control) {
                    $this.Active = $false  # Exit the main loop
                    return $true
                }
            }
            # Remove Escape handling - let child screens handle it
        }
        
        # Let TabContainer handle tab switching shortcuts (numbers, Ctrl+Tab, etc)
        # This is safe because TabContainer is not focusable, so it won't be in the normal input chain
        if ($this.TabContainer) {
            return $this.TabContainer.HandleInput($keyInfo)
        }
        
        return $false
    }
    
    # Override render to add border
    [string] OnRender() {
        $sb = Get-PooledStringBuilder 4096
        
        # Draw main screen border
        $theme = $this.ServiceContainer.GetService('ThemeManager')
        if ($theme) {
            $borderColor = $theme.GetColor('border.normal')
            $sb.Append([BorderStyle]::RenderBorder(
                $this.X, $this.Y, $this.Width, $this.Height,
                [BorderType]::Rounded, $borderColor
            ))
        }
        
        # Render base content (which includes TabContainer)
        $sb.Append(([Screen]$this).OnRender())
        
        $result = $sb.ToString()
        Return-PooledStringBuilder $sb
        return $result
    }
}