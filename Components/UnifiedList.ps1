# UnifiedList.ps1 - The ONE list component that replaces MinimalDataGrid + SearchableListBox + MinimalListBox
# Solves: Theme inconsistencies, alignment issues, complex APIs, service injection chaos

class UnifiedList : FocusableComponent {
    # DISPLAY MODES - Single component, multiple presentation modes
    [UnifiedListMode]$Mode = [UnifiedListMode]::DataGrid  # DataGrid, SearchList, SimpleList
    
    # CORE DATA PROPERTIES
    [System.Collections.Generic.List[object]]$Items
    [int]$SelectedIndex = -1
    [string]$Title = ""
    [scriptblock]$OnSelectionChanged = {}
    [scriptblock]$OnItemActivated = {}  # Enter/double-click
    
    # DATA GRID MODE PROPERTIES (for ProjectsScreen, TaskScreen, etc.)
    [System.Collections.Generic.List[UnifiedColumn]]$Columns
    [bool]$ShowHeader = $true
    [bool]$ShowRowNumbers = $false
    [bool]$ShowColumnSeparators = $false
    
    # SEARCH LIST MODE PROPERTIES (for CommandLibraryScreen, etc.)
    [string]$SearchQuery = ""
    [string]$SearchPrompt = "Search..."
    [scriptblock]$SearchFilter = $null  # Custom search logic
    [scriptblock]$ItemRenderer = $null  # Custom item display
    [bool]$ShowSearch = $true
    
    # VISUAL PROPERTIES - Consistent across all modes
    [bool]$ShowBorder = $true
    [BorderType]$BorderType = [BorderType]::Rounded
    
    # INTERNAL STATE - Minimal and reliable
    hidden [int]$_scrollOffset = 0
    hidden [int]$_viewportRows = 0
    hidden [int]$_contentX = 0
    hidden [int]$_contentY = 0
    hidden [int]$_contentWidth = 0
    hidden [int]$_contentHeight = 0
    hidden [int]$_searchY = 0  # Y position of search box
    hidden [int]$_headerY = 0  # Y position of header
    hidden [int]$_dataY = 0    # Y position of data rows
    
    # THEME COLORS - Cached once, consistent everywhere
    hidden [hashtable]$_colors = @{}
    hidden [ThemeManager]$Theme
    
    # FILTERED DATA - For search functionality
    hidden [System.Collections.Generic.List[object]]$_filteredItems
    hidden [string]$_lastSearchQuery = ""
    
    UnifiedList() : base() {
        $this.Items = [System.Collections.Generic.List[object]]::new()
        $this.Columns = [System.Collections.Generic.List[UnifiedColumn]]::new()
        $this._filteredItems = [System.Collections.Generic.List[object]]::new()
        $this.IsFocusable = $true
        $this.FocusStyle = 'minimal'
        $this.SelectedIndex = 0  # Start with first item selected
    }
    
    UnifiedList([UnifiedListMode]$mode) : base() {
        $this.Mode = $mode
        $this.Items = [System.Collections.Generic.List[object]]::new()
        $this.Columns = [System.Collections.Generic.List[UnifiedColumn]]::new()
        $this._filteredItems = [System.Collections.Generic.List[object]]::new()
        $this.IsFocusable = $true
        $this.FocusStyle = 'minimal'
        $this.SelectedIndex = 0  # Start with first item selected
        
        # Mode-specific defaults
        switch ($mode) {
            ([UnifiedListMode]::SearchList) {
                $this.ShowSearch = $true
                $this.ShowHeader = $false
            }
            ([UnifiedListMode]::SimpleList) {
                $this.ShowSearch = $false
                $this.ShowHeader = $false
            }
        }
    }
    
    # ═══════════════════════════════════════════════════════════════════════════════════════
    # INITIALIZATION & THEME MANAGEMENT - Guaranteed consistent theming
    # ═══════════════════════════════════════════════════════════════════════════════════════
    
