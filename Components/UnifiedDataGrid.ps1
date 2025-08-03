# UnifiedDataGrid.ps1 - Simple, focused data grid component for tables
# Replaces the complex UnifiedList DataGrid mode

class UnifiedDataGrid : FocusableComponent {
    # Core properties
    [System.Collections.Generic.List[object]]$Items
    [System.Collections.Generic.List[hashtable]]$Columns
    [int]$SelectedIndex = 0
    
    # Visual properties
    [bool]$ShowHeader = $true
    [bool]$ShowBorder = $true
    [bool]$ShowRowNumbers = $false
    
    # Callbacks
    [scriptblock]$OnSelectionChanged = {}
    [scriptblock]$OnItemActivated = {}
    
    # Internal state
    hidden [int]$_scrollOffset = 0
    hidden [int]$_viewportHeight = 0
    hidden [hashtable]$_colors = @{}
    hidden [int]$_headerHeight = 0
    
    UnifiedDataGrid() : base() {
        $this.Items = [System.Collections.Generic.List[object]]::new()
        $this.Columns = [System.Collections.Generic.List[hashtable]]::new()
        $this.IsFocusable = $true
        $this.FocusStyle = 'border'
    }
    
    [void] OnInitialize() {
        ([FocusableComponent]$this).OnInitialize()
        
        # Get theme and subscribe to changes
        $theme = $this.ServiceContainer.GetService('ThemeManager')
        if ($theme) {
            $this.ApplyTheme()
            
            $eventBus = $this.ServiceContainer.GetService('EventBus')
            if ($eventBus) {
                $grid = $this
                $eventBus.Subscribe('theme.changed', {
                    param($sender, $eventData)
                    $grid.ApplyTheme()
                    $grid.Invalidate()
                }.GetNewClosure())
            }
        }
    }
    
    [void] ApplyTheme() {
        $theme = $this.ServiceContainer.GetService('ThemeManager')
        if ($theme) {
            $this._colors = @{
                border = $theme.GetColor('border.normal')
                borderFocus = $theme.GetColor('border.focused')
                text = $theme.GetColor('text.primary')
                header = $theme.GetColor('list.header.text')
                headerBg = $theme.GetBgColor('list.header.background')
                selectedBg = $theme.GetBgColor('list.selected.background')
                selectedText = $theme.GetColor('list.selected.text')
                background = $theme.GetBgColor('surface.background')
            }
        }
    }
    
    [void] SetColumns([array]$columnDefs) {
        $this.Columns.Clear()
        foreach ($col in $columnDefs) {
            $this.Columns.Add($col)
        }
        $this.AutoSizeColumns()
        $this.Invalidate()
    }
    
    [void] SetItems([array]$items) {
        $this.Items.Clear()
        if ($items) {
            foreach ($item in $items) {
                $this.Items.Add($item)
            }
        }
        
        # Adjust selection
        if ($this.Items.Count -eq 0) {
            $this.SelectedIndex = -1
        } elseif ($this.SelectedIndex -ge $this.Items.Count) {
            $this.SelectedIndex = $this.Items.Count - 1
        } elseif ($this.SelectedIndex -lt 0 -and $this.Items.Count -gt 0) {
            $this.SelectedIndex = 0
        }
        
        $this.Invalidate()
    }
    
    [object] GetSelectedItem() {
        if ($this.SelectedIndex -ge 0 -and $this.SelectedIndex -lt $this.Items.Count) {
            return $this.Items[$this.SelectedIndex]
        }
        return $null
    }
    
    [void] OnBoundsChanged() {
        ([FocusableComponent]$this).OnBoundsChanged()
        
        # Calculate viewport
        $contentPadding = if ($this.ShowBorder) { 2 } else { 0 }
        $this._headerHeight = if ($this.ShowHeader) { 2 } else { 0 }  # Header + separator
        $this._viewportHeight = $this.Height - $contentPadding - $this._headerHeight
        
        $this.AutoSizeColumns()
        $this.EnsureSelectedVisible()
    }
    
    [void] AutoSizeColumns() {
        if ($this.Columns.Count -eq 0 -or $this.Width -le 0) { return }
        
        # Calculate available width
        $availableWidth = $this.Width
        if ($this.ShowBorder) { $availableWidth -= 2 }
        if ($this.ShowRowNumbers) { $availableWidth -= 6 }
        
        # Count fixed vs flexible columns
        $fixedWidth = 0
        $flexCount = 0
        
        foreach ($col in $this.Columns) {
            if ($col.Width -gt 0) {
                $fixedWidth += $col.Width
            } else {
                $flexCount++
            }
        }
        
        # Distribute remaining width to flexible columns
        if ($flexCount -gt 0) {
            $flexWidth = [Math]::Max(10, [int](($availableWidth - $fixedWidth) / $flexCount))
            foreach ($col in $this.Columns) {
                if ($col.Width -eq 0) {
                    $col.Width = $flexWidth
                }
            }
        }
    }
    
