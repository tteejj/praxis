# DataGrid.ps1 - Fast data grid component for tabular display
# Simplified from AxiomPhoenix with focus on performance

class DataGrid : UIElement {
    [System.Collections.ArrayList]$Items
    [hashtable[]]$Columns = @()
    [int]$SelectedIndex = 0
    [int]$ScrollOffset = 0
    [bool]$ShowHeader = $true
    [bool]$ShowBorder = $true
    [string]$Title = ""
    [scriptblock]$OnSelectionChanged = {}
    
    hidden [ThemeManager]$Theme
    hidden [hashtable]$_headerCache = @{}
    hidden [bool]$_headerCacheValid = $false
    
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
        $this._headerCacheValid = $false
        $this.Invalidate()
    }
    
    # Set the columns for the grid
    [void] SetColumns([hashtable[]]$columns) {
        $this.Columns = $columns
        $this._headerCacheValid = $false
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
    
    # Ensure selected item is visible
    hidden [void] EnsureVisible() {
        if ($this.Items.Count -eq 0) { return }
        
        $contentHeight = $this.Height - 2  # Account for borders
        if ($this.ShowHeader) { $contentHeight-- }
        
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
        $sb = Get-PooledStringBuilder 2048  # DataGrid can render many rows and columns
        
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
        
        # Clear content area
        $bgColor = $this.Theme.GetBgColor("background")
        for ($y = 0; $y -lt $contentHeight; $y++) {
            $sb.Append([VT]::MoveTo($contentX, $contentY + $y))
            $sb.Append($bgColor)
            $sb.Append(" " * $contentWidth)
        }
        
        $currentY = $contentY
        
        # Render header if enabled
        if ($this.ShowHeader -and $this.Columns.Count -gt 0) {
            $sb.Append([VT]::MoveTo($contentX, $currentY))
            $sb.Append($this.Theme.GetBgColor("header.background"))
            $sb.Append($this.Theme.GetColor("header.foreground"))
            
            $x = 0
            foreach ($col in $this.Columns) {
                $header = if ($col.Header) { $col.Header } else { $col.Name }
                $width = if ($col.Width) { $col.Width } else { 10 }
                
                # Ensure we don't overflow
                if ($x + $width -gt $contentWidth) {
                    $width = $contentWidth - $x
                }
                
                if ($width -gt 0) {
                    $text = if ($header.Length -gt $width) {
                        $header.Substring(0, $width - 1) + "…"
                    } else {
                        $header.PadRight($width)
                    }
                    $sb.Append($text)
                    $x += $width
                }
                
                if ($x -ge $contentWidth) { break }
            }
            
            # Fill remaining header space
            if ($x -lt $contentWidth) {
                $remaining = [Math]::Max(0, $contentWidth - $x)
                if ($remaining -gt 0) {
                    $sb.Append(" " * $remaining)
                }
            }
            
            $sb.Append([VT]::Reset())
            $currentY++
            $contentHeight--
        }
        
        # Render data rows
        $visibleRows = [Math]::Min($contentHeight, $this.Items.Count - $this.ScrollOffset)
        
        for ($i = 0; $i -lt $visibleRows; $i++) {
            $itemIndex = $this.ScrollOffset + $i
            if ($itemIndex -ge $this.Items.Count) { break }
            
            $item = $this.Items[$itemIndex]
            $isSelected = ($itemIndex -eq $this.SelectedIndex)
            
            $sb.Append([VT]::MoveTo($contentX, $currentY + $i))
            
            if ($isSelected) {
                $sb.Append($this.Theme.GetBgColor("selection.background"))
                $sb.Append($this.Theme.GetColor("selection.foreground"))
            } else {
                $sb.Append($this.Theme.GetColor("foreground"))
            }
            
            # Render columns
            $x = 0
            foreach ($col in $this.Columns) {
                $width = if ($col.Width) { $col.Width } else { 10 }
                
                # Ensure we don't overflow
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
                }
                
                if ($x -ge $contentWidth) { break }
            }
            
            # Fill remaining row space
            if ($x -lt $contentWidth) {
                $remaining = [Math]::Max(0, $contentWidth - $x)
                if ($remaining -gt 0) {
                    $sb.Append(" " * $remaining)
                }
            }
        }
        
        # Clear remaining rows
        for ($i = $visibleRows; $i -lt $contentHeight; $i++) {
            $sb.Append([VT]::MoveTo($contentX, $currentY + $i))
            $sb.Append($this.Theme.GetColor("background"))
            $sb.Append(" " * $contentWidth)
        }
        
        # Show scroll indicator
        if ($this.Items.Count -gt $contentHeight) {
            $scrollBarX = $this.X + $this.Width - 1
            $scrollBarHeight = $contentHeight
            $scrollThumbSize = [Math]::Max(1, [int]($scrollBarHeight * $contentHeight / $this.Items.Count))
            $scrollThumbPos = [int]($this.ScrollOffset * ($scrollBarHeight - $scrollThumbSize) / ($this.Items.Count - $contentHeight))
            
            $sb.Append($this.Theme.GetColor("scrollbar"))
            for ($i = 0; $i -lt $scrollBarHeight; $i++) {
                $sb.Append([VT]::MoveTo($scrollBarX, $currentY + $i))
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
                $pageSize = $this.Height - 2
                if ($this.ShowHeader) { $pageSize-- }
                $this.SelectedIndex = [Math]::Max(0, $this.SelectedIndex - $pageSize)
                $this.EnsureVisible()
                $handled = $true
            }
            ([System.ConsoleKey]::PageDown) {
                $pageSize = $this.Height - 2
                if ($this.ShowHeader) { $pageSize-- }
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
}