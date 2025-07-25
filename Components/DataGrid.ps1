# DataGrid.ps1 - Fast data grid component for tabular display with full grid lines
# Optimized for performance with caching and pooled string builders

class DataGrid : UIElement {
    [System.Collections.ArrayList]$Items
    [hashtable[]]$Columns = @()
    [int]$SelectedIndex = 0
    [int]$ScrollOffset = 0
    [bool]$ShowHeader = $true
    [bool]$ShowBorder = $true
    [bool]$ShowGridLines = $true  # New property for grid lines
    [string]$Title = ""
    [scriptblock]$OnSelectionChanged = {}
    
    hidden [ThemeManager]$Theme
    hidden [hashtable]$_columnWidths = @{}
    hidden [string]$_cachedHeader = ""
    hidden [string]$_cachedSeparator = ""
    hidden [bool]$_layoutCacheValid = $false
    hidden [int]$_lastWidth = 0
    
    DataGrid() : base() {
        $this.Items = [System.Collections.ArrayList]::new()
        $this.IsFocusable = $true
    }
    
    [void] Initialize([ServiceContainer]$services) {
        $this.Theme = $services.GetService("ThemeManager")
        $this.Theme.Subscribe({ $this.OnThemeChanged() })
        $this.OnThemeChanged()
    }
    
    [void] OnThemeChanged() {
        $this._layoutCacheValid = $false
        $this.Invalidate()
    }
    
    # Set the columns for the grid
    [void] SetColumns([hashtable[]]$columns) {
        $this.Columns = $columns
        $this._layoutCacheValid = $false
        $this.Invalidate()
    }
    
    # Set data items
    [void] SetItems($items) {
        $this.Items.Clear()
        if ($items) {
            foreach ($item in $items) {
                $this.Items.Add($item) | Out-Null
            }
        }
        $this.SelectedIndex = if ($this.Items.Count -gt 0) { 0 } else { -1 }
        $this.ScrollOffset = 0
        $this.Invalidate()
    }
    
    # Get selected item
    [object] GetSelectedItem() {
        if ($this.SelectedIndex -ge 0 -and $this.SelectedIndex -lt $this.Items.Count) {
            return $this.Items[$this.SelectedIndex]
        }
        return $null
    }
    
    # Select specific index
    [void] SelectIndex([int]$index) {
        if ($index -ge 0 -and $index -lt $this.Items.Count) {
            $oldIndex = $this.SelectedIndex
            $this.SelectedIndex = $index
            $this.EnsureVisible()
            
            if ($oldIndex -ne $this.SelectedIndex -and $this.OnSelectionChanged) {
                & $this.OnSelectionChanged
            }
            
            $this.Invalidate()
        }
    }
    
    # Calculate column widths with auto-sizing
    hidden [void] CalculateColumnWidths([int]$availableWidth) {
        if ($this._layoutCacheValid -and $this._lastWidth -eq $availableWidth) {
            return
        }
        
        $this._columnWidths.Clear()
        $totalFixed = 0
        $flexCount = 0
        
        # First pass: calculate fixed widths and count flex columns
        foreach ($col in $this.Columns) {
            if ($col.Width -and $col.Width -gt 0) {
                $this._columnWidths[$col.Name] = $col.Width
                $totalFixed += $col.Width
            } else {
                $flexCount++
            }
        }
        
        # Add space for separators if grid lines are shown
        if ($this.ShowGridLines -and $this.Columns.Count -gt 1) {
            $totalFixed += ($this.Columns.Count - 1)  # Vertical separators
        }
        
        # Second pass: distribute remaining width to flex columns
        if ($flexCount -gt 0 -and $availableWidth -gt $totalFixed) {
            $flexWidth = [Math]::Floor(($availableWidth - $totalFixed) / $flexCount)
            foreach ($col in $this.Columns) {
                if (-not $col.Width -or $col.Width -eq 0) {
                    $this._columnWidths[$col.Name] = [Math]::Max(5, $flexWidth)  # Min width of 5
                }
            }
        }
        
        $this._lastWidth = $availableWidth
        $this._layoutCacheValid = $true
    }
    
