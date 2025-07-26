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
        $focusColor = $this.ThemeManager.GetColor('focus')
        
        switch ($this.FocusIndicatorStyle) {
            'minimal' {
                # Subtle underline for minimal look
                $this.CachedFocusPrefix = [VT]::Underline() + $focusColor
                $this.CachedFocusSuffix = [VT]::NoUnderline() + [VT]::Reset()
            }
            'border' {
                # Clean border focus (will be rendered by components)
                $this.CachedFocusPrefix = $focusColor
                $this.CachedFocusSuffix = [VT]::Reset()
            }
            'glow' {
                # Bright background for high visibility
                $bgColor = $this.ThemeManager.GetColor('focus.background')
                $this.CachedFocusPrefix = $bgColor + $focusColor
                $this.CachedFocusSuffix = [VT]::Reset()
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
        if ($global:Logger) {
            $elementName = if ($element) { $element.GetType().Name } else { 'null' }
            $global:Logger.Debug("FocusManager.SetFocus: START - Element=$elementName")
        }
        
        if ($this.NavigationLocked) { 
            if ($global:Logger) {
                $global:Logger.Debug("FocusManager.SetFocus: NavigationLocked=true, returning false")
            }
            return $false 
        }
        if (-not $element -or -not $element.IsFocusable) { 
            if ($global:Logger) {
                $global:Logger.Debug("FocusManager.SetFocus: Element null or not focusable, returning false")
            }
            return $false 
        }
        if ($this.CurrentFocused -eq $element) { 
            if ($global:Logger) {
                $global:Logger.Debug("FocusManager.SetFocus: Element already focused, returning true")
            }
            return $true 
        }
        
        # Clear previous focus
        if ($this.CurrentFocused) {
            if ($global:Logger) {
                $global:Logger.Debug("FocusManager.SetFocus: Clearing focus from $($this.CurrentFocused.GetType().Name)")
            }
            $this.CurrentFocused.IsFocused = $false
            $this.CurrentFocused.OnLostFocus()
            $this.CurrentFocused.InvalidateFocusOnly()
        }
        
        # Set new focus
        if ($global:Logger) {
            $global:Logger.Debug("FocusManager.SetFocus: Setting focus to $($element.GetType().Name)")
        }
        $this.CurrentFocused = $element
        $element.IsFocused = $true
        $element.OnGotFocus()
        $element.InvalidateFocusOnly()
        
        # Maintain history (keep last 10)
        $this.FocusHistory.Enqueue($element)
        if ($this.FocusHistory.Count -gt 10) {
            [void]$this.FocusHistory.Dequeue()
        }
        
        if ($global:Logger) {
            $global:Logger.Debug("FocusManager.SetFocus: SUCCESS - Focus set to $($element.GetType().Name)")
        }
        return $true
    }
    
    # Get currently focused element (O(1))
    [UIElement] GetFocused() {
        return $this.CurrentFocused
    }
    
    # Navigate to next focusable element
    [bool] FocusNext([UIElement] $container) {
        if ($global:Logger) {
            $stackTrace = (Get-PSCallStack | Select-Object -Skip 1 -First 3 | ForEach-Object { "$($_.Command):$($_.ScriptLineNumber)" }) -join " <- "
            $global:Logger.Debug("FocusManager.FocusNext CALLED FROM: $stackTrace")
        }
        
        if ($this.NavigationLocked) { return $false }
        
        try {
            $focusables = $this.GetFocusableChildren($container)
            if ($global:Logger) {
                $global:Logger.Debug("FocusManager.FocusNext: Found $($focusables.Count) focusable elements")
                for ($i = 0; $i -lt $focusables.Count; $i++) {
                    $global:Logger.Debug("  [$i] $($focusables[$i].GetType().Name) TabIndex=$($focusables[$i].TabIndex)")
                }
            }
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
            if ($global:Logger) {
                $global:Logger.Debug("FocusManager.FocusNext: Current focused at index $currentIndex")
            }
        }
        
        $nextIndex = ($currentIndex + 1) % $focusables.Count
        if ($global:Logger) {
            $global:Logger.Debug("FocusManager.FocusNext: Moving focus from index $currentIndex to $nextIndex")
        }
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
        if ($global:Logger) {
            $global:Logger.Debug("FocusManager.GetFocusableChildren: START - Container=$($container.GetType().Name)")
        }
        
        $result = [List[UIElement]]::new()
        $this.CollectFocusables($container, $result)
        
        if ($global:Logger) {
            $global:Logger.Debug("FocusManager.GetFocusableChildren: After CollectFocusables - Found $($result.Count) items")
        }
        
        # Return empty list if no focusables found
        if ($result.Count -eq 0) {
            if ($global:Logger) {
                $global:Logger.Debug("FocusManager.GetFocusableChildren: No focusables found, returning empty list")
            }
            return $result
        }
        
        # Sort by TabIndex if specified
        $sorted = $result | Sort-Object -Property @{
            Expression = { if ($_.TabIndex -ge 0) { $_.TabIndex } else { [int]::MaxValue } }
        }, @{
            Expression = { $result.IndexOf($_) }
        }
        
        if ($global:Logger) {
            $global:Logger.Debug("FocusManager.GetFocusableChildren: After sort - sorted is null? $($null -eq $sorted)")
            $global:Logger.Debug("FocusManager.GetFocusableChildren: sorted type: $($sorted.GetType().FullName)")
        }
        
        # Handle null result from Sort-Object (happens when input is empty)
        if ($null -eq $sorted) {
            if ($global:Logger) {
                $global:Logger.Debug("FocusManager.GetFocusableChildren: Sort returned null, creating empty list")
            }
            return [List[UIElement]]::new()
        }
        
        # Create new list and add sorted items one by one
        $finalList = [List[UIElement]]::new()
        foreach ($item in $sorted) {
            $finalList.Add($item)
        }
        if ($global:Logger) {
            $global:Logger.Debug("FocusManager.GetFocusableChildren: DONE - Returning $($finalList.Count) focusable elements")
        }
        return $finalList
    }
    
    [void] CollectFocusables([UIElement] $element, [List[UIElement]] $list) {
        if ($global:Logger) {
            $global:Logger.Debug("FocusManager.CollectFocusables: START - Element=$($element.GetType().Name)")
            $global:Logger.Debug("  IsFocusable=$($element.IsFocusable)")
            $global:Logger.Debug("  IsVisible=$($element.IsVisible)")
            $global:Logger.Debug("  Visible=$($element.Visible)")
            $global:Logger.Debug("  Children.Count=$($element.Children.Count)")
            $global:Logger.Debug("  Is Container? $($element -is [Container])")
        }
        
        if ($element.IsFocusable -and $element.IsVisible) {
            $list.Add($element)
            if ($global:Logger) {
                $global:Logger.Debug("FocusManager.CollectFocusables: >>> ADDED $($element.GetType().Name) to list (now has $($list.Count) items)")
            }
        } else {
            if ($global:Logger) {
                $global:Logger.Debug("FocusManager.CollectFocusables: NOT ADDING - IsFocusable=$($element.IsFocusable) IsVisible=$($element.IsVisible)")
            }
        }
        
        if ($element -is [Container]) {
            if ($global:Logger) {
                $global:Logger.Debug("FocusManager.CollectFocusables: Processing $($element.Children.Count) children of $($element.GetType().Name)")
            }
            $childIndex = 0
            foreach ($child in $element.Children) {
                if ($global:Logger) {
                    $global:Logger.Debug("FocusManager.CollectFocusables: Processing child[$childIndex] = $($child.GetType().Name)")
                }
                $this.CollectFocusables($child, $list)
                $childIndex++
            }
        } else {
            if ($global:Logger) {
                $global:Logger.Debug("FocusManager.CollectFocusables: Not a container, skipping children")
            }
        }
        
        if ($global:Logger) {
            $global:Logger.Debug("FocusManager.CollectFocusables: END - Element=$($element.GetType().Name), List now has $($list.Count) items")
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