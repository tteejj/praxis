# GridPanel.ps1 - Fast grid layout component for PRAXIS

class GridPanel : Container {
    [int]$Columns = 2
    [int]$Rows = 0  # Auto-calculated if 0
    [int]$CellSpacing = 1
    [int]$MinCellWidth = 5
    [int]$MinCellHeight = 2
    [bool]$ShowBorder = $false
    [bool]$AutoSize = $true  # Auto-calculate rows based on children
    
    # Cached layout calculations
    hidden [int]$_cachedCellWidth = 0
    hidden [int]$_cachedCellHeight = 0
    hidden [bool]$_layoutInvalid = $true
    hidden [int]$_lastWidth = 0
    hidden [int]$_lastHeight = 0
    hidden [int]$_lastColumns = 0
    hidden [int]$_lastChildCount = 0
    hidden [hashtable]$_colors = @{}
    hidden [ThemeManager]$Theme
    
    GridPanel() : base() {
        $this.DrawBackground = $false
    }
    
    [void] OnInitialize() {
        ([Container]$this).OnInitialize()
        $this.Theme = $this.ServiceContainer.GetService('ThemeManager')
        if ($this.Theme) {
            $this.Theme.Subscribe({ $this.OnThemeChanged() })
            $this.OnThemeChanged()
        }
    }
    
    [void] OnThemeChanged() {
        if ($this.Theme) {
            $this._colors = @{
                'border' = $this.Theme.GetColor("border")
            }
        }
        $this.Invalidate()
    }
    
    GridPanel([int]$columns) : base() {
        $this.Columns = [Math]::Max(1, $columns)
        $this.DrawBackground = $false
    }
    
    [void] SetGridSize([int]$columns, [int]$rows) {
        $this.Columns = [Math]::Max(1, $columns)
        $this.Rows = [Math]::Max(0, $rows)
        $this.InvalidateLayout()
    }
    
    [void] InvalidateLayout() {
        $this._layoutInvalid = $true
        $this.Invalidate()
    }
    
    [void] AddChild([UIElement]$child) {
        # Call base implementation
        ([Container]$this).AddChild($child)
        # Invalidate layout when children change
        $this.InvalidateLayout()
    }
    
    [void] RemoveChild([UIElement]$child) {
        # Call base implementation
        ([Container]$this).RemoveChild($child)
        # Invalidate layout when children change
        $this.InvalidateLayout()
    }
    
    [void] OnBoundsChanged() {
        $this.InvalidateLayout()
        $this.UpdateLayout()
    }
    
    [void] UpdateLayout() {
        if (-not $this._layoutInvalid -and 
            $this._lastWidth -eq $this.Width -and 
            $this._lastHeight -eq $this.Height -and
            $this._lastColumns -eq $this.Columns -and
            $this._lastChildCount -eq $this.Children.Count) {
            return  # Layout is still valid
        }
        
        $visibleChildren = @($this.Children | Where-Object { $_.Visible })
        if ($visibleChildren.Count -eq 0) {
            $this._layoutInvalid = $false
            return
        }
        
        # Calculate grid dimensions
        $cols = $this.Columns
        $actualRows = if ($this.AutoSize) {
            [Math]::Ceiling($visibleChildren.Count / $cols)
        } else {
            [Math]::Max(1, $this.Rows)
        }
        
        # Calculate cell dimensions
        $totalSpacingWidth = ($cols - 1) * $this.CellSpacing
        $totalSpacingHeight = ($actualRows - 1) * $this.CellSpacing
        
        $cellWidth = [Math]::Max($this.MinCellWidth, 
            [int](($this.Width - $totalSpacingWidth) / $cols))
        $cellHeight = [Math]::Max($this.MinCellHeight, 
            [int](($this.Height - $totalSpacingHeight) / $actualRows))
        
        # Position children in grid
        for ($i = 0; $i -lt $visibleChildren.Count; $i++) {
            $child = $visibleChildren[$i]
            $col = $i % $cols
            $row = [int]($i / $cols)
            
            # Calculate position
            $childX = $this.X + ($col * ($cellWidth + $this.CellSpacing))
            $childY = $this.Y + ($row * ($cellHeight + $this.CellSpacing))
            
            # Set child bounds
            $child.SetBounds($childX, $childY, $cellWidth, $cellHeight)
        }
        
        # Cache the layout
        $this._cachedCellWidth = $cellWidth
        $this._cachedCellHeight = $cellHeight
        $this._lastWidth = $this.Width
        $this._lastHeight = $this.Height
        $this._lastColumns = $this.Columns
        $this._lastChildCount = $this.Children.Count
        $this._layoutInvalid = $false
    }
    
    [string] OnRender() {
        # Update layout before rendering
        $this.UpdateLayout()
        
        # Use fast string-based rendering
        $sb = Get-PooledStringBuilder 2048
        
        # Render all visible children
        foreach ($child in $this.Children) {
            if ($child.Visible) {
                $sb.Append($child.Render())
            }
        }
        
        # Optional: render grid borders
        if ($this.ShowBorder -and $this._cachedCellWidth -gt 0) {
            $borderColor = $this._colors['border']
            $sb.Append($borderColor)
            
            # Draw grid lines (simplified - just basic grid)
            $cols = $this.Columns
            $actualRows = if ($this.AutoSize) {
                [Math]::Ceiling($this.Children.Count / $cols)
            } else {
                $this.Rows
            }
            
            # Vertical lines
            for ($col = 1; $col -lt $cols; $col++) {
                $lineX = $this.X + ($col * ($this._cachedCellWidth + $this.CellSpacing)) - 1
                for ($y = 0; $y -lt $this.Height; $y++) {
                    $sb.Append([VT]::MoveTo($lineX, $this.Y + $y))
                    $sb.Append("│")
                }
            }
            
            # Horizontal lines
            for ($row = 1; $row -lt $actualRows; $row++) {
                $lineY = $this.Y + ($row * ($this._cachedCellHeight + $this.CellSpacing)) - 1
                $sb.Append([VT]::MoveTo($this.X, $lineY))
                $sb.Append([StringCache]::GetHorizontalLine($this.Width))
            }
            
            $sb.Append([VT]::Reset())
        }
        
        $result = $sb.ToString()
        Return-PooledStringBuilder $sb
        return $result
    }
    
    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        # Route input to focused child
        foreach ($child in $this.Children) {
            if ($child.IsFocused -and $child.HandleInput($key)) {
                return $true
            }
        }
        
        # Let base Container handle other input (Tab navigation, etc.)
        return ([Container]$this).HandleInput($key)
    }
    
    # Helper methods
    [int] GetCellWidth() { return $this._cachedCellWidth }
    [int] GetCellHeight() { return $this._cachedCellHeight }
    
    # Get child at grid position
    [UIElement] GetChildAt([int]$col, [int]$row) {
        $index = ($row * $this.Columns) + $col
        if ($index -ge 0 -and $index -lt $this.Children.Count) {
            return $this.Children[$index]
        }
        return $null
    }
    
    # Focus management with grid navigation
    [void] FocusCell([int]$col, [int]$row) {
        $child = $this.GetChildAt($col, $row)
        if ($child -and $child.IsFocusable) {
            $child.Focus()
        }
    }
}