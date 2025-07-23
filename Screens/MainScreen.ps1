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
            $this.TabChangedSubscription = $this.EventBus.Subscribe([EventNames]::TabChanged, {
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
        
        $dashboardScreen = [DashboardScreen]::new()
        $this.TabContainer.AddTab("Dashboard", $dashboardScreen)
        
        $fileBrowserScreen = [FileBrowserScreen]::new()
        $this.TabContainer.AddTab("Files", $fileBrowserScreen)
        
        $textEditorScreen = [TextEditorScreen]::new()
        $this.TabContainer.AddTab("Editor", $textEditorScreen)
        
        $settingsScreen = [SettingsScreen]::new()
        $this.TabContainer.AddTab("Settings", $settingsScreen)
        
        if ($global:Logger) {
            $global:Logger.Debug("MainScreen: Added $($this.TabContainer.Tabs.Count) tabs")
        }
        
        # Create command palette (overlay)
        $this.CommandPalette = [CommandPalette]::new()
        $this.CommandPalette.Initialize($global:ServiceContainer)
        $this.AddChild($this.CommandPalette)
        
        # Key bindings now handled by GetShortcutBindings() method
    }
    
    
    [void] OnBoundsChanged() {
        if ($this.TabContainer) {
            $this.TabContainer.SetBounds($this.X, $this.Y, $this.Width, $this.Height)
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
        
        # Focus on the active tab's content
        if ($this.TabContainer) {
            $activeTab = $this.TabContainer.GetActiveTab()
            if ($activeTab -and $activeTab.Content) {
                $activeTab.Content.Focus()
            }
        }
    }
    
    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        if ($global:Logger) {
            $global:Logger.Debug("MainScreen.HandleInput: Key=$($key.Key) Char='$($key.KeyChar)'")
        }
        
        # Command palette gets input priority when visible
        if ($this.CommandPalette -and $this.CommandPalette.IsVisible) {
            $handled = $this.CommandPalette.HandleInput($key)
            if ($global:Logger) {
                $global:Logger.Debug("CommandPalette handled: $handled")
            }
            if ($handled) { return $true }
        }
        
        # Let TabContainer handle tab-specific shortcuts first
        if ($this.TabContainer) {
            $handled = $this.TabContainer.HandleInput($key)
            if ($global:Logger) {
                $global:Logger.Debug("TabContainer handled: $handled")
            }
            if ($handled) { return $true }
        }
        
        # Handle MainScreen-specific shortcuts
        switch ($key.Key) {
            ([System.ConsoleKey]::Q) {
                if (-not $key.Modifiers -and $key.KeyChar -eq 'Q') {
                    $this.Active = $false
                    return $true
                }
            }
            ([System.ConsoleKey]::Escape) {
                try {
                    if ($this.CommandPalette -and $this.CommandPalette.IsVisible) {
                        $this.CommandPalette.Hide()
                    } elseif ($this.TabContainer -and $this.TabContainer.GetActiveTab() -and $this.TabContainer.GetActiveTab().Content) {
                        if ($this.TabContainer.GetActiveTab().Content.Active) {
                            $this.Active = $false
                        }
                    } else {
                        $this.Active = $false
                    }
                } catch {
                    # If anything fails, just exit
                    $this.Active = $false
                }
                return $true
            }
        }
        
        # Otherwise use normal handling
        $handled = ([Screen]$this).HandleInput($key)
        if ($global:Logger) {
            $global:Logger.Debug("Screen base handled: $handled")
        }
        return $handled
    }
}