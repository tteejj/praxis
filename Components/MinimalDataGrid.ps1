# MinimalDataGrid.ps1 - High-performance table with connected borders and all features

class MinimalDataGrid : FocusableComponent {
    # Public properties
    [System.Collections.Generic.List[object]]$Items
    [System.Collections.Generic.List[GridColumn]]$Columns
    [int]$SelectedIndex = -1
    [string]$Title = ""
    [bool]$ShowBorder = $true
    [BorderType]$BorderType = [BorderType]::Rounded
    [bool]$ShowTitle = $true
    [bool]$ShowHeader = $true
    [bool]$ShowGridLines = $false
    [bool]$ShowColumnSeparators = $true
    [bool]$ShowRowNumbers = $false
    [bool]$AlternateRowColors = $false
    [int]$RowSpacing = 0  # Extra lines between rows
    [scriptblock]$OnItemSelected = $null
    
    # Layout properties
    hidden [int]$_contentX
    hidden [int]$_contentY
    hidden [int]$_contentWidth
    hidden [int]$_contentHeight
    hidden [int]$_headerY
    hidden [int]$_dataY
    hidden [int]$_scrollOffset = 0
    hidden [int]$_viewportRows = 0
    hidden [int]$_titleHeight = 0
    
    # Cached colors - pre-computed ANSI sequences
    hidden [hashtable]$_colors = @{}
    hidden [ThemeManager]$Theme
    hidden [hashtable]$_borderChars = @{}
    
    # Track previous bounds to know when to clear
    hidden [int]$_lastX = -1
    hidden [int]$_lastY = -1
    hidden [int]$_lastWidth = -1
    hidden [int]$_lastHeight = -1
    
    # Cached render components
    hidden [string]$_cachedHeader = ""
    hidden [bool]$_headerInvalid = $true
    hidden [string]$_cachedRows = ""
    hidden [bool]$_rowsInvalid = $true
    hidden [int]$_lastItemCount = -1
    hidden [int]$_lastSelectedIndex = -1
    
    MinimalDataGrid() : base() {
        $this.Items = [System.Collections.Generic.List[object]]::new()
        $this.Columns = [System.Collections.Generic.List[GridColumn]]::new()
        $this.IsFocusable = $true
        $this._colors = @{}
    }
    
    [void] OnInitialize() {
        ([FocusableComponent]$this).OnInitialize()
        $this.Theme = $this.ServiceContainer.GetService("ThemeManager")
        if ($this.Theme) {
            $this.Theme.Subscribe({ $this.OnThemeChanged() })
            $this.OnThemeChanged()
        }
    }
    
    [void] OnThemeChanged() {
        $this.CacheThemeColors()
        $this.Invalidate()
    }
    
    [void] CacheThemeColors() {
        if ($this.Theme) {
            $this._colors = @{
                border = $this.Theme.GetColor('border.normal')
                background = $this.Theme.GetBgColor('surface.background')
                header = $this.Theme.GetColor('list.header.text')
                headerBg = $this.Theme.GetBgColor('list.header.background')
                text = $this.Theme.GetColor('text.primary')
                selectedText = $this.Theme.GetColor('menu.text.selected')
                selectedBg = $this.Theme.GetBgColor('menu.background.selected')
                gridLine = $this.Theme.GetColor('border.faint')
                focusIndicator = $this.Theme.GetColor('color.primary')
                titleColor = $this.Theme.GetColor('color.primary')
                alternate = $this.Theme.GetColor('text.disabled')
            }
        }
        
        # Cache border characters
        if ($this.BorderType -ne [BorderType]::None) {
            $style = [BorderStyle]::Styles[$this.BorderType.ToString()]
            if ($style) {
                $this._borderChars = $style
            }
        }
    }
    
    # Convenience method to add a single column
    [void] AddColumn([string]$name, [scriptblock]$valueGetter, [int]$width = 0) {
        $col = [GridColumn]::new()
        $col.Name = $name
        $col.Header = $name
        $col.ValueGetter = $valueGetter
        $col.Width = $width
        $this.Columns.Add($col)
        $this.AutoSizeColumns()
        $this.Invalidate()
    }
    
