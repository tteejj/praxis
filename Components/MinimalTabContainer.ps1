# MinimalTabContainer.ps1 - Clean tab container without rendering artifacts

class MinimalTabContainer : Container {
    [System.Collections.Generic.List[TabItem]]$Tabs
    [int]$ActiveTabIndex = -1
    [int]$TabBarHeight = 1  # Minimal single-line tabs
    
    hidden [ThemeManager]$Theme
    hidden [string]$_cachedTabBar = ""
    hidden [bool]$_tabBarInvalid = $true
    hidden [hashtable]$_colors = @{}
    
    # Double-buffering for artifact-free rendering
    hidden [UIElement]$_activeContent = $null
    hidden [bool]$_contentSwitching = $false
    
    MinimalTabContainer() : base() {
        $this.Tabs = [System.Collections.Generic.List[TabItem]]::new()
        $this.DrawBackground = $true  # Always clear background
    }
    
    [void] OnInitialize() {
        $this.Theme = $this.ServiceContainer.GetService("ThemeManager")
        $this.Theme.Subscribe({ $this.OnThemeChanged() })
        $this.OnThemeChanged()
    }
    
    [void] OnThemeChanged() {
        if ($this.Theme) {
            $this._colors = @{
                'normal' = $this.Theme.GetColor("tab.foreground")
                'active' = $this.Theme.GetColor("tab.active.foreground")
                'accent' = $this.Theme.GetColor("accent")
                'background' = $this.Theme.GetBgColor("background")
            }
        }
        $this._tabBarInvalid = $true
        $this.Invalidate()
    }
    
    [void] AddTab([string]$title, [UIElement]$content) {
        $tab = [TabItem]::new()
        $tab.Title = $title
        $tab.Content = $content
        $tab.ShortcutKey = [Math]::Min($this.Tabs.Count + 1, 9)
        
        # Initialize content
        if ($content -and $global:ServiceContainer) {
            $content.Initialize($global:ServiceContainer)
        }
        
        $this.Tabs.Add($tab)
        $this._tabBarInvalid = $true
        
        # Activate first tab
        if ($this.Tabs.Count -eq 1) {
            $this.ActivateTab(0)
        }
        
        $this.Invalidate()
    }
    
    [void] ActivateTab([int]$index) {
        if ($index -lt 0 -or $index -ge $this.Tabs.Count -or $index -eq $this.ActiveTabIndex) {
            return
        }
        
        # Begin content switch
        $this._contentSwitching = $true
        
        # Clear focus from old content
        $focusManager = $null
        if ($this.ServiceContainer) {
            $focusManager = $this.ServiceContainer.GetService('FocusManager')
        }
        
        if ($focusManager -and $this._activeContent) {
            $focused = $focusManager.GetFocused()
            if ($focused -and $this.ContainsElement($focused)) {
                $focusManager.ClearFocus()
            }
        }
        
        # Remove old content
        if ($this._activeContent) {
            $this.Children.Remove($this._activeContent)
            if ($this._activeContent -is [Screen]) {
                $this._activeContent.OnDeactivated()
            }
        }
        
        # Update index
        $this.ActiveTabIndex = $index
        $newTab = $this.Tabs[$index]
        
        # Set new content
        $this._activeContent = $newTab.Content
        if ($this._activeContent) {
            # Position content
            $contentY = $this.Y + $this.TabBarHeight
            $contentHeight = $this.Height - $this.TabBarHeight
            $this._activeContent.SetBounds($this.X, $contentY, $this.Width, $contentHeight)
            
            # Add to children
            $this.Children.Add($this._activeContent)
            
            # Activate if screen
            if ($this._activeContent -is [Screen]) {
                $this._activeContent.OnActivated()
            }
            
            # Focus first focusable element
            if ($focusManager) {
                $focusables = $focusManager.GetFocusableChildren($this._activeContent)
                if ($focusables.Count -gt 0) {
                    [void]$focusManager.SetFocus($focusables[0])
                }
            }
        }
        
        # End content switch
        $this._contentSwitching = $false
        $this._tabBarInvalid = $true
        $this.Invalidate()
    }
    
