# MinimalDataGrid.ps1 - Clean, minimalist data grid component

class MinimalDataGrid : FocusableComponent {
    [System.Collections.Generic.List[object]]$Items
    [System.Collections.Generic.List[GridColumn]]$Columns
    [int]$SelectedIndex = -1
    [string]$Title = ""
    [bool]$ShowBorder = $true
    [bool]$ShowHeader = $true
    [bool]$ShowGridLines = $false  # Minimal style - no grid lines by default
    [bool]$ShowRowNumbers = $false
    [bool]$AlternateRowColors = $false
    [BorderType]$BorderType = [BorderType]::Rounded
    
    # Scrolling
    hidden [int]$_scrollOffset = 0
    hidden [int]$_viewportHeight = 0
    hidden [int]$_headerHeight = 0
    
    # Cached rendering
    hidden [string]$_cachedHeader = ""
    hidden [bool]$_headerInvalid = $true
    
    # Colors
    hidden [hashtable]$_colors = @{}
    
    MinimalDataGrid() : base() {
        $this.Items = [System.Collections.Generic.List[object]]::new()
        $this.Columns = [System.Collections.Generic.List[GridColumn]]::new()
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
                    $this._headerInvalid = $true
                }.GetNewClosure())
            }
        }
    }
    
    [void] UpdateColors() {
        if ($this.Theme) {
            $this._colors = @{
                header = $this.Theme.GetColor('header.foreground')
                headerBg = $this.Theme.GetBgColor('header.background')
                normal = $this.Theme.GetColor('normal')
                selected = $this.Theme.GetColor('menu.selected.foreground')
                selectedBg = $this.Theme.GetBgColor('menu.selected.background')
                alternate = $this.Theme.GetColor('disabled')
                border = $this.Theme.GetColor('border')
                accent = $this.Theme.GetColor('accent')
            }
        }
    }
    
    [void] AddColumn([string]$name, [scriptblock]$valueGetter, [int]$width = 0) {
        $col = [GridColumn]::new()
        $col.Name = $name
        $col.ValueGetter = $valueGetter
        $col.Width = $width
        $this.Columns.Add($col)
        $this._headerInvalid = $true
        $this.Invalidate()
    }
    
    [void] SetItems([object[]]$items) {
        $this.Items.Clear()
        $this.Items.AddRange($items)
        
        # Auto-size columns if needed
        $this.AutoSizeColumns()
        
        if ($this.SelectedIndex -ge $this.Items.Count) {
            $this.SelectedIndex = $this.Items.Count - 1
        }
        
        $this.Invalidate()
    }
    
    [void] SetColumns([hashtable[]]$columns) {
        $this.Columns.Clear()
        foreach ($colDef in $columns) {
            $col = [GridColumn]::new()
            $col.Name = $colDef.Name
            $col.Header = $colDef.Header
            $col.Width = $colDef.Width
            if ($colDef.ContainsKey('Getter')) {
                $col.ValueGetter = $colDef.Getter
            }
            if ($colDef.ContainsKey('Formatter')) {
                $col.Formatter = $colDef.Formatter
            }
            $this.Columns.Add($col)
        }
        $this._headerInvalid = $true
        $this.Invalidate()
    }
    
    [void] AutoSizeColumns() {
        if ($this.Columns.Count -eq 0) { return }
        
        # Calculate max width for each column
        foreach ($col in $this.Columns) {
            if ($col.Width -gt 0) { continue }  # Skip fixed-width columns
            
            $maxWidth = $col.Name.Length
            foreach ($item in $this.Items) {
                $value = ""
                if ($col.ValueGetter) {
                    $value = (& $col.ValueGetter $item).ToString()
                } elseif ($col.Name -and $item.PSObject.Properties[$col.Name]) {
                    $value = $item."$($col.Name)".ToString()
                }
                $maxWidth = [Math]::Max($maxWidth, $value.Length)
            }
            
            $col.Width = [Math]::Max(3, [Math]::Min($maxWidth + 2, 30))  # Min 3, max 30 chars
        }
    }
    
    [string] RenderContent() {
        if ($this.Columns.Count -eq 0) { return "" }
        
        $sb = Get-PooledStringBuilder 4096
        
        # Calculate viewport
        $this._headerHeight = if ($this.ShowHeader) { 2 } else { 0 }
        $borderInset = if ($this.BorderType -ne [BorderType]::None) { 2 } else { 0 }
        $this._viewportHeight = $this.Height - $this._headerHeight - $borderInset
        
        # Ensure scroll is valid
        $this.EnsureSelectedVisible()
        
        # Render border if enabled
        if ($this.BorderType -ne [BorderType]::None) {
            $color = if ($this.IsFocused) { $this._colors.accent } else { $this._colors.border }
            $sb.Append([BorderStyle]::RenderBorder(
                $this.X, $this.Y, $this.Width, $this.Height,
                $this.BorderType, $color
            ))
        }
        
        # Render header
        if ($this.ShowHeader) {
            if ($this._headerInvalid) {
                $this.RebuildHeader()
            }
            $sb.Append($this._cachedHeader)
        }
        
        # Render rows
        $startY = $this.Y + $this._headerHeight
        if ($this.BorderType -ne [BorderType]::None) { $startY++ }
        
        $endIndex = [Math]::Min($this._scrollOffset + $this._viewportHeight, $this.Items.Count)
        
        for ($i = $this._scrollOffset; $i -lt $endIndex; $i++) {
            $y = $startY + ($i - $this._scrollOffset)
            $this.RenderRow($sb, $i, $y)
        }
        
        # Minimal scrollbar if needed
        if ($this.Items.Count -gt $this._viewportHeight) {
            $this.RenderScrollbar($sb)
        }
        
        $result = $sb.ToString()
        Return-PooledStringBuilder $sb
        return $result
    }
    
    [void] RenderRow([System.Text.StringBuilder]$sb, [int]$index, [int]$y) {
        $item = $this.Items[$index]
        $x = $this.X + 1
        if ($this.BorderType -ne [BorderType]::None) { $x++ }
        
        $sb.Append([VT]::MoveTo($x, $y))
        
        # Row selection
        if ($index -eq $this.SelectedIndex) {
            $sb.Append($this._colors.selectedBg)
            $sb.Append($this._colors.selected)
            if ($this.IsFocused) {
                $sb.Append('▸ ')
            } else {
                $sb.Append('  ')
            }
        } else {
            # Alternate row colors
            if ($this.AlternateRowColors -and ($index % 2 -eq 1)) {
                $sb.Append($this._colors.alternate)
            } else {
                $sb.Append($this._colors.normal)
            }
            $sb.Append('  ')
        }
        
        # Row number if enabled
        if ($this.ShowRowNumbers) {
            $sb.Append(($index + 1).ToString().PadLeft(4))
            $sb.Append(' │ ')
        }
        
        # Render columns
        foreach ($col in $this.Columns) {
            $value = ""
            if ($col.ValueGetter) {
                $rawValue = & $col.ValueGetter $item
                if ($col.Formatter) {
                    $value = (& $col.Formatter $rawValue).ToString()
                } else {
                    $value = if ($null -ne $rawValue) { $rawValue.ToString() } else { "" }
                }
            } elseif ($col.Name -and $item.PSObject.Properties[$col.Name]) {
                $rawValue = $item."$($col.Name)"
                if ($col.Formatter) {
                    $value = (& $col.Formatter $rawValue).ToString()
                } else {
                    $value = if ($null -ne $rawValue) { $rawValue.ToString() } else { "" }
                }
            }
            
            if ($col.Width -gt 1 -and $value.Length -gt $col.Width - 1) {
                $maxLength = [Math]::Max(1, $col.Width - 2)
                if ($value.Length -gt $maxLength) {
                    $value = $value.Substring(0, $maxLength) + '…'
                }
            }
            $sb.Append($value.PadRight($col.Width))
        }
        
        # Clear to end of row
        $remainingWidth = $this.Width - ($x - $this.X) - 2
        if ($this.ShowRowNumbers) { $remainingWidth -= 7 }
        foreach ($col in $this.Columns) { $remainingWidth -= $col.Width }
        if ($remainingWidth -gt 0) {
            $sb.Append(' ' * $remainingWidth)
        }
        
        $sb.Append([VT]::Reset())
    }
    
    [void] RebuildHeader() {
        $sb = Get-PooledStringBuilder 512
        
        $x = $this.X + 1
        $y = $this.Y
        if ($this.BorderType -ne [BorderType]::None) { 
            $x++
            $y++
        }
        
        # Header row
        $sb.Append([VT]::MoveTo($x, $y))
        $sb.Append($this._colors.headerBg)
        $sb.Append($this._colors.header)
        $sb.Append('  ')  # Selection column
        
        if ($this.ShowRowNumbers) {
            $sb.Append(' No. │ ')
        }
        
        foreach ($col in $this.Columns) {
            $header = if ($col.Header) { $col.Header } else { $col.Name }
            if ($header.Length -gt $col.Width) {
                $header = $header.Substring(0, [Math]::Max(1, $col.Width - 1)) + '…'
            }
            $sb.Append($header.PadRight($col.Width))
        }
        
        # Clear to end
        $totalWidth = 2
        if ($this.ShowRowNumbers) { $totalWidth += 7 }
        foreach ($col in $this.Columns) { $totalWidth += $col.Width }
        $remainingWidth = $this.Width - $totalWidth - 2
        if ($this.BorderType -ne [BorderType]::None) { $remainingWidth -= 2 }

        # Ensure remainingWidth is not negative before using it for multiplication
        if ($remainingWidth -lt 0) {
            $remainingWidth = 0
        }

        if ($remainingWidth -gt 0) {
            $sb.Append(' ' * $remainingWidth)
        }
        
        $sb.Append([VT]::Reset())
        
        # Separator line
        $sb.Append([VT]::MoveTo($x, $y + 1))
        $sb.Append($this._colors.border)
        $separatorWidth = $this.Width - 2
        if ($this.BorderType -ne [BorderType]::None) {
            $separatorWidth -= 2
        }
        if ($separatorWidth -gt 0) {
            $sb.Append('─' * $separatorWidth)
        }
        $sb.Append([VT]::Reset())
        
        $this._cachedHeader = $sb.ToString()
        Return-PooledStringBuilder $sb
        $this._headerInvalid = $false
    }
    
    [void] RenderScrollbar([System.Text.StringBuilder]$sb) {
        $scrollbarX = $this.X + $this.Width - 1
        if ($this.BorderType -ne [BorderType]::None) { $scrollbarX-- }
        
        $scrollbarY = $this.Y + $this._headerHeight
        if ($this.BorderType -ne [BorderType]::None) { $scrollbarY++ }
        
        $scrollbarHeight = $this._viewportHeight
        
        # Calculate thumb
        $thumbSize = [Math]::Max(1, [int]($scrollbarHeight * $scrollbarHeight / $this.Items.Count))
        $thumbPos = [int]($this._scrollOffset * ($scrollbarHeight - $thumbSize) / ($this.Items.Count - $this._viewportHeight))
        
        $sb.Append($this._colors.border)
        
        for ($i = 0; $i -lt $scrollbarHeight; $i++) {
            $sb.Append([VT]::MoveTo($scrollbarX, $scrollbarY + $i))
            if ($i -ge $thumbPos -and $i -lt ($thumbPos + $thumbSize)) {
                $sb.Append('▐')
            } else {
                $sb.Append('│')
            }
        }
        
        $sb.Append([VT]::Reset())
    }
    
    [void] EnsureSelectedVisible() {
        if ($this.SelectedIndex -lt 0 -or $this.Items.Count -eq 0) { return }
        
        if ($this.SelectedIndex -lt $this._scrollOffset) {
            $this._scrollOffset = $this.SelectedIndex
        } elseif ($this.SelectedIndex -ge ($this._scrollOffset + $this._viewportHeight)) {
            $this._scrollOffset = $this.SelectedIndex - $this._viewportHeight + 1
        }
        
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
                    $this.Invalidate()
                }
                return $true
            }
            ([System.ConsoleKey]::DownArrow) {
                if ($this.SelectedIndex -lt ($this.Items.Count - 1)) {
                    $this.SelectedIndex++
                    $this.Invalidate()
                }
                return $true
            }
            ([System.ConsoleKey]::Home) {
                $this.SelectedIndex = 0
                $this._scrollOffset = 0
                $this.Invalidate()
                return $true
            }
            ([System.ConsoleKey]::End) {
                $this.SelectedIndex = $this.Items.Count - 1
                $this.Invalidate()
                return $true
            }
            ([System.ConsoleKey]::PageUp) {
                $this.SelectedIndex = [Math]::Max(0, $this.SelectedIndex - $this._viewportHeight)
                $this.Invalidate()
                return $true
            }
            ([System.ConsoleKey]::PageDown) {
                $this.SelectedIndex = [Math]::Min($this.Items.Count - 1, $this.SelectedIndex + $this._viewportHeight)
                $this.Invalidate()
                return $true
            }
        }
        
        return $false
    }
    
    [void] OnBoundsChanged() {
        $this._headerInvalid = $true
        $this.AutoSizeColumns()
    }
    
    [void] OnGotFocus() {
        if ($this.SelectedIndex -lt 0 -and $this.Items.Count -gt 0) {
            $this.SelectedIndex = 0
        }
        ([FocusableComponent]$this).OnGotFocus()
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
            $this.SelectedIndex = $index
            $this.EnsureSelectedVisible()
            $this.Invalidate()
        }
    }
}

class GridColumn {
    [string]$Name
    [string]$Header
    [scriptblock]$ValueGetter
    [scriptblock]$Formatter
    [int]$Width
}