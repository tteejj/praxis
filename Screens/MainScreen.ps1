# MainScreen.ps1 - Main screen with tab container

class MainScreen : Screen {
    [TabContainer]$TabContainer
    [CommandPalette]$CommandPalette
    [MinimalStatusBar]$StatusBar
    [EventBus]$EventBus
    hidden [string]$TabChangedSubscription
    hidden [bool]$_needsDeferredInit = $false
    hidden [System.Timers.Timer]$UpdateTimer
    
    MainScreen() : base() {
        $this.Title = "PRAXIS"
    }
    
    [void] OnInitialize() {
        if ($global:Logger) {
            $global:Logger.Debug("MainScreen.OnInitialize: Starting simplified initialization")
        }
        
        # Create tab container immediately but don't initialize tabs yet
        $this.TabContainer = [TabContainer]::new()
        $this.TabContainer.Initialize($global:ServiceContainer)
        $this.AddChild($this.TabContainer)
        
        # Defer heavy initialization to OnActivated
        $this._needsDeferredInit = $true
        
        if ($global:Logger) {
            $global:Logger.Debug("MainScreen.OnInitialize: Completed simplified initialization")
        }
    }
    
    [void] OnActivated() {
        ([Screen]$this).OnActivated()
        
        if ($this._needsDeferredInit) {
            if ($global:Logger) {
                $global:Logger.Debug("MainScreen.OnActivated: Starting deferred initialization")
            }
            
            # Get EventBus
            $this.EventBus = $global:ServiceContainer.GetService('EventBus')
            
            # Subscribe to tab change events
            if ($this.EventBus) {
                $screen = $this
                $this.TabChangedSubscription = $this.EventBus.Subscribe('navigation.tabChanged', {
                    param($sender, $eventData)
                    if ($eventData.TabIndex -ne $null -and $screen.TabContainer) {
                        $screen.TabContainer.ActivateTab($eventData.TabIndex)
                        $screen.RequestRender()
                        $screen.UpdateStatusBar()
                    }
                }.GetNewClosure())
            }
            
            # Add tabs - these will be lazy-initialized when activated
            $this.TabContainer.AddTab("Projects", [ProjectsScreen]::new())
            $this.TabContainer.AddTab("Tasks", [TaskScreen]::new())
            $this.TabContainer.AddTab("Time", [TimeEntryScreen]::new())
            $this.TabContainer.AddTab("Files", [FileBrowserScreen]::new())
            $this.TabContainer.AddTab("Editor", [TextEditorScreenNew]::new())
            $this.TabContainer.AddTab("Commands", [CommandLibraryScreen]::new())
            $this.TabContainer.AddTab("Macro Factory", [VisualMacroFactoryScreen]::new())
            $this.TabContainer.AddTab("Settings", [SettingsScreen]::new())
            
            # Create status bar
            $this.StatusBar = [MinimalStatusBar]::new()
            $this.StatusBar.Height = 1
            $this.AddChild($this.StatusBar)
            
            # Create command palette
            $this.CommandPalette = [CommandPalette]::new()
            $this.CommandPalette.Initialize($global:ServiceContainer)
            $this.AddChild($this.CommandPalette)
            
            # Subscribe to events
            $this.SetupEventHandlers()
            
            # Start update timer
            $this.StartTimer()
            
            # Initial status update
            $this.UpdateStatusBar()
            
            $this._needsDeferredInit = $false
            
            if ($global:Logger) {
                $global:Logger.Debug("MainScreen.OnActivated: Completed deferred initialization")
            }
        }
    }
    
    hidden [void] SetupEventHandlers() {
        # Subscribe to timer events
        if ($global:ServiceContainer.GetService('EventBus')) {
            $mainScreen = $this
            $global:ServiceContainer.GetService('EventBus').Subscribe('time.changed', {
                param($sender, $eventData)
                $mainScreen.UpdateStatusBar()
            }.GetNewClosure())
        }
    }
    
    hidden [void] StartTimer() {
        # Create timer for status bar updates
        $this.UpdateTimer = [System.Timers.Timer]::new()
        $this.UpdateTimer.Interval = 30000  # 30 seconds
        $this.UpdateTimer.AutoReset = $true
        
        $timer = $this.UpdateTimer
        $screen = $this
        
        Register-ObjectEvent -InputObject $timer -EventName Elapsed -Action {
            if ($screen.Active) {
                $screen.UpdateStatusBar()
            }
        } | Out-Null
        
        $this.UpdateTimer.Start()
    }
    
    [void] OnBoundsChanged() {
        if ($global:Logger) {
            $global:Logger.Debug("MainScreen.OnBoundsChanged: Bounds=($($this.X),$($this.Y),$($this.Width),$($this.Height))")
        }
        if ($this.TabContainer) {
            # TabContainer gets full screen except status bar
            if ($global:Logger) {
                $global:Logger.Debug("MainScreen: TabContainer bounds before: ($($this.TabContainer.X),$($this.TabContainer.Y),$($this.TabContainer.Width),$($this.TabContainer.Height))")
            }
            $this.TabContainer.SetBounds($this.X, $this.Y, $this.Width, $this.Height - 1)
            if ($global:Logger) {
                $global:Logger.Debug("MainScreen: TabContainer bounds after: ($($this.TabContainer.X),$($this.TabContainer.Y),$($this.TabContainer.Width),$($this.TabContainer.Height))")
            }
        }
        if ($this.StatusBar) {
            # Status bar at bottom
            $this.StatusBar.SetBounds($this.X, $this.Y + $this.Height - 1, $this.Width, 1)
        }
        if ($this.CommandPalette) {
            # Command palette overlays when visible
            $paletteHeight = [Math]::Min(20, [Math]::Max(10, $this.Height - 4))
            $paletteY = $this.Y + 2
            $this.CommandPalette.SetBounds($this.X + 2, $paletteY, $this.Width - 4, $paletteHeight)
        }
    }
    