    [void] SetColumns([array]$columns) {
        $this.Columns.Clear()
        foreach ($colDef in $columns) {
            $col = [GridColumn]::new()
            $col.Name = $colDef.Name
            $col.Header = if ($colDef.Header) { $colDef.Header } else { $colDef.Name }
            $col.Width = if ($colDef.Width) { $colDef.Width } else { 0 }
            $col.Getter = if ($colDef.Getter) { $colDef.Getter } else { $null }
            $col.ValueGetter = if ($colDef.Getter) { $colDef.Getter } else { $null }
            $col.Formatter = if ($colDef.Formatter) { $colDef.Formatter } else { $null }
            $this.Columns.Add($col)
        }
        $this.AutoSizeColumns()
        $this._headerInvalid = $true
        $this.Invalidate()
    }
    
    [void] SetItems([array]$items) {
        $this.Items.Clear()
        if ($items) {
            foreach ($item in $items) {
                $this.Items.Add($item)
            }
        }
        if ($this.SelectedIndex -ge $this.Items.Count) {
            $this.SelectedIndex = $this.Items.Count - 1
        }
        $this.AutoSizeColumns()
        $this._rowsInvalid = $true
        $this._lastItemCount = $this.Items.Count
        $this.Invalidate()
    }
    
    [void] AutoSizeColumns() {
        if ($this.Columns.Count -eq 0 -or $this._contentWidth -le 0) { return }
        
        # First, calculate max content width for each column
        foreach ($col in $this.Columns) {
            $maxWidth = $col.Header.Length
            # Only sample first few items for performance
            $itemsToCheck = [Math]::Min($this.Items.Count, 20)
            for ($i = 0; $i -lt $itemsToCheck; $i++) {
                $item = $this.Items[$i]
                $value = $this.GetColumnValue($item, $col)
                if ($value) {
                    $maxWidth = [Math]::Max($maxWidth, $value.Length)
                }
            }
            $col.MaxContentWidth = $maxWidth
        }
        
        # Calculate available width
        $availableWidth = $this._contentWidth
        if ($this.ShowRowNumbers) { $availableWidth -= 6 }
        $availableWidth -= 3  # Selection indicator space
        
        # Calculate column separators space
        if ($this.ShowColumnSeparators) {
            $availableWidth -= ($this.Columns.Count - 1)
        }
        
        # Auto-size columns with 0 width
        $fixedWidth = 0
        $flexColumns = @()
        foreach ($col in $this.Columns) {
            if ($col.Width -gt 0) {
                $fixedWidth += $col.Width
            } else {
                $flexColumns += $col
            }
        }
        
        if ($flexColumns.Count -gt 0 -and $availableWidth -gt $fixedWidth) {
            $remainingWidth = $availableWidth - $fixedWidth
            
            # First pass: give each column its minimum needed width
            $totalNeeded = 0
            foreach ($col in $flexColumns) {
                $col.Width = [Math]::Max($col.Header.Length + 2, [Math]::Min($col.MaxContentWidth + 2, 30))
                $totalNeeded += $col.Width
            }
            
            # Adjust if needed
            if ($totalNeeded -gt $remainingWidth) {
                # Need to shrink columns - distribute shrinkage proportionally
                $shrinkFactor = $remainingWidth / $totalNeeded
                foreach ($col in $flexColumns) {
                    $col.Width = [Math]::Max($col.Header.Length + 2, [int]($col.Width * $shrinkFactor))
                }
            }
        }
    }
    
    [void] OnBoundsChanged() {
        $this.CalculateLayout()
        $this.AutoSizeColumns()
        $this._headerInvalid = $true
        ([FocusableComponent]$this).OnBoundsChanged()
    }
    
