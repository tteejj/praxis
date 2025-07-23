# FocusManager.ps1 - High-performance focus management with scope support
# Based on AxiomPhoenix patterns with PRAXIS string-rendering optimizations

class FocusManager {
    hidden [System.WeakReference]$_focusedElementRef
    hidden [System.Collections.Generic.Stack[UIElement]]$_focusScopeStack
    hidden [hashtable]$_focusCache  # Scope hash -> focusable elements array
    
    FocusManager() {
        $this._focusScopeStack = [System.Collections.Generic.Stack[UIElement]]::new()
        $this._focusCache = @{}
    }
    
    # Main focus API
    [UIElement] GetFocusedElement() {
        if ($this._focusedElementRef -and $this._focusedElementRef.IsAlive) {
            return $this._focusedElementRef.Target
        }
        return $null
    }
    
    [void] SetFocus([UIElement]$element) {
        if (-not $element -or -not $element.IsFocusable -or -not $element.Visible) { 
            if ($global:Logger) {
                $elementName = if ($element) { $element.GetType().Name } else { "null" }
                $focusable = if ($element) { $element.IsFocusable } else { "N/A" }
                $visible = if ($element) { $element.Visible } else { "N/A" }
                $global:Logger.Debug("FocusManager: Cannot focus $elementName (focusable=$focusable, visible=$visible)")
            }
            return 
        }
        
        $current = $this.GetFocusedElement()
        if ($current -eq $element) { 
            if ($global:Logger) {
                $global:Logger.Debug("FocusManager: Element already has focus: $($element.GetType().Name)")
            }
            return 
        }
        
        # Blur current
        if ($current) {
            $current.IsFocused = $false
            $current.OnLostFocus()
            $current.Invalidate()
            if ($global:Logger) {
                $global:Logger.Debug("FocusManager: Blurred $($current.GetType().Name)")
            }
        }
        
        # Focus new
        $this._focusedElementRef = [System.WeakReference]::new($element)
        $element.IsFocused = $true
        $element.OnGotFocus()
        $element.Invalidate()
        
        if ($global:Logger) {
            $global:Logger.Debug("FocusManager: Focused $($element.GetType().Name)")
        }
    }
    
    [void] ClearFocus() {
        $current = $this.GetFocusedElement()
        if ($current) {
            $current.IsFocused = $false
            $current.OnLostFocus()
            $current.Invalidate()
            $this._focusedElementRef = $null
            
            if ($global:Logger) {
                $global:Logger.Debug("FocusManager: Cleared focus from $($current.GetType().Name)")
            }
        }
    }
    
    # Tab navigation (replaces all per-screen FocusNext methods)
    [void] FocusNext() { 
        if ($global:Logger) {
            $global:Logger.Debug("FocusManager.FocusNext: Called")
        }
        $this._MoveFocus($false) 
    }
    [void] FocusPrevious() { 
        if ($global:Logger) {
            $global:Logger.Debug("FocusManager.FocusPrevious: Called")
        }
        $this._MoveFocus($true) 
    }
    
    # Scope management for screens/dialogs
    [void] PushFocusScope([UIElement]$scope) {
        $this._focusScopeStack.Push($scope)
        $this.InvalidateFocusCache($scope)
        
        if ($global:Logger) {
            $global:Logger.Debug("FocusManager: Pushed focus scope: $($scope.GetType().Name)")
        }
        
        # Focus first focusable element in new scope
        $this.FocusFirstInCurrentScope()
    }
    
    [void] PopFocusScope() {
        if ($this._focusScopeStack.Count -gt 0) {
            $popped = $this._focusScopeStack.Pop()
            $this.InvalidateFocusCache($popped)
            
            if ($global:Logger) {
                $global:Logger.Debug("FocusManager: Popped focus scope: $($popped.GetType().Name)")
            }
            
            # Focus first element in previous scope if any
            if ($this._focusScopeStack.Count -gt 0) {
                $this.FocusFirstInCurrentScope()
            } else {
                $this.ClearFocus()
            }
        }
    }
    
