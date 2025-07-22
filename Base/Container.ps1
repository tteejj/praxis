# Container.ps1 - Base class for components that contain other components
# Optimized for fast string aggregation

class Container : UIElement {
    # Optional background
    [bool]$DrawBackground = $false
    hidden [string]$_cachedBackground = ""
    hidden [string]$_cachedBgColor = ""
    hidden [ThemeManager]$Theme
    
    Container() : base() {
    }
    
    # Initialize method for containers that need it
    [void] Initialize([ServiceContainer]$services) {
        # Get theme service if available
        try {
            $this.Theme = $services.GetService("ThemeManager")
        } catch {
            # Theme not available yet, ignore
        }
        
        # Derived classes can override for additional initialization
    }
    
    # Efficient child rendering with string builder
    [string] OnRender() {
        $sb = [System.Text.StringBuilder]::new()
        
        # Draw background if enabled
        if ($this.DrawBackground -and $this._cachedBackground) {
            $sb.Append($this._cachedBackground)
        }
        
        # Render all visible children
        foreach ($child in $this.Children) {
            if ($child.Visible) {
                $sb.Append($child.Render())
            }
        }
        
        return $sb.ToString()
    }
    
    # Pre-compute background
    [void] SetBackgroundColor([string]$ansiColor) {
        $this._cachedBgColor = $ansiColor
        $this.InvalidateBackground()
    }
    
    [void] InvalidateBackground() {
        if (-not $this.DrawBackground -or $this.Width -le 0 -or $this.Height -le 0) { 
            $this._cachedBackground = ""
            return 
        }
        
        $sb = [System.Text.StringBuilder]::new()
        $line = " " * $this.Width
        
        for ($y = 0; $y -lt $this.Height; $y++) {
            $sb.Append([VT]::MoveTo($this.X, $this.Y + $y))
            if ($this._cachedBgColor) {
                $sb.Append($this._cachedBgColor)
            }
            $sb.Append($line)
        }
        
        if ($this._cachedBgColor) {
            $sb.Append([VT]::Reset())
        }
        
        $this._cachedBackground = $sb.ToString()
    }
    
    [void] OnBoundsChanged() {
        # Recalculate background when size changes
        if ($this.DrawBackground) {
            $this.InvalidateBackground()
        }
        
        # Let derived classes handle child layout
        $this.LayoutChildren()
    }
    
    # Override in derived classes for custom layouts
    [void] LayoutChildren() {
        # Base implementation does nothing
        # Derived classes like HorizontalSplit, VerticalSplit, etc. will implement
    }
    
    # Find child at specific coordinates
    [UIElement] HitTest([int]$x, [int]$y) {
        # Check if point is within our bounds
        if ($x -lt $this.X -or $x -ge ($this.X + $this.Width) -or
            $y -lt $this.Y -or $y -ge ($this.Y + $this.Height)) {
            return $null
        }
        
        # Check children in reverse order (top to bottom)
        for ($i = $this.Children.Count - 1; $i -ge 0; $i--) {
            $child = $this.Children[$i]
            if ($child.Visible) {
                $hit = if ($child -is [Container]) {
                    $child.HitTest($x, $y)
                } else {
                    # Non-containers do simple bounds check
                    if ($x -ge $child.X -and $x -lt ($child.X + $child.Width) -and
                        $y -ge $child.Y -and $y -lt ($child.Y + $child.Height)) {
                        $child
                    } else {
                        $null
                    }
                }
                
                if ($hit) { return $hit }
            }
        }
        
        # No child hit, return self
        return $this
    }
    
    # Route input to focused child
    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        if ($global:Logger) {
            $global:Logger.Debug("Container.HandleInput: Key=$($key.Key) Char='$($key.KeyChar)' Type=$($this.GetType().Name)")
        }
        
        # First try focused child
        $focused = $this.FindFocused()
        if ($global:Logger -and $focused) {
            $global:Logger.Debug("Container: Focused child is $($focused.GetType().Name)")
        }
        
        if ($focused -and $focused -ne $this) {
            if ($focused.HandleInput($key)) {
                if ($global:Logger) {
                    $global:Logger.Debug("Container: Input handled by focused child")
                }
                return $true
            }
        }
        
        # If no child is focused but we have children, try the first focusable one
        if (-not $focused -and $this.Children.Count -gt 0) {
            if ($global:Logger) {
                $global:Logger.Debug("Container: No focused child, trying to focus first focusable")
            }
            foreach ($child in $this.Children) {
                if ($child.IsFocusable -and $child.Visible) {
                    $child.Focus()
                    if ($child.HandleInput($key)) {
                        return $true
                    }
                }
            }
        }
        
        # Then handle at this level
        return $false
    }
}