    [void] CalculateLayout() {
        # Ensure we have valid bounds
        if ($this.Width -le 0 -or $this.Height -le 0) {
            return
        }
        
        # Calculate content area (inside border if present)
        if ($this.ShowBorder -and $this.BorderType -ne [BorderType]::None) {
            $this._contentX = $this.X + 1
            $this._contentY = $this.Y + 1
            $this._contentWidth = [Math]::Max(1, $this.Width - 2)
            $this._contentHeight = [Math]::Max(1, $this.Height - 2)
        } else {
            $this._contentX = $this.X
            $this._contentY = $this.Y
            $this._contentWidth = [Math]::Max(1, $this.Width)
            $this._contentHeight = [Math]::Max(1, $this.Height)
        }
        
        # Calculate vertical positions
        $currentY = $this._contentY
        
        # Title height (rounded box takes 1 line)
        if ($this.ShowTitle -and $this.Title) {
            $this._titleHeight = 1
            $currentY += $this._titleHeight
        } else {
            $this._titleHeight = 0
        }
        
        # Header
        if ($this.ShowHeader) {
            $this._headerY = $currentY
            $currentY++
            # Always show header separator for connected table look
            $currentY++
        }
        
        # Data starts here
        $this._dataY = $currentY
        
        # Calculate viewport rows
        $rowHeight = 1 + $this.RowSpacing
        if ($this.ShowGridLines) { $rowHeight++ }
        
        $remainingHeight = $this._contentY + $this._contentHeight - $this._dataY
        $this._viewportRows = [Math]::Max(0, [Math]::Floor($remainingHeight / $rowHeight))
    }
    
    [string] OnRender() {
        # Check if we have valid colors first
        if (-not $this._colors -or $this._colors.Count -eq 0) {
            return ""
        }
        
        # Use larger buffer for better performance
        $sb = Get-PooledStringBuilder 8192
        
        try {
            # Clear the area if bounds changed
            if ($this._cachedClear -and $this._cachedClear.Length -gt 0) {
                [void]$sb.Append($this._cachedClear)
            }
            
            # Draw border if enabled
            if ($this.ShowBorder -and $this.BorderType -ne [BorderType]::None -and $this._colors.border) {
                # Adjust border top if we have a title
                if ($this.ShowTitle -and $this.Title) {
                    # Draw custom border with title integration
                    $this.RenderBorderWithTitle($sb)
                } else {
                    # Standard border
                    $borderStr = [BorderStyle]::RenderBorder(
                        $this.X, $this.Y, $this.Width, $this.Height,
                        $this.BorderType, $this._colors.border
                    )
                    [void]$sb.Append($borderStr)
                }
            }
            
            # Draw header if enabled
            if ($this.ShowHeader) {
                if ($this._headerInvalid) {
                    $this._cachedHeader = $this.BuildHeaderString()
                    $this._headerInvalid = $false
                }
                [void]$sb.Append($this._cachedHeader)
            }
            
            # Draw data rows with caching
            if ($this._rowsInvalid -or $this._lastSelectedIndex -ne $this.SelectedIndex -or 
                $this._lastItemCount -ne $this.Items.Count) {
                $rowBuilder = Get-PooledStringBuilder 4096
                try {
                    $this.RenderDataRows($rowBuilder)
                    $this._cachedRows = $rowBuilder.ToString()
                    $this._rowsInvalid = $false
                    $this._lastSelectedIndex = $this.SelectedIndex
                    $this._lastItemCount = $this.Items.Count
                }
                finally {
                    Return-PooledStringBuilder $rowBuilder
                }
            }
            [void]$sb.Append($this._cachedRows)
            
            # Draw scrollbar if needed
            if ($this.Items.Count -gt $this._viewportRows -and $this._viewportRows -gt 0) {
                $this.RenderScrollbar($sb)
            }
            
            $result = $sb.ToString()
            return $result
        }
        finally {
            Return-PooledStringBuilder $sb
        }
    }
    
