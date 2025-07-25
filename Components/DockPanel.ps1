# DockPanel.ps1 - Dock-based layout container
# Allows children to be docked to Top, Bottom, Left, Right, or Fill remaining space

enum DockPosition {
    Top
    Bottom
    Left
    Right
    Fill
}

class DockPanel : Container {
    [bool]$LastChildFill = $true
    [int]$DockSpacing = 0
    
    # Layout caching for performance
    hidden [bool]$_layoutInvalid = $true
    hidden [int]$_lastWidth = 0
    hidden [int]$_lastHeight = 0
    hidden [int]$_lastChildCount = 0
    
    # Available content area after docking
    hidden [int]$_contentX = 0
    hidden [int]$_contentY = 0  
    hidden [int]$_contentWidth = 0
    hidden [int]$_contentHeight = 0
    
    DockPanel() : base() {
        # DockPanel manages its own layout
    }
    
    [void] SetChildDock([UIElement]$child, [DockPosition]$position) {
        # Add custom property to track dock position
        $child | Add-Member -MemberType NoteProperty -Name "DockPosition" -Value $position -Force
        $this.InvalidateLayout()
    }
    
    [void] SetChildHeight([UIElement]$child, [int]$height) {
        # Add custom property to track fixed height
        $child | Add-Member -MemberType NoteProperty -Name "FixedHeight" -Value $height -Force
        $child.Height = $height
        $this.InvalidateLayout()
    }
    
    [void] SetChildWidth([UIElement]$child, [int]$width) {
        # Add custom property to track fixed width
        $child | Add-Member -MemberType NoteProperty -Name "FixedWidth" -Value $width -Force
        $child.Width = $width
        $this.InvalidateLayout()
    }
    
    [DockPosition] GetChildDock([UIElement]$child) {
        if ($child.PSObject.Properties["DockPosition"]) {
            return $child.DockPosition
        }
        return [DockPosition]::Fill
    }
    
    [void] InvalidateLayout() {
        $this._layoutInvalid = $true
        $this.Invalidate()
    }
    
    [void] OnBoundsChanged() {
        $this.InvalidateLayout()
        ([Container]$this).OnBoundsChanged()
    }
    
    [void] AddChild([UIElement]$child) {
        ([Container]$this).AddChild($child)
        $this.InvalidateLayout()
    }
    
    [void] RemoveChild([UIElement]$child) {
        ([Container]$this).RemoveChild($child)
        $this.InvalidateLayout()
    }
    
