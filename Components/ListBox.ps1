# ListBox.ps1 - Fast list box component with selection and scrolling

class ListBox : UIElement {
    [System.Collections.ArrayList]$Items
    [int]$SelectedIndex = 0
    [int]$ScrollOffset = 0
    [int]$VisibleItems = 10
    [bool]$ShowBorder = $true
    [bool]$ShowScrollbar = $true
    
    # Display properties
    [scriptblock]$ItemRenderer = { param($item) $item.ToString() }
    [string]$Title = ""
    
    # Callback for selection changes
    [scriptblock]$OnSelectionChanged = {}
    
    # Cached rendering
    hidden [string]$_cachedItems = ""
    hidden [bool]$_itemsCacheInvalid = $true
    hidden [ThemeManager]$Theme
    
    # Version-based change detection
    hidden [int]$_dataVersion = 0
    hidden [int]$_lastRenderedVersion = -1
    hidden [string]$_cachedRender = ""
    
    # Cached theme colors
    hidden [hashtable]$_colors = @{}
    
    ListBox() : base() {
        $this.Items = [System.Collections.ArrayList]::new()
        $this.IsFocusable = $true
    }
    
    [void] OnInitialize() {
        $this.Theme = $this.ServiceContainer.GetService("ThemeManager")
        $this.Theme.Subscribe({ $this.OnThemeChanged() })
        $this.OnThemeChanged()
    }
    
    [void] OnThemeChanged() {
        # Cache colors on theme change
        if ($this.Theme) {
            $this._colors = @{
                "accent" = $this.Theme.GetColor("accent")
                "foreground" = $this.Theme.GetColor("foreground")
                "selection.bg" = $this.Theme.GetBgColor("selection")
                "selection.fg" = $this.Theme.GetColor("menu.selected.foreground")
                "border" = $this.Theme.GetColor("border")
                "border.focused" = $this.Theme.GetColor("border.focused")
                "scrollbar" = $this.Theme.GetColor("scrollbar")
                "scrollbar.thumb" = $this.Theme.GetColor("scrollbar.thumb")
                "disabled" = $this.Theme.GetColor("disabled")
                "background" = $this.Theme.GetBgColor("background")
            }
        }
        $this._dataVersion++  # Increment for theme change
        $this._itemsCacheInvalid = $true
        $this.Invalidate()
    }
    
    [void] SetItems([array]$items) {
        $oldIndex = $this.SelectedIndex
        $this.Items.Clear()
        $this.Items.AddRange($items)
        $this.SelectedIndex = 0
        $this.ScrollOffset = 0
        $this._dataVersion++  # Increment on any data change
        $this._itemsCacheInvalid = $true
        $this.Invalidate()
        
        # Trigger callback if we have items and the selection changed
        if ($this.Items.Count -gt 0 -and ($oldIndex -ne 0 -or $this.Items.Count -eq 1) -and $this.OnSelectionChanged) {
            try {
                & $this.OnSelectionChanged
            } catch {
                if ($global:Logger) {
                    $global:Logger.Error("ListBox.SetItems: Error executing OnSelectionChanged handler - $($_.Exception.Message)")
                }
            }
        }
    }
    
    [void] AddItem([object]$item) {
        $this.Items.Add($item)
        $this._itemsCacheInvalid = $true
        $this.Invalidate()
    }
    
    [object] GetSelectedItem() {
        if ($this.SelectedIndex -ge 0 -and $this.SelectedIndex -lt $this.Items.Count) {
            return $this.Items[$this.SelectedIndex]
        }
        return $null
    }
    
    [void] SelectIndex([int]$index) {
        if ($index -ge 0 -and $index -lt $this.Items.Count) {
            $oldIndex = $this.SelectedIndex
            $this.SelectedIndex = $index
            $this.EnsureVisible($index)
            $this._dataVersion++  # Increment on selection change
            $this._itemsCacheInvalid = $true
            $this.Invalidate()
            
            # Trigger callback if selection actually changed
            if ($oldIndex -ne $index -and $this.OnSelectionChanged) {
                try {
                    & $this.OnSelectionChanged
                } catch {
                    if ($global:Logger) {
                        $global:Logger.Error("ListBox.SelectIndex: Error executing OnSelectionChanged handler - $($_.Exception.Message)")
                    }
                }
            }
        }
    }
    