    [void] OnInitialize() {
        ([FocusableComponent]$this).OnInitialize()
        $this.Theme = $this.ServiceContainer.GetService("ThemeManager")
        
        if ($this.Theme) {
            # Subscribe to theme changes
            $eventBus = $this.ServiceContainer.GetService('EventBus')
            if ($eventBus) {
                $eventBus.Subscribe('theme.changed', {
                    param($sender, $eventData)
                    $this.CacheThemeColors()
                    $this.Invalidate()
                }.GetNewClosure())
            }
            
            $this.CacheThemeColors()
            $this.Invalidate()  # Force re-render with theme colors
        }
        
        # Initialize filtered items
        $this.RefreshFilteredItems()
    }
    
    [void] CacheThemeColors() {
        if ($this.Theme) {
            $this._colors = @{
                # Text colors - all amber
                text = $this.Theme.GetColor('text.primary')
                textSecondary = $this.Theme.GetColor('text.secondary')
                textDisabled = $this.Theme.GetColor('text.disabled')
                
                # Background colors
                normalBg = $this.Theme.GetBgColor('surface.background')
                
                # Selection colors - unified with UnifiedDialog
                selectedText = $this.Theme.GetColor('focus.reverse.text')
                selectedBg = $this.Theme.GetBgColor('focus.reverse.background')
                
                # Border and structure
                border = $this.Theme.GetColor('border.normal')
                borderFocused = $this.Theme.GetColor('border.focused')
                
                # Header colors
                header = $this.Theme.GetColor('list.header.text')
                headerBg = $this.Theme.GetBgColor('list.header.background')
                
                # Focus indicator
                focusIndicator = $this.Theme.GetColor('color.primary')
                
                # Search colors
                searchText = $this.Theme.GetColor('input.text')
                searchPlaceholder = $this.Theme.GetColor('input.placeholder')
                
                # Grid lines
                gridLine = $this.Theme.GetColor('border.normal')
            }
        }
    }
    
    # ═══════════════════════════════════════════════════════════════════════════════════════
    # DATA MANAGEMENT - Unified API for all modes
    # ═══════════════════════════════════════════════════════════════════════════════════════
    
    [void] SetItems([array]$items) {
        $this.Items.Clear()
        if ($items) {
            foreach ($item in $items) {
                $this.Items.Add($item)
            }
        }
        
        $this.RefreshFilteredItems()
        $this.AdjustSelection()
        $this.Invalidate()
    }
    
    [void] RefreshFilteredItems() {
        $this._filteredItems.Clear()
        
        if ($this.Items.Count -eq 0) {
            return
        }
        
        # Apply search filter if in search mode and query exists
        if ($this.Mode -eq [UnifiedListMode]::SearchList -and $this.SearchQuery.Length -gt 0) {
            foreach ($item in $this.Items) {
                $shouldInclude = $false
                
                if ($this.SearchFilter) {
                    # Custom search filter
                    $shouldInclude = & $this.SearchFilter $item $this.SearchQuery
                } else {
                    # Default search: convert item to string and check contains
                    $itemText = $this.GetItemDisplayText($item)
                    $shouldInclude = $itemText -like "*$($this.SearchQuery)*"
                }
                
                if ($shouldInclude) {
                    $this._filteredItems.Add($item)
                }
            }
        } else {
            # No filtering - show all items
            foreach ($item in $this.Items) {
                $this._filteredItems.Add($item)
            }
        }
        
        $this._lastSearchQuery = $this.SearchQuery
    }
    
    [string] GetItemDisplayText([object]$item) {
        if ($this.ItemRenderer) {
            return & $this.ItemRenderer $item
        } elseif ($item -and $item.PSObject.Properties['ToString']) {
            return $item.ToString()
        } else {
            return "$item"
        }
    }
    
