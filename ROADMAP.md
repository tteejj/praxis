# PRAXIS Development Roadmap

## Development Approach: Build & Remodel
We're following an agile "build & remodel" pattern:
- **Build features** with current patterns (callbacks, scriptblocks)
- **Deliver working functionality** quickly
- **Refactor gradually** as foundation pieces (EventBus, etc.) are added
- **Learn from usage** what the framework really needs

This approach means some components may need updates when core systems like EventBus are implemented, but we get a working application sooner and can validate our architectural decisions through real use.

## Current Status
PRAXIS is a hybrid TUI framework combining:
- **Architecture from AxiomPhoenix**: Service-based DI, component hierarchy, theming
- **Speed from ALCAR**: Fast string-based rendering with cached VT100 sequences

### ✅ Completed
1. **Core Framework**
   - Fast UIElement base class with render caching
   - Container system for layouts
   - ServiceContainer for dependency injection
   - ThemeManager with pre-cached ANSI colors
   - Logger service (adapted from AxiomPhoenix)

2. **Screen Management**
   - ScreenManager for lifecycle and rendering
   - TabContainer for tab-based switching (1-9 shortcuts, Ctrl+Tab)
   - Screen base class with key bindings
   - Input handling chain fixed

3. **Basic Components**
   - ListBox with scrolling and selection
   - Button component
   - CommandPalette overlay (partially working)

4. **Sample Screens**
   - ProjectsScreen (ported from ALCAR)
   - TestScreen for tabs 2 & 3

### ✅ Recently Completed
1. **Command Palette Actions Fixed**
   - Proper context capture with `.GetNewClosure()`
   - Error handling for all commands
   - New project and new task commands working

2. **TextBox Component**
   - Fast string-based rendering
   - Placeholder text, scrolling, cursor
   - OnChange and OnSubmit callbacks

3. **Dialog System**
   - Modal dialog overlays
   - NewProjectDialog and NewTaskDialog
   - Tab navigation between controls

4. **TaskScreen Implementation**
   - Full task management with CRUD operations
   - Task model with status, priority, progress
   - TaskService with persistence
   - Filter/search functionality
   - Keyboard shortcuts (n/e/d/s/p)

5. **Focus Navigation Fixed**
   - Tab navigation between components working
   - Focus visual indicators (blue borders)
   - Proper focus management in containers

6. **EditTaskDialog**
   - Full task editing capabilities
   - Status, priority, progress editing
   - Integrated with TaskScreen

7. **ConfirmationDialog**
   - Generic confirmation dialog
   - Y/N keyboard shortcuts
   - Used for delete operations

8. **DataGrid Component**
   - Ported from AxiomPhoenix
   - Column-based display
   - Scrolling and selection
   - Theme-aware styling

9. **Configuration System**
   - ConfigurationService with persistence
   - Dot notation for nested settings
   - Auto-save capability
   - Default settings structure

10. **SettingsScreen**
    - Visual settings management
    - Category-based organization
    - DataGrid for settings display
    - Reset functionality
    - Working around missing ListBox.OnSelectionChanged (will refactor when EventBus added)

11. **Dialog and Button Fixes** (2025-07-22)
    - Fixed ConfigurationService registration missing from Start.ps1
    - Fixed all dialog button initialization (missing ServiceContainer)
    - Fixed button text rendering (integer division and caching issues)
    - Fixed dialog positioning (moved to OnBoundsChanged)
    - Fixed DataGrid negative width calculations
    - Applied consistent dark overlay rendering to all dialogs

12. **ListBox OnSelectionChanged** (2025-07-22)
    - Added OnSelectionChanged callback property to ListBox
    - Follows same pattern as Button.OnClick
    - Updated SettingsScreen to use callback instead of manual tracking
    - Removed ~15 lines of workaround code

13. **Dialog Components Completed** (2025-07-22)
    - **EditProjectDialog**: Full project editing with name, nickname, notes, and due date
    - **TextInputDialog**: Generic text input with customizable prompt and default value
    - **NumberInputDialog**: Numeric input with validation, min/max constraints, and decimal support
    - All dialogs follow consistent patterns: dark overlay, centered layout, proper button positioning

14. **Task Edit Fix & Command Palette Updates** (2025-07-22)
    - Fixed Task model property mismatch: changed `ModifiedAt` to `UpdatedAt` in TaskScreen
    - Added edit/delete commands to CommandPalette for both projects and tasks
    - Commands automatically switch to appropriate tab before executing
    - All CRUD operations now accessible via command palette (`/` or `:`)