    [void] RenderBorderWithTitle([System.Text.StringBuilder]$sb) {
        # Draw standard border
        $borderStr = [BorderStyle]::RenderBorder(
            $this.X, $this.Y, $this.Width, $this.Height,
            $this.BorderType, $this._colors.border
        )
        [void]$sb.Append($borderStr)
        
        # Add title to top border
        if ($this.Title -and $this.Title.Length -gt 0) {
            $titleText = " $($this.Title) "
            $titleX = $this.X + 2
            [void]$sb.Append([VT]::MoveTo($titleX, $this.Y))
            [void]$sb.Append($this._colors.titleColor)
            [void]$sb.Append($titleText)
        }
        return
        
    }
    
    [string] BuildHeaderString() {
        $sb = Get-PooledStringBuilder 512
        try {
            $this.RenderHeader($sb)
            return $sb.ToString()
        }
        finally {
            Return-PooledStringBuilder $sb
        }
    }
    
    [void] RenderHeader([System.Text.StringBuilder]$sb) {
        if ($this.Columns.Count -eq 0 -or $this._headerY -eq 0) { return }
        
        $y = $this._headerY
        $x = $this._contentX
        
        # Header background
        [void]$sb.Append([VT]::MoveTo($x, $y))
        if ($this._colors.headerBg) {
            [void]$sb.Append($this._colors.headerBg)
        }
        if ($this._colors.header) {
            [void]$sb.Append($this._colors.header)
        }
        
        # Row number column
        if ($this.ShowRowNumbers) {
            [void]$sb.Append("  #   ")
        }
        
        # Selection indicator space
        [void]$sb.Append("   ")
        
        # Column headers - check for overflow
        $currentX = 3  # Selection indicator
        if ($this.ShowRowNumbers) { $currentX += 6 }
        
        for ($i = 0; $i -lt $this.Columns.Count; $i++) {
            $col = $this.Columns[$i]
            
            # Check if this column would overflow
            $neededWidth = $col.Width
            if ($this.ShowColumnSeparators -and $i -lt ($this.Columns.Count - 1)) {
                $neededWidth += 1  # For separator
            }
            
            if (($currentX + $neededWidth) -gt $this._contentWidth) {
                # Column would overflow - stop rendering
                break
            }
            
            $header = $col.Header
            
            # Truncate if too long
            if ($header.Length -gt $col.Width) {
                $header = $header.Substring(0, [Math]::Max(1, $col.Width - 1)) + "…"
            }
            
            [void]$sb.Append($header.PadRight($col.Width))
            
            # Column separator
            if ($this.ShowColumnSeparators -and $i -lt ($this.Columns.Count - 1)) {
                [void]$sb.Append($this._colors.gridLine)
                [void]$sb.Append("│")
                [void]$sb.Append($this._colors.header)
            }
            
            $currentX += $neededWidth
        }
        
        # Fill remaining space
        $usedWidth = 3  # Selection indicator
        if ($this.ShowRowNumbers) { $usedWidth += 6 }
        foreach ($col in $this.Columns) {
            $usedWidth += $col.Width
        }
        if ($this.ShowColumnSeparators) {
            $usedWidth += ($this.Columns.Count - 1)
        }
        
        $remainingWidth = $this._contentWidth - $usedWidth
        if ($remainingWidth -gt 0) {
            [void]$sb.Append([StringCache]::GetSpaces($remainingWidth))
        }
        
        # Header separator line that connects to borders
        $y++
        [void]$sb.Append([VT]::MoveTo($this.X, $y))
        [void]$sb.Append($this._colors.gridLine)
        
        # Left T-junction
        if ($this.ShowBorder -and $this.BorderType -ne [BorderType]::None) {
            [void]$sb.Append($this._borderChars.LT)
        } else {
            [void]$sb.Append($this._borderChars.H)
        }
        
        # Draw line with column intersections
        $currentX = 1
        if ($this.ShowRowNumbers) {
            for ($i = 0; $i -lt 6; $i++) {
                [void]$sb.Append($this._borderChars.H)
            }
            $currentX += 6
        }
        
        # Selection space
        for ($i = 0; $i -lt 3; $i++) {
            [void]$sb.Append($this._borderChars.H)
        }
        $currentX += 3
        
        # Column lines with intersections - only for visible columns
        $lineX = $currentX
        for ($i = 0; $i -lt $this.Columns.Count; $i++) {
            $col = $this.Columns[$i]
            
            # Check if this column would overflow
            $neededWidth = $col.Width
            if ($this.ShowColumnSeparators -and $i -lt ($this.Columns.Count - 1)) {
                $neededWidth += 1
            }
            
            if (($lineX + $neededWidth) -gt ($this.Width - 2)) {
                # Would overflow - stop
                break
            }
            
            for ($j = 0; $j -lt $col.Width; $j++) {
                [void]$sb.Append($this._borderChars.H)
            }
            
            if ($this.ShowColumnSeparators -and $i -lt ($this.Columns.Count - 1)) {
                # Column intersection
                [void]$sb.Append($this._borderChars.TT)
            }
            
            $lineX += $neededWidth
        }
        
        # Fill to right border
        $remaining = $this.Width - $lineX - 1
        for ($i = 0; $i -lt $remaining; $i++) {
            [void]$sb.Append($this._borderChars.H)
        }
        
        # Right T-junction
        if ($this.ShowBorder -and $this.BorderType -ne [BorderType]::None) {
            [void]$sb.Append($this._borderChars.RT)
        } else {
            [void]$sb.Append($this._borderChars.H)
        }
    }
    