    [void] AdjustSelection() {
        $itemCount = $this._filteredItems.Count
        if ($itemCount -eq 0) {
            $this.SelectedIndex = -1
        } elseif ($this.SelectedIndex -ge $itemCount) {
            $this.SelectedIndex = $itemCount - 1
        } elseif ($this.SelectedIndex -lt 0 -and $itemCount -gt 0) {
            $this.SelectedIndex = 0
        }
        
        # Ensure we have a selection if there are items
        if ($this.SelectedIndex -eq -1 -and $itemCount -gt 0) {
            $this.SelectedIndex = 0
        }
    }
    
    [object] GetSelectedItem() {
        if ($this.SelectedIndex -ge 0 -and $this.SelectedIndex -lt $this._filteredItems.Count) {
            return $this._filteredItems[$this.SelectedIndex]
        }
        return $null
    }
    
    # ═══════════════════════════════════════════════════════════════════════════════════════
    # COLUMN MANAGEMENT - For DataGrid mode
    # ═══════════════════════════════════════════════════════════════════════════════════════
    
    [void] SetColumns([array]$columns) {
        $this.Columns.Clear()
        foreach ($colDef in $columns) {
            $col = [UnifiedColumn]::new()
            $col.Name = $colDef.Name
            $col.Header = if ($colDef.Header) { $colDef.Header } else { $colDef.Name }
            $col.Width = if ($colDef.Width) { $colDef.Width } else { 0 }
            $col.Getter = if ($colDef.Getter) { $colDef.Getter } else { $null }
            $col.Formatter = if ($colDef.Formatter) { $colDef.Formatter } else { $null }
            $this.Columns.Add($col)
        }
        $this.AutoSizeColumns()
        $this.Invalidate()
    }
    
    [void] AutoSizeColumns() {
        if ($this.Columns.Count -eq 0 -or $this._contentWidth -le 0) { 
            return 
        }
        
        # Calculate available width
        $availableWidth = $this._contentWidth - 3  # Selection indicator space
        if ($this.ShowRowNumbers) { 
            $availableWidth -= 6 
        }
        
        # Calculate column separators space
        if ($this.ShowColumnSeparators -and $this.Columns.Count -gt 1) {
            $availableWidth -= ($this.Columns.Count - 1)
        }
        
        # Auto-size flexible columns (width = 0)
        $fixedWidth = 0
        $flexColumns = @()
        foreach ($col in $this.Columns) {
            if ($col.Width -gt 0) {
                $fixedWidth += $col.Width
            } else {
                $flexColumns += $col
            }
        }
        
        $remainingWidth = $availableWidth - $fixedWidth
        if ($flexColumns.Count -gt 0 -and $remainingWidth -gt 0) {
            $flexWidth = [Math]::Max(5, [int]($remainingWidth / $flexColumns.Count))
            foreach ($flexCol in $flexColumns) {
                $flexCol.Width = $flexWidth
            }
        }
    }
    
    [string] GetColumnValue([object]$item, [UnifiedColumn]$col) {
        $value = $null
        
        if ($col.Getter) {
            $value = & $col.Getter $item
        } elseif ($item -is [hashtable] -and $item.ContainsKey($col.Name)) {
            $value = $item[$col.Name]
        } elseif ($item.PSObject.Properties[$col.Name]) {
            $value = $item.($col.Name)
        }
        
        if ($null -eq $value) { 
            $value = "" 
        }
        
        if ($col.Formatter) {
            $value = & $col.Formatter $value
        } else {
            $value = $value.ToString()
        }
        
        return $value
    }
    
    # ═══════════════════════════════════════════════════════════════════════════════════════
    # LAYOUT MANAGEMENT - Automatic, consistent positioning
    # ═══════════════════════════════════════════════════════════════════════════════════════
    
    [void] OnBoundsChanged() {
        ([FocusableComponent]$this).OnBoundsChanged()
        $this.CalculateLayout()
        $this.AutoSizeColumns()
    }
    