    [void] UpdateLayout() {
        # Check if layout needs updating
        if (-not $this._layoutInvalid -and 
            $this.Width -eq $this._lastWidth -and 
            $this.Height -eq $this._lastHeight -and 
            $this.Children.Count -eq $this._lastChildCount) {
            return
        }
        
        if ($global:Logger) {
            $global:Logger.Debug("DockPanel.UpdateLayout: Recalculating layout for $($this.Children.Count) children")
        }
        
        # Initialize available area (full container minus any padding)
        $availableX = $this.X
        $availableY = $this.Y
        $availableWidth = $this.Width
        $availableHeight = $this.Height
        
        # Group children by dock position
        $topChildren = @()
        $bottomChildren = @()
        $leftChildren = @()
        $rightChildren = @()
        $fillChild = $null
        
        foreach ($child in $this.Children) {
            if (-not $child.Visible) { continue }
            
            $dock = $this.GetChildDock($child)
            switch ($dock) {
                ([DockPosition]::Top) { $topChildren += $child }
                ([DockPosition]::Bottom) { $bottomChildren += $child }
                ([DockPosition]::Left) { $leftChildren += $child }
                ([DockPosition]::Right) { $rightChildren += $child }
                ([DockPosition]::Fill) { $fillChild = $child }
            }
        }
        
        # Process docked children in order: Top, Bottom, Left, Right
        
        # Top docked children
        foreach ($child in $topChildren) {
            $childHeight = if ($child.PSObject.Properties["FixedHeight"]) { $child.FixedHeight } else { $child.Height }
            $child.SetBounds($availableX, $availableY, $availableWidth, $childHeight)
            $availableY += $childHeight + $this.DockSpacing
            $availableHeight -= $childHeight + $this.DockSpacing
        }
        
        # Bottom docked children
        foreach ($child in $bottomChildren) {
            $childHeight = if ($child.PSObject.Properties["FixedHeight"]) { $child.FixedHeight } else { $child.Height }
            $childY = $availableY + $availableHeight - $childHeight
            $child.SetBounds($availableX, $childY, $availableWidth, $childHeight)
            $availableHeight -= $childHeight + $this.DockSpacing
        }
        
        # Left docked children  
        foreach ($child in $leftChildren) {
            $childWidth = if ($child.PSObject.Properties["FixedWidth"]) { $child.FixedWidth } else { $child.Width }
            $child.SetBounds($availableX, $availableY, $childWidth, $availableHeight)
            $availableX += $childWidth + $this.DockSpacing
            $availableWidth -= $childWidth + $this.DockSpacing
        }
        
        # Right docked children
        foreach ($child in $rightChildren) {
            $childWidth = if ($child.PSObject.Properties["FixedWidth"]) { $child.FixedWidth } else { $child.Width }
            $childX = $availableX + $availableWidth - $childWidth
            $child.SetBounds($childX, $availableY, $childWidth, $availableHeight)
            $availableWidth -= $childWidth + $this.DockSpacing
        }
        
        # Fill remaining space with fill child (if LastChildFill is enabled and we have one)
        if ($this.LastChildFill -and $fillChild) {
            # Ensure minimum size
            $fillWidth = [Math]::Max(0, $availableWidth)
            $fillHeight = [Math]::Max(0, $availableHeight)
            $fillChild.SetBounds($availableX, $availableY, $fillWidth, $fillHeight)
        }
        
        # Cache current state
        $this._contentX = $availableX
        $this._contentY = $availableY
        $this._contentWidth = $availableWidth
        $this._contentHeight = $availableHeight
        $this._lastWidth = $this.Width
        $this._lastHeight = $this.Height
        $this._lastChildCount = $this.Children.Count
        $this._layoutInvalid = $false
        
        if ($global:Logger) {
            $global:Logger.Debug("DockPanel.UpdateLayout: Layout complete. Content area: ($availableX,$availableY) ${availableWidth}x$availableHeight")
        }
    }
    
    [string] OnRender() {
        # Update layout before rendering
        $this.UpdateLayout()
        
        # Use fast string-based rendering - render all visible children
        $sb = Get-PooledStringBuilder 2048
        
        foreach ($child in $this.Children) {
            if ($child.Visible) {
                $sb.Append($child.Render())
            }
        }
        
        $result = $sb.ToString()
        Return-PooledStringBuilder $sb
        return $result
    }
    
    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        # Route input to focused child first
        foreach ($child in $this.Children) {
            if ($child.IsFocused -and $child.HandleInput($key)) {
                return $true
            }
        }
        
        # Let base Container handle other input (Tab navigation, etc.)
        return ([Container]$this).HandleInput($key)
    }
    
    # Helper methods
    [hashtable] GetContentArea() {
        $this.UpdateLayout()
        return @{
            X = $this._contentX
            Y = $this._contentY
            Width = $this._contentWidth
            Height = $this._contentHeight
        }
    }
    
    # Convenience methods for setting dock positions
    [void] DockTop([UIElement]$child) { $this.SetChildDock($child, [DockPosition]::Top) }
    [void] DockBottom([UIElement]$child) { $this.SetChildDock($child, [DockPosition]::Bottom) }
    [void] DockLeft([UIElement]$child) { $this.SetChildDock($child, [DockPosition]::Left) }
    [void] DockRight([UIElement]$child) { $this.SetChildDock($child, [DockPosition]::Right) }
    [void] DockFill([UIElement]$child) { $this.SetChildDock($child, [DockPosition]::Fill) }
}