    # Build cached header string
    hidden [void] BuildCachedHeader([int]$contentWidth) {
        if ($this._layoutCacheValid -and $this._cachedHeader) {
            return
        }
        
        $sb = Get-PooledStringBuilder 256
        $x = 0
        
        for ($i = 0; $i -lt $this.Columns.Count; $i++) {
            $col = $this.Columns[$i]
            $width = $this._columnWidths[$col.Name]
            
            if ($x + $width -gt $contentWidth) {
                $width = $contentWidth - $x
            }
            
            if ($width -gt 0) {
                $header = if ($col.Header) { $col.Header } else { $col.Name }
                $text = if ($header.Length -gt $width) {
                    $header.Substring(0, $width - 1) + "…"
                } else {
                    $header.PadRight($width)
                }
                $sb.Append($text)
                $x += $width
                
                # Add separator after column (except last)
                if ($this.ShowGridLines -and $i -lt $this.Columns.Count - 1 -and $x -lt $contentWidth) {
                    $sb.Append("│")
                    $x++
                }
            }
            
            if ($x -ge $contentWidth) { break }
        }
        
        # Fill remaining space
        if ($x -lt $contentWidth) {
            $sb.Append(" " * ($contentWidth - $x))
        }
        
        $this._cachedHeader = $sb.ToString()
        Return-PooledStringBuilder $sb
    }
    
    # Build cached separator line
    hidden [void] BuildCachedSeparator([int]$contentWidth) {
        if ($this._layoutCacheValid -and $this._cachedSeparator) {
            return
        }
        
        $sb = Get-PooledStringBuilder 256
        $x = 0
        
        for ($i = 0; $i -lt $this.Columns.Count; $i++) {
            $col = $this.Columns[$i]
            $width = $this._columnWidths[$col.Name]
            
            if ($x + $width -gt $contentWidth) {
                $width = $contentWidth - $x
            }
            
            if ($width -gt 0) {
                $sb.Append("─" * $width)
                $x += $width
                
                # Add intersection after column (except last)
                if ($this.ShowGridLines -and $i -lt $this.Columns.Count - 1 -and $x -lt $contentWidth) {
                    $sb.Append("┼")
                    $x++
                }
            }
            
            if ($x -ge $contentWidth) { break }
        }
        
        # Fill remaining space
        if ($x -lt $contentWidth) {
            $sb.Append("─" * ($contentWidth - $x))
        }
        
        $this._cachedSeparator = $sb.ToString()
        Return-PooledStringBuilder $sb
    }
    
    # Ensure selected item is visible
    hidden [void] EnsureVisible() {
        if ($this.Items.Count -eq 0) { return }
        
        $contentHeight = $this.Height - 2  # Account for borders
        if ($this.ShowHeader) { 
            $contentHeight -= 2  # Header + separator line
        }
        
        # Account for row separators
        if ($this.ShowGridLines) {
            $contentHeight = [Math]::Floor($contentHeight / 2)  # Each row takes 2 lines with separator
        }
        
        # Scroll up if selected is above visible area
        if ($this.SelectedIndex -lt $this.ScrollOffset) {
            $this.ScrollOffset = $this.SelectedIndex
        }
        # Scroll down if selected is below visible area
        elseif ($this.SelectedIndex -ge ($this.ScrollOffset + $contentHeight)) {
            $this.ScrollOffset = $this.SelectedIndex - $contentHeight + 1
        }
        
        # Ensure scroll offset is valid
        $maxScroll = [Math]::Max(0, $this.Items.Count - $contentHeight)
        $this.ScrollOffset = [Math]::Max(0, [Math]::Min($this.ScrollOffset, $maxScroll))
    }
    