    [void] CalculateLayout() {
        # Calculate content area (inside border)
        if ($this.ShowBorder) {
            $this._contentX = $this.X + 1
            $this._contentY = $this.Y + 1
            $this._contentWidth = $this.Width - 2
            $this._contentHeight = $this.Height - 2
        } else {
            $this._contentX = $this.X
            $this._contentY = $this.Y
            $this._contentWidth = $this.Width
            $this._contentHeight = $this.Height
        }
        
        # Calculate layout based on mode
        $currentY = $this._contentY
        
        # Account for title if present - title is rendered in top border, but may need space
        if ($this.Title -and $this.ShowBorder) {
            # Title is in border, but ensure first data row doesn't overlap
            # No adjustment needed - title is purely in border
        }
        
        # Search box (if enabled)
        if ($this.Mode -eq [UnifiedListMode]::SearchList -and $this.ShowSearch) {
            $this._searchY = $currentY
            $currentY += 2  # Search box + separator
        } else {
            $this._searchY = -1
        }
        
        # Header (if enabled)
        if ($this.Mode -eq [UnifiedListMode]::DataGrid -and $this.ShowHeader) {
            $this._headerY = $currentY
            $currentY += 2  # Header + separator
        } else {
            $this._headerY = -1
        }
        
        # Data area
        $this._dataY = $currentY
        # Calculate how many rows we can display in the remaining space
        $usedRows = $currentY - $this._contentY
        $this._viewportRows = $this._contentHeight - $usedRows
    }
    
    # ═══════════════════════════════════════════════════════════════════════════════════════
    # RENDERING SYSTEM - Flicker-free, consistent theming
    # ═══════════════════════════════════════════════════════════════════════════════════════
    
    [string] RenderContent() {
        $sb = Get-PooledStringBuilder 2048
        
        try {
            # MANUAL BORDER RENDERING - FUCK BorderStyle
            if ($this.ShowBorder) {
                $this.RenderManualBorder($sb)
            }
            
            # Render search box
            if ($this._searchY -ge 0) {
                $this.RenderSearchBox($sb)
            }
            
            # Render header
            if ($this._headerY -ge 0) {
                $this.RenderHeader($sb)
            }
            
            # Render data rows
            $this.RenderDataRows($sb)
            
            return $sb.ToString()
        }
        finally {
            Return-PooledStringBuilder $sb
        }
    }
    
    [void] RenderSearchBox([System.Text.StringBuilder]$sb) {
        [void]$sb.Append([VT]::MoveTo($this._contentX, $this._searchY))
        [void]$sb.Append($this._colors.searchText)
        
        $searchText = if ($this.SearchQuery.Length -gt 0) { 
            $this.SearchQuery 
        } else { 
            $this.SearchPrompt 
        }
        
        if ($this.SearchQuery.Length -eq 0) {
            [void]$sb.Append($this._colors.searchPlaceholder)
        }
        
        [void]$sb.Append("🔍 $searchText")
        
        # Search separator line
        $separatorY = $this._searchY + 1
        [void]$sb.Append([VT]::MoveTo($this._contentX, $separatorY))
        [void]$sb.Append($this._colors.gridLine)
        [void]$sb.Append("─" * $this._contentWidth)
    }
    
