# UnifiedMainScreen.ps1 - Main screen using unified components with proper theming and layout
# Fixes: Grey menu theme, border conflicts, split-screen layout issues

class UnifiedMainScreen : UnifiedScreen {
    [SimpleList]$MenuList          # LEFT MENU - SimpleList for clean menu display
    [Screen]$CurrentScreen          # RIGHT CONTENT - Current active screen
    [MinimalStatusBar]$StatusBar    # BOTTOM STATUS - Keep existing for now
    [EventBus]$EventBus
    [ContextPopup]$ActionPopup
    
    # Menu items in fixed order - using ordered hashtable for consistent display
    hidden [System.Collections.Specialized.OrderedDictionary]$MenuItems = [ordered]@{
        "Projects" = [ProjectsScreenUnified]
        "Tasks" = [TaskScreen] 
        "Time Entry" = [TimeEntryScreen]
        "Files" = [FileBrowserScreen]
        "Commands" = [CommandLibraryScreen]
        "Macro Factory" = [VisualMacroFactoryScreen]
        "Settings" = [SettingsScreen]
    }
    
    hidden [hashtable]$ScreenInstances = @{}
    hidden [string]$CurrentScreenName = "Projects"
    hidden [bool]$MenuFocused = $true
    
    # LAYOUT PROPERTIES - Clean split-screen management
    hidden [int]$MenuWidth = 0
    hidden [int]$ContentX = 0
    hidden [int]$ContentWidth = 0
    hidden [int]$ContentHeight = 0
    
    UnifiedMainScreen() : base("PRAXIS") {
        $this.ShowBorder = $false  # No border for main screen
        $this.ShowTitle = $false   # Title in menu instead
    }
    
    [void] OnScreenInitialize() {
        if ($global:Logger) {
            $global:Logger.Debug("UnifiedMainScreen.OnInitialize: Starting unified initialization")
        }
        
        # Create LEFT MENU using SimpleList
        $this.MenuList = [SimpleList]::new()
        $this.MenuList.Title = "PRAXIS"  # Show title in menu
        $this.MenuList.ShowBorder = $true  # Border helps separate menu from content
        $this.MenuList.ShowTitle = $true
        
        # Add menu items
        $menuItemsList = [System.Collections.ArrayList]::new()
        foreach ($menuName in $this.MenuItems.Keys) {
            $menuItemsList.Add($menuName) | Out-Null
        }
        $this.MenuList.SetItems($menuItemsList)
        $this.MenuList.SelectedIndex = 0  # Select first item (Projects)
        
        # Menu selection handler
        $mainScreen = $this
        $this.MenuList.OnSelectionChanged = {
            $selectedItem = $mainScreen.MenuList.GetSelectedItem()
            if ($selectedItem) {
                $mainScreen.SwitchToScreen($selectedItem)
            }
        }.GetNewClosure()
        
        $this.MenuList.Initialize($this.ServiceContainer)
        $this.AddChild($this.MenuList)
        
        # Create status bar
        $this.StatusBar = [MinimalStatusBar]::new()
        $this.StatusBar.Height = 1
        $this.AddChild($this.StatusBar)
        
        # Create action popup (but don't add as child yet)
        try {
            $this.ActionPopup = [ContextPopup]::new()
            $this.ActionPopup.Initialize($this.ServiceContainer)
        } catch {
            if ($global:Logger) {
                $global:Logger.Error("UnifiedMainScreen.OnInitialize: Error creating ActionPopup: $_")
            }
        }
        
        # Initialize with first screen
        $this.SwitchToScreen("Projects")
        
        # Ensure menu starts focused
        $focusManager = $this.ServiceContainer.GetService('FocusManager')
        if ($focusManager) {
            $focusManager.SetFocus($this.MenuList)
        }
        
        if ($global:Logger) {
            $global:Logger.Debug("UnifiedMainScreen.OnInitialize: Unified initialization complete")
        }
    }
    
    [void] LayoutContent() {
        if (-not $this.MenuList -or -not $this.StatusBar) { 
            return 
        }
        
        # CLEAN LAYOUT CALCULATION - No overlapping borders
        # Menu needs enough width for longest item "Macro Factory" (13 chars) + padding + border
        $this.MenuWidth = 18  # Fixed width to ensure all menu items fit
        $this.ContentX = $this.X + $this.MenuWidth + 1  # +1 for gap between menu and content
        $this.ContentWidth = $this.Width - $this.MenuWidth - 1
        $this.ContentHeight = $this.Height - 1  # Reserve 1 line for status
        
        # Position LEFT MENU (no overlapping)
        $this.MenuList.SetBounds($this.X, $this.Y, $this.MenuWidth, $this.ContentHeight)
        
        if ($global:Logger) {
            $global:Logger.Debug("UnifiedMainScreen.LayoutContent: MenuWidth=$($this.MenuWidth), ContentX=$($this.ContentX), ContentWidth=$($this.ContentWidth)")
        }
        
        # Position RIGHT CONTENT (clean separation from menu)
        if ($this.CurrentScreen) {
            $this.CurrentScreen.SetBounds($this.ContentX, $this.Y, $this.ContentWidth, $this.ContentHeight)
        }
        
        # Position BOTTOM STATUS BAR (full width)
        $this.StatusBar.SetBounds($this.X, $this.Y + $this.Height - 1, $this.Width, 1)
        
        # Base class handles the rest
    }
    
