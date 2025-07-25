# VerticalSplit.ps1 - Fast vertical layout component for PRAXIS

class VerticalSplit : Container {
    [UIElement]$TopPane
    [UIElement]$BottomPane
    [int]$SplitRatio = 50  # Percentage for top pane (0-100)
    [int]$MinPaneHeight = 3
    [bool]$ShowBorder = $false
    [bool]$Resizable = $false  # Future: allow dragging the split
    
    # Cached layout calculations
    hidden [int]$_cachedTopHeight = 0
    hidden [int]$_cachedBottomHeight = 0
    hidden [int]$_cachedBottomY = 0
    hidden [bool]$_layoutInvalid = $true
    hidden [int]$_lastHeight = 0
    hidden [int]$_lastSplitRatio = 0
    
    VerticalSplit() : base() {
        $this.DrawBackground = $false
    }
    
    [void] SetTopPane([UIElement]$pane) {
        if ($this.TopPane) {
            $this.RemoveChild($this.TopPane)
        }
        $this.TopPane = $pane
        if ($pane) {
            $this.AddChild($pane)
        }
        $this.InvalidateLayout()
    }
    
    [void] SetBottomPane([UIElement]$pane) {
        if ($this.BottomPane) {
            $this.RemoveChild($this.BottomPane)
        }
        $this.BottomPane = $pane
        if ($pane) {
            $this.AddChild($pane)
        }
        $this.InvalidateLayout()
    }
    
    [void] SetSplitRatio([int]$ratio) {
        $this.SplitRatio = [Math]::Max(10, [Math]::Min(90, $ratio))
        $this.InvalidateLayout()
    }
    
    [void] InvalidateLayout() {
        $this._layoutInvalid = $true
        $this.Invalidate()
    }
    
    [void] OnBoundsChanged() {
        $this.InvalidateLayout()
        $this.UpdateLayout()
    }
    
    [void] UpdateLayout() {
        if (-not $this._layoutInvalid -and 
            $this._lastHeight -eq $this.Height -and 
            $this._lastSplitRatio -eq $this.SplitRatio) {
            return  # Layout is still valid
        }
        
        # Calculate pane dimensions
        $totalHeight = $this.Height
        $topHeight = [int](($totalHeight * $this.SplitRatio) / 100)
        $topHeight = [Math]::Max($this.MinPaneHeight, [Math]::Min($topHeight, $totalHeight - $this.MinPaneHeight))
        $bottomHeight = $totalHeight - $topHeight
        $bottomY = $this.Y + $topHeight
        
        # Update top pane
        if ($this.TopPane) {
            $this.TopPane.SetBounds($this.X, $this.Y, $this.Width, $topHeight)
        }
        
        # Update bottom pane
        if ($this.BottomPane) {
            $this.BottomPane.SetBounds($this.X, $bottomY, $this.Width, $bottomHeight)
        }
        
        # Cache the layout
        $this._cachedTopHeight = $topHeight
        $this._cachedBottomHeight = $bottomHeight
        $this._cachedBottomY = $bottomY
        $this._lastHeight = $this.Height
        $this._lastSplitRatio = $this.SplitRatio
        $this._layoutInvalid = $false
    }
    
    [string] OnRender() {
        # Update layout before rendering
        $this.UpdateLayout()
        
        # Use fast string-based rendering
        $sb = Get-PooledStringBuilder 1024
        
        # Render children
        if ($this.TopPane -and $this.TopPane.Visible) {
            $sb.Append($this.TopPane.Render())
        }
        
        if ($this.BottomPane -and $this.BottomPane.Visible) {
            $sb.Append($this.BottomPane.Render())
        }
        
        # Optional: render split border
        if ($this.ShowBorder -and $this._cachedTopHeight -gt 0) {
            $borderColor = $this.Theme.GetColor("border")
            $sb.Append([VT]::MoveTo($this.X, $this._cachedBottomY - 1))
            $sb.Append($borderColor)
            $sb.Append("─" * $this.Width)
            $sb.Append([VT]::Reset())
        }
        
        $result = $sb.ToString()
        Return-PooledStringBuilder $sb
        return $result
    }
    
    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        # Route input to focused pane
        if ($this.TopPane -and $this.TopPane.IsFocused) {
            if ($this.TopPane.HandleInput($key)) {
                return $true
            }
        }
        
        if ($this.BottomPane -and $this.BottomPane.IsFocused) {
            if ($this.BottomPane.HandleInput($key)) {
                return $true
            }
        }
        
        # Let base Container handle other input (Tab navigation, etc.)
        return ([Container]$this).HandleInput($key)
    }
    
    # Helper methods for common split ratios
    [void] SetEqualSplit() { $this.SetSplitRatio(50) }
    [void] SetTopFavoredSplit() { $this.SetSplitRatio(70) }
    [void] SetBottomFavoredSplit() { $this.SetSplitRatio(30) }
    
    # Get pane by position
    [UIElement] GetTopPane() { return $this.TopPane }
    [UIElement] GetBottomPane() { return $this.BottomPane }
    
    # Focus management
    [void] FocusTopPane() {
        if ($this.TopPane -and $this.TopPane.IsFocusable) {
            $this.TopPane.Focus()
        }
    }
    
    [void] FocusBottomPane() {
        if ($this.BottomPane -and $this.BottomPane.IsFocusable) {
            $this.BottomPane.Focus()
        }
    }
}