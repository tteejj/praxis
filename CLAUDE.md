# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

PRAXIS is a high-performance Terminal User Interface (TUI) framework for PowerShell that prioritizes rendering speed (60+ FPS) while maintaining clean architecture. It combines service-based dependency injection with fast string-based rendering using cached VT100/ANSI sequences.

## Key Commands

```bash
# Run the application
pwsh -File Start.ps1

# Run with debug output
pwsh -File Start.ps1 -Debug

# Run tests (each tests specific functionality)
./test-all-features.ps1
./test-navigation.ps1
./test-focus.ps1
./test-dialogs.ps1
```

## Architecture Overview

### Core Components

1. **ServiceContainer** (Core/ServiceContainer.ps1): Central DI container - all services register here at startup
2. **ScreenManager** (Core/ScreenManager.ps1): Main application loop, manages screen lifecycle and rendering
3. **VT100** (Core/VT100.ps1): ANSI escape sequence handling with true color support

### UI Hierarchy

- **UIElement** (Base/UIElement.ps1): Base class with render caching - all UI inherits from this
- **Container** (Base/Container.ps1): Base for components containing children
- **Screen** (Base/Screen.ps1): Base for application screens with key bindings

### Critical Performance Patterns

1. **String-Based Rendering**: Components render to strings, not objects. Use StringBuilder for concatenation.
2. **Render Caching**: Components have `_cacheInvalid` flag. Call `Invalidate()` when state changes.
3. **Pre-cached Sequences**: Theme colors and positions are pre-computed ANSI strings.
4. **Bubble-up Invalidation**: Child changes propagate to parents automatically.

### Development Patterns

When creating new components:
```powershell
# 1. Inherit from appropriate base class
class MyComponent : Container {
    # 2. Call base constructor
    MyComponent() : base() {
        $this.IsFocusable = $true  # If interactive
    }
    
    # 3. Override OnInitialize for setup
    [void] OnInitialize() {
        $this.ThemeManager = $this.ServiceContainer.GetService('ThemeManager')
        # Subscribe to events, create children, etc.
    }
    
    # 4. Override OnRender for visuals
    [string] OnRender() {
        $sb = [System.Text.StringBuilder]::new()
        # Build your string representation
        return $sb.ToString()
    }
    
    # 5. Call Invalidate() when state changes
    [void] UpdateState() {
        $this._someState = $newValue
        $this.Invalidate()
    }
}
```

### Input Handling

- Override `HandleInput($key)` and return `$true` if handled
- Containers route input to focused child first
- Key bindings are defined at Screen level

### Focus Management

- Set `IsFocusable = $true` for interactive components
- Override `OnGotFocus()` and `OnLostFocus()` for visual feedback
- Use Tab key for navigation between focusable elements

### Service Registration

Services are registered in Start.ps1:
```powershell
$container.RegisterService('ServiceName', [ServiceClass]::new())
```

Access services in components:
```powershell
$this.ServiceContainer.GetService('ServiceName')
```

## Important Notes

- Always use `Invalidate()` when component state changes - this triggers re-render
- Pre-cache ANSI sequences where possible (see ThemeManager pattern)
- Avoid allocations in render loops - reuse StringBuilders
- Test with `./test-all-features.ps1` for comprehensive functionality check
- The framework is designed for extension - new screens/components follow established patterns