    [void] RenderDataRows([System.Text.StringBuilder]$sb) {
        if ($this.Items.Count -eq 0) { return }
        
        $endIndex = [Math]::Min($this._scrollOffset + $this._viewportRows, $this.Items.Count)
        $rowHeight = 1 + $this.RowSpacing
        if ($this.ShowGridLines) { $rowHeight++ }
        
        for ($i = $this._scrollOffset; $i -lt $endIndex; $i++) {
            $item = $this.Items[$i]
            $rowY = $this._dataY + (($i - $this._scrollOffset) * $rowHeight)
            
            # Row background
            [void]$sb.Append([VT]::MoveTo($this._contentX, $rowY))
            
            # Determine colors
            $bgColor = $this._colors.background
            $textColor = $this._colors.text
            
            if ($i -eq $this.SelectedIndex) {
                $bgColor = $this._colors.selectedBg
                $textColor = $this._colors.selectedText
            } elseif ($this.AlternateRowColors -and ($i % 2 -eq 1)) {
                $textColor = $this._colors.alternate
            }
            
            [void]$sb.Append($bgColor)
            [void]$sb.Append($textColor)
            
            # Row number
            if ($this.ShowRowNumbers) {
                $rowNum = ($i + 1).ToString().PadLeft(5)
                [void]$sb.Append($rowNum)
                [void]$sb.Append(" ")
            }
            
            # Selection indicator (3 spaces to match header)
            if ($i -eq $this.SelectedIndex -and $this.IsFocused) {
                [void]$sb.Append($this._colors.focusIndicator)
                [void]$sb.Append("▸ ")
                [void]$sb.Append($textColor)
            } else {
                [void]$sb.Append("   ")  # 3 spaces to match header
            }
            
            # Column data - check for overflow
            $dataX = 3  # Selection indicator
            if ($this.ShowRowNumbers) { $dataX += 6 }
            
            for ($j = 0; $j -lt $this.Columns.Count; $j++) {
                $col = $this.Columns[$j]
                
                # Check if this column would overflow
                $neededWidth = $col.Width
                if ($this.ShowColumnSeparators -and $j -lt ($this.Columns.Count - 1)) {
                    $neededWidth += 1
                }
                
                if (($dataX + $neededWidth) -gt $this._contentWidth) {
                    # Column would overflow - stop rendering
                    break
                }
                
                $value = $this.GetColumnValue($item, $col)
                
                # Truncate if too long
                if ($value.Length -gt $col.Width) {
                    $value = $value.Substring(0, [Math]::Max(1, $col.Width - 1)) + "…"
                }
                
                [void]$sb.Append($value.PadRight($col.Width))
                
                # Column separator
                if ($this.ShowColumnSeparators -and $j -lt ($this.Columns.Count - 1)) {
                    [void]$sb.Append($this._colors.gridLine)
                    [void]$sb.Append("│")
                    [void]$sb.Append($textColor)
                }
                
                $dataX += $neededWidth
            }
            
            # Fill remaining width
            $usedWidth = 3  # Selection indicator
            if ($this.ShowRowNumbers) { $usedWidth += 6 }
            foreach ($col in $this.Columns) {
                $usedWidth += $col.Width
            }
            if ($this.ShowColumnSeparators) {
                $usedWidth += ($this.Columns.Count - 1)
            }
            
            $remainingWidth = $this._contentWidth - $usedWidth
            if ($remainingWidth -gt 0) {
                [void]$sb.Append([StringCache]::GetSpaces($remainingWidth))
            }
            
            # Reset colors to prevent bleed
            [void]$sb.Append([VT]::Reset())
            
            # Row spacing - skip if 0 for performance
            if ($this.RowSpacing -gt 0) {
                for ($s = 1; $s -le $this.RowSpacing; $s++) {
                    [void]$sb.Append([VT]::MoveTo($this._contentX, $rowY + $s))
                    [void]$sb.Append($this._colors.background)
                    [void]$sb.Append([StringCache]::GetSpaces($this._contentWidth))
                }
            }
            
            # Grid line below row (connected to borders)
            if ($this.ShowGridLines -and $i -lt ($endIndex - 1)) {
                $lineY = $rowY + 1 + $this.RowSpacing
                [void]$sb.Append([VT]::MoveTo($this.X, $lineY))
                [void]$sb.Append($this._colors.gridLine)
                
                # Left T-junction
                if ($this.ShowBorder -and $this.BorderType -ne [BorderType]::None) {
                    [void]$sb.Append($this._borderChars.LT)
                } else {
                    [void]$sb.Append($this._borderChars.H)
                }
                
                # Draw line
                for ($x = 0; $x -lt ($this.Width - 2); $x++) {
                    [void]$sb.Append($this._borderChars.H)
                }
                
                # Right T-junction
                if ($this.ShowBorder -and $this.BorderType -ne [BorderType]::None) {
                    [void]$sb.Append($this._borderChars.RT)
                } else {
                    [void]$sb.Append($this._borderChars.H)
                }
            }
        }
    }
    