    [string] OnRender() {
        $sb = Get-PooledStringBuilder 4096  # Larger size for grid with separators
        
        # Calculate content area
        $contentX = $this.X + 1
        $contentY = $this.Y + 1
        $contentWidth = $this.Width - 2
        $contentHeight = $this.Height - 2
        
        # Draw border if enabled
        if ($this.ShowBorder) {
            $borderColor = if ($this.IsFocused) { 
                $this.Theme.GetColor("border.focused") 
            } else { 
                $this.Theme.GetColor("border") 
            }
            
            # Top border with title
            $sb.Append([VT]::MoveTo($this.X, $this.Y))
            $sb.Append($borderColor)
            $sb.Append([VT]::TL())
            
            if ($this.Title) {
                $titleText = " $($this.Title) "
                $titleLen = $titleText.Length
                $borderLen = $this.Width - 2
                $leftPad = [int](($borderLen - $titleLen) / 2)
                
                if ($leftPad -gt 0) {
                    $sb.Append([VT]::H() * $leftPad)
                }
                $sb.Append($this.Theme.GetColor("accent"))
                $sb.Append($titleText)
                $sb.Append($borderColor)
                $remainingBorder = [Math]::Max(0, $borderLen - $leftPad - $titleLen)
                if ($remainingBorder -gt 0) {
                    $sb.Append([VT]::H() * $remainingBorder)
                }
            } else {
                $topBorderWidth = [Math]::Max(0, $this.Width - 2)
                if ($topBorderWidth -gt 0) {
                    $sb.Append([VT]::H() * $topBorderWidth)
                }
            }
            
            $sb.Append([VT]::TR())
            
            # Side borders
            for ($i = 1; $i -lt $this.Height - 1; $i++) {
                $sb.Append([VT]::MoveTo($this.X, $this.Y + $i))
                $sb.Append([VT]::V())
                $sb.Append([VT]::MoveTo($this.X + $this.Width - 1, $this.Y + $i))
                $sb.Append([VT]::V())
            }
            
            # Bottom border
            $sb.Append([VT]::MoveTo($this.X, $this.Y + $this.Height - 1))
            $sb.Append([VT]::BL())
            $bottomBorderWidth = [Math]::Max(0, $this.Width - 2)
            if ($bottomBorderWidth -gt 0) {
                $sb.Append([VT]::H() * $bottomBorderWidth)
            }
            $sb.Append([VT]::BR())
            $sb.Append([VT]::Reset())
        } else {
            $contentX = $this.X
            $contentY = $this.Y
            $contentWidth = $this.Width
            $contentHeight = $this.Height
        }
        
        # Calculate column widths
        $this.CalculateColumnWidths($contentWidth)
        
        # Clear content area
        $bgColor = $this.Theme.GetBgColor("background")
        for ($y = 0; $y -lt $contentHeight; $y++) {
            $sb.Append([VT]::MoveTo($contentX, $contentY + $y))
            $sb.Append($bgColor)
            $sb.Append(" " * $contentWidth)
        }
        
        $currentY = $contentY
        $dataStartY = $currentY
        
        # Render header if enabled
        if ($this.ShowHeader -and $this.Columns.Count -gt 0) {
            # Build cached header
            $this.BuildCachedHeader($contentWidth)
            
            # Render header
            $sb.Append([VT]::MoveTo($contentX, $currentY))
            $sb.Append($this.Theme.GetBgColor("header.background"))
            $sb.Append($this.Theme.GetColor("header.foreground"))
            $sb.Append($this._cachedHeader)
            $sb.Append([VT]::Reset())
            $currentY++
            
            # Render header separator line
            if ($this.ShowGridLines) {
                $this.BuildCachedSeparator($contentWidth)
                $sb.Append([VT]::MoveTo($contentX, $currentY))
                $sb.Append($this.Theme.GetColor("border"))
                $sb.Append($this._cachedSeparator)
                $sb.Append([VT]::Reset())
                $currentY++
            }
            
            $dataStartY = $currentY
            $contentHeight = $this.Height - 2 - ($currentY - $contentY)
        }
        
        # Calculate visible rows (accounting for separators)
        $rowHeight = if ($this.ShowGridLines) { 2 } else { 1 }
        $maxVisibleRows = [Math]::Floor($contentHeight / $rowHeight)
        $visibleRows = [Math]::Min($maxVisibleRows, $this.Items.Count - $this.ScrollOffset)
        
        # Render data rows
        for ($i = 0; $i -lt $visibleRows; $i++) {
            $itemIndex = $this.ScrollOffset + $i
            if ($itemIndex -ge $this.Items.Count) { break }
            
            $item = $this.Items[$itemIndex]
            $isSelected = ($itemIndex -eq $this.SelectedIndex)
            $rowY = $currentY + ($i * $rowHeight)
            
            # Render data row
            $sb.Append([VT]::MoveTo($contentX, $rowY))
            
            if ($isSelected) {
                $sb.Append($this.Theme.GetBgColor("selection"))
                $sb.Append($this.Theme.GetColor("foreground"))
            } else {
                $sb.Append($this.Theme.GetBgColor("background"))
                $sb.Append($this.Theme.GetColor("foreground"))
            }
            
            # Render columns
            $x = 0
            for ($j = 0; $j -lt $this.Columns.Count; $j++) {
                $col = $this.Columns[$j]
                $width = $this._columnWidths[$col.Name]
                
                if ($x + $width -gt $contentWidth) {
                    $width = $contentWidth - $x
                }
                
                if ($width -gt 0) {
                    # Get value using property name or custom getter
                    $value = ""
                    if ($col.Getter) {
                        $value = & $col.Getter $item
                    } elseif ($col.Name -and $item.PSObject.Properties[$col.Name]) {
                        $value = $item.($col.Name)
                    }
                    
                    # Apply formatter if provided
                    if ($col.Formatter) {
                        $value = & $col.Formatter $value
                    }
                    
                    # Convert to string and truncate if needed
                    $text = $value.ToString()
                    if ($text.Length -gt $width) {
                        $text = $text.Substring(0, $width - 1) + "…"
                    } else {
                        $text = $text.PadRight($width)
                    }
                    
                    $sb.Append($text)
                    $x += $width
                    
                    # Add vertical separator after column (except last)
                    if ($this.ShowGridLines -and $j -lt $this.Columns.Count - 1 -and $x -lt $contentWidth) {
                        if ($isSelected) {
                            # Keep selection colors for separator
                            $sb.Append("│")
                        } else {
                            $sb.Append($this.Theme.GetColor("border"))
                            $sb.Append("│")
                            $sb.Append($this.Theme.GetColor("foreground"))
                        }
                        $x++
                    }
                }
                
                if ($x -ge $contentWidth) { break }
            }
            
            # Fill remaining row space
            if ($x -lt $contentWidth) {
                $sb.Append(" " * ($contentWidth - $x))
            }
            
            # Render row separator (except after last visible row)
            if ($this.ShowGridLines -and $i -lt $visibleRows - 1) {
                $sb.Append([VT]::MoveTo($contentX, $rowY + 1))
                $sb.Append($this.Theme.GetColor("border"))
                
                $x = 0
                for ($j = 0; $j -lt $this.Columns.Count; $j++) {
                    $col = $this.Columns[$j]
                    $width = $this._columnWidths[$col.Name]
                    
                    if ($x + $width -gt $contentWidth) {
                        $width = $contentWidth - $x
                    }
                    
                    if ($width -gt 0) {
                        $sb.Append("─" * $width)
                        $x += $width
                        
                        # Add intersection
                        if ($j -lt $this.Columns.Count - 1 -and $x -lt $contentWidth) {
                            $sb.Append("┼")
                            $x++
                        }
                    }
                    
                    if ($x -ge $contentWidth) { break }
                }
                
                # Fill remaining separator
                if ($x -lt $contentWidth) {
                    $sb.Append("─" * ($contentWidth - $x))
                }
                $sb.Append([VT]::Reset())
            }
        }
        
        # Show scroll indicator
        if ($this.Items.Count -gt $maxVisibleRows) {
            $scrollBarX = $this.X + $this.Width - 1
            $scrollBarHeight = $contentHeight
            $scrollThumbSize = [Math]::Max(1, [int]($scrollBarHeight * $maxVisibleRows / $this.Items.Count))
            $scrollThumbPos = [int]($this.ScrollOffset * ($scrollBarHeight - $scrollThumbSize) / ($this.Items.Count - $maxVisibleRows))
            
            $sb.Append($this.Theme.GetColor("scrollbar"))
            for ($i = 0; $i -lt $scrollBarHeight; $i++) {
                $sb.Append([VT]::MoveTo($scrollBarX, $dataStartY + $i))
                if ($i -ge $scrollThumbPos -and $i -lt ($scrollThumbPos + $scrollThumbSize)) {
                    $sb.Append("█")
                } else {
                    $sb.Append("│")
                }
            }
        }
        
        $sb.Append([VT]::Reset())
        $result = $sb.ToString()
        Return-PooledStringBuilder $sb  # Return to pool for reuse
        return $result
    }
    
    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        if (-not $this.IsFocused -or $this.Items.Count -eq 0) { return $false }
        