    [void] RenderHeader([System.Text.StringBuilder]$sb) {
        [void]$sb.Append([VT]::MoveTo($this._contentX, $this._headerY))
        [void]$sb.Append($this._colors.headerBg)
        [void]$sb.Append($this._colors.header)
        
        # Build header line
        $headerLine = ""
        
        # Selection indicator space
        $headerLine += "   "
        
        # Row numbers space
        if ($this.ShowRowNumbers) {
            $headerLine += "  #   "
        }
        
        # Column headers
        for ($i = 0; $i -lt $this.Columns.Count; $i++) {
            $col = $this.Columns[$i]
            $header = $col.Header
            
            # Truncate if too long
            if ($header.Length -gt $col.Width) {
                $header = $header.Substring(0, [Math]::Max(1, $col.Width - 1)) + "…"
            }
            
            $headerLine += $header.PadRight($col.Width)
            
            # Column separator
            if ($this.ShowColumnSeparators -and $i -lt ($this.Columns.Count - 1)) {
                $headerLine += "│"
            }
        }
        
        # Ensure header line fits within content width
        if ($headerLine.Length -gt $this._contentWidth) {
            $headerLine = $headerLine.Substring(0, $this._contentWidth)
        } elseif ($headerLine.Length -lt $this._contentWidth) {
            $headerLine = $headerLine.PadRight($this._contentWidth)
        }
        
        [void]$sb.Append($headerLine)
        
        # Header separator line with T-junctions for column separators
        $separatorY = $this._headerY + 1
        [void]$sb.Append([VT]::MoveTo($this._contentX, $separatorY))
        [void]$sb.Append($this._colors.gridLine)
        
        # Build separator line with T-junctions at exact column positions
        $separatorPositions = @()
        
        if ($this.ShowColumnSeparators -and $this.Columns.Count -gt 1) {
            $currentPos = 3  # Selection indicator space
            if ($this.ShowRowNumbers) { $currentPos += 6 }
            
            # Calculate exact positions of column separators
            for ($i = 0; $i -lt ($this.Columns.Count - 1); $i++) {
                $currentPos += $this.Columns[$i].Width
                $separatorPositions += $currentPos
                $currentPos += 1  # Skip the separator itself
            }
        }
        
        # Build the separator line
        $separatorLine = ""
        for ($pos = 0; $pos -lt $this._contentWidth; $pos++) {
            if ($separatorPositions -contains $pos) {
                $separatorLine += "┼"  # T-junction
            } else {
                $separatorLine += "─"  # Horizontal line
            }
        }
        
        [void]$sb.Append($separatorLine)
    }
    
    [void] RenderDataRows([System.Text.StringBuilder]$sb) {
        if ($this._filteredItems.Count -eq 0) {
            # Empty state
            $emptyY = $this._dataY + [int]($this._viewportRows / 2)
            [void]$sb.Append([VT]::MoveTo($this._contentX, $emptyY))
            [void]$sb.Append($this._colors.textDisabled)
            [void]$sb.Append("No items to display")
            return
        }
        
        # Calculate visible range
        $startIndex = $this._scrollOffset
        $endIndex = [Math]::Min($startIndex + $this._viewportRows, $this._filteredItems.Count)
        
        for ($i = $startIndex; $i -lt $endIndex; $i++) {
            $rowY = $this._dataY + ($i - $startIndex)
            $item = $this._filteredItems[$i]
            $isSelected = ($i -eq $this.SelectedIndex)
            
            [void]$sb.Append([VT]::MoveTo($this._contentX, $rowY))
            
            # Apply selection colors - ALWAYS set both foreground AND background
            if ($isSelected -and $this.IsFocused) {
                [void]$sb.Append($this._colors.selectedBg)
                [void]$sb.Append($this._colors.selectedText)
            } else {
                # Set normal background and text colors
                if ($this._colors.normalBg) { [void]$sb.Append($this._colors.normalBg) }
                if ($this._colors.text) { [void]$sb.Append($this._colors.text) }
            }
            
            # Selection indicator - consistent 3-character width
            if ($isSelected -and $this.IsFocused) {
                [void]$sb.Append($this._colors.focusIndicator)
                [void]$sb.Append("▸  ")  # Arrow + 2 spaces = 3 chars total
                [void]$sb.Append($this._colors.selectedText)
            } else {
                [void]$sb.Append("   ")
            }
            
            # Row content based on mode
            switch ($this.Mode) {
                ([UnifiedListMode]::DataGrid) {
                    $this.RenderDataGridRow($sb, $item, $isSelected)
                }
                ([UnifiedListMode]::SearchList) {
                    $this.RenderSearchListRow($sb, $item, $isSelected)
                }
                ([UnifiedListMode]::SimpleList) {
                    $this.RenderSimpleListRow($sb, $item, $isSelected)
                }
            }
            
            # Fill remaining width for selected rows
            if ($isSelected -and $this.IsFocused) {
                $usedWidth = $this.GetRowUsedWidth()
                $remainingWidth = $this._contentWidth - $usedWidth
                if ($remainingWidth -gt 0) {
                    [void]$sb.Append([StringCache]::GetSpaces($remainingWidth))
                }
                # Restore normal colors after selection highlighting  
                if ($this._colors.normalBg) { [void]$sb.Append($this._colors.normalBg) }
                if ($this._colors.text) { [void]$sb.Append($this._colors.text) }
            }
            
            # Colors are managed by individual components - no global reset needed
        }
    }
    
