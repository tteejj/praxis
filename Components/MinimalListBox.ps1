# MinimalListBox.ps1 - Clean, minimalist list box component

class MinimalListBox : FocusableComponent {
    [System.Collections.Generic.List[object]]$Items
    [int]$SelectedIndex = -1
    [scriptblock]$OnSelectionChanged = {}
    [bool]$ShowBorder = $false
    [BorderType]$BorderType = [BorderType]::Rounded
    [bool]$ShowScrollbar = $true
    
    # Display options
    [scriptblock]$ItemFormatter = { param($item) $item.ToString() }
    [int]$MaxDisplayLength = 0  # 0 = no limit
    
    # Scrolling
    hidden [int]$_scrollOffset = 0
    hidden [int]$_viewportHeight = 0
    
    # Cached colors
    hidden [string]$_normalColor = ""
    hidden [string]$_selectedColor = ""
    hidden [string]$_selectedBgColor = ""
    hidden [string]$_scrollbarColor = ""
    
    MinimalListBox() : base() {
        $this.Items = [System.Collections.Generic.List[object]]::new()
        $this.FocusStyle = 'minimal'
    }
    
    [void] OnInitialize() {
        ([FocusableComponent]$this).OnInitialize()
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
            $this._normalColor = $this.Theme.GetColor('normal')
            $this._selectedColor = $this.Theme.GetColor('menu.selected.foreground')
            $this._selectedBgColor = $this.Theme.GetBgColor('menu.selected.background')
            $this._scrollbarColor = $this.Theme.GetColor('scrollbar')
        }
    }
    
    [void] SetItems([object[]]$items) {
        $this.Items.Clear()
        $this.Items.AddRange($items)
        
        # Reset selection if out of bounds
        if ($this.SelectedIndex -ge $this.Items.Count) {
            $this.SelectedIndex = $this.Items.Count - 1
        }
        
        $this.Invalidate()
    }
    
    [object] GetSelectedItem() {
        if ($this.SelectedIndex -ge 0 -and $this.SelectedIndex -lt $this.Items.Count) {
            return $this.Items[$this.SelectedIndex]
        }
        return $null
    }
    
    [string] RenderContent() {
        $sb = Get-PooledStringBuilder 2048
        
        # Calculate viewport
        $this._viewportHeight = $this.Height
        if ($this.ShowBorder) { $this._viewportHeight -= 2 }
        
        # Ensure scroll offset is valid
        $this.EnsureSelectedVisible()
        
        # Draw items
        $startY = $this.Y
        if ($this.ShowBorder) { $startY++ }
        
        $endIndex = [Math]::Min($this._scrollOffset + $this._viewportHeight, $this.Items.Count)
        
        for ($i = $this._scrollOffset; $i -lt $endIndex; $i++) {
            $y = $startY + ($i - $this._scrollOffset)
            $sb.Append([VT]::MoveTo($this.X + 1, $y))
            
            # Format item
            $text = & $this.ItemFormatter $this.Items[$i]
            if ($this.MaxDisplayLength -gt 0 -and $text.Length -gt $this.MaxDisplayLength) {
                $text = $text.Substring(0, $this.MaxDisplayLength - 1) + "…"
            }
            
            # Pad to width
            $availableWidth = $this.Width - 2
            if ($this.ShowScrollbar -and $this.Items.Count -gt $this._viewportHeight) {
                $availableWidth--
            }
            
            if ($text.Length -lt $availableWidth) {
                $text = $text.PadRight($availableWidth)
            } elseif ($text.Length -gt $availableWidth) {
                $text = $text.Substring(0, $availableWidth - 1) + "…"
            }
            
            # Render with selection highlight
            if ($i -eq $this.SelectedIndex) {
                $sb.Append($this._selectedBgColor)
                $sb.Append($this._selectedColor)
                if ($this.IsFocused) {
                    $sb.Append("▸ ")  # Minimal focus indicator
                    $text = $text.Substring(2)
                }
            } else {
                $sb.Append($this._normalColor)
                $sb.Append("  ")
                $text = $text.Substring(2)
            }
            
            $sb.Append($text)
            $sb.Append([VT]::Reset())
        }
        
        # Minimal scrollbar
        if ($this.ShowScrollbar -and $this.Items.Count -gt $this._viewportHeight) {
            $this.RenderMinimalScrollbar($sb)
        }
        
        # Border if enabled
        if ($this.ShowBorder) {
            $this.RenderMinimalBorder($sb)
        }
        
        $result = $sb.ToString()
        Return-PooledStringBuilder $sb
        return $result
    }
    
    [void] RenderMinimalScrollbar([System.Text.StringBuilder]$sb) {
        $scrollbarX = $this.X + $this.Width - 1
        $scrollbarHeight = $this._viewportHeight
        $scrollbarY = $this.Y
        if ($this.ShowBorder) { 
            $scrollbarY++
            $scrollbarHeight = [Math]::Max(1, $scrollbarHeight - 2)
        }
        
        # Calculate thumb position
        $thumbSize = [Math]::Max(1, [int]($scrollbarHeight * $scrollbarHeight / $this.Items.Count))
        $thumbPos = [int]($this._scrollOffset * ($scrollbarHeight - $thumbSize) / ($this.Items.Count - $this._viewportHeight))
        
        $sb.Append($this._scrollbarColor)
        
        for ($i = 0; $i -lt $scrollbarHeight; $i++) {
            $sb.Append([VT]::MoveTo($scrollbarX, $scrollbarY + $i))
            if ($i -ge $thumbPos -and $i -lt ($thumbPos + $thumbSize)) {
                $sb.Append('▐')  # Minimal scrollbar thumb
            } else {
                $sb.Append('│')  # Minimal scrollbar track
            }
        }
        
        $sb.Append([VT]::Reset())
    }
    
    [void] RenderMinimalBorder([System.Text.StringBuilder]$sb) {
        # Use BorderStyle for consistent rendering
        $borderColor = if ($this.IsFocused) { 
            $this.Theme.GetColor('border.focused') 
        } else { 
            $this.Theme.GetColor('border.normal') 
        }
        $sb.Append([BorderStyle]::RenderBorder($this.X, $this.Y, $this.Width, $this.Height, $this.BorderType, $borderColor))
    }
    
    [void] EnsureSelectedVisible() {
        if ($this.SelectedIndex -lt 0 -or $this.Items.Count -eq 0) { return }
        
        if ($this.SelectedIndex -lt $this._scrollOffset) {
            $this._scrollOffset = $this.SelectedIndex
        } elseif ($this.SelectedIndex -ge ($this._scrollOffset + $this._viewportHeight)) {
            $this._scrollOffset = $this.SelectedIndex - $this._viewportHeight + 1
        }
        
        # Clamp scroll offset
        $maxScroll = [Math]::Max(0, $this.Items.Count - $this._viewportHeight)
        $this._scrollOffset = [Math]::Max(0, [Math]::Min($this._scrollOffset, $maxScroll))
    }
    
    [bool] OnHandleInput([System.ConsoleKeyInfo]$key) {
        if ($this.Items.Count -eq 0) { return $false }
        
        $oldIndex = $this.SelectedIndex
        
        switch ($key.Key) {
            ([System.ConsoleKey]::UpArrow) {
                if ($this.SelectedIndex -gt 0) {
                    $this.SelectedIndex--
                    $this.OnSelectionChangedInternal($oldIndex)
                }
                return $true
            }
            ([System.ConsoleKey]::DownArrow) {
                if ($this.SelectedIndex -lt ($this.Items.Count - 1)) {
                    $this.SelectedIndex++
                    $this.OnSelectionChangedInternal($oldIndex)
                }
                return $true
            }
            ([System.ConsoleKey]::Home) {
                $this.SelectedIndex = 0
                $this._scrollOffset = 0
                $this.OnSelectionChangedInternal($oldIndex)
                return $true
            }
            ([System.ConsoleKey]::End) {
                $this.SelectedIndex = $this.Items.Count - 1
                $this.OnSelectionChangedInternal($oldIndex)
                return $true
            }
            ([System.ConsoleKey]::PageUp) {
                $this.SelectedIndex = [Math]::Max(0, $this.SelectedIndex - $this._viewportHeight)
                $this.OnSelectionChangedInternal($oldIndex)
                return $true
            }
            ([System.ConsoleKey]::PageDown) {
                $this.SelectedIndex = [Math]::Min($this.Items.Count - 1, $this.SelectedIndex + $this._viewportHeight)
                $this.OnSelectionChangedInternal($oldIndex)
                return $true
            }
            ([System.ConsoleKey]::Enter) {
                if ($this.OnSelectionChanged) {
                    & $this.OnSelectionChanged
                }
                return $true
            }
        }
        
        return $false
    }
    
    [void] OnSelectionChangedInternal([int]$oldIndex) {
        if ($oldIndex -ne $this.SelectedIndex) {
            $this.Invalidate()
            if ($this.OnSelectionChanged) {
                & $this.OnSelectionChanged
            }
        }
    }
    
    [void] OnGotFocus() {
        if ($this.SelectedIndex -lt 0 -and $this.Items.Count -gt 0) {
            $this.SelectedIndex = 0
        }
        ([FocusableComponent]$this).OnGotFocus()
    }
}