    [void] SwitchToScreen([string]$screenName) {
        if (-not $this.MenuItems.Contains($screenName)) {
            if ($global:Logger) {
                $global:Logger.Warning("UnifiedMainScreen.SwitchToScreen: Unknown screen '$screenName'")
            }
            return
        }
        
        # Remove current screen
        if ($this.CurrentScreen) {
            $this.RemoveChild($this.CurrentScreen)
            $this.CurrentScreen = $null
        }
        
        # Get or create screen instance
        if (-not $this.ScreenInstances.ContainsKey($screenName)) {
            $screenType = $this.MenuItems[$screenName]
            $this.ScreenInstances[$screenName] = $screenType::new()
            $this.ScreenInstances[$screenName].Initialize($this.ServiceContainer)
        }
        
        # Set new current screen
        $this.CurrentScreen = $this.ScreenInstances[$screenName]
        $this.CurrentScreenName = $screenName
        $this.AddChild($this.CurrentScreen)
        
        # Update layout
        if ($this.ContentWidth -gt 0) {
            $this.CurrentScreen.SetBounds($this.ContentX, $this.Y, $this.ContentWidth, $this.ContentHeight)
        }
        
        # Update status bar
        $this.UpdateStatusBar()
        
        # KEEP FOCUS ON MENU - Don't let new screens steal focus
        if ($this.MenuFocused) {
            $focusManager = $this.ServiceContainer.GetService('FocusManager')
            if ($focusManager) {
                $focusManager.SetFocus($this.MenuList)
            }
        }
        
        if ($global:Logger) {
            $global:Logger.Debug("UnifiedMainScreen.SwitchToScreen: Switched to '$screenName'")
        }
    }
    
    [void] UpdateStatusBar() {
        if ($this.StatusBar) {
            $focusInfo = if ($this.MenuFocused) { "Focus: MENU" } else { "Focus: CONTENT" }
            $navigation = "←/→ switch focus | / actions | ↑/↓ navigate"
            $time = (Get-Date).ToString("HH:mm")
            
            $this.StatusBar.LeftText = $this.CurrentScreenName
            $this.StatusBar.CenterText = "$focusInfo | $navigation"
            $this.StatusBar.RightText = $time
        }
    }
    
    [string] RenderContent() {
        $sb = Get-PooledStringBuilder 512
        
        try {
            # NO BACKGROUND RENDERING - let components handle their own backgrounds
            # This prevents border conflicts and rendering issues
            
            # Update status bar before rendering
            $this.UpdateStatusBar()
            
            return $sb.ToString()
        }
        finally {
            Return-PooledStringBuilder $sb
        }
    }
    
    [bool] HandleScreenInput([System.ConsoleKeyInfo]$keyInfo) {
        # Handle focus switching between menu and content
        switch ($keyInfo.Key) {
            ([System.ConsoleKey]::LeftArrow) {
                if (-not $this.MenuFocused) {
                    $this.MenuFocused = $true
                    $focusManager = $this.GetService('FocusManager')
                    if ($focusManager) {
                        $focusManager.SetFocus($this.MenuList)
                    }
                    $this.UpdateStatusBar()
                    return $true
                }
            }
            ([System.ConsoleKey]::RightArrow) {
                if ($this.MenuFocused -and $this.CurrentScreen) {
                    $this.MenuFocused = $false
                    $focusManager = $this.GetService('FocusManager')
                    if ($focusManager) {
                        $focusManager.SetFocus($this.CurrentScreen)
                    }
                    $this.UpdateStatusBar()
                    return $true
                }
            }
            ([System.ConsoleKey]::Tab) {
                # Toggle focus between menu and content
                $this.MenuFocused = -not $this.MenuFocused
                $focusManager = $this.GetService('FocusManager')
                if ($focusManager) {
                    if ($this.MenuFocused) {
                        $focusManager.SetFocus($this.MenuList)
                    } elseif ($this.CurrentScreen) {
                        $focusManager.SetFocus($this.CurrentScreen)
                    }
                }
                $this.UpdateStatusBar()
                return $true
            }
        }
        
        # Handle number keys for direct screen switching
        if ($keyInfo.KeyChar -ge '1' -and $keyInfo.KeyChar -le '9') {
            $index = [int]$keyInfo.KeyChar - [int]'1'
            $screenNames = @($this.MenuItems.Keys)
            if ($index -lt $screenNames.Count) {
                $screenName = $screenNames[$index]
                $this.SwitchToScreen($screenName)
                $this.MenuList.SelectIndex($index)
                return $true
            }
        }
        
        # Handle action palette
        if ($keyInfo.KeyChar -eq '/' -or $keyInfo.KeyChar -eq ':') {
            if ($this.ActionPopup) {
                # Show action popup for current screen
                # Implementation would go here
            }
            return $true
        }
        
        return $false
    }
    
    [void] OnActivated() {
        ([Screen]$this).OnActivated()
        
        # Set initial focus to menu
        $focusManager = $this.GetService('FocusManager')
        if ($focusManager) {
            $focusManager.SetFocus($this.MenuList)
        }
        $this.MenuFocused = $true
        $this.UpdateStatusBar()
    }
}