    [void] RenderDataGridRow([System.Text.StringBuilder]$sb, [object]$item, [bool]$isSelected) {
        # Build row content first
        $rowContent = ""
        
        # Row number
        if ($this.ShowRowNumbers) {
            $rowNum = ($this.SelectedIndex + 1).ToString().PadLeft(5)
            $rowContent += $rowNum + " "
        }
        
        # Column data
        for ($j = 0; $j -lt $this.Columns.Count; $j++) {
            $col = $this.Columns[$j]
            $value = $this.GetColumnValue($item, $col)
            
            # Truncate if too long
            if ($value.Length -gt $col.Width) {
                $value = $value.Substring(0, [Math]::Max(1, $col.Width - 1)) + "…"
            }
            
            $rowContent += $value.PadRight($col.Width)
            
            # Column separator
            if ($this.ShowColumnSeparators -and $j -lt ($this.Columns.Count - 1)) {
                $rowContent += "│"
            }
        }
        
        # Ensure row content fits within available width (content width minus selection indicator)
        $maxRowWidth = $this._contentWidth - 3  # 3 chars for selection indicator
        if ($rowContent.Length -gt $maxRowWidth) {
            $rowContent = $rowContent.Substring(0, $maxRowWidth)
        }
        
        [void]$sb.Append($rowContent)
    }
    
    [void] RenderSearchListRow([System.Text.StringBuilder]$sb, [object]$item, [bool]$isSelected) {
        $displayText = $this.GetItemDisplayText($item)
        $maxWidth = $this._contentWidth - 3  # Account for selection indicator
        
        if ($displayText.Length -gt $maxWidth) {
            $displayText = $displayText.Substring(0, $maxWidth - 1) + "…"
        }
        
        [void]$sb.Append($displayText)
    }
    
    [void] RenderSimpleListRow([System.Text.StringBuilder]$sb, [object]$item, [bool]$isSelected) {
        # Same as search list for now
        $this.RenderSearchListRow($sb, $item, $isSelected)
    }
    
    [int] GetRowUsedWidth() {
        $usedWidth = 3  # Selection indicator
        
        if ($this.Mode -eq [UnifiedListMode]::DataGrid) {
            if ($this.ShowRowNumbers) { 
                $usedWidth += 6 
            }
            foreach ($col in $this.Columns) {
                $usedWidth += $col.Width
            }
            if ($this.ShowColumnSeparators -and $this.Columns.Count -gt 1) {
                $usedWidth += ($this.Columns.Count - 1)
            }
        }
        
        return $usedWidth
    }
    
