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
    [bool]$IsFocusable = $false
    [bool]$IsFocused = $false
    [int]$TabIndex = 0
    
    # Hierarchy
    [UIElement]$Parent = $null
    [System.Collections.Generic.List[UIElement]]$Children
    
    # Caching for maximum speed
    hidden [string]$_renderCache = ""
    hidden [bool]$_cacheInvalid = $true
    
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
        if ($this._cacheInvalid) { return }  # Already invalid
        
        $this._cacheInvalid = $true
        $this.InvalidatePosition()  # Position might have changed too
        
        
        # Propagate up the tree
        if ($this.Parent) {
            $this.Parent.Invalidate()
        }
    }
    
    # Pre-compute position strings
    [void] InvalidatePosition() {
        # Pre-compute ANSI sequences for this element's position
        $this._cachedPosition = [VT]::MoveTo($this.X, $this.Y)
        
        # Pre-compute clear sequence for this element's area
        if ($this.Width -gt 0 -and $this.Height -gt 0) {
            $clearLine = " " * $this.Width
            $clearSeq = [System.Text.StringBuilder]::new()
            for ($i = 0; $i -lt $this.Height; $i++) {
                $clearSeq.Append([VT]::MoveTo($this.X, $this.Y + $i))
                $clearSeq.Append($clearLine)
            }
            $this._cachedClear = $clearSeq.ToString()
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
        $this.Invalidate()
    }
    
    [void] RemoveChild([UIElement]$child) {
        $child.Parent = $null
        $this.Children.Remove($child)
        $this.Invalidate()
    }
    
    # Focus management
    [void] Focus() {
        if (-not $this.IsFocusable) { return }
        
        # Unfocus currently focused element
        $root = $this.GetRoot()
        $focused = $root.FindFocused()
        if ($focused -and $focused -ne $this) {
            $focused.IsFocused = $false
            $focused.OnLostFocus()
            $focused.Invalidate()
        }
        
        $this.IsFocused = $true
        $this.OnGotFocus()
        $this.Invalidate()
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
    
    # Input handling
    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        # Base implementation does nothing
        return $false
    }
}