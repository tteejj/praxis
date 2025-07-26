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
    # PARENT-DELEGATED INPUT MODEL with FocusManager optimization
    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        # Handle Tab navigation first
        if ($key.Key -eq [System.ConsoleKey]::Tab) {
            if ($global:Logger) {
                $global:Logger.Debug("Container.HandleInput: Tab key pressed in $($this.GetType().Name)")
            }
            
            $focusManager = $null
            if ($this.ServiceContainer) {
                $focusManager = $this.ServiceContainer.GetService('FocusManager')
            }
            
            if ($focusManager) {
                if ($global:Logger) {
                    $global:Logger.Debug("Container: Using FocusManager for Tab navigation")
                    $global:Logger.Debug("Container: Passing container=$($this.GetType().Name) with $($this.Children.Count) children")
                }
                
                $result = $false
                if ($key.Modifiers -band [System.ConsoleModifiers]::Shift) {
                    $result = $focusManager.FocusPrevious($this)
                } else {
                    $result = $focusManager.FocusNext($this)
                }
                
                if ($global:Logger) {
                    $global:Logger.Debug("Container: FocusManager.FocusNext/Previous returned: $result")
                }
                
                $this.Invalidate()
                return $true
            } else {
                if ($global:Logger) {
                    $global:Logger.Warning("Container: No FocusManager available for Tab handling!")
                }
            }
        }
        
        # Fast path: Use FocusManager to get current focus
        $focusManager = $null
        if ($this.ServiceContainer) {
            $focusManager = $this.ServiceContainer.GetService('FocusManager')
        }
        
        if ($focusManager) {
            $focused = $focusManager.GetFocused()
            if ($focused -and $this.ContainsElement($focused)) {
                return $focused.HandleInput($key)
            }
        }
        
        # Fallback to traditional search
        $focused = $this.FindFocusedChild()
        if ($focused) {
            return $focused.HandleInput($key)
        }
        
        return $false
    }
    
    # Check if this container contains the given element
    [bool] ContainsElement([UIElement]$element) {
        $current = $element
        while ($current) {
            if ($current.Parent -eq $this) { return $true }
            $current = $current.Parent
        }
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
    
    # Fast focus navigation using FocusManager
    [void] FocusNextChild([UIElement]$currentChild) {
        $focusManager = $null
        if ($this.ServiceContainer) {
            $focusManager = $this.ServiceContainer.GetService('FocusManager')
        }
        
        if ($focusManager) {
            [void]$focusManager.FocusNext($this)
        } else {
            # Fallback for initialization
            $this.FocusFirstInTree()
        }
    }
    
    [void] FocusPreviousChild([UIElement]$currentChild) {
        $focusManager = $null
        if ($this.ServiceContainer) {
            $focusManager = $this.ServiceContainer.GetService('FocusManager')
        }
        
        if ($focusManager) {
            [void]$focusManager.FocusPrevious($this)
        } else {
            # Fallback for initialization
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
        $focusManager = $null
        if ($this.ServiceContainer) {
            $focusManager = $this.ServiceContainer.GetService('FocusManager')
        }
        
        if ($focusManager) {
            $focusables = $focusManager.GetFocusableChildren($this)
            if ($focusables.Count -gt 0) {
                [void]$focusManager.SetFocus($focusables[0])
            }
        } else {
            # Fallback
            $focusable = $this.Children | Where-Object { $_.IsFocusable -and $_.Visible } | Select-Object -First 1
            if ($focusable) {
                $focusable.Focus()
            }
        }
    }
    
    # Focus last focusable element in the entire tree
    [void] FocusLastInTree() {
        $focusManager = $null
        if ($this.ServiceContainer) {
            $focusManager = $this.ServiceContainer.GetService('FocusManager')
        }
        
        if ($focusManager) {
            $focusables = $focusManager.GetFocusableChildren($this)
            if ($focusables.Count -gt 0) {
                [void]$focusManager.SetFocus($focusables[$focusables.Count - 1])
            }
        } else {
            # Fallback - check children in reverse
            for ($i = $this.Children.Count - 1; $i -ge 0; $i--) {
                $child = $this.Children[$i]
                if ($child.Visible -and $child.IsFocusable) {
                    $child.Focus()
                    return
                }
            }
        }
    }
}