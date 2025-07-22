# PRAXIS - Performance-Focused PowerShell TUI Framework

PRAXIS is a high-performance Terminal User Interface framework that combines the architectural elegance of AxiomPhoenix with the raw speed of ALCAR's string-based rendering.

## Key Features

- **Fast String-Based Rendering**: No object allocation in render loops
- **Tab-Based Navigation**: Switch between multiple screens with 1-9 or Ctrl+Tab
- **Cached Rendering**: Components only re-render when state changes
- **Pre-computed ANSI Sequences**: Theme colors are calculated once, not per-frame
- **Service Architecture**: Clean separation of concerns with dependency injection
- **Responsive Layouts**: Automatic handling of terminal resize

## Architecture Principles

1. **Render = String Concatenation**: The render loop does nothing but combine pre-built strings
2. **State Changes Invalidate**: Expensive operations happen only when data changes
3. **Cache Everything**: Colors, positions, and rendered content are all cached
4. **No Per-Frame Allocations**: Reuse StringBuilders and pre-allocated buffers

## How to Run

```bash
cd ~/projects/github/praxis
pwsh -File Start.ps1
```

Or make it executable and run directly:
```bash
chmod +x Start.ps1
./Start.ps1
```

## Project Structure

```
praxis/
├── Base/              # Core base classes (UIElement, Container, Screen)
├── Components/        # Reusable UI components (TabContainer, etc.)
├── Core/              # Core systems (VT100, ServiceContainer, ScreenManager)
├── Services/          # Application services (ThemeManager, etc.)
├── Screens/           # Application screens
└── Start.ps1          # Entry point
```

## Performance

PRAXIS achieves 60+ FPS on complex UIs by:
- Pre-computing all ANSI escape sequences
- Caching rendered strings at component level
- Using StringBuilder for efficient string operations
- Minimizing object allocations in hot paths

## Future Enhancements

- [ ] Window splitting (horizontal/vertical)
- [ ] Command palette
- [ ] More built-in components
- [ ] Additional themes
- [ ] Performance profiling tools