    [void] RenderScrollbar([System.Text.StringBuilder]$sb) {
        if ($this._viewportRows -le 0 -or $this.Items.Count -le 0) { return }
        
        $scrollbarX = $this._contentX + $this._contentWidth - 1
        $scrollbarHeight = $this._viewportRows
        
        # Calculate thumb position and size
        $thumbSize = [Math]::Max(1, [Math]::Floor($scrollbarHeight * $this._viewportRows / $this.Items.Count))
        $thumbPos = [Math]::Floor($scrollbarHeight * $this._scrollOffset / $this.Items.Count)
        
        for ($i = 0; $i -lt $scrollbarHeight; $i++) {
            $y = $this._dataY + $i
            [void]$sb.Append([VT]::MoveTo($scrollbarX, $y))
            
            if ($i -ge $thumbPos -and $i -lt ($thumbPos + $thumbSize)) {
                [void]$sb.Append($this._colors.focusIndicator)
                [void]$sb.Append("█")
            } else {
                [void]$sb.Append($this._colors.gridLine)
                [void]$sb.Append("│")
            }
        }
    }
    
    [string] GetColumnValue([object]$item, [GridColumn]$col) {
        $value = $null
        
        if ($col.Getter -or $col.ValueGetter) {
            $getter = if ($col.Getter) { $col.Getter } else { $col.ValueGetter }
            $value = & $getter $item
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
    
    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        $handled = $false
        
        switch ($key.Key) {
            ([System.ConsoleKey]::UpArrow) {
                if ($this.SelectedIndex -gt 0) {
                    $this.SelectedIndex--
                    $this.EnsureSelectedVisible()
                    $this._rowsInvalid = $true
                    $this.Invalidate()
                    $handled = $true
                }
            }
            ([System.ConsoleKey]::DownArrow) {
                if ($this.SelectedIndex -lt ($this.Items.Count - 1)) {
                    $this.SelectedIndex++
                    $this.EnsureSelectedVisible()
                    $this._rowsInvalid = $true
                    $this.Invalidate()
                    $handled = $true
                }
            }
            ([System.ConsoleKey]::PageUp) {
                $this.SelectedIndex = [Math]::Max(0, $this.SelectedIndex - $this._viewportRows)
                $this.EnsureSelectedVisible()
                $this.Invalidate()
                $handled = $true
            }
            ([System.ConsoleKey]::PageDown) {
                $this.SelectedIndex = [Math]::Min($this.Items.Count - 1, $this.SelectedIndex + $this._viewportRows)
                $this.EnsureSelectedVisible()
                $this.Invalidate()
                $handled = $true
            }
            ([System.ConsoleKey]::Home) {
                $this.SelectedIndex = 0
                $this.EnsureSelectedVisible()
                $this.Invalidate()
                $handled = $true
            }
            ([System.ConsoleKey]::End) {
                $this.SelectedIndex = $this.Items.Count - 1
                $this.EnsureSelectedVisible()
                $this.Invalidate()
                $handled = $true
            }
            ([System.ConsoleKey]::Enter) {
                if ($this.OnItemSelected -and $this.SelectedIndex -ge 0) {
                    $selectedItem = $this.GetSelectedItem()
                    if ($selectedItem) {
                        & $this.OnItemSelected $selectedItem
                    }
                }
                $handled = $true
            }
        }
        
        # Don't call base class to avoid infinite recursion
        # The base FocusableComponent.HandleInput would eventually call back to this method
        # if (-not $handled) {
        #     $handled = ([FocusableComponent]$this).HandleInput($key)
        # }
        
        return $handled
    }
    
    # Compatibility method name
    [bool] OnHandleInput([System.ConsoleKeyInfo]$key) {
        return $this.HandleInput($key)
    }
    
    [void] EnsureSelectedVisible() {
        if ($this.SelectedIndex -lt 0 -or $this.Items.Count -eq 0) { return }
        
        if ($this.SelectedIndex -lt $this._scrollOffset) {
            $this._scrollOffset = $this.SelectedIndex
        } elseif ($this.SelectedIndex -ge ($this._scrollOffset + $this._viewportRows)) {
            $this._scrollOffset = $this.SelectedIndex - $this._viewportRows + 1
        }
        
        $this._scrollOffset = [Math]::Max(0, [Math]::Min($this._scrollOffset, $this.Items.Count - $this._viewportRows))
    }
    
    [object] GetSelectedItem() {
        if ($this.SelectedIndex -ge 0 -and $this.SelectedIndex -lt $this.Items.Count) {
            return $this.Items[$this.SelectedIndex]
        }
        return $null
    }
    
    [void] SelectIndex([int]$index) {
        if ($index -ge 0 -and $index -lt $this.Items.Count) {
            $this.SelectedIndex = $index
            $this.EnsureSelectedVisible()
            $this.Invalidate()
        }
    }
    
    [void] SelectFirst() {
        $this.SelectIndex(0)
    }
    
    [void] SelectLast() {
        $this.SelectIndex($this.Items.Count - 1)
    }
    
    [void] ClearSelection() {
        $this.SelectedIndex = -1
        $this.Invalidate()
    }
    
    [void] OnGotFocus() {
        $this._rowsInvalid = $true
        $this.Invalidate()
        ([FocusableComponent]$this).OnGotFocus()
    }
    
    [void] OnLostFocus() {
        $this._rowsInvalid = $true
        $this.Invalidate()
        ([FocusableComponent]$this).OnLostFocus()
    }
}

class GridColumn {
    [string]$Name
    [string]$Header
    [scriptblock]$Getter
    [scriptblock]$ValueGetter
    [scriptblock]$Formatter
    [int]$Width
    [int]$MaxContentWidth
}