    [string] RenderContent() {
        $sb = [System.Text.StringBuilder]::new()
        
        # Draw border
        if ($this.ShowBorder) {
            $borderColor = if ($this.IsFocused) { $this._colors.borderFocus } else { $this._colors.border }
            $this.RenderBorder($sb, $borderColor)
        }
        
        # Draw header
        if ($this.ShowHeader) {
            $this.RenderHeader($sb)
        }
        
        # Draw rows
        $this.RenderRows($sb)
        
        return $sb.ToString()
    }
    
    [void] RenderBorder([System.Text.StringBuilder]$sb, [string]$color) {
        if ($this.Width -lt 2 -or $this.Height -lt 2) { return }
        
        [void]$sb.Append($color)
        
        # Top border
        [void]$sb.Append([VT]::MoveTo($this.X, $this.Y))
        [void]$sb.Append("┌" + ("─" * ($this.Width - 2)) + "┐")
        
        # Side borders
        for ($i = 1; $i -lt ($this.Height - 1); $i++) {
            [void]$sb.Append([VT]::MoveTo($this.X, $this.Y + $i))
            [void]$sb.Append("│")
            [void]$sb.Append([VT]::MoveTo($this.X + $this.Width - 1, $this.Y + $i))
            [void]$sb.Append("│")
        }
        
        # Bottom border
        [void]$sb.Append([VT]::MoveTo($this.X, $this.Y + $this.Height - 1))
        [void]$sb.Append("└" + ("─" * ($this.Width - 2)) + "┘")
    }
    
    [void] RenderHeader([System.Text.StringBuilder]$sb) {
        $headerY = $this.Y + $(if ($this.ShowBorder) { 1 } else { 0 })
        $contentX = $this.X + $(if ($this.ShowBorder) { 1 } else { 0 })
        $contentWidth = $this.Width - $(if ($this.ShowBorder) { 2 } else { 0 })
        
        # Header row
        [void]$sb.Append([VT]::MoveTo($contentX, $headerY))
        [void]$sb.Append($this._colors.headerBg)
        [void]$sb.Append($this._colors.header)
        
        $headerText = ""
        if ($this.ShowRowNumbers) {
            $headerText += "  #  "
        }
        
        foreach ($col in $this.Columns) {
            $header = $col.Header
            if ($header.Length -gt $col.Width) {
                $header = $header.Substring(0, [Math]::Max(1, $col.Width - 1)) + "…"
            }
            $headerText += $header.PadRight($col.Width)
        }
        
        # Ensure header fits
        if ($headerText.Length -gt $contentWidth) {
            $headerText = $headerText.Substring(0, $contentWidth)
        } else {
            $headerText = $headerText.PadRight($contentWidth)
        }
        
        [void]$sb.Append($headerText)
        
        # Separator line
        [void]$sb.Append([VT]::MoveTo($contentX, $headerY + 1))
        [void]$sb.Append($this._colors.border)
        [void]$sb.Append("─" * $contentWidth)
        
        [void]$sb.Append([VT]::Reset())
    }
    
    [void] RenderRows([System.Text.StringBuilder]$sb) {
        if ($this.Items.Count -eq 0) { return }
        
        $contentX = $this.X + $(if ($this.ShowBorder) { 1 } else { 0 })
        $dataY = $this.Y + $(if ($this.ShowBorder) { 1 } else { 0 }) + $this._headerHeight
        $contentWidth = $this.Width - $(if ($this.ShowBorder) { 2 } else { 0 })
        
        # Determine visible range
        $startIdx = $this._scrollOffset
        $endIdx = [Math]::Min($startIdx + $this._viewportHeight, $this.Items.Count)
        
        for ($i = $startIdx; $i -lt $endIdx; $i++) {
            $item = $this.Items[$i]
            $isSelected = ($i -eq $this.SelectedIndex)
            $rowY = $dataY + ($i - $startIdx)
            
            [void]$sb.Append([VT]::MoveTo($contentX, $rowY))
            
            # Apply selection colors
            if ($isSelected -and $this.IsFocused) {
                [void]$sb.Append($this._colors.selectedBg)
                [void]$sb.Append($this._colors.selectedText)
            } else {
                if ($this._colors.background) { [void]$sb.Append($this._colors.background) }
                [void]$sb.Append($this._colors.text)
            }
            
            # Build row text
            $rowText = ""
            
            if ($this.ShowRowNumbers) {
                $rowText += ($i + 1).ToString().PadLeft(3) + "  "
            }
            
            foreach ($col in $this.Columns) {
                $value = $this.GetColumnValue($item, $col)
                if ($value.Length -gt $col.Width) {
                    $value = $value.Substring(0, [Math]::Max(1, $col.Width - 1)) + "…"
                }
                $rowText += $value.PadRight($col.Width)
            }
            
            # Ensure row fits
            if ($rowText.Length -gt $contentWidth) {
                $rowText = $rowText.Substring(0, $contentWidth)
            } else {
                $rowText = $rowText.PadRight($contentWidth)
            }
            
            [void]$sb.Append($rowText)
        }
        
        [void]$sb.Append([VT]::Reset())
    }
    
