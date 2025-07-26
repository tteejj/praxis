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
    
    # Efficient child rendering with string builder
    [string] OnRender() {
        $sb = Get-PooledStringBuilder 1024
        
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
        
        $result = $sb.ToString()
        Return-PooledStringBuilder $sb
        return $result
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
        
        $sb = Get-PooledStringBuilder ($this.Width * $this.Height * 2)
        $line = [StringCache]::GetSpaces($this.Width)
        
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
        Return-PooledStringBuilder $sb
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
    # PARENT-DELEGATED INPUT MODEL
    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        # Debug logging removed for performance
        
        # Simple rule: Let focused child handle first
        $focused = $this.FindFocusedChild()
        if ($focused) {
            if ($global:Logger) {
                $global:Logger.Debug("Container: Routing to focused child $($focused.GetType().Name)")
            }
            return $focused.HandleInput($key)
        }
        
        # No focused child
        return $false
    }
    
    # Find direct focused child (not deep search)
    [UIElement] FindFocusedChild() {
        foreach ($child in $this.Children) {
            if ($child.Visible -and $child.IsFocused) {
                if ($global:Logger) {
                    $global:Logger.Debug("Container.FindFocusedChild: Found focused child $($child.GetType().Name)")
                }
                return $child
            }
        }
        if ($global:Logger) {
            $global:Logger.Debug("Container.FindFocusedChild: No focused child found among $($this.Children.Count) children")
        }
        return $null
    }
    
    # Parent-delegated focus navigation
    [void] FocusNextChild([UIElement]$currentChild) {
        if ($global:Logger) {
            $global:Logger.Debug("Container.FocusNextChild: Type=$($this.GetType().Name), CurrentChild=$($currentChild.GetType().Name)")
        }
        
        # For containers, we need to consider both focusable children AND containers
        $allChildren = $this.Children | Where-Object { $_.Visible }
        $currentIndex = -1
        
        # Find current child index
        for ($i = 0; $i -lt $allChildren.Count; $i++) {
            if ($allChildren[$i] -eq $currentChild) {
                $currentIndex = $i
                break
            }
        }
        
        if ($currentIndex -eq -1) {
            # Current child not found, shouldn't happen
            return
        }
        
        # Look for next child that either is focusable or contains focusable elements
        for ($i = $currentIndex + 1; $i -lt $allChildren.Count; $i++) {
            $child = $allChildren[$i]
            if ($child.IsFocusable) {
                $child.Focus()
                return
            } elseif ($child -is [Container]) {
                # Try to focus first element in this container
                $child.FocusFirstInTree()
                if ($this.GetRoot().FindFocused()) {
                    return  # Focus was set
                }
            }
        }
        
        # No next child found, bubble up or wrap
        if ($this.Parent) {
            $this.Parent.FocusNextChild($this)
        } else {
            # We're at root, wrap to beginning
            $this.FocusFirstInTree()
        }
    }
    
    [void] FocusPreviousChild([UIElement]$currentChild) {
        if ($global:Logger) {
            $global:Logger.Debug("Container.FocusPreviousChild: Type=$($this.GetType().Name), CurrentChild=$($currentChild.GetType().Name)")
        }
        
        # For containers, we need to consider both focusable children AND containers
        $allChildren = $this.Children | Where-Object { $_.Visible }
        $currentIndex = -1
        
        # Find current child index
        for ($i = 0; $i -lt $allChildren.Count; $i++) {
            if ($allChildren[$i] -eq $currentChild) {
                $currentIndex = $i
                break
            }
        }
        
        if ($currentIndex -eq -1) {
            # Current child not found, shouldn't happen
            return
        }
        
        # Look for previous child that either is focusable or contains focusable elements
        for ($i = $currentIndex - 1; $i -ge 0; $i--) {
            $child = $allChildren[$i]
            if ($child.IsFocusable) {
                $child.Focus()
                return
            } elseif ($child -is [Container]) {
                # Try to focus last element in this container
                $child.FocusLastInTree()
                if ($this.GetRoot().FindFocused()) {
                    return  # Focus was set
                }
            }
        }
        
        # No previous child found, bubble up or wrap
        if ($this.Parent) {
            $this.Parent.FocusPreviousChild($this)
        } else {
            # We're at root, wrap to end
            $this.FocusLastInTree()
        }
    }
    
    # Focus first focusable child
    [void] FocusFirst() {
        $focusable = $this.Children | Where-Object { $_.IsFocusable -and $_.Visible } | Select-Object -First 1
        if ($focusable) {
            $focusable.Focus()
        }
    }
    
    # Focus first focusable element in the entire tree
    [void] FocusFirstInTree() {
        # First check if any direct children are focusable
        $focusable = $this.Children | Where-Object { $_.IsFocusable -and $_.Visible } | Select-Object -First 1
        if ($focusable) {
            $focusable.Focus()
            return
        }
        
        # Otherwise check children's children
        foreach ($child in $this.Children) {
            if ($child -is [Container] -and $child.Visible) {
                $child.FocusFirstInTree()
                # If focus was set, we're done
                $root = $this.GetRoot()
                if ($root.FindFocused()) {
                    return
                }
            }
        }
    }
    
    # Focus last focusable element in the entire tree
    [void] FocusLastInTree() {
        # Check children in reverse order
        for ($i = $this.Children.Count - 1; $i -ge 0; $i--) {
            $child = $this.Children[$i]
            if ($child.Visible) {
                if ($child -is [Container]) {
                    # Recurse into container
                    $child.FocusLastInTree()
                    # If focus was set, we're done
                    $root = $this.GetRoot()
                    if ($root.FindFocused()) {
                        return
                    }
                } elseif ($child.IsFocusable) {
                    $child.Focus()
                    return
                }
            }
        }
    }
}