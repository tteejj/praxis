# HorizontalSplit.ps1 - Fast horizontal layout component for PRAXIS

class HorizontalSplit : Container {
    [UIElement]$LeftPane
    [UIElement]$RightPane
    [int]$SplitRatio = 50  # Percentage for left pane (0-100)
    [int]$MinPaneWidth = 5
    [bool]$ShowBorder = $false
    [bool]$Resizable = $false  # Future: allow dragging the split
    
    # Cached layout calculations
    hidden [int]$_cachedLeftWidth = 0
    hidden [int]$_cachedRightWidth = 0
    hidden [int]$_cachedRightX = 0
    hidden [bool]$_layoutInvalid = $true
    hidden [int]$_lastWidth = 0
    hidden [int]$_lastSplitRatio = 0
    hidden [hashtable]$_colors = @{}
    hidden [ThemeManager]$Theme
    
    HorizontalSplit() : base() {
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
    
    [void] SetLeftPane([UIElement]$pane) {
        if ($this.LeftPane) {
            $this.RemoveChild($this.LeftPane)
        }
        $this.LeftPane = $pane
        if ($pane) {
            $this.AddChild($pane)
        }
        $this.InvalidateLayout()
    }
    
    [void] SetRightPane([UIElement]$pane) {
        if ($this.RightPane) {
            $this.RemoveChild($this.RightPane)
        }
        $this.RightPane = $pane
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
            $this._lastWidth -eq $this.Width -and 
            $this._lastSplitRatio -eq $this.SplitRatio) {
            return  # Layout is still valid
        }
        
        # Calculate pane dimensions
        $totalWidth = $this.Width
        $leftWidth = [int](($totalWidth * $this.SplitRatio) / 100)
        $leftWidth = [Math]::Max($this.MinPaneWidth, [Math]::Min($leftWidth, $totalWidth - $this.MinPaneWidth))
        $rightWidth = $totalWidth - $leftWidth
        $rightX = $this.X + $leftWidth
        
        # Update left pane
        if ($this.LeftPane) {
            $this.LeftPane.SetBounds($this.X, $this.Y, $leftWidth, $this.Height)
        }
        
        # Update right pane
        if ($this.RightPane) {
            $this.RightPane.SetBounds($rightX, $this.Y, $rightWidth, $this.Height)
        }
        
        # Cache the layout
        $this._cachedLeftWidth = $leftWidth
        $this._cachedRightWidth = $rightWidth
        $this._cachedRightX = $rightX
        $this._lastWidth = $this.Width
        $this._lastSplitRatio = $this.SplitRatio
        $this._layoutInvalid = $false
    }
    
    [string] OnRender() {
        # Update layout before rendering
        $this.UpdateLayout()
        
        # Use fast string-based rendering
        $sb = Get-PooledStringBuilder 1024
        
        # Render children
        if ($this.LeftPane -and $this.LeftPane.Visible) {
            $sb.Append($this.LeftPane.Render())
        }
        
        if ($this.RightPane -and $this.RightPane.Visible) {
            $sb.Append($this.RightPane.Render())
        }
        
        # Optional: render split border
        if ($this.ShowBorder -and $this._cachedLeftWidth -gt 0) {
            $borderColor = $this._colors['border']
            for ($y = 0; $y -lt $this.Height; $y++) {
                $sb.Append([VT]::MoveTo($this._cachedRightX - 1, $this.Y + $y))
                $sb.Append($borderColor)
                $sb.Append("│")
            }
            $sb.Append([VT]::Reset())
        }
        
        $result = $sb.ToString()
        Return-PooledStringBuilder $sb
        return $result
    }
    
    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        # Route input to focused pane
        if ($this.LeftPane -and $this.LeftPane.IsFocused) {
            if ($this.LeftPane.HandleInput($key)) {
                return $true
            }
        }
        
        if ($this.RightPane -and $this.RightPane.IsFocused) {
            if ($this.RightPane.HandleInput($key)) {
                return $true
            }
        }
        
        # Let base Container handle other input (Tab navigation, etc.)
        return ([Container]$this).HandleInput($key)
    }
    
    # Helper methods for common split ratios
    [void] SetEqualSplit() { $this.SetSplitRatio(50) }
    [void] SetLeftFavoredSplit() { $this.SetSplitRatio(70) }
    [void] SetRightFavoredSplit() { $this.SetSplitRatio(30) }
    
    # Get pane by position
    [UIElement] GetLeftPane() { return $this.LeftPane }
    [UIElement] GetRightPane() { return $this.RightPane }
    
    # Focus management
    [void] FocusLeftPane() {
        if ($this.LeftPane -and $this.LeftPane.IsFocusable) {
            $this.LeftPane.Focus()
        }
    }
    
    [void] FocusRightPane() {
        if ($this.RightPane -and $this.RightPane.IsFocusable) {
            $this.RightPane.Focus()
        }
    }
}