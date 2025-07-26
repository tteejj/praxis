# UIElement.ps1 - Fast base class for all UI components
# Inspired by AxiomPhoenix architecture but optimized for string-based rendering

class UIElement {
    # Position and dimensions
    [int]$X = 0
    [int]$Y = 0
    [int]$Width = 0
    [int]$Height = 0
    
    # Visibility and focus
    [bool]$Visible = $true
    [bool]$IsVisible = $true  # Some code may be checking IsVisible instead of Visible
    [bool]$IsFocusable = $false
    [bool]$IsFocused = $false
    [int]$TabIndex = 0
    
    # Hierarchy
    [UIElement]$Parent = $null
    [System.Collections.Generic.List[UIElement]]$Children
    
    # Service container for dependency injection
    hidden [ServiceContainer]$ServiceContainer
    
    # Caching for maximum speed
    hidden [string]$_renderCache = ""
    hidden [bool]$_cacheInvalid = $true
    hidden [bool]$_focusOnly = $false  # Lightweight focus-only update
    
    # Pre-computed values
    hidden [string]$_cachedPosition = ""
    hidden [string]$_cachedClear = ""
    
    UIElement() {
        $this.Children = [System.Collections.Generic.List[UIElement]]::new()
    }
    
    # Fast render - returns cached string if valid
    [string] Render() {
        if (-not $this.Visible) { return "" }
        
        if ($this._cacheInvalid) {
            # Rebuild cache only when needed
            $this._renderCache = $this.OnRender()
            $this._cacheInvalid = $false
        }
        
        return $this._renderCache
    }
    
    # Override in derived classes
    [string] OnRender() {
        return ""
    }
    
    # Mark this element (and parents) as needing re-render
    [void] Invalidate() {
        if ($this._cacheInvalid -and -not $this._focusOnly) { return }  # Already invalid
        
        $this._cacheInvalid = $true
        $this._focusOnly = $false
        $this.InvalidatePosition()  # Position might have changed too
        
        # Propagate up the tree
        if ($this.Parent) {
            $this.Parent.Invalidate()
        }
        
        # Render request is handled by propagation to root
    }
    
    # Lightweight invalidation for focus changes only
    [void] InvalidateFocusOnly() {
        if ($this._cacheInvalid -and -not $this._focusOnly) { return }
        
        $this._cacheInvalid = $true
        $this._focusOnly = $true
        
        # Propagate with focus-only flag
        if ($this.Parent -and $this.Parent._focusOnly) {
            $this.Parent.InvalidateFocusOnly()
        } elseif ($this.Parent) {
            $this.Parent.Invalidate()
        }
    }
    
    # Pre-compute position strings
    [void] InvalidatePosition() {
        # Pre-compute ANSI sequences for this element's position
        $this._cachedPosition = [VT]::MoveTo($this.X, $this.Y)
        
        # Pre-compute clear sequence for this element's area
        if ($this.Width -gt 0 -and $this.Height -gt 0) {
            $clearLine = [StringCache]::GetSpaces($this.Width)
            $clearSeq = Get-PooledStringBuilder ($this.Height * ($this.Width + 10))
            for ($i = 0; $i -lt $this.Height; $i++) {
                $clearSeq.Append([VT]::MoveTo($this.X, $this.Y + $i))
                $clearSeq.Append($clearLine)
            }
            $this._cachedClear = $clearSeq.ToString()
            Return-PooledStringBuilder $clearSeq
        } else {
            $this._cachedClear = ""
        }
    }
    
    # Layout management
    [void] SetBounds([int]$x, [int]$y, [int]$width, [int]$height) {
        if ($this.X -eq $x -and $this.Y -eq $y -and 
            $this.Width -eq $width -and $this.Height -eq $height) {
            return  # No change
        }
        
        $this.X = $x
        $this.Y = $y
        $this.Width = $width
        $this.Height = $height
        
        $this.InvalidatePosition()
        $this.Invalidate()
        $this.OnBoundsChanged()
    }
    
    # Override for custom layout logic
    [void] OnBoundsChanged() {
        # Base implementation does nothing
    }
    
    # Child management
    [void] AddChild([UIElement]$child) {
        $child.Parent = $this
        $this.Children.Add($child)

        # Initialize the child with the container's services.
        if ($this.ServiceContainer) {
            $child.Initialize($this.ServiceContainer)
        }

        $this.Invalidate()
    }
    
    [void] RemoveChild([UIElement]$child) {
        if ($child.IsFocusable -and $this.ServiceContainer) {
            $focusManager = $this.ServiceContainer.GetService('FocusManager')
            if ($focusManager) {
                $focusManager.UnregisterFocusable($child)
            }
        }
        $child.Parent = $null
        $this.Children.Remove($child)
        $this.Invalidate()
    }
    
    # Fast focus management using FocusManager
    [void] Focus() {
        $focusManager = $null
        if ($this.ServiceContainer) {
            $focusManager = $this.ServiceContainer.GetService('FocusManager')
        }
        
        if ($focusManager) {
            [void]$focusManager.SetFocus($this)
        } else {
            # Fallback for initialization phase
            $this.IsFocused = $true
            $this.OnGotFocus()
            $this.InvalidateFocusOnly()
        }
    }
    
    # Find focused element in tree
    [UIElement] FindFocusedElement([UIElement]$element) {
        if ($element.IsFocused) { return $element }
        foreach ($child in $element.Children) {
            $found = $this.FindFocusedElement($child)
            if ($found) { return $found }
        }
        return $null
    }
    
    [UIElement] GetRoot() {
        $current = $this
        while ($current.Parent) {
            $current = $current.Parent
        }
        return $current
    }
    
    [UIElement] FindFocused() {
        if ($this.IsFocused) { return $this }
        
        foreach ($child in $this.Children) {
            $focused = $child.FindFocused()
            if ($focused) { return $focused }
        }
        
        return $null
    }
    
    # Override for focus behavior
    [void] OnGotFocus() {}
    [void] OnLostFocus() {}
    
    # Initialize with service container
    [void] Initialize([ServiceContainer]$services) {
        if ($this.ServiceContainer) { return } # Already initialized

        $this.ServiceContainer = $services
        
        # Register with focus manager if focusable
        $focusManager = $services.GetService('FocusManager')
        if ($this.IsFocusable -and $focusManager) {
            $focusManager.RegisterFocusable($this)
        }
        
        # Recursively initialize children that might have been added before we had a service container
        foreach ($child in $this.Children) {
            $child.Initialize($services)
        }

        $this.OnInitialize()
    }
    
    # Override for custom initialization
    [void] OnInitialize() {}
    
    # Input handling
    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        # Base implementation does nothing
        return $false
    }
}