        $handled = $false
        $oldIndex = $this.SelectedIndex
        
        switch ($key.Key) {
            ([System.ConsoleKey]::UpArrow) {
                if ($this.SelectedIndex -gt 0) {
                    $this.SelectedIndex--
                    $this.EnsureVisible()
                    $handled = $true
                }
            }
            ([System.ConsoleKey]::DownArrow) {
                if ($this.SelectedIndex -lt $this.Items.Count - 1) {
                    $this.SelectedIndex++
                    $this.EnsureVisible()
                    $handled = $true
                }
            }
            ([System.ConsoleKey]::PageUp) {
                $rowHeight = if ($this.ShowGridLines) { 2 } else { 1 }
                $pageSize = [Math]::Floor(($this.Height - 2 - (if ($this.ShowHeader) { 2 } else { 0 })) / $rowHeight)
                $this.SelectedIndex = [Math]::Max(0, $this.SelectedIndex - $pageSize)
                $this.EnsureVisible()
                $handled = $true
            }
            ([System.ConsoleKey]::PageDown) {
                $rowHeight = if ($this.ShowGridLines) { 2 } else { 1 }
                $pageSize = [Math]::Floor(($this.Height - 2 - (if ($this.ShowHeader) { 2 } else { 0 })) / $rowHeight)
                $this.SelectedIndex = [Math]::Min($this.Items.Count - 1, $this.SelectedIndex + $pageSize)
                $this.EnsureVisible()
                $handled = $true
            }
            ([System.ConsoleKey]::Home) {
                $this.SelectedIndex = 0
                $this.EnsureVisible()
                $handled = $true
            }
            ([System.ConsoleKey]::End) {
                $this.SelectedIndex = $this.Items.Count - 1
                $this.EnsureVisible()
                $handled = $true
            }
        }
        
        if ($handled) {
            $this.Invalidate()
            
            # Fire selection changed event
            if ($oldIndex -ne $this.SelectedIndex -and $this.OnSelectionChanged) {
                & $this.OnSelectionChanged
            }
        }
        
        return $handled
    }
    
    [void] OnGotFocus() {
        $this.Invalidate()
    }
    
    [void] OnLostFocus() {
        $this.Invalidate()
    }
    
    [void] OnBoundsChanged() {
        # Invalidate layout cache when bounds change
        if ($this.Width -ne $this._lastWidth) {
            $this._layoutCacheValid = $false
        }
        ([UIElement]$this).OnBoundsChanged()
    }
}