    [string] GetColumnValue([object]$item, [hashtable]$col) {
        $value = $null
        
        if ($col.Getter) {
            $value = & $col.Getter $item
        } elseif ($item -is [hashtable] -and $item.ContainsKey($col.Name)) {
            $value = $item[$col.Name]
        } elseif ($item.PSObject.Properties[$col.Name]) {
            $value = $item.($col.Name)
        }
        
        if ($null -eq $value) { $value = "" }
        
        if ($col.Formatter) {
            $value = & $col.Formatter $value
        } else {
            $value = $value.ToString()
        }
        
        return $value
    }
    
    [bool] OnHandleInput([System.ConsoleKeyInfo]$key) {
        $handled = $false
        
        switch ($key.Key) {
            ([System.ConsoleKey]::UpArrow) {
                if ($this.SelectedIndex -gt 0) {
                    $this.SelectedIndex--
                    $this.EnsureSelectedVisible()
                    $this.Invalidate()
                    if ($this.OnSelectionChanged) {
                        & $this.OnSelectionChanged
                    }
                }
                $handled = $true
            }
            ([System.ConsoleKey]::DownArrow) {
                if ($this.SelectedIndex -lt ($this.Items.Count - 1)) {
                    $this.SelectedIndex++
                    $this.EnsureSelectedVisible()
                    $this.Invalidate()
                    if ($this.OnSelectionChanged) {
                        & $this.OnSelectionChanged
                    }
                }
                $handled = $true
            }
            ([System.ConsoleKey]::PageUp) {
                $this.SelectedIndex = [Math]::Max(0, $this.SelectedIndex - $this._viewportHeight)
                $this.EnsureSelectedVisible()
                $this.Invalidate()
                if ($this.OnSelectionChanged) {
                    & $this.OnSelectionChanged
                }
                $handled = $true
            }
            ([System.ConsoleKey]::PageDown) {
                $this.SelectedIndex = [Math]::Min($this.Items.Count - 1, $this.SelectedIndex + $this._viewportHeight)
                $this.EnsureSelectedVisible()
                $this.Invalidate()
                if ($this.OnSelectionChanged) {
                    & $this.OnSelectionChanged
                }
                $handled = $true
            }
            ([System.ConsoleKey]::Home) {
                if ($this.Items.Count -gt 0) {
                    $this.SelectedIndex = 0
                    $this.EnsureSelectedVisible()
                    $this.Invalidate()
                    if ($this.OnSelectionChanged) {
                        & $this.OnSelectionChanged
                    }
                }
                $handled = $true
            }
            ([System.ConsoleKey]::End) {
                if ($this.Items.Count -gt 0) {
                    $this.SelectedIndex = $this.Items.Count - 1
                    $this.EnsureSelectedVisible()
                    $this.Invalidate()
                    if ($this.OnSelectionChanged) {
                        & $this.OnSelectionChanged
                    }
                }
                $handled = $true
            }
            ([System.ConsoleKey]::Enter) {
                if ($this.OnItemActivated -and $this.SelectedIndex -ge 0) {
                    $item = $this.GetSelectedItem()
                    if ($item) {
                        & $this.OnItemActivated $item
                    }
                }
                $handled = $true
            }
        }
        
        return $handled
    }
    
    [void] EnsureSelectedVisible() {
        if ($this.SelectedIndex -lt $this._scrollOffset) {
            $this._scrollOffset = $this.SelectedIndex
        } elseif ($this.SelectedIndex -ge ($this._scrollOffset + $this._viewportHeight)) {
            $this._scrollOffset = $this.SelectedIndex - $this._viewportHeight + 1
        }
        
        # Bounds check
        $this._scrollOffset = [Math]::Max(0, $this._scrollOffset)
        $maxScroll = [Math]::Max(0, $this.Items.Count - $this._viewportHeight)
        $this._scrollOffset = [Math]::Min($this._scrollOffset, $maxScroll)
    }
}