    # MANUAL BORDER RENDERING - Simple clean borders, no junctions
    [void] RenderManualBorder([System.Text.StringBuilder]$sb) {
        if ($this.Width -lt 2 -or $this.Height -lt 2) { return }
        
        # Set border color
        if ($this._colors.border) { 
            [void]$sb.Append($this._colors.border) 
        }
        
        # Top border with T-junctions for column separators
        [void]$sb.Append([VT]::MoveTo($this.X, $this.Y))
        [void]$sb.Append("┌")  # Top left corner
        
        # Build top border with T-junctions at exact column positions
        $separatorPositions = @()
        
        if ($this.ShowColumnSeparators -and $this.Columns.Count -gt 1 -and $this._headerY -ge 0) {
            $currentPos = 3  # Selection indicator space
            if ($this.ShowRowNumbers) { $currentPos += 6 }
            
            # Calculate exact positions of column separators
            for ($i = 0; $i -lt ($this.Columns.Count - 1); $i++) {
                $currentPos += $this.Columns[$i].Width
                $separatorPositions += $currentPos
                $currentPos += 1  # Skip the separator itself
            }
        }
        
        # Build the top border line
        $topBorderLine = ""
        for ($pos = 0; $pos -lt ($this.Width - 2); $pos++) {
            if ($separatorPositions -contains $pos) {
                $topBorderLine += "┬"  # T-junction pointing down
            } else {
                $topBorderLine += "─"  # Horizontal line
            }
        }
        
        [void]$sb.Append($topBorderLine)
        [void]$sb.Append("┐")  # Top right corner
        
        # Side borders - always simple
        for ($i = 1; $i -lt ($this.Height - 1); $i++) {
            # Left border
            [void]$sb.Append([VT]::MoveTo($this.X, $this.Y + $i))
            [void]$sb.Append("│")
            
            # Right border
            [void]$sb.Append([VT]::MoveTo($this.X + $this.Width - 1, $this.Y + $i))
            [void]$sb.Append("│")
        }
        
        # Bottom border with T-junctions for column separators
        [void]$sb.Append([VT]::MoveTo($this.X, $this.Y + $this.Height - 1))
        [void]$sb.Append("└")  # Bottom left corner
        
        # Build bottom border with T-junctions at exact column positions
        $separatorPositions = @()
        
        if ($this.ShowColumnSeparators -and $this.Columns.Count -gt 1 -and $this._headerY -ge 0) {
            $currentPos = 3  # Selection indicator space
            if ($this.ShowRowNumbers) { $currentPos += 6 }
            
            # Calculate exact positions of column separators
            for ($i = 0; $i -lt ($this.Columns.Count - 1); $i++) {
                $currentPos += $this.Columns[$i].Width
                $separatorPositions += $currentPos
                $currentPos += 1  # Skip the separator itself
            }
        }
        
        # Build the bottom border line
        $bottomBorderLine = ""
        for ($pos = 0; $pos -lt ($this.Width - 2); $pos++) {
            if ($separatorPositions -contains $pos) {
                $bottomBorderLine += "┴"  # T-junction pointing up
            } else {
                $bottomBorderLine += "─"  # Horizontal line
            }
        }
        
        [void]$sb.Append($bottomBorderLine)
        [void]$sb.Append("┘")  # Bottom right corner
    }
    
    # ═══════════════════════════════════════════════════════════════════════════════════════
    # INPUT HANDLING - Consistent navigation across all modes
    # ═══════════════════════════════════════════════════════════════════════════════════════
    
