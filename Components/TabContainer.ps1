# TabContainer.ps1 - Fast tab-based screen switching
# Core component for PRAXIS multi-screen management

class TabContainer : Container {
    [System.Collections.Generic.List[TabItem]]$Tabs
    [int]$ActiveTabIndex = 0
    [int]$TabBarHeight = 2
    
    hidden [ThemeManager]$Theme
    hidden [hashtable]$_tabCache = @{}
    hidden [string]$_cachedTabBar = ""
    hidden [bool]$_tabBarInvalid = $true
    
    TabContainer() : base() {
        $this.Tabs = [System.Collections.Generic.List[TabItem]]::new()
    }
    
    [void] Initialize([ServiceContainer]$services) {
        $this.Theme = $services.GetService("ThemeManager")
        $this.Theme.Subscribe({ $this.OnThemeChanged() })
        $this.OnThemeChanged()
    }
    
    [void] OnThemeChanged() {
        $this._tabBarInvalid = $true
        $this.Invalidate()
        
        # Propagate to all tabs
        foreach ($tab in $this.Tabs) {
            if ($tab.Content -and $tab.Content -is [Screen]) {
                $tab.Content.OnThemeChanged()
            }
        }
    }
    
    # Add a new tab
    [void] AddTab([string]$title, [UIElement]$content) {
        $tab = [TabItem]::new()
        $tab.Title = $title
        $tab.Content = $content
        $tab.ShortcutKey = $this.Tabs.Count + 1  # 1-9 shortcuts
        
        # Initialize the content if it's a Screen
        if ($content -is [Screen] -and $global:ServiceContainer) {
            $content.Initialize($global:ServiceContainer)
            # Tab content shouldn't draw their own background
            $content.DrawBackground = $false
        }
        
        $this.Tabs.Add($tab)
        $this._tabBarInvalid = $true
        
        # Set as active if first tab
        if ($this.Tabs.Count -eq 1) {
            $this.ActivateTab(0)
        } else {
            # Position but don't add to children yet
            $this.PositionContent($content, $false)
        }
        
        $this.Invalidate()
    }
    
    # Switch to a specific tab
    [void] ActivateTab([int]$index) {
        if ($index -lt 0 -or $index -ge $this.Tabs.Count) { return }
        
        if ($global:Logger) {
            $global:Logger.Debug("TabContainer.ActivateTab: Switching from tab $($this.ActiveTabIndex) to tab $index")
        }
        
        # Deactivate current
        if ($this.ActiveTabIndex -ge 0 -and $this.ActiveTabIndex -lt $this.Tabs.Count) {
            $oldTab = $this.Tabs[$this.ActiveTabIndex]
            if ($oldTab.Content) {
                if ($global:Logger) {
                    $global:Logger.Debug("TabContainer: Removing old tab content: $($oldTab.Title)")
                }
                $this.RemoveChild($oldTab.Content)
                if ($oldTab.Content -is [Screen]) {
                    $oldTab.Content.OnDeactivated()
                }
            }
        }
        
        # Activate new
        $this.ActiveTabIndex = $index
        $newTab = $this.Tabs[$index]
        if ($newTab.Content) {
            if ($global:Logger) {
                $global:Logger.Debug("TabContainer: Adding new tab content: $($newTab.Title)")
                $global:Logger.Debug("TabContainer: Content type: $($newTab.Content.GetType().Name)")
            }
            $this.PositionContent($newTab.Content, $true)
            $this.AddChild($newTab.Content)
            if ($newTab.Content -is [Screen]) {
                # Ensure tab content doesn't draw its own background
                $newTab.Content.DrawBackground = $false
                $newTab.Content.OnActivated()
            }
            $newTab.Content.Focus()
            if ($global:Logger) {
                $global:Logger.Debug("TabContainer: New content bounds: X=$($newTab.Content.X) Y=$($newTab.Content.Y) W=$($newTab.Content.Width) H=$($newTab.Content.Height)")
            }
        }
        
        $this._tabBarInvalid = $true
        $this.Invalidate()
        
        # Force parent to redraw completely to clear any artifacts
        if ($this.Parent) {
            $this.Parent.Invalidate()
        }
        
        # Force a render request
        if ($global:ScreenManager) {
            $global:ScreenManager.RequestRender()
        }
    }
    