15. **🎉 EventBus System Implementation** (2025-07-22)
    - **Complete publish/subscribe event system** for decoupled component communication
    - **Event-driven architecture** replacing direct parent/child references and callbacks
    - **Dynamic command registration** - screens can register commands at runtime
    - **Cross-screen communication** - components notify each other via events
    - **ThemeManager integration** - theme changes now use EventBus while maintaining backward compatibility
    - **Dialog lifecycle events** - dialogs publish open/close events for monitoring
    - **Comprehensive event types** - 20+ standardized event names for consistency
    - **EventBus monitor tool** - built-in debugging UI accessible via command palette
    - **Event history and debugging** - optional event logging and statistics
    - **Backward compatibility** - all existing callback patterns still work
    - **Documentation** - complete EventBus.md with patterns, examples, and migration guide

16. **🔄 Input System Refactor** (2025-07-22)
    - **MAJOR ARCHITECTURE CHANGE**: Replaced complex service-based input handling with simple, direct patterns
    - **Removed broken services**: ShortcutManager and FocusManager caused method invocation errors and context loss
    - **ScreenManager direct global shortcuts**: `/`, `:`, Tab, Ctrl+Q handled at top level for reliability
    - **Screen.FocusNext() method**: Simple, fast focus navigation shared by all screens - no complex caching
    - **UIElement.Focus() simplified**: Direct focus management with tree traversal - no WeakReferences or services
    - **Dialog HandleInput() methods**: Direct key handling in dialogs - no scriptblock context issues
    - **PowerShell-native patterns**: Works WITH PowerShell object model instead of fighting it
    - **Speed optimized**: No service lookups in hot paths, direct method calls, minimal allocations
    - **Reliability improved**: Tab works everywhere, Escape works in dialogs, no more "method not found" errors

17. **🎯 Critical Input Routing Fix** (2025-07-22)
    - **DISCOVERED**: TabContainer was not routing input to active tab content screens
    - **ROOT CAUSE**: TabContainer inherited from Container and used Container.HandleInput() which routed to TabContainer's "children" (tab headers), not tab content
    - **INPUT FLOW TRACED**: MainScreen → TabContainer → Container.HandleInput() → ListBox (bypassed ProjectsScreen entirely!)
    - **SOLUTION**: Modified TabContainer.HandleInput() to route directly to active tab's content: `activeTab.Content.HandleInput(key)`
    - **PATTERN ESTABLISHED**: Screen-level shortcuts (e, d, n, r) are handled BEFORE passing to child components
    - **DEBUGGING METHOD**: Used logs to trace exact input flow - `grep -a "Key pressed: E" praxis.log` revealed the routing path
    - **CONSTRUCTOR BUG FIXED**: ProjectsScreen DeleteProject() was passing 2 args to ConfirmationDialog constructor (only accepts 1)

18. **🏗️ Layout System Implementation** (2025-07-22)
    - **DESIGNED**: PRAXIS layout system based on AxiomPhoenix Panel patterns with ALCAR's fast string rendering
    - **HorizontalSplit**: Two-pane horizontal layout with configurable split ratio (10-90%), cached layout calculations
    - **VerticalSplit**: Two-pane vertical layout with configurable split ratio, optimized boundary updates
    - **GridPanel**: Multi-column grid layout with auto-sizing, configurable spacing, optional borders
    - **PERFORMANCE**: All layouts use cached calculations to avoid expensive re-calculations on every render
    - **STRING-BASED RENDERING**: Compatible with PRAXIS's fast VT100 string concatenation approach
    - **INPUT ROUTING**: Proper focus management and input routing to panes/cells
    - **HELPER METHODS**: Built-in methods for common split ratios (Equal, LeftFavored, etc.) and focus management
    - **TESTED**: Full integration test with complex nested layout (HorizontalSplit → VerticalSplit → GridPanel) successful

## ✅ Major Issues Resolved (2025-07-22)
1. **"Method invocation failed because [ShortcutManager] does not contain a method named 'EditTask'"** - FIXED
   - Root cause: Scriptblock context loss in service-based shortcut system  
   - Solution: Direct method calls in screen HandleInput methods

2. **Tab navigation not working anywhere** - FIXED
   - Root cause: Complex service dependencies and scope management
   - Solution: Simple Screen.FocusNext() method with direct tree traversal

