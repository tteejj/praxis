# TabContainer.ps1 - Fast tab-based screen switching
# Core component for PRAXIS multi-screen management

class TabContainer : Container {
    [System.Collections.Generic.List[TabItem]]$Tabs
    [int]$ActiveTabIndex = 0
    [int]$TabBarHeight = 1  # Simple single-line tab bar
    
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
                'tab.active.background' = $this.Theme.GetBgColor("tab.background.active")
                'tab.active.foreground' = $this.Theme.GetColor("tab.text.active")
                'tab.active.accent' = $this.Theme.GetColor("tab.border.active")
                'tab.foreground' = $this.Theme.GetColor("tab.text")
                'border' = $this.Theme.GetColor("border.normal")
                'background' = $this.Theme.GetBgColor("surface.background")
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
        $tab.IsInitialized = $false  # Content not initialized yet
        
        # Don't initialize screens here - wait until they're activated
        # This prevents slow startup when adding many tabs
        if ($content -is [Screen]) {
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
        
        if ($global:Logger) {
            $global:Logger.Info("TabContainer.ActivateTab: START switching to tab $index")
        }
        
        $this._dataVersion++  # Increment on tab activation change
        
        if ($global:Logger) {
            $global:Logger.Info("TabContainer.ActivateTab: About to deactivate current tab")
        }
        
        # Store old content reference
        $oldContent = $null
        
        # Deactivate current
        if ($this.ActiveTabIndex -ge 0 -and $this.ActiveTabIndex -lt $this.Tabs.Count) {
            if ($global:Logger) {
                $global:Logger.Info("TabContainer.ActivateTab: Deactivating current tab $($this.ActiveTabIndex)")
            }
            $oldTab = $this.Tabs[$this.ActiveTabIndex]
            if ($oldTab.Content) {
                $oldContent = $oldTab.Content
                if ($global:Logger) {
                    $global:Logger.Info("TabContainer.ActivateTab: Removing old child content")
                }
                $this.RemoveChild($oldTab.Content)
                if ($global:Logger) {
                    $global:Logger.Info("TabContainer.ActivateTab: Old child content removed")
                }
            }
        }
        
        # Activate new
        if ($global:Logger) {
            $global:Logger.Info("TabContainer.ActivateTab: About to activate new tab $index")
        }
        $this.ActiveTabIndex = $index
        $newTab = $this.Tabs[$index]
        if ($newTab.Content) {
            if ($global:Logger) {
                $global:Logger.Info("TabContainer.ActivateTab: New tab has content, checking initialization")
            }
            # Initialize content if not already done (lazy loading)
            if (-not $newTab.IsInitialized -and $newTab.Content -is [Screen] -and $global:ServiceContainer) {
                if ($global:Logger) {
                    $global:Logger.Info("TabContainer.ActivateTab: Initializing new tab content")
                }
                $newTab.Content.Initialize($global:ServiceContainer)
                $newTab.IsInitialized = $true
                if ($global:Logger) {
                    $global:Logger.Info("TabContainer.ActivateTab: New tab content initialized")
                }
            }
            
            if ($global:Logger) {
                $global:Logger.Info("TabContainer.ActivateTab: Positioning new content")
            }
            $this.PositionContent($newTab.Content, $true)
            if ($global:Logger) {
                $global:Logger.Info("TabContainer.ActivateTab: Adding new child")
            }
            $this.AddChild($newTab.Content)
            if ($global:Logger) {
                $global:Logger.Info("TabContainer.ActivateTab: New child added")
            }
            if ($newTab.Content -is [Screen]) {
                if ($global:Logger) {
                    $global:Logger.Info("TabContainer.ActivateTab: Setting up screen properties")
                }
                # Tab content should draw its own background with theme background
                $newTab.Content.DrawBackground = $true
                $bgColor = if ($this.Theme) { $this.Theme.GetBgColor("surface.background") } else { "" }
                $newTab.Content.SetBackgroundColor($bgColor)
                if ($global:Logger) {
                    $global:Logger.Info("TabContainer.ActivateTab: About to call OnActivated()")
                }
                $newTab.Content.OnActivated()
                if ($global:Logger) {
                    $global:Logger.Info("TabContainer.ActivateTab: OnActivated() completed")
                }
            }
            # Force the new content to invalidate
            if ($global:Logger) {
                $global:Logger.Info("TabContainer.ActivateTab: Invalidating new content")
            }
            $newTab.Content.Invalidate()
            if ($global:Logger) {
                $global:Logger.Info("TabContainer.ActivateTab: New content invalidated")
            }
        }
        
        # Now safely deactivate old content after UI tree is updated
        if ($oldContent -and $oldContent -is [Screen]) {
            if ($global:Logger) {
                $global:Logger.Info("TabContainer.ActivateTab: Deactivating old content")
            }
            $oldContent.OnDeactivated()
            if ($global:Logger) {
                $global:Logger.Info("TabContainer.ActivateTab: Old content deactivated")
            }
        }
        
        if ($global:Logger) {
            $global:Logger.Info("TabContainer.ActivateTab: COMPLETED switching to tab $index")
        }
        
        $this._tabBarInvalid = $true
        $this.Invalidate()
        
        # Force parent to redraw completely to clear any artifacts
        if ($this.Parent) {
            $this.Parent.Invalidate()
        }
        
        if ($global:Logger) {
            $global:Logger.Info("TabContainer.ActivateTab: COMPLETED switching to tab $index")
        }
    }
    