    # Position content below tab bar
    hidden [void] PositionContent([UIElement]$content, [bool]$isActive) {
        $content.SetBounds(
            $this.X,
            $this.Y + $this.TabBarHeight,
            $this.Width,
            $this.Height - $this.TabBarHeight
        )
    }
    
    # Layout management
    [void] OnBoundsChanged() {
        # Update tab bar cache
        $this._tabBarInvalid = $true
        
        # Update active content bounds
        if ($this.ActiveTabIndex -ge 0 -and $this.ActiveTabIndex -lt $this.Tabs.Count) {
            $activeTab = $this.Tabs[$this.ActiveTabIndex]
            if ($activeTab.Content) {
                $this.PositionContent($activeTab.Content, $true)
            }
        }
    }
    
    # Render the tab container
    [string] OnRender() {
        if ($global:Logger) {
            $global:Logger.Debug("TabContainer.OnRender: tabBarInvalid=$($this._tabBarInvalid), Children.Count=$($this.Children.Count)")
        }
        
        $sb = [System.Text.StringBuilder]::new()
        
        # Render tab bar
        if ($this._tabBarInvalid) {
            $this.RebuildTabBar()
        }
        $sb.Append($this._cachedTabBar)
        
        # Clear content area below tab bar
        $bgColor = if ($this.Theme) { $this.Theme.GetBgColor("background") } else { "" }
        $contentY = $this.Y + $this.TabBarHeight
        $contentHeight = $this.Height - $this.TabBarHeight
        $clearLine = " " * $this.Width
        
        for ($y = 0; $y -lt $contentHeight; $y++) {
            $sb.Append([VT]::MoveTo($this.X, $contentY + $y))
            if ($bgColor) { $sb.Append($bgColor) }
            $sb.Append($clearLine)
        }
        if ($bgColor) { $sb.Append([VT]::Reset()) }
        
        # Render active content (base class handles children)
        $baseRender = ([Container]$this).OnRender()
        $sb.Append($baseRender)
        
        if ($global:Logger -and $baseRender.Length -eq 0) {
            $global:Logger.Warning("TabContainer: Base render returned empty string")
        }
        
        return $sb.ToString()
    }
    
    # Build the tab bar
    hidden [void] RebuildTabBar() {
        $sb = [System.Text.StringBuilder]::new()
        
        # Tab bar background
        $sb.Append([VT]::MoveTo($this.X, $this.Y))
        $sb.Append($this.Theme.GetBgColor("tab.background"))
        $sb.Append(" " * $this.Width)
        
        # Draw tabs
        $x = $this.X + 1
        for ($i = 0; $i -lt $this.Tabs.Count; $i++) {
            $tab = $this.Tabs[$i]
            $title = $tab.Title
            
            # Add shortcut hint if applicable
            if ($tab.ShortcutKey -ge 1 -and $tab.ShortcutKey -le 9) {
                $title = "$($tab.ShortcutKey):$title"
            }
            
            # Calculate tab width
            $tabWidth = $title.Length + 4  # Padding
            
            # Don't draw if it would overflow
            if (($x + $tabWidth) -gt ($this.X + $this.Width - 1)) {
                break
            }
            
            $sb.Append([VT]::MoveTo($x, $this.Y))
            
            # Tab styling
            if ($i -eq $this.ActiveTabIndex) {
                # Active tab
                $sb.Append($this.Theme.GetBgColor("tab.active.background"))
                $sb.Append($this.Theme.GetColor("tab.active.foreground"))
                $sb.Append(" $title ")
                
                # Bottom accent line
                $sb.Append([VT]::MoveTo($x, $this.Y + 1))
                $sb.Append($this.Theme.GetColor("tab.active.accent"))
                $sb.Append("─" * ($tabWidth - 2))
            } else {
                # Inactive tab
                $sb.Append($this.Theme.GetBgColor("tab.background"))
                $sb.Append($this.Theme.GetColor("tab.foreground"))
                $sb.Append(" $title ")
            }
            
            $x += $tabWidth + 1
        }
        
        # Reset and draw separator line
        $sb.Append([VT]::Reset())
        $sb.Append([VT]::MoveTo($this.X, $this.Y + 1))
        $sb.Append($this.Theme.GetColor("border"))
        $sb.Append("─" * $this.Width)
        $sb.Append([VT]::Reset())
        
        $this._cachedTabBar = $sb.ToString()
        $this._tabBarInvalid = $false
    }
    
