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
    hidden [hashtable]$_colors = @{}
    
    # Version-based change detection
    hidden [int]$_dataVersion = 0
    hidden [int]$_lastRenderedVersion = -1
    hidden [string]$_cachedVersionRender = ""
    
    TabContainer() : base() {
        $this.Tabs = [System.Collections.Generic.List[TabItem]]::new()
    }
    
    [void] OnInitialize() {
        $this.Theme = $this.ServiceContainer.GetService("ThemeManager")
        $this.Theme.Subscribe({ $this.OnThemeChanged() })
        $this.OnThemeChanged()
    }
    
    [void] OnThemeChanged() {
        if ($this.Theme) {
            $this._colors = @{
                'tab.background' = $this.Theme.GetBgColor("tab.background")
                'tab.active.background' = $this.Theme.GetBgColor("tab.active.background")
                'tab.active.foreground' = $this.Theme.GetColor("tab.active.foreground")
                'tab.active.accent' = $this.Theme.GetColor("tab.active.accent")
                'tab.foreground' = $this.Theme.GetColor("tab.foreground")
                'border' = $this.Theme.GetColor("border")
            }
        }
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
            # Tab content should draw their own background
            $content.DrawBackground = $true
        }
        
        $this.Tabs.Add($tab)
        $this._dataVersion++  # Increment on tab change
        $this._tabBarInvalid = $true
        
        # Set as active if first tab
        if ($this.Tabs.Count -eq 1) {
            # Force activation of first tab by temporarily setting ActiveTabIndex to -1
            $oldIndex = $this.ActiveTabIndex
            $this.ActiveTabIndex = -1
            $this.ActivateTab(0)
            # If ActivateTab failed, restore the index
            if ($this.ActiveTabIndex -eq -1) {
                $this.ActiveTabIndex = $oldIndex
            }
        } else {
            # Position but don't add to children yet
            $this.PositionContent($content, $false)
        }
        
        $this.Invalidate()
    }
    
    # Switch to a specific tab
    [void] ActivateTab([int]$index) {
        if ($index -lt 0 -or $index -ge $this.Tabs.Count) { return }
        
        # Don't switch if already on this tab
        if ($index -eq $this.ActiveTabIndex) { return }
        
        $this._dataVersion++  # Increment on tab activation change
        
        if ($global:Logger) {
            $global:Logger.Debug("TabContainer.ActivateTab: Switching from tab $($this.ActiveTabIndex) to tab $index")
        }
        
        # Store old content reference
        $oldContent = $null
        
        # Deactivate current
        if ($this.ActiveTabIndex -ge 0 -and $this.ActiveTabIndex -lt $this.Tabs.Count) {
            $oldTab = $this.Tabs[$this.ActiveTabIndex]
            if ($oldTab.Content) {
                if ($global:Logger) {
                    $global:Logger.Debug("TabContainer: Removing old tab content: $($oldTab.Title)")
                }
                $oldContent = $oldTab.Content
                $this.RemoveChild($oldTab.Content)
            }
        }
        
        # Activate new
        $this.ActiveTabIndex = $index
        $newTab = $this.Tabs[$index]
        if ($newTab.Content) {
            if ($global:Logger) {
                $global:Logger.Debug("TabContainer: Adding new tab content: $($newTab.Title)")
                $global:Logger.Debug("TabContainer: Content type: $($newTab.Content.GetType().Name)")
                $global:Logger.Debug("TabContainer: Container bounds: X=$($this.X) Y=$($this.Y) W=$($this.Width) H=$($this.Height)")
            }
            $this.PositionContent($newTab.Content, $true)
            $this.AddChild($newTab.Content)
            if ($newTab.Content -is [Screen]) {
                # Tab content should draw its own background to clear old content
                $newTab.Content.DrawBackground = $true
                $newTab.Content.SetBackgroundColor([VT]::Reset())
                $newTab.Content.OnActivated()
            }
            # Force the new content to invalidate
            $newTab.Content.Invalidate()
            if ($global:Logger) {
                $global:Logger.Debug("TabContainer: New content bounds: X=$($newTab.Content.X) Y=$($newTab.Content.Y) W=$($newTab.Content.Width) H=$($newTab.Content.Height)")
            }
        }
        
        # Now safely deactivate old content after UI tree is updated
        if ($oldContent -and $oldContent -is [Screen]) {
            $oldContent.OnDeactivated()
        }
        
        $this._tabBarInvalid = $true
        $this.Invalidate()
        
        # Force parent to redraw completely to clear any artifacts
        if ($this.Parent) {
            $this.Parent.Invalidate()
        }
    }
    
    # Position content below tab bar
    hidden [void] PositionContent([UIElement]$content, [bool]$isActive) {
        # Only set bounds if we have valid dimensions
        if ($this.Width -gt 0 -and $this.Height -gt $this.TabBarHeight) {
            $content.SetBounds(
                $this.X,
                $this.Y + $this.TabBarHeight,
                $this.Width,
                $this.Height - $this.TabBarHeight
            )
        }
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
        
        $sb = Get-PooledStringBuilder 2048
        
        # Render tab bar
        if ($this._tabBarInvalid) {
            $this.RebuildTabBar()
        }
        $sb.Append($this._cachedTabBar)
        
        # Render active content (base class handles children)
        $baseRender = ([Container]$this).OnRender()
        $sb.Append($baseRender)
        
        if ($global:Logger) {
            $global:Logger.Debug("TabContainer.OnRender: Children.Count = $($this.Children.Count), baseRender.Length = $($baseRender.Length)")
            if ($this.Children.Count -gt 0) {
                $global:Logger.Debug("TabContainer.OnRender: First child type = $($this.Children[0].GetType().Name)")
            }
        }
        
        $result = $sb.ToString()
        Return-PooledStringBuilder $sb
        return $result
    }
    
    # Build the tab bar
    hidden [void] RebuildTabBar() {
        $sb = Get-PooledStringBuilder 1024
        
        # Tab bar background
        $sb.Append([VT]::MoveTo($this.X, $this.Y))
        $sb.Append($this._colors['tab.background'])
        $sb.Append([StringCache]::GetSpaces($this.Width))
        
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
                $sb.Append($this._colors['tab.active.background'])
                $sb.Append($this._colors['tab.active.foreground'])
                $sb.Append(" $title ")
                
                # Bottom accent line
                $sb.Append([VT]::MoveTo($x, $this.Y + 1))
                $sb.Append($this._colors['tab.active.accent'])
                $sb.Append([StringCache]::GetHorizontalLine($tabWidth - 2))
            } else {
                # Inactive tab
                $sb.Append($this._colors['tab.background'])
                $sb.Append($this._colors['tab.foreground'])
                $sb.Append(" $title ")
            }
            
            $x += $tabWidth + 1
        }
        
        # Reset and draw separator line
        $sb.Append([VT]::Reset())
        $sb.Append([VT]::MoveTo($this.X, $this.Y + 1))
        $sb.Append($this._colors['border'])
        $sb.Append([StringCache]::GetHorizontalLine($this.Width))
        $sb.Append([VT]::Reset())
        
        $this._cachedTabBar = $sb.ToString()
        Return-PooledStringBuilder $sb
        $this._tabBarInvalid = $false
    }
    
    # Handle keyboard input
    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        # Debug logging removed for performance
        
        # Check TabContainer shortcuts FIRST before passing to children
        
        # Number keys for quick tab switching
        if ($key.KeyChar -ge '1' -and $key.KeyChar -le '9') {
            $tabIndex = [int]$key.KeyChar - [int][char]'1'
            if ($tabIndex -lt $this.Tabs.Count) {
                if ($global:Logger) {
                    $global:Logger.Debug("TabContainer: Switching to tab $($tabIndex + 1)")
                }
                $this.ActivateTab($tabIndex)
                return $true
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
        
        # Route to active tab's content if tab switching didn't handle it
        $activeTab = $this.GetActiveTab()
        if ($activeTab -and $activeTab.Content) {
            if ($global:Logger) {
                $global:Logger.Debug("TabContainer: Routing input to active tab content: $($activeTab.Content.GetType().Name)")
            }
            if ($activeTab.Content.HandleInput($key)) {
                return $true
            }
        }
        
        # No one handled it
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