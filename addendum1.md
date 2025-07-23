  The current implementation feels like it's fighting PowerShell's natural patterns
  rather than working with them. The errors suggest fundamental issues with object
  context and method resolution that may be inherent to the service-based approach.

> Speed is king AND working WITH powershell are the new mantras of this project. if
  the now current system is fine in theory but terrible in practice, then yes we need
   to change. if we do it per screen, can we standardize somewhat? or is a hybrid
  part global/part per screen local approach worthwhile? your simpler alternative
  needs an explanation. i dont know what it's doing in comparison to the current or
  past.

● Analysis: Current vs Past vs Proposed

  Current System (Service-Based) - BROKEN

  # Input Flow:
  User Input → ScreenManager → ShortcutManager.HandleInput() →
    Scriptblock with wrong $this context → CRASH

  # Focus Flow:
  Screen.OnActivated() → FocusManager.PushFocusScope() →
    Complex caching/scope management → Often fails to focus anything

  # Problems:
  - Scriptblock context loss ($this refers to ShortcutManager, not Screen)
  - Over-engineered focus management with WeakReferences and caches
  - Services not available when needed
  - Fighting PowerShell's natural object model

  Past System (Per-Screen) - WORKED BUT DUPLICATED

  # Each screen had:
  [void] BindKey([ConsoleKey]$key, [scriptblock]$action) {
      $this._keyBindings[$key] = $action
  }

  [bool] HandleInput([ConsoleKeyInfo]$key) {
      if ($this._keyBindings.ContainsKey($key.Key)) {
          & $this._keyBindings[$key.Key]  # $this context preserved!
          return $true
      }
      return $false
  }

  [void] FocusNext() {
      $focusable = $this.Children | Where-Object { $_.IsFocusable }
      # Simple array iteration
  }

  # Problems:
  - ~390 lines of duplicated FocusNext() methods
  - No global shortcuts (/ for command palette)
  - Code repetition across screens

  Proposed Hybrid - BEST OF BOTH WORLDS

  # Global shortcuts handled in ScreenManager (works with PowerShell)
  if ($key.KeyChar -eq '/' -or $key.KeyChar -eq ':') {
      $this.ShowCommandPalette()
      return $true
  }
  if ($key.Key -eq [ConsoleKey]::Tab) {
      $this._activeScreen.FocusNext()  # Delegate to screen
      return $true
  }

  # Screen-specific shortcuts stay local (preserves $this context)
  class TaskScreen : Screen {
      [bool] HandleInput([ConsoleKeyInfo]$key) {
          switch ($key.KeyChar) {
              'n' { $this.NewTask(); return $true }      # $this = TaskScreen ✓
              'e' { $this.EditTask(); return $true }     # Works perfectly
              'delete' { $this.DeleteTask(); return $true }
          }
          return ([Screen]$this).HandleInput($key)  # Chain to base
      }

      [void] FocusNext() {
          # One shared implementation in Screen base class
          # No caching, no WeakReferences, no scope stacks
          $focusable = $this.GetFocusableDescendants()
          $current = $this.FindFocused()
          $next = $this.GetNextFocusable($current, $focusable)
          $next.Focus()
      }
  }

  Why This Hybrid Approach Works

  1. Works WITH PowerShell

  - No scriptblock context loss
  - Natural method calls ($this.EditTask() just works)
  - No service container dependencies in hot paths
  - Simple object-oriented method dispatch

  2. Speed Optimized

  - Direct method calls (no service lookups)
  - No complex caching or WeakReferences
  - No stack management overhead
  - Minimal allocations in input loop

  3. Standardization Without Duplication

  # Base Screen provides common functionality:
  class Screen : Container {
      [bool] HandleInput([ConsoleKeyInfo]$key) {
          # Common keys handled here
          if ($key.Key -eq [ConsoleKey]::Escape) {
              $this.HandleEscape()
              return $true
          }

          # Let derived screen handle specific keys
          return ([Container]$this).HandleInput($key)
      }

      [void] FocusNext() {
          # ONE implementation shared by all screens
          # Simple, fast, reliable
      }

      [virtual void] HandleEscape() {
          # Default: close dialog or quit app
      }
  }

  4. Clear Separation of Concerns

  - ScreenManager: Global shortcuts (/, :, Ctrl+Q)
  - Screen classes: Screen-specific shortcuts (n, e, d)
  - Base Screen: Common functionality (Tab, Escape)
  - Components: Component-specific input (text entry)

  Implementation Strategy

  Phase 1: Fix Global Shortcuts

  # In ScreenManager.Run():
  if ($key.KeyChar -eq '/') {
      $this.GetActiveScreen().ShowCommandPalette()
      continue
  }
  if ($key.Key -eq [ConsoleKey]::Tab) {
      $this.GetActiveScreen().FocusNext()
      continue
  }

  Phase 2: Simplify Focus Management

  # In Screen base class:
  [void] FocusNext() {
      $focusable = @()
      $this.CollectFocusable($this, [ref]$focusable)
      $focusable = $focusable | Sort-Object TabIndex, Y, X

      $currentIndex = [array]::IndexOf($focusable, $this.FindFocused())
      $nextIndex = ($currentIndex + 1) % $focusable.Count
      $focusable[$nextIndex].Focus()
  }

  Phase 3: Remove Services

  - Delete ShortcutManager and FocusManager
  - Remove service container dependencies
  - Clean up Screen.OnActivated/OnDeactivated

  Benefits of This Approach

  1. Immediate fixes: Tab and Escape will work everywhere
  2. No context issues: $this always refers to the right object
  3. Performance: Direct method calls, no service lookups
  4. Maintainable: Clear, simple code paths
  5. Debuggable: Stack traces make sense
  6. PowerShell-native: Uses language strengths, not fighting them

  The current service-based approach was a good idea in theory but created more
  problems than it solved. The hybrid approach keeps the benefits (no duplication,
  global shortcuts) while eliminating the problems (context loss, over-engineering).