    # Handle keyboard input
    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        if ($global:Logger) {
            $global:Logger.Debug("TabContainer.HandleInput: Key=$($key.Key) Char='$($key.KeyChar)' Modifiers=$($key.Modifiers)")
            $global:Logger.Debug("TabContainer: KeyChar type: $($key.KeyChar.GetType().Name) Value: '$($key.KeyChar)'")
            $global:Logger.Debug("TabContainer: KeyChar ASCII value: $([int]$key.KeyChar)")
        }
        
        # Check TabContainer shortcuts FIRST before passing to children
        
        # Number keys for quick tab switching
        if ($global:Logger) {
            $global:Logger.Debug("TabContainer: About to check number keys. KeyChar='$($key.KeyChar)' ASCII=$([int]$key.KeyChar)")
            $global:Logger.Debug("TabContainer: Checking if $([int]$key.KeyChar) is between $([int]'1') (49) and $([int]'9') (57)")
        }
        if ($key.KeyChar -ge '1' -and $key.KeyChar -le '9') {
            if ($global:Logger) {
                $global:Logger.Debug("TabContainer: Number key detected!")
            }
            $tabIndex = [int]$key.KeyChar - [int][char]'1'
            if ($global:Logger) {
                $global:Logger.Debug("TabContainer: Tab index calculated: $tabIndex, Tabs.Count: $($this.Tabs.Count)")
            }
            if ($tabIndex -lt $this.Tabs.Count) {
                if ($global:Logger) {
                    $global:Logger.Debug("TabContainer: Switching to tab $($tabIndex + 1)")
                }
                $this.ActivateTab($tabIndex)
                return $true
            } else {
                if ($global:Logger) {
                    $global:Logger.Debug("TabContainer: Tab index $tabIndex is out of range (Tabs.Count=$($this.Tabs.Count))")
                }
            }
        }
        
        # Ctrl+Tab / Ctrl+Shift+Tab for cycling
        if ($key.Key -eq [System.ConsoleKey]::Tab -and 
            ($key.Modifiers -band [System.ConsoleModifiers]::Control)) {
            if ($key.Modifiers -band [System.ConsoleModifiers]::Shift) {
                $this.PreviousTab()
            } else {
                $this.NextTab()
            }
            return $true
        }
        
        # Alt+Left/Right for navigation
        if ($key.Modifiers -band [System.ConsoleModifiers]::Alt) {
            if ($key.Key -eq [System.ConsoleKey]::LeftArrow) {
                $this.PreviousTab()
                return $true
            } elseif ($key.Key -eq [System.ConsoleKey]::RightArrow) {
                $this.NextTab()
                return $true
            }
        }
        
        # Now pass to active tab's content
        $activeTab = $this.GetActiveTab()
        if ($activeTab -and $activeTab.Content) {
            if ($global:Logger) {
                $global:Logger.Debug("TabContainer: Routing input to active tab content: $($activeTab.Content.GetType().Name)")
            }
            return $activeTab.Content.HandleInput($key)
        }
        
        # Fallback to container behavior if no active content
        return $false
    }
    
    # Navigation helpers
    [void] NextTab() {
        if ($this.Tabs.Count -gt 0) {
            $next = ($this.ActiveTabIndex + 1) % $this.Tabs.Count
            $this.ActivateTab($next)
        }
    }
    
    [void] PreviousTab() {
        if ($this.Tabs.Count -gt 0) {
            $prev = $this.ActiveTabIndex - 1
            if ($prev -lt 0) { $prev = $this.Tabs.Count - 1 }
            $this.ActivateTab($prev)
        }
    }
    
    # Get active tab
    [TabItem] GetActiveTab() {
        if ($this.ActiveTabIndex -ge 0 -and $this.ActiveTabIndex -lt $this.Tabs.Count) {
            return $this.Tabs[$this.ActiveTabIndex]
        }
        return $null
    }
}

# Tab item class
class TabItem {
    [string]$Title = "Tab"
    [UIElement]$Content = $null
    [int]$ShortcutKey = 0
}