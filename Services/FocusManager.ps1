using namespace System.Collections.Generic

class FocusManager {
    # Singleton focus management with O(1) focus lookups
    [UIElement] $CurrentFocused
    [HashSet[UIElement]] $FocusableElements
    [Queue[UIElement]] $FocusHistory
    [bool] $NavigationLocked
    [ThemeManager] $ThemeManager
    
    # Visual style settings
    [string] $FocusIndicatorStyle = 'minimal'  # minimal, border, glow
    [string] $CachedFocusPrefix
    [string] $CachedFocusSuffix
    
    FocusManager() {
        $this.FocusableElements = [HashSet[UIElement]]::new()
        $this.FocusHistory = [Queue[UIElement]]::new()
        $this.NavigationLocked = $false
    }
    
    [void] Initialize([ServiceContainer] $container) {
        $this.ThemeManager = $container.GetService('ThemeManager')
        $this.UpdateFocusStyle()
    }
    
    [void] UpdateFocusStyle() {
        # Pre-cache minimal focus indicators for speed
        $focusColor = $this.ThemeManager.GetColor('state.focused')
        
        switch ($this.FocusIndicatorStyle) {
            'minimal' {
                # Subtle underline for minimal look
                $this.CachedFocusPrefix = [VT]::Underline() + $focusColor
                $this.CachedFocusSuffix = [VT]::NoUnderline() 
            }
            'border' {
                # Clean border focus (will be rendered by components)
                $this.CachedFocusPrefix = $focusColor
                $this.CachedFocusSuffix = "" 
            }
            'glow' {
                # Bright background for high visibility
                $bgColor = $this.ThemeManager.GetColor('focus.background')
                $this.CachedFocusPrefix = $bgColor + $focusColor
                $this.CachedFocusSuffix = "" 
            }
        }
    }
    
    # Register a focusable element (O(1))
    [void] RegisterFocusable([UIElement] $element) {
        if ($element.IsFocusable) {
            [void]$this.FocusableElements.Add($element)
        }
    }
    
    # Unregister element (O(1))
    [void] UnregisterFocusable([UIElement] $element) {
        [void]$this.FocusableElements.Remove($element)
        if ($this.CurrentFocused -eq $element) {
            $this.CurrentFocused = $null
        }
    }
    
    # Set focus with O(1) performance
    [bool] SetFocus([UIElement] $element) {
        if ($this.NavigationLocked) { 
            return $false 
        }
        if (-not $element -or -not $element.IsFocusable) { 
            return $false 
        }
        if ($this.CurrentFocused -eq $element) { 
            return $true 
        }
        
        # Clear previous focus
        if ($this.CurrentFocused) {
            $this.CurrentFocused.IsFocused = $false
            $this.CurrentFocused.OnLostFocus()
            $this.CurrentFocused.InvalidateFocusOnly()
        }
        
        # Set new focus
        $this.CurrentFocused = $element
        $element.IsFocused = $true
        $element.OnGotFocus()
        $element.InvalidateFocusOnly()
        
        # Maintain history (keep last 10)
        $this.FocusHistory.Enqueue($element)
        if ($this.FocusHistory.Count -gt 10) {
            [void]$this.FocusHistory.Dequeue()
        }
        return $true
    }
    
    # Get currently focused element (O(1))
    [UIElement] GetFocused() {
        return $this.CurrentFocused
    }
    
    # Navigate to next focusable element
    [bool] FocusNext([UIElement] $container) {
        if ($this.NavigationLocked) { return $false }
        
        try {
            $focusables = $this.GetFocusableChildren($container)
        } catch {
            if ($global:Logger) {
                $global:Logger.Error("FocusManager.FocusNext: Error getting focusables: $_")
            }
            return $false
        }
        
        if ($focusables.Count -eq 0) { return $false }
        
        $currentIndex = -1
        if ($this.CurrentFocused) {
            for ($i = 0; $i -lt $focusables.Count; $i++) {
                if ($focusables[$i] -eq $this.CurrentFocused) {
                    $currentIndex = $i
                    break
                }
            }
        }
        
        $nextIndex = ($currentIndex + 1) % $focusables.Count
        return $this.SetFocus($focusables[$nextIndex])
    }
    
    # Navigate to previous focusable element
    [bool] FocusPrevious([UIElement] $container) {
        if ($this.NavigationLocked) { return $false }
        
        $focusables = $this.GetFocusableChildren($container)
        if ($focusables.Count -eq 0) { return $false }
        
        $currentIndex = -1
        if ($this.CurrentFocused) {
            for ($i = 0; $i -lt $focusables.Count; $i++) {
                if ($focusables[$i] -eq $this.CurrentFocused) {
                    $currentIndex = $i
                    break
                }
            }
        }
        
        $prevIndex = if ($currentIndex -le 0) { $focusables.Count - 1 } else { $currentIndex - 1 }
        return $this.SetFocus($focusables[$prevIndex])
    }
    
    # Get focusable children in tab order
    [List[UIElement]] GetFocusableChildren([UIElement] $container) {
        $result = [List[UIElement]]::new()
        $this.CollectFocusables($container, $result)
        # Return empty list if no focusables found
        if ($result.Count -eq 0) {
            return $result
        }
        
        # Sort by TabIndex if specified
        $sorted = $result | Sort-Object -Property @{
            Expression = { if ($_.TabIndex -ge 0) { $_.TabIndex } else { [int]::MaxValue } }
        }, @{
            Expression = { $result.IndexOf($_) }
        }
        # Handle null result from Sort-Object (happens when input is empty)
        if ($null -eq $sorted) {
            return [List[UIElement]]::new()
        }
        
        # Create new list and add sorted items one by one
        $finalList = [List[UIElement]]::new()
        foreach ($item in $sorted) {
            $finalList.Add($item)
        }
        return $finalList
    }
    
    [void] CollectFocusables([UIElement] $element, [List[UIElement]] $list) {
        if ($element.IsFocusable -and $element.IsVisible) {
            $list.Add($element)
        }
        
        if ($element -is [Container]) {
            $childIndex = 0
            foreach ($child in $element.Children) {
                $this.CollectFocusables($child, $list)
                $childIndex++
            }
        }
    }
    
    # Lock navigation during operations
    [void] LockNavigation() {
        $this.NavigationLocked = $true
    }
    
    [void] UnlockNavigation() {
        $this.NavigationLocked = $false
    }
    
    # Clear all focus
    [void] ClearFocus() {
        if ($this.CurrentFocused) {
            $this.CurrentFocused.IsFocused = $false
            $this.CurrentFocused.OnLostFocus()
            $this.CurrentFocused.InvalidateFocusOnly()
            $this.CurrentFocused = $null
        }
    }
    
    # Get focus style strings for rendering
    [string] GetFocusPrefix() { return $this.CachedFocusPrefix }
    [string] GetFocusSuffix() { return $this.CachedFocusSuffix }
}