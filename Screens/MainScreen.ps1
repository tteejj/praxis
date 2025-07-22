# MainScreen.ps1 - Main screen with tab container

class MainScreen : Screen {
    [TabContainer]$TabContainer
    [CommandPalette]$CommandPalette
    
    MainScreen() : base() {
        $this.Title = "PRAXIS"
    }
    
    [void] OnInitialize() {
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
        
        $test2 = [TestScreen]::new()
        $test2.Message = "Tasks Screen (Coming Soon)"
        $this.TabContainer.AddTab("Tasks", $test2)
        
        $test3 = [TestScreen]::new()
        $test3.Message = "Dashboard (Coming Soon)"
        $this.TabContainer.AddTab("Dashboard", $test3)
        
        if ($global:Logger) {
            $global:Logger.Debug("MainScreen: Added $($this.TabContainer.Tabs.Count) tabs")
        }
        
        # Create command palette (overlay)
        $this.CommandPalette = [CommandPalette]::new()
        $this.CommandPalette.Initialize($global:ServiceContainer)
        $this.AddChild($this.CommandPalette)
        
        # Global key bindings
        $this.BindKey('q', { $this.Active = $false })
        $this.BindKey([System.ConsoleKey]::Escape, { 
            if ($this.CommandPalette.IsVisible) {
                $this.CommandPalette.Hide()
            } elseif ($this.TabContainer.GetActiveTab().Content.Active) {
                $this.Active = $false
            }
        })
        
        # Command palette shortcut
        $this.BindKey('/', { 
            $this.CommandPalette.Show()
            $this.RequestRender()
        })
        $this.BindKey(':', { 
            $this.CommandPalette.Show()
            $this.RequestRender()
        })
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
        
        # Otherwise use normal handling
        $handled = ([Screen]$this).HandleInput($key)
        if ($global:Logger) {
            $global:Logger.Debug("Screen base handled: $handled")
        }
        return $handled
    }
}