    [string] OnRender() {
        $sb = Get-PooledStringBuilder 4096
        
        # Clear entire area first to prevent artifacts
        if ($this.DrawBackground -and $this._colors.ContainsKey('background')) {
            $sb.Append($this._colors['background'])
            for ($y = 0; $y -lt $this.Height; $y++) {
                $sb.Append([VT]::MoveTo($this.X, $this.Y + $y))
                $sb.Append([StringCache]::GetSpaces($this.Width))
            }
        }
        
        # Render tab bar
        if ($this._tabBarInvalid) {
            $this.RebuildTabBar()
        }
        $sb.Append($this._cachedTabBar)
        
        # Render active content
        if ($this._activeContent -and -not $this._contentSwitching) {
            $sb.Append($this._activeContent.Render())
        }
        
        $result = $sb.ToString()
        Return-PooledStringBuilder $sb
        return $result
    }
    
    [void] RebuildTabBar() {
        $sb = Get-PooledStringBuilder 512
        
        # Move to tab bar position
        $sb.Append([VT]::MoveTo($this.X, $this.Y))
        
        # Clear tab bar line
        $sb.Append([StringCache]::GetSpaces($this.Width))
        $sb.Append([VT]::MoveTo($this.X, $this.Y))
        
        # Minimal tab style
        $x = $this.X + 1
        for ($i = 0; $i -lt $this.Tabs.Count; $i++) {
            $tab = $this.Tabs[$i]
            $title = $tab.Title
            
            # Add shortcut number if applicable
            if ($tab.ShortcutKey -le 9) {
                $title = "$($tab.ShortcutKey):$title"
            }
            
            # Active tab styling
            if ($i -eq $this.ActiveTabIndex) {
                $sb.Append($this._colors['accent'])
                $sb.Append(" [$title] ")
                $sb.Append([VT]::Reset())
            } else {
                $sb.Append($this._colors['normal'])
                $sb.Append("  $title  ")
            }
            
            $x += $title.Length + 4
            
            # Add separator
            if ($i -lt $this.Tabs.Count - 1 -and $x -lt ($this.X + $this.Width - 10)) {
                $sb.Append($this._colors['normal'])
                $sb.Append("│")
                $x += 1
            }
            
            # Stop if we run out of space
            if ($x -gt ($this.X + $this.Width - 5)) {
                break
            }
        }
        
        $sb.Append([VT]::Reset())
        
        # Subtle separator line
        $sb.Append([VT]::MoveTo($this.X, $this.Y + $this.TabBarHeight - 1))
        $sb.Append($this._colors['normal'])
        $sb.Append('─' * $this.Width)
        $sb.Append([VT]::Reset())
        
        $this._cachedTabBar = $sb.ToString()
        Return-PooledStringBuilder $sb
        $this._tabBarInvalid = $false
    }
    
    [void] OnBoundsChanged() {
        $this._tabBarInvalid = $true
        
        # Update active content bounds
        if ($this._activeContent) {
            $contentY = $this.Y + $this.TabBarHeight
            $contentHeight = $this.Height - $this.TabBarHeight
            $this._activeContent.SetBounds($this.X, $contentY, $this.Width, $contentHeight)
        }
    }
    
    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        # Number shortcuts for tabs
        if ($key.KeyChar -ge '1' -and $key.KeyChar -le '9') {
            $tabIndex = [int]($key.KeyChar - '1')
            if ($tabIndex -lt $this.Tabs.Count) {
                $this.ActivateTab($tabIndex)
                return $true
            }
        }
        
        # Tab navigation
        if ($key.Key -eq [System.ConsoleKey]::Tab -and 
            ($key.Modifiers -band [System.ConsoleModifiers]::Control)) {
            if ($key.Modifiers -band [System.ConsoleModifiers]::Shift) {
                # Ctrl+Shift+Tab - previous tab
                $newIndex = if ($this.ActiveTabIndex -gt 0) { $this.ActiveTabIndex - 1 } else { $this.Tabs.Count - 1 }
            } else {
                # Ctrl+Tab - next tab
                $newIndex = if ($this.ActiveTabIndex -lt $this.Tabs.Count - 1) { $this.ActiveTabIndex + 1 } else { 0 }
            }
            $this.ActivateTab($newIndex)
            return $true
        }
        
        # Delegate to active content
        return ([Container]$this).HandleInput($key)
    }
    
    # Helper class
    [bool] ContainsElement([UIElement]$element) {
        $current = $element
        while ($current) {
            if ($current -eq $this._activeContent) { return $true }
            $current = $current.Parent
        }
        return $false
    }
}

# TabItem class remains the same
class TabItem {
    [string]$Title
    [UIElement]$Content
    [int]$ShortcutKey = 0
}