# MainScreen.ps1 - Main screen with tab container

class MainScreen : Screen {
    [TabContainer]$TabContainer
    [CommandPalette]$CommandPalette
    [MinimalStatusBar]$StatusBar
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
                    # Update status bar for new tab
                    $this.UpdateStatusBar()
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
        
        # Create status bar
        $this.StatusBar = [MinimalStatusBar]::new()
        $this.StatusBar.Initialize($global:ServiceContainer)
        
        # Update status bar based on active tab
        $this.UpdateStatusBar()
        
        $this.AddChild($this.StatusBar)
        
        # Ensure bounds are set if we already have them
        if ($this.Width -gt 0 -and $this.Height -gt 0) {
            $this.OnBoundsChanged()
        }
        
        # Key bindings now handled by GetShortcutBindings() method
    }
    
    
    [void] OnBoundsChanged() {
        if ($this.TabContainer) {
            # Leave space for border and status bar
            $this.TabContainer.SetBounds($this.X + 1, $this.Y + 1, $this.Width - 2, $this.Height - 3)
        }
        if ($this.CommandPalette) {
            # Command palette uses full screen for centering
            $this.CommandPalette.SetBounds($this.X, $this.Y, $this.Width, $this.Height)
        }
        if ($this.StatusBar) {
            # Status bar at bottom
            $this.StatusBar.SetBounds($this.X + 1, $this.Y + $this.Height - 2, $this.Width - 2, 1)
        }
    }
    
    [void] OnActivated() {
        # Call base to trigger render
        ([Screen]$this).OnActivated()
        
        # Make sure bounds are set
        if ($this.Width -eq 0 -or $this.Height -eq 0) {
            $this.SetBounds(0, 0, [Console]::WindowWidth, [Console]::WindowHeight)
        }
        
        # Update status bar for current tab
        $this.UpdateStatusBar()
        
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
    
    [void] UpdateStatusBar() {
        if (-not $this.StatusBar -or -not $this.TabContainer) { return }
        
        $activeTab = $this.TabContainer.GetActiveTab()
        if ($activeTab) {
            $this.StatusBar.LeftText = "PRAXIS - $($activeTab.Title)"
            
            # Set context-specific hints based on active tab
            switch ($activeTab.Title) {
                "Tasks" {
                    $this.StatusBar.SetHints(@(
                        @{Key="N"; Action="New"}
                        @{Key="E"; Action="Edit"}
                        @{Key="D"; Action="Delete"}
                        @{Key="S"; Action="Status"}
                        @{Key="P"; Action="Priority"}
                        @{Key="Tab"; Action="Navigate"}
                    ))
                }
                "Projects" {
                    $this.StatusBar.SetHints(@(
                        @{Key="N"; Action="New"}
                        @{Key="E"; Action="Edit"}
                        @{Key="D"; Action="Delete"}
                        @{Key="Enter"; Action="Details"}
                        @{Key="Tab"; Action="Navigate"}
                    ))
                }
                "Time" {
                    $this.StatusBar.SetHints(@(
                        @{Key="Q"; Action="Quick Entry"}
                        @{Key="N"; Action="New"}
                        @{Key="E"; Action="Edit"}
                        @{Key="D"; Action="Delete"}
                        @{Key="Tab"; Action="Navigate"}
                    ))
                }
                "Commands" {
                    $this.StatusBar.SetHints(@(
                        @{Key="N"; Action="New"}
                        @{Key="E"; Action="Edit"}
                        @{Key="D"; Action="Delete"}
                        @{Key="Enter"; Action="Execute"}
                        @{Key="Tab"; Action="Navigate"}
                    ))
                }
                "Settings" {
                    $this.StatusBar.SetHints(@(
                        @{Key="Enter"; Action="Edit"}
                        @{Key="T"; Action="Theme"}
                        @{Key="R"; Action="Reset"}
                        @{Key="Tab"; Action="Navigate"}
                    ))
                }
                default {
                    # Default hints
                    $this.StatusBar.SetHints(@(
                        @{Key="Tab"; Action="Switch Tab"}
                        @{Key="Ctrl+P"; Action="Command"}
                        @{Key="F1"; Action="Help"}
                        @{Key="Ctrl+Q"; Action="Quit"}
                    ))
                }
            }
        } else {
            $this.StatusBar.LeftText = "PRAXIS"
        }
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