    [bool] OnHandleInput([System.ConsoleKeyInfo]$key) {
        # Search mode input handling
        if ($this.Mode -eq [UnifiedListMode]::SearchList -and $this.ShowSearch) {
            # Handle search input
            if ($key.KeyChar -match '[a-zA-Z0-9 ]' -and -not [char]::IsControl($key.KeyChar)) {
                $this.SearchQuery += $key.KeyChar
                $this.RefreshFilteredItems()
                $this.AdjustSelection()
                $this.Invalidate()
                return $true
            }
            
            if ($key.Key -eq [System.ConsoleKey]::Backspace -and $this.SearchQuery.Length -gt 0) {
                $this.SearchQuery = $this.SearchQuery.Substring(0, $this.SearchQuery.Length - 1)
                $this.RefreshFilteredItems()
                $this.AdjustSelection()
                $this.Invalidate()
                return $true
            }
        }
        
        # Navigation input handling
        switch ($key.Key) {
            ([System.ConsoleKey]::UpArrow) {
                if ($this.SelectedIndex -gt 0) {
                    $this.SelectedIndex--
                    $this.EnsureSelectedVisible()
                    $this.Invalidate()
                }
                return $true
            }
            ([System.ConsoleKey]::DownArrow) {
                if ($this.SelectedIndex -lt ($this._filteredItems.Count - 1)) {
                    $this.SelectedIndex++
                    $this.EnsureSelectedVisible()
                    $this.Invalidate()
                }
                return $true
            }
            ([System.ConsoleKey]::PageUp) {
                $this.SelectedIndex = [Math]::Max(0, $this.SelectedIndex - $this._viewportRows)
                $this.EnsureSelectedVisible()
                $this.Invalidate()
                return $true
            }
            ([System.ConsoleKey]::PageDown) {
                $this.SelectedIndex = [Math]::Min($this._filteredItems.Count - 1, $this.SelectedIndex + $this._viewportRows)
                $this.EnsureSelectedVisible()
                $this.Invalidate()
                return $true
            }
            ([System.ConsoleKey]::Home) {
                $this.SelectedIndex = 0
                $this.EnsureSelectedVisible()
                $this.Invalidate()
                return $true
            }
            ([System.ConsoleKey]::End) {
                $this.SelectedIndex = $this._filteredItems.Count - 1
                $this.EnsureSelectedVisible()
                $this.Invalidate()
                return $true
            }
            ([System.ConsoleKey]::Enter) {
                if ($this.OnSelectionChanged) {
                    & $this.OnSelectionChanged
                }
                if ($this.OnItemActivated) {
                    $selectedItem = $this.GetSelectedItem()
                    if ($selectedItem) {
                        & $this.OnItemActivated $selectedItem
                    }
                }
                return $true
            }
        }
        
        return $false
    }
    
    [void] EnsureSelectedVisible() {
        if ($this.SelectedIndex -lt $this._scrollOffset) {
            $this._scrollOffset = $this.SelectedIndex
        } elseif ($this.SelectedIndex -ge ($this._scrollOffset + $this._viewportRows)) {
            $this._scrollOffset = $this.SelectedIndex - $this._viewportRows + 1
        }
        
        # Bounds check
        $this._scrollOffset = [Math]::Max(0, $this._scrollOffset)
        $maxScroll = [Math]::Max(0, $this._filteredItems.Count - $this._viewportRows)
        $this._scrollOffset = [Math]::Min($this._scrollOffset, $maxScroll)
    }
    
    # ═══════════════════════════════════════════════════════════════════════════════════════
    # PUBLIC API - Simple, consistent methods
    # ═══════════════════════════════════════════════════════════════════════════════════════
    
    [void] SetSearchQuery([string]$query) {
        if ($this.SearchQuery -ne $query) {
            $this.SearchQuery = $query
            $this.RefreshFilteredItems()
            $this.AdjustSelection()
            $this.Invalidate()
        }
    }
    
    [void] ClearSearch() {
        $this.SetSearchQuery("")
    }
    
    [void] SelectIndex([int]$index) {
        if ($index -ge 0 -and $index -lt $this._filteredItems.Count) {
            $this.SelectedIndex = $index
            $this.EnsureSelectedVisible()
            $this.Invalidate()
        }
    }
    
    [void] SelectItem([object]$item) {
        for ($i = 0; $i -lt $this._filteredItems.Count; $i++) {
            if ($this._filteredItems[$i] -eq $item) {
                $this.SelectIndex($i)
                break
            }
        }
    }
}

# Supporting enums and classes
enum UnifiedListMode {
    DataGrid = 0    # For ProjectsScreen, TaskScreen - columns, headers
    SearchList = 1  # For CommandLibraryScreen - search box, custom rendering
    SimpleList = 2  # Basic list display
}

class UnifiedColumn {
    [string]$Name = ""
    [string]$Header = ""
    [int]$Width = 0
    [scriptblock]$Getter = $null
    [scriptblock]$Formatter = $null
}