    [void] EnsureVisible([int]$index) {
        # Adjust scroll to keep selected item visible
        $visibleEnd = $this.ScrollOffset + $this.VisibleItems - 1
        
        if ($index -lt $this.ScrollOffset) {
            $this.ScrollOffset = $index
        } elseif ($index -gt $visibleEnd) {
            $this.ScrollOffset = $index - $this.VisibleItems + 1
        }
    }
    
    [void] OnBoundsChanged() {
        # Recalculate visible items based on height
        $contentHeight = $this.Height
        if ($this.ShowBorder) { $contentHeight -= 2 }
        if ($this.Title) { $contentHeight -= 1 }
        
        $this.VisibleItems = [Math]::Max(1, $contentHeight)
        $this._itemsCacheInvalid = $true
    }
    
    [string] OnRender() {
        if ($this._itemsCacheInvalid) {
            $this.RebuildItemsCache()
        }
        return $this._cachedItems
    }
    
    [void] RebuildItemsCache() {
        $sb = Get-PooledStringBuilder 2048  # ListBox can have many items
        
        $contentX = $this.X
        $contentY = $this.Y
        $contentWidth = $this.Width
        
        # Draw border if enabled
        if ($this.ShowBorder) {
            $this.DrawBorder($sb)
            $contentX++
            $contentY++
            $contentWidth -= 2
        }
        
        # Draw title if present
        if ($this.Title) {
            $sb.Append([VT]::MoveTo($contentX, $contentY))
            $sb.Append($this._colors["accent"])
            $titleText = $this.Title
            if ($titleText.Length -gt $contentWidth) {
                $titleText = $titleText.Substring(0, $contentWidth - 3) + "..."
            }
            $sb.Append($titleText)
            $sb.Append($this._colors["foreground"])
            $contentY++
        }
        
        # Draw items
        $endIndex = [Math]::Min($this.ScrollOffset + $this.VisibleItems, $this.Items.Count)
        $itemY = $contentY
        
        for ($i = $this.ScrollOffset; $i -lt $endIndex; $i++) {
            $item = $this.Items[$i]
            $text = & $this.ItemRenderer $item
            
            # Truncate if too long
            if ($text.Length -gt $contentWidth - 2) {
                $text = $text.Substring(0, $contentWidth - 5) + "..."
            }
            
            $sb.Append([VT]::MoveTo($contentX, $itemY))
            
            # Selection highlighting
            if ($i -eq $this.SelectedIndex) {
                if ($this.IsFocused) {
                    $sb.Append($this._colors["selection.bg"])
                    $sb.Append($this._colors["selection.fg"])
                } else {
                    $sb.Append($this._colors["disabled"])
                }
                $sb.Append("> ")
            } else {
                $sb.Append("  ")
            }
            
            $sb.Append($text)
            
            # Clear to end of line if selected
            if ($i -eq $this.SelectedIndex) {
                $remainingSpace = $contentWidth - $text.Length - 2
                if ($remainingSpace -gt 0) {
                    $sb.Append([StringCache]::GetSpaces($remainingSpace))
                }
                $sb.Append([VT]::Reset())
            }
            
            $itemY++
        }
        
        # Clear any remaining empty lines in the visible area
        $remainingLines = $this.VisibleItems - ($endIndex - $this.ScrollOffset)
        if ($remainingLines -gt 0) {
            $bgColor = $this._colors["background"]
            $clearLine = [StringCache]::GetSpaces($contentWidth)
            
            for ($i = 0; $i -lt $remainingLines; $i++) {
                $sb.Append([VT]::MoveTo($contentX, $itemY))
                $sb.Append($bgColor)
                $sb.Append($clearLine)
                $sb.Append([VT]::Reset())
                $itemY++
            }
        }
        
        # Draw scrollbar if enabled and needed
        if ($this.ShowScrollbar -and $this.Items.Count -gt $this.VisibleItems) {
            $this.DrawScrollbar($sb)
        }
        
        $sb.Append([VT]::Reset())
        $this._cachedItems = $sb.ToString()
        Return-PooledStringBuilder $sb  # Return to pool for reuse
        $this._itemsCacheInvalid = $false
    }
    
