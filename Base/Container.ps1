# Container.ps1 - Base class for components that contain other components
# Optimized for fast string aggregation

class Container : UIElement {
    # Optional background
    [bool]$DrawBackground = $false
    hidden [string]$_cachedBackground = ""
    hidden [string]$_cachedBgColor = ""
    hidden [object]$Theme
    
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
                $childOutput = $child.Render()
                $sb.Append($childOutput)
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
        
        # For screens at position 0,0, ensure we fill the entire console
        $fillWidth = $this.Width
        $fillHeight = $this.Height
        if ($this.X -eq 0 -and $this.Y -eq 0 -and $this.GetType().BaseType.Name -eq 'Screen') {
            # This is likely a full-screen component
            try {
                $fillWidth = [Math]::Max($this.Width, [Console]::WindowWidth)
                $fillHeight = [Math]::Max($this.Height, [Console]::WindowHeight)
            } catch {
                # Fallback to component size if console size unavailable
                $fillWidth = $this.Width
                $fillHeight = $this.Height
            }
        }
        
        $sb = Get-PooledStringBuilder ($fillWidth * $fillHeight * 2)
        $line = [StringCache]::GetSpaces($fillWidth)
        
        for ($y = 0; $y -lt $fillHeight; $y++) {
            $sb.Append([VT]::MoveTo($this.X, $this.Y + $y))
            if ($this._cachedBgColor) {
                $sb.Append($this._cachedBgColor)
            }
            $sb.Append($line)
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
        # Route input to focused child
        
        # Handle Tab navigation first
        if ($key.Key -eq [System.ConsoleKey]::Tab) {
            
            $focusManager = $null
            if ($this.ServiceContainer) {
                $focusManager = $this.ServiceContainer.GetService('FocusManager')
            }
            
            if ($focusManager) {
                $result = $false
                if ($key.Modifiers -band [System.ConsoleModifiers]::Shift) {
                    $result = $focusManager.FocusPrevious($this)
                } else {
                    $result = $focusManager.FocusNext($this)
                }
                
                $this.Invalidate()
                return $true
            }
        }
        
        
        # Fast path: Use FocusManager to get current focus
        $focusManager = $null
        if ($this.ServiceContainer) {
            $focusManager = $this.ServiceContainer.GetService('FocusManager')
        }
        
        if ($focusManager) {
            
            $focused = $focusManager.GetFocused()
            $focusedType = if ($focused) { $focused.GetType().Name } else { 'null' }
            
            
            if ($focused -and $this.ContainsElement($focused)) {
                
                $result = $focused.HandleInput($key)
                
                
                return $result
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
                return $child
            }
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
        if ($global:Logger) {
            $global:Logger.Debug("Container.FocusFirst: Looking for focusable child in $($this.GetType().Name)")
        }
        
        # Try to use FocusManager for proper focus handling
        $focusManager = $null
        if ($this.ServiceContainer) {
            $focusManager = $this.ServiceContainer.GetService('FocusManager')
        }
        
        if ($focusManager) {
            # Use FocusManager to find and focus first focusable in tree
            $focusables = $focusManager.GetFocusableChildren($this)
            if ($focusables.Count -gt 0) {
                if ($global:Logger) {
                    $global:Logger.Debug("Container.FocusFirst: Found $($focusables.Count) focusables, focusing first: $($focusables[0].GetType().Name)")
                }
                [void]$focusManager.SetFocus($focusables[0])
            } else {
                if ($global:Logger) {
                    $global:Logger.Debug("Container.FocusFirst: No focusable children found in tree")
                }
            }
        } else {
            # Fallback to simple approach
            $focusable = $this.Children | Where-Object { $_.IsFocusable -and $_.Visible } | Select-Object -First 1
            if ($focusable) {
                if ($global:Logger) {
                    $global:Logger.Debug("Container.FocusFirst: Fallback - focusing $($focusable.GetType().Name)")
                }
                $focusable.Focus()
            } else {
                if ($global:Logger) {
                    $global:Logger.Debug("Container.FocusFirst: Fallback - no focusable children found")
                }
            }
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