3. **Escape key not working in dialogs** - FIXED
   - Root cause: Service-based shortcut context not properly established
   - Solution: Direct HandleInput() methods in dialog classes

4. **Service over-engineering** - FIXED
   - Root cause: Fighting PowerShell's natural object model with complex service abstractions
   - Solution: Hybrid approach - global shortcuts in ScreenManager, screen-specific in HandleInput()

## 🔧 Current Technical Debt
Simplified after input system refactor:

1. **Direct Global Service Access**
   - Using $global:ServiceContainer directly
   - Should use proper injection patterns
   - Will improve with StateManager implementation

2. ~~**Manual Focus Management**~~ ✅ **RESOLVED (2025-07-22)**
   - ~~Each screen manually handles Tab navigation~~
   - ~~Should be centralized in a FocusManager~~
   - **Now handled by shared Screen.FocusNext() method - simple and reliable**

3. ~~**Command Registration**~~ ✅ **RESOLVED (2025-07-22)**
   - ~~Commands are manually added in CommandPalette initialization~~
   - ~~Should allow dynamic registration from screens/components~~
   - **EventBus now supports dynamic command registration via `[CommandRegistration]::RegisterCommand()`**

4. **Model Property Inconsistencies**
   - Task has UpdatedAt, Project has none
   - Should standardize timestamp properties across models
   - Consider base class for common properties

## 🔧 New Technical Debt (from EventBus Integration)
Items to address as the EventBus system matures:

1. **Mixed Event/Callback Patterns**
   - Components support both EventBus and legacy callbacks
   - Should gradually migrate all components to EventBus-only
   - Legacy support can be removed in future versions

2. **Event Type Safety**
   - Event data is passed as hashtables without type checking
   - Could benefit from strongly-typed event classes
   - EventNames constants help but don't enforce data structure

## 📋 TODO - Core Features

### 1. Complete Dialog Components
- [x] EditTaskDialog for task editing - COMPLETED
- [x] ConfirmationDialog for delete operations - COMPLETED
- [x] EditProjectDialog for project editing - COMPLETED
- [x] TextInputDialog for simple text input - COMPLETED
- [x] NumberInputDialog for numeric input - COMPLETED

### 2. Port Essential Components
**From AxiomPhoenix**:
- [x] TextBox (`ACO.003_TextBoxComponent.ps1`) - COMPLETED
- [x] DataGrid (`ACO.022_DataGridComponent.ps1`) - COMPLETED (simplified version)
- [x] **TreeView** (`ACO.015_TreeView.ps1`) - **COMPLETED (2025-07-22)** ✨
- [x] **ProgressBar** (`ACO.010_ProgressBarComponent.ps1`) - **COMPLETED (2025-07-22)** ✨
- [x] Dialog system - COMPLETED (custom implementation)

**From ALCAR**:
- [ ] FastFileTree (for file browser)
- [ ] SearchableListBox
- [ ] MultiSelectListBox

### 3. Layout System
**Source**: AxiomPhoenix layout components
- [x] HorizontalSplit - **COMPLETED (2025-07-22)** ✨
- [x] VerticalSplit - **COMPLETED (2025-07-22)** ✨
- [x] Grid layout (GridPanel) - **COMPLETED (2025-07-22)** ✨
- [x] **Dock panel (DockPanel)** - **COMPLETED (2025-07-22)** ✨

### 4. Core Services
**From AxiomPhoenix**:
- [x] ConfigurationService (`ASE.002_ConfigurationService.ps1`) - COMPLETED
- [x] **EventBus** (`ASE.004_EventBus.ps1`) - **COMPLETED (2025-07-22)** ✨
- [x] ~~ShortcutManager~~ - **REMOVED (2025-07-22)** - Replaced with direct ScreenManager global shortcuts + screen HandleInput methods
- [x] **StateManager** (`ASE.009_StateManager.ps1`) - **COMPLETED (2025-07-22)** 🚀 **BLAZINGLY FAST**

### 5. Advanced Features
- [ ] Window management (multiple floating windows)
- [ ] Resize support for splits
- [ ] Mouse support
- [ ] Async operations
- [ ] Notifications/toasts

## 📁 Code Sources

### From AxiomPhoenix (`../_mono/AxiomPhoenix_v4_Split/`)
- **Components**: `/Components/ACO.*` files
- **Services**: `/Services/ASE.*` files
- **Base classes**: `/Base/ABA.*` files
- **Screens**: `/Screens/ASC.*` files

