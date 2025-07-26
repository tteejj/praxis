# MinimalContextMenu.ps1 - Clean, minimal context menu component

class ContextMenuItem {
    [string]$Text
    [string]$Shortcut = ""
    [scriptblock]$Action
    [bool]$IsSeparator = $false
    [bool]$IsEnabled = $true
    [string]$Icon = ""  # Optional icon/emoji
    
    ContextMenuItem() {}
    
    ContextMenuItem([string]$text, [scriptblock]$action) {
        $this.Text = $text
        $this.Action = $action
    }
    
    static [ContextMenuItem] Separator() {
        $item = [ContextMenuItem]::new()
        $item.IsSeparator = $true
        return $item
    }
}

class MinimalContextMenu : UIElement {
    [System.Collections.Generic.List[ContextMenuItem]]$Items
    [int]$SelectedIndex = 0
    [bool]$IsVisible = $false
    [int]$MenuX = 0
    [int]$MenuY = 0
    [int]$MenuWidth = 0
    [int]$MenuHeight = 0
    [scriptblock]$OnClose = {}
    
    # Styling
    [BorderType]$BorderType = [BorderType]::Rounded
    [bool]$ShowShadow = $true
    [int]$MinWidth = 20
    [int]$MaxWidth = 40
    
    # Colors
    hidden [hashtable]$_colors = @{}
    hidden [ThemeManager]$Theme
    
    MinimalContextMenu() : base() {
        $this.Items = [System.Collections.Generic.List[ContextMenuItem]]::new()
        $this.IsFocusable = $true
    }
    
    [void] OnInitialize() {
        $this.Theme = $this.ServiceContainer.GetService('ThemeManager')
        $this.UpdateColors()
        if ($this.Theme) {
            # Subscribe to theme changes via EventBus
            $eventBus = $this.ServiceContainer.GetService('EventBus')
            if ($eventBus) {
                $eventBus.Subscribe('theme.changed', {
                    param($sender, $eventData)
                    $this.UpdateColors()
                }.GetNewClosure())
            }
        }
    }
    
    [void] UpdateColors() {
        if ($this.Theme) {
            $this._colors = @{
                background = $this.Theme.GetBgColor('menu.background')
                text = $this.Theme.GetColor('menu.foreground')
                selected = $this.Theme.GetColor('menu.selected.foreground')
                selectedBg = $this.Theme.GetBgColor('menu.selected.background')
                disabled = $this.Theme.GetColor('disabled')
                border = $this.Theme.GetColor('border')
                shortcut = $this.Theme.GetColor('accent')
                separator = $this.Theme.GetColor('border')
            }
        }
    }
    
    [void] AddItem([string]$text, [scriptblock]$action) {
        $this.Items.Add([ContextMenuItem]::new($text, $action))
    }
    
    [void] AddItem([ContextMenuItem]$item) {
        $this.Items.Add($item)
    }
    
    [void] AddSeparator() {
        $this.Items.Add([ContextMenuItem]::Separator())
    }
    
    [void] Show([int]$x, [int]$y) {
        $this.MenuX = $x
        $this.MenuY = $y
        $this.IsVisible = $true
        
        # Calculate menu dimensions
        $this.CalculateSize()
        
        # Adjust position to stay on screen
        $screenWidth = [Console]::WindowWidth
        $screenHeight = [Console]::WindowHeight
        
        if ($this.MenuX + $this.MenuWidth -gt $screenWidth) {
            $this.MenuX = $screenWidth - $this.MenuWidth - 1
        }
        if ($this.MenuY + $this.MenuHeight -gt $screenHeight) {
            $this.MenuY = $screenHeight - $this.MenuHeight - 1
        }
        
        # Find first selectable item
        $this.SelectedIndex = -1
        for ($i = 0; $i -lt $this.Items.Count; $i++) {
            if (-not $this.Items[$i].IsSeparator -and $this.Items[$i].IsEnabled) {
                $this.SelectedIndex = $i
                break
            }
        }
        
        $this.Focus()
        $this.Invalidate()
    }
    