    [void] DrawBorder([System.Text.StringBuilder]$sb) {
        $borderColor = if ($this.IsFocused) { 
            $this._colors["border.focused"] 
        } else { 
            $this._colors["border"] 
        }
        
        # Top border
        $sb.Append([VT]::MoveTo($this.X, $this.Y))
        $sb.Append($borderColor)
        $sb.Append([VT]::TL() + [StringCache]::GetVTHorizontal($this.Width - 2) + [VT]::TR())
        
        # Side borders
        for ($y = 1; $y -lt $this.Height - 1; $y++) {
            $sb.Append([VT]::MoveTo($this.X, $this.Y + $y))
            $sb.Append([VT]::V())
            $sb.Append([VT]::MoveTo($this.X + $this.Width - 1, $this.Y + $y))
            $sb.Append([VT]::V())
        }
        
        # Bottom border
        $sb.Append([VT]::MoveTo($this.X, $this.Y + $this.Height - 1))
        $sb.Append([VT]::BL() + [StringCache]::GetVTHorizontal($this.Width - 2) + [VT]::BR())
        $sb.Append([VT]::Reset())
    }
    
    [void] DrawScrollbar([System.Text.StringBuilder]$sb) {
        $scrollbarX = $this.X + $this.Width - 1
        if ($this.ShowBorder) { $scrollbarX-- }
        
        $scrollbarY = $this.Y + 1
        if ($this.ShowBorder) { $scrollbarY++ }
        if ($this.Title) { $scrollbarY++ }
        
        $scrollbarHeight = $this.VisibleItems
        
        # Calculate thumb position and size
        $thumbSize = [Math]::Max(1, [int]($scrollbarHeight * $this.VisibleItems / $this.Items.Count))
        $thumbPos = [int]($scrollbarY + ($scrollbarHeight - $thumbSize) * $this.ScrollOffset / ($this.Items.Count - $this.VisibleItems))
        
        # Draw scrollbar track and thumb
        for ($y = $scrollbarY; $y -lt $scrollbarY + $scrollbarHeight; $y++) {
            $sb.Append([VT]::MoveTo($scrollbarX, $y))
            
            if ($y -ge $thumbPos -and $y -lt $thumbPos + $thumbSize) {
                $sb.Append($this._colors["accent"])
                $sb.Append("█")
            } else {
                $sb.Append($this._colors["border"])
                $sb.Append("│")
            }
        }
    }
    
    # Input handling
    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        try {
            $handled = $false
            
            switch ($key.Key) {
            ([System.ConsoleKey]::UpArrow) {
                if ($this.SelectedIndex -gt 0) {
                    $this.SelectIndex($this.SelectedIndex - 1)
                    $handled = $true
                }
            }
            ([System.ConsoleKey]::DownArrow) {
                if ($this.SelectedIndex -lt $this.Items.Count - 1) {
                    $this.SelectIndex($this.SelectedIndex + 1)
                    $handled = $true
                }
            }
            ([System.ConsoleKey]::PageUp) {
                $newIndex = [Math]::Max(0, $this.SelectedIndex - $this.VisibleItems)
                $this.SelectIndex($newIndex)
                $handled = $true
            }
            ([System.ConsoleKey]::PageDown) {
                $newIndex = [Math]::Min($this.Items.Count - 1, $this.SelectedIndex + $this.VisibleItems)
                $this.SelectIndex($newIndex)
                $handled = $true
            }
            ([System.ConsoleKey]::Home) {
                $this.SelectIndex(0)
                $handled = $true
            }
            ([System.ConsoleKey]::End) {
                $this.SelectIndex($this.Items.Count - 1)
                $handled = $true
            }
            }
            
            return $handled
        } catch {
            if ($global:Logger) {
                $global:Logger.Error("ListBox.HandleInput: Error processing input - $($_.Exception.Message)")
            }
            return $false
        }
    }
    
    # Focus handling
    [void] OnGotFocus() {
        $this._dataVersion++  # Increment for focus change
        $this._itemsCacheInvalid = $true
        $this.Invalidate()
    }
    
    [void] OnLostFocus() {
        $this._dataVersion++  # Increment for focus change
        $this._itemsCacheInvalid = $true
        $this.Invalidate()
    }
}