    [void] OnDeactivated() {
        if ($this.UpdateTimer) {
            $this.UpdateTimer.Stop()
        }
        ([Screen]$this).OnDeactivated()
    }
    
    [bool] HandleScreenInput([System.ConsoleKeyInfo]$keyInfo) {
        # CRITICAL DEBUG: Track freeze-causing keys
        if ($keyInfo.KeyChar -eq '2' -or $keyInfo.KeyChar -eq '3') {
            if ($global:Logger) {
                $global:Logger.Info("MainScreen.HandleScreenInput: START processing key '$($keyInfo.KeyChar)'")
            }
        }
        
        # F1 for help
        if ($keyInfo.Key -eq [System.ConsoleKey]::F1) {
            $helpOverlay = [KeyboardHelpOverlay]::new()
            $helpOverlay.Initialize($global:ServiceContainer)
            $global:ScreenManager.Push($helpOverlay)
            return $true
        }
        
        # Let TabContainer handle its input first
        if ($this.TabContainer -and $this.TabContainer.HandleInput($keyInfo)) {
            if ($keyInfo.KeyChar -eq '2' -or $keyInfo.KeyChar -eq '3') {
                if ($global:Logger) {
                    $global:Logger.Info("MainScreen.HandleScreenInput: TabContainer handled key '$($keyInfo.KeyChar)'")
                }
            }
            return $true
        }
        
        if ($keyInfo.KeyChar -eq '2' -or $keyInfo.KeyChar -eq '3') {
            if ($global:Logger) {
                $global:Logger.Info("MainScreen.HandleScreenInput: COMPLETED processing key '$($keyInfo.KeyChar)', returning false")
            }
        }
        
        return $false
    }
    
    [hashtable] GetShortcutBindings() {
        $bindings = @{
            # Tab navigation
            'Ctrl+Tab' = @{
                Action = { $this.TabContainer.NextTab() }
                Description = "Next tab"
            }
            'Ctrl+Shift+Tab' = @{
                Action = { $this.TabContainer.PreviousTab() }
                Description = "Previous tab"
            }
            'Alt+Right' = @{
                Action = { $this.TabContainer.NextTab() }
                Description = "Next tab"
            }
            'Alt+Left' = @{
                Action = { $this.TabContainer.PreviousTab() }
                Description = "Previous tab"
            }
            
            # Quick tab access (1-9)
            '1' = @{ Action = { $this.TabContainer.ActivateTab(0) }; Description = "Go to tab 1" }
            '2' = @{ Action = { $this.TabContainer.ActivateTab(1) }; Description = "Go to tab 2" }
            '3' = @{ Action = { $this.TabContainer.ActivateTab(2) }; Description = "Go to tab 3" }
            '4' = @{ Action = { $this.TabContainer.ActivateTab(3) }; Description = "Go to tab 4" }
            '5' = @{ Action = { $this.TabContainer.ActivateTab(4) }; Description = "Go to tab 5" }
            '6' = @{ Action = { $this.TabContainer.ActivateTab(5) }; Description = "Go to tab 6" }
            '7' = @{ Action = { $this.TabContainer.ActivateTab(6) }; Description = "Go to tab 7" }
            '8' = @{ Action = { $this.TabContainer.ActivateTab(7) }; Description = "Go to tab 8" }
            '9' = @{ Action = { $this.TabContainer.ActivateTab(8) }; Description = "Go to tab 9" }
            
            # Help
            'F1' = @{
                Action = { 
                    $helpOverlay = [KeyboardHelpOverlay]::new()
                    $helpOverlay.Initialize($global:ServiceContainer)
                    $global:ScreenManager.Push($helpOverlay)
                }
                Description = "Show keyboard help"
            }
        }
        
        return $bindings
    }
    
    [void] UpdateStatusBar() {
        if (-not $this.StatusBar -or -not $this.TabContainer) { return }
        
        $activeTab = $this.TabContainer.GetActiveTab()
        if (-not $activeTab) { return }
        
        # Build status info
        $leftStatus = "Tab: $($activeTab.Title)"
        
        # Get tab-specific status
        $middleStatus = ""
        if ($activeTab.Content -and $activeTab.Content.PSObject.Methods['GetStatusInfo']) {
            $middleStatus = $activeTab.Content.GetStatusInfo()
        }
        
        # Time and memory
        $time = Get-Date -Format "HH:mm"
        $memoryMB = [Math]::Round((Get-Process -Id $global:PID).WorkingSet64 / 1MB, 0)
        $rightStatus = "Mem: ${memoryMB}MB | $time"
        
        $this.StatusBar.LeftText = $leftStatus
        $this.StatusBar.CenterText = $middleStatus
        $this.StatusBar.RightText = $rightStatus
        $this.StatusBar.Invalidate()
    }
    
    [string] OnRender() {
        $sb = Get-PooledStringBuilder 2048
        
        # Clear background
        $bgColor = if ($this.Theme) { $this.Theme.GetBgColor('surface.background') } else { [VT]::BgRgb(16, 16, 16) }
        $sb.Append([VT]::Clear())
        $sb.Append($bgColor)
        
        # Let base class render children (TabContainer, StatusBar, etc)
        $baseRender = ([Screen]$this).OnRender()
        $sb.Append($baseRender)
        
        $result = $sb.ToString()
        Return-PooledStringBuilder $sb
        return $result
    }
}