    [void] FocusFirstInCurrentScope() {
        if ($this._focusScopeStack.Count -eq 0) { return }
        
        $currentScope = $this._focusScopeStack.Peek()
        $focusable = $this._GetFocusableElements($currentScope)
        
        if ($focusable.Count -gt 0) {
            $this.SetFocus($focusable[0])
        }
    }
    
    [void] InvalidateFocusCache([UIElement]$scope) {
        $scopeHash = $scope.GetHashCode()
        if ($this._focusCache.ContainsKey($scopeHash)) {
            $this._focusCache.Remove($scopeHash)
            if ($global:Logger) {
                $global:Logger.Debug("FocusManager: Invalidated focus cache for $($scope.GetType().Name)")
            }
        }
    }
    
    # Performance-critical focus movement
    hidden [void] _MoveFocus([bool]$reverse) {
        if ($this._focusScopeStack.Count -eq 0) { 
            if ($global:Logger) {
                $global:Logger.Debug("FocusManager: No focus scope available for tab navigation")
            }
            return 
        }
        
        $currentScope = $this._focusScopeStack.Peek()
        $focusable = $this._GetFocusableElements($currentScope)
        
        # Simplified focus debug logging
        
        if ($focusable.Count -eq 0) { 
            if ($global:Logger) {
                $global:Logger.Debug("FocusManager: No focusable elements in current scope")
            }
            return 
        }
        
        $currentFocused = $this.GetFocusedElement()
        $currentIndex = if ($currentFocused) { [array]::IndexOf($focusable, $currentFocused) } else { -1 }
        
        $nextIndex = if ($currentIndex -eq -1) { 
            0 
        } else { 
            $currentIndex + (if ($reverse) { -1 } else { 1 })
        }
        
        # Wrap around
        if ($nextIndex -ge $focusable.Count) { $nextIndex = 0 }
        if ($nextIndex -lt 0) { $nextIndex = $focusable.Count - 1 }
        
        # Focus move debug logging simplified
        
        $this.SetFocus($focusable[$nextIndex])
    }
    
    # Cached focusable element collection (performance critical)
    hidden [UIElement[]] _GetFocusableElements([UIElement]$scope) {
        $scopeHash = $scope.GetHashCode()
        
        # Return cached if valid
        if ($this._focusCache.ContainsKey($scopeHash)) {
            return $this._focusCache[$scopeHash]
        }
        
        if ($global:Logger) {
            $childCount = if ($scope.Children) { $scope.Children.Count } else { 0 }
            $global:Logger.Debug("FocusManager: Building focus cache for $($scope.GetType().Name) with $childCount children")
        }
        
        # Build new cache using breadth-first search
        $focusable = [System.Collections.Generic.List[UIElement]]::new()
        $queue = [System.Collections.Queue]::new($scope.Children)
        
        while ($queue.Count -gt 0) {
            $current = $queue.Dequeue()
            
            if ($current.Visible) {
                if ($current.IsFocusable) {
                    $focusable.Add($current)
                }
                
                # Add children to queue
                foreach ($child in $current.Children) {
                    $queue.Enqueue($child)
                }
            }
        }
        
        # Sort by TabIndex, then Y, then X for predictable order
        $sorted = $focusable | Sort-Object TabIndex, Y, X
        
        # Cache result
        $this._focusCache[$scopeHash] = $sorted
        
        if ($global:Logger) {
            $elementList = if ($sorted.Count -gt 0) { 
                ($sorted | ForEach-Object { $_.GetType().Name }) -join ", " 
            } else { 
                "none" 
            }
            $global:Logger.Debug("FocusManager: Cached $($sorted.Count) focusable elements for $($scope.GetType().Name): $elementList")
        }
        
        return $sorted
    }
    
    # Debug helpers
    [string] GetCurrentScope() {
        if ($this._focusScopeStack.Count -eq 0) { return "No scope" }
        $scope = $this._focusScopeStack.Peek()
        return $scope.GetType().Name
    }
    
    [int] GetFocusableCount() {
        if ($this._focusScopeStack.Count -eq 0) { return 0 }
        $scope = $this._focusScopeStack.Peek()
        $focusable = $this._GetFocusableElements($scope)
        return $focusable.Count
    }
}