    [void] Hide() {
        $this.IsVisible = $false
        if ($this.OnClose) {
            & $this.OnClose
        }
        $this.Invalidate()
    }
    
    [void] CalculateSize() {
        $maxTextLength = 0
        $maxShortcutLength = 0
        
        foreach ($item in $this.Items) {
            if (-not $item.IsSeparator) {
                $textLen = $item.Text.Length
                if ($item.Icon) { $textLen += 3 }  # Icon + space
                $maxTextLength = [Math]::Max($maxTextLength, $textLen)
                $maxShortcutLength = [Math]::Max($maxShortcutLength, $item.Shortcut.Length)
            }
        }
        
        # Width = padding + text + gap + shortcut + padding
        $this.MenuWidth = 2 + $maxTextLength + 2 + $maxShortcutLength + 2
        $this.MenuWidth = [Math]::Max($this.MinWidth, [Math]::Min($this.MaxWidth, $this.MenuWidth))
        
        # Height = border + items + border
        $this.MenuHeight = 2 + $this.Items.Count
    }
    
    [string] OnRender() {
        if (-not $this.IsVisible) { return "" }
        
        $sb = Get-PooledStringBuilder 2048
        
        # Shadow
        if ($this.ShowShadow) {
            $this.RenderShadow($sb)
        }
        
        # Background
        $sb.Append($this._colors.background)
        for ($y = 0; $y -lt $this.MenuHeight; $y++) {
            $sb.Append([VT]::MoveTo($this.MenuX, $this.MenuY + $y))
            $sb.Append(' ' * $this.MenuWidth)
        }
        
        # Border
        $sb.Append([BorderStyle]::RenderBorder(
            $this.MenuX, $this.MenuY, $this.MenuWidth, $this.MenuHeight,
            $this.BorderType, $this._colors.border
        ))
        
        # Items
        $y = $this.MenuY + 1
        for ($i = 0; $i -lt $this.Items.Count; $i++) {
            $this.RenderItem($sb, $this.Items[$i], $i, $y)
            $y++
        }
        
        $sb.Append([VT]::Reset())
        
        $result = $sb.ToString()
        Return-PooledStringBuilder $sb
        return $result
    }
    
    [void] RenderShadow([System.Text.StringBuilder]$sb) {
        $shadowColor = [VT]::RGBBG(20, 20, 20)
        
        # Right shadow
        for ($y = 1; $y -lt $this.MenuHeight; $y++) {
            $sb.Append([VT]::MoveTo($this.MenuX + $this.MenuWidth, $this.MenuY + $y))
            $sb.Append($shadowColor)
            $sb.Append(' ')
        }
        
        # Bottom shadow
        $sb.Append([VT]::MoveTo($this.MenuX + 1, $this.MenuY + $this.MenuHeight))
        $sb.Append($shadowColor)
        $sb.Append(' ' * $this.MenuWidth)
        
        $sb.Append([VT]::Reset())
    }
    
    [void] RenderItem([System.Text.StringBuilder]$sb, [ContextMenuItem]$item, [int]$index, [int]$y) {
        $sb.Append([VT]::MoveTo($this.MenuX + 1, $y))
        
        if ($item.IsSeparator) {
            # Render separator
            $sb.Append($this._colors.separator)
            $sb.Append('─' * ($this.MenuWidth - 2))
        } else {
            # Selection highlight
            if ($index -eq $this.SelectedIndex) {
                $sb.Append($this._colors.selectedBg)
                $sb.Append($this._colors.selected)
            } else {
                $sb.Append($this._colors.background)
                if ($item.IsEnabled) {
                    $sb.Append($this._colors.text)
                } else {
                    $sb.Append($this._colors.disabled)
                }
            }
            
            # Icon
            if ($item.Icon) {
                $sb.Append(" $($item.Icon) ")
            } else {
                $sb.Append("  ")
            }
            
            # Text
            $text = $item.Text
            $availableWidth = $this.MenuWidth - 6  # Borders + padding
            if ($item.Shortcut) {
                $availableWidth -= ($item.Shortcut.Length + 2)
            }
            
            if ($text.Length -gt $availableWidth) {
                $text = $text.Substring(0, $availableWidth - 1) + "…"
            }
            $sb.Append($text)
            
            # Padding
            $paddingLength = $availableWidth - $text.Length
            if ($paddingLength -gt 0) {
                $sb.Append(' ' * $paddingLength)
            }
            
            # Shortcut
            if ($item.Shortcut) {
                $sb.Append("  ")
                if ($index -eq $this.SelectedIndex) {
                    $sb.Append($this._colors.selected)
                } else {
                    $sb.Append($this._colors.shortcut)
                }
                $sb.Append($item.Shortcut)
            }
            
            # Clear to end
            $sb.Append("  ")
        }
        
        $sb.Append([VT]::Reset())
    }
    
    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        if (-not $this.IsVisible) { return $false }
        