    # Position content below tab bar with Island Components gaps
    hidden [void] PositionContent([UIElement]$content, [bool]$isActive) {
        # Only set bounds if we have valid dimensions
        if ($this.Width -gt 0 -and $this.Height -gt $this.TabBarHeight) {
            # Island Components architecture standard gaps
            $gap = 2  # Standard visual separation per Island Components spec
            $topGap = 2  # Gap between tabs and content
            $availableWidth = $this.Width - ($gap * 2)
            $availableHeight = $this.Height - $this.TabBarHeight - $topGap - $gap
            
            # Ensure we don't create negative dimensions
            if ($availableWidth -gt 0 -and $availableHeight -gt 0) {
                $contentY = $this.Y + $this.TabBarHeight + $topGap
                $content.SetBounds(
                    $this.X + $gap,
                    $contentY,
                    $availableWidth,
                    $availableHeight
                )
            }
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
        $sb = Get-PooledStringBuilder 2048
        
        # Render tab bar
        if ($this._tabBarInvalid) {
            $this.RebuildTabBar()
        }
        $sb.Append($this._cachedTabBar)
        
        # Render active content (base class handles children)
        $baseRender = ([Container]$this).OnRender()
        $sb.Append($baseRender)
        
        $result = $sb.ToString()
        Return-PooledStringBuilder $sb
        return $result
    }
    
    # Build the tab bar
    hidden [void] RebuildTabBar() {
        $sb = Get-PooledStringBuilder 1024
        
        # Save cursor position to restore after tab bar rendering
        $sb.Append([VT]::SavePos())
        
        # Island Components: Tab bar using background color only (no borders)
        # Fill tab bar area with tab background color
        $sb.Append([VT]::MoveTo($this.X, $this.Y))
        $sb.Append($this._colors['tab.background'])
        $sb.Append([StringCache]::GetSpaces($this.Width))
        
        # Don't fill gap line - let content handle its own background
        # This prevents overlap issues with content positioning
        
        # Draw tabs with adaptive sizing for different terminal widths
        $x = $this.X + 2
        $availableWidth = $this.Width - 4  # Leave some margin
        $maxX = $this.X + $this.Width - 2  # Absolute maximum X position
        
        # First pass: calculate ideal widths
        $idealWidths = @()
        $totalIdealWidth = 0
        for ($i = 0; $i -lt $this.Tabs.Count; $i++) {
            $tab = $this.Tabs[$i]
            $title = $tab.Title
            
            # Add shortcut hint if applicable
            if ($tab.ShortcutKey -ge 1 -and $tab.ShortcutKey -le 9) {
                $title = "$($tab.ShortcutKey):$title"
            }
            
            $idealWidth = $title.Length + 4  # Padding
            $idealWidths += $idealWidth
            $totalIdealWidth += $idealWidth + 1  # +1 for spacing
        }
        
        # Adaptive sizing based on available space
        if ($totalIdealWidth -gt $availableWidth -and $this.Tabs.Count -gt 0) {
            # Need to compress tabs - use shorter titles and less padding
            for ($i = 0; $i -lt $this.Tabs.Count; $i++) {
                $tab = $this.Tabs[$i]
                $title = $tab.Title
                
                # Add shortcut hint
                if ($tab.ShortcutKey -ge 1 -and $tab.ShortcutKey -le 9) {
                    $shortTitle = "$($tab.ShortcutKey):$($title.Substring(0, [Math]::Min(4, $title.Length)))"
                } else {
                    $shortTitle = $title.Substring(0, [Math]::Min(6, $title.Length))
                }
                
                # Minimal padding for compact mode
                $tabWidth = $shortTitle.Length + 2
                
                # Don't draw if it would still overflow
                if (($x + $tabWidth) -gt $maxX) {
                    break
                }
                
                $sb.Append([VT]::MoveTo($x, $this.Y))
                
                # Tab styling
                if ($i -eq $this.ActiveTabIndex) {
                    # Active tab
                    $sb.Append($this._colors['tab.active.background'])
                    $sb.Append($this._colors['tab.active.foreground'])
                    $sb.Append(" $shortTitle ")
                } else {
                    # Inactive tab
                    $sb.Append($this._colors['tab.background'])
                    $sb.Append($this._colors['tab.foreground'])
                    $sb.Append(" $shortTitle ")
                }
                
                # Reset colors to prevent bleed
                $sb.Append($this._colors['tab.background'])
                
                $x += $tabWidth + 1
            }
        } else {
            # Plenty of space - use full titles
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
                if (($x + $tabWidth) -gt $maxX) {
                    break
                }
                
                $sb.Append([VT]::MoveTo($x, $this.Y))
                
                # Tab styling
                if ($i -eq $this.ActiveTabIndex) {
                    # Active tab
                    $sb.Append($this._colors['tab.active.background'])
                    $sb.Append($this._colors['tab.active.foreground'])
                    $sb.Append(" $title ")
                } else {
                    # Inactive tab
                    $sb.Append($this._colors['tab.background'])
                    $sb.Append($this._colors['tab.foreground'])
                    $sb.Append(" $title ")
                }
                
                # Reset colors to prevent bleed
                $sb.Append($this._colors['tab.background'])
                
                $x += $tabWidth + 1
            }
        }
        
        # Fill the rest of the tab bar line to prevent artifacts
        if ($x -lt $maxX) {
            $sb.Append([VT]::MoveTo($x, $this.Y))
            $sb.Append($this._colors['tab.background'])
            $sb.Append([StringCache]::GetSpaces($maxX - $x))
        }
        
        # Reset color at end
        $sb.Append([VT]::Reset())
        
        # Restore cursor position
        $sb.Append([VT]::RestorePos())
        
        # No separator line - let content draw its own borders to avoid T-junctions
        # Previously: Draw separator line caused T-junction conflicts with grid borders
        
        $this._cachedTabBar = $sb.ToString()
        Return-PooledStringBuilder $sb
        $this._tabBarInvalid = $false
    }
    
    # Handle keyboard input
    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        # CORRECT INPUT HIERARCHY: Children first, then container shortcuts
        
        # 1. Let child components handle input first
        $handled = ([Container]$this).HandleInput($key)
        if ($handled) {
            return $true
        }
        
        # 2. Only handle TabContainer shortcuts if no child handled the input
        
        # Number keys for quick tab switching (only when TabContainer has focus)
        if ($key.KeyChar -ge '1' -and $key.KeyChar -le '9') {
            $tabIndex = [int]$key.KeyChar - [int][char]'1'
            if ($tabIndex -lt $this.Tabs.Count) {
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
        
        # No TabContainer shortcut handled it
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
    [bool]$IsInitialized = $false  # Track if content has been initialized
}