### From ALCAR (`../_mono/ALCAR_AXP/`)
- **Fast components**: `FastComponents/` directory
- **Project management**: `ProjectContext*.ps1` screens
- **String rendering**: Direct VT100 manipulation patterns

### Key Principles
1. **Speed First**: Always prefer cached string rendering over object allocation
2. **Lazy Evaluation**: Only rebuild what changes
3. **Service Pattern**: Use DI for all cross-cutting concerns
4. **Component Reuse**: Build once, use everywhere
5. **Theme Consistency**: All colors through ThemeManager

### 🎯 Input Handling Best Practices (Established 2025-07-22)

**For Screen Classes**:
```powershell
[bool] HandleInput([System.ConsoleKeyInfo]$key) {
    # 1. Handle screen-specific shortcuts FIRST (before children)
    switch ($key.Key) {
        ([System.ConsoleKey]::E) {
            if (-not $key.Modifiers -and ($key.KeyChar -eq 'E' -or $key.KeyChar -eq 'e')) {
                $this.EditItem()
                return $true
            }
        }
        # ... other shortcuts
    }
    
    # 2. Let base Screen handle navigation (Tab, etc.)
    if (([Screen]$this).HandleInput($key)) {
        return $true
    }
    
    # 3. Finally pass to focused children
    return ([Container]$this).HandleInput($key)
}
```

**For Container Components** (like TabContainer):
- Route input to logical content, not just direct children
- Use `activeTab.Content.HandleInput(key)` instead of `([Container]$this).HandleInput(key)`

**Debugging Input Issues**:
- Use logs: `grep -a "Key pressed: [KEY]" _Logs/praxis.log`
- Trace the routing path: MainScreen → TabContainer → Screen → Container → Child
- Verify HandleInput methods are actually being called

## Next Immediate Steps

### ✅ Completed Quick Wins (2025-07-22)
1. ~~Add OnSelectionChanged to ListBox (match Button.OnClick pattern)~~ ✅
2. ~~Create EditProjectDialog for project editing~~ ✅
3. ~~Create simple input dialogs (TextInputDialog, NumberInputDialog)~~ ✅
4. ~~Add edit/delete commands to CommandPalette~~ ✅

### ✅ Completed Quick Wins (2025-07-22)
1. ~~**Implement Dashboard screen with project/task overview**~~ ✅ **COMPLETED** - Ultra-complex dashboard with nested layouts
2. ~~**Complete Layout System**~~ ✅ **COMPLETED** - DockPanel, HorizontalSplit, VerticalSplit, GridPanel all working
3. ~~**Add Essential Components**~~ ✅ **COMPLETED** - TreeView and ProgressBar ported from AxiomPhoenix
4. ~~**OnSelectionChanged Support**~~ ✅ **COMPLETED** - DataGrid already has full support

### 📋 Next Priority Tasks
1. Create FilePickerDialog using TreeView ✨ **NOW POSSIBLE**
2. Port SearchableListBox from ALCAR
3. Port MultiSelectListBox functionality

### Foundation Improvements (Can be done in parallel)
1. ~~Add EventBus for decoupled communication~~ ✅ **COMPLETED (2025-07-22)**
2. ~~Port ShortcutManager for centralized key handling~~ ❌ **REMOVED (2025-07-22)** - Direct patterns work better with PowerShell
3. Port StateManager for application state  
4. ~~Create FocusManager service~~ ❌ **REMOVED (2025-07-22)** - Simple Screen.FocusNext() method works better

## 🚀 Enabled by EventBus (Now Available)
With the EventBus system in place, these patterns are now possible:

1. **Dynamic Feature Registration**
   - Screens can register commands at runtime
   - Components can advertise their capabilities
   - Plugins could register functionality via events

2. **Decoupled Screen Communication**
   - Cross-screen data refresh notifications
   - Cascading updates (e.g., project deletion → task cleanup)
   - Global application state changes

3. **Advanced Debugging**
   - Event flow visualization via EventBus Monitor
   - Real-time event logging and statistics
   - Component interaction analysis

4. **Future Extensibility**
   - Plugin system foundation is now in place
   - Undo/redo system can be built on events
   - Application state snapshots via event replay

### Component Library Expansion
1. Port TreeView component for hierarchical data
2. Port ProgressBar component
3. Add SearchableListBox
4. Add file browser functionality

## Performance Goals
- Sub-10ms render times for full screen updates
- <1ms for partial updates
- Minimal memory allocation in render loop
- Instant (<50ms) tab switching