        switch ($key.Key) {
            ([System.ConsoleKey]::Escape) {
                $this.Hide()
                return $true
            }
            ([System.ConsoleKey]::UpArrow) {
                $this.SelectPrevious()
                return $true
            }
            ([System.ConsoleKey]::DownArrow) {
                $this.SelectNext()
                return $true
            }
            ([System.ConsoleKey]::Enter) {
                $this.ExecuteSelected()
                return $true
            }
            ([System.ConsoleKey]::Home) {
                $this.SelectFirst()
                return $true
            }
            ([System.ConsoleKey]::End) {
                $this.SelectLast()
                return $true
            }
        }
        
        # Check for shortcut keys
        foreach ($item in $this.Items) {
            if ($item.Shortcut -and $item.IsEnabled -and -not $item.IsSeparator) {
                # Simple shortcut matching (first character)
                if ($item.Shortcut.Length -gt 0 -and 
                    [char]::ToUpper($key.KeyChar) -eq [char]::ToUpper($item.Shortcut[0])) {
                    if ($item.Action) {
                        & $item.Action
                    }
                    $this.Hide()
                    return $true
                }
            }
        }
        
        return $false
    }
    
    [void] SelectNext() {
        if ($this.Items.Count -eq 0) { return }
        
        $start = $this.SelectedIndex
        do {
            $this.SelectedIndex = ($this.SelectedIndex + 1) % $this.Items.Count
            $item = $this.Items[$this.SelectedIndex]
        } while (($item.IsSeparator -or -not $item.IsEnabled) -and $this.SelectedIndex -ne $start)
        
        $this.Invalidate()
    }
    
    [void] SelectPrevious() {
        if ($this.Items.Count -eq 0) { return }
        
        $start = $this.SelectedIndex
        do {
            $this.SelectedIndex--
            if ($this.SelectedIndex -lt 0) {
                $this.SelectedIndex = $this.Items.Count - 1
            }
            $item = $this.Items[$this.SelectedIndex]
        } while (($item.IsSeparator -or -not $item.IsEnabled) -and $this.SelectedIndex -ne $start)
        
        $this.Invalidate()
    }
    
    [void] SelectFirst() {
        for ($i = 0; $i -lt $this.Items.Count; $i++) {
            $item = $this.Items[$i]
            if (-not $item.IsSeparator -and $item.IsEnabled) {
                $this.SelectedIndex = $i
                $this.Invalidate()
                return
            }
        }
    }
    
    [void] SelectLast() {
        for ($i = $this.Items.Count - 1; $i -ge 0; $i--) {
            $item = $this.Items[$i]
            if (-not $item.IsSeparator -and $item.IsEnabled) {
                $this.SelectedIndex = $i
                $this.Invalidate()
                return
            }
        }
    }
    
    [void] ExecuteSelected() {
        if ($this.SelectedIndex -ge 0 -and $this.SelectedIndex -lt $this.Items.Count) {
            $item = $this.Items[$this.SelectedIndex]
            if ($item.IsEnabled -and -not $item.IsSeparator -and $item.Action) {
                & $item.Action
            }
        }
        $this.Hide()
    }
}