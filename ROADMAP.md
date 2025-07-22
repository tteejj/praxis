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

## 🔧 Known Technical Debt
These items work but need refactoring when foundation pieces are added:

1. **Direct Global Service Access**
   - Using $global:ServiceContainer directly
   - Should use proper injection patterns
   - Will improve with StateManager implementation

2. **Manual Focus Management**
   - Each screen manually handles Tab navigation
   - Should be centralized in a FocusManager
   - Part of planned ShortcutManager service

3. **Command Registration**
   - Commands are manually added in CommandPalette initialization
   - Should allow dynamic registration from screens/components
   - Will be addressed with EventBus implementation

4. **Model Property Inconsistencies**
   - Task has UpdatedAt, Project has none
   - Should standardize timestamp properties across models
   - Consider base class for common properties

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
- [ ] TreeView (`ACO.015_TreeView.ps1`)
- [ ] ProgressBar (`ACO.010_ProgressBarComponent.ps1`)
- [x] Dialog system - COMPLETED (custom implementation)

**From ALCAR**:
- [ ] FastFileTree (for file browser)
- [ ] SearchableListBox
- [ ] MultiSelectListBox

### 3. Layout System
**Source**: AxiomPhoenix layout components
- [ ] HorizontalSplit (`ACO.007_HorizontalSplitComponent.ps1`)
- [ ] VerticalSplit (`ACO.008_VerticalSplitComponent.ps1`)
- [ ] Grid layout
- [ ] Dock panel

### 4. Core Services
**From AxiomPhoenix**:
- [x] ConfigurationService (`ASE.002_ConfigurationService.ps1`) - COMPLETED
- [ ] EventBus (`ASE.004_EventBus.ps1`)
- [ ] ShortcutManager (`ASE.008_ShortcutManager.ps1`)
- [ ] StateManager (`ASE.009_StateManager.ps1`)

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

## Next Immediate Steps

### ✅ Completed Quick Wins (2025-07-22)
1. ~~Add OnSelectionChanged to ListBox (match Button.OnClick pattern)~~ ✅
2. ~~Create EditProjectDialog for project editing~~ ✅
3. ~~Create simple input dialogs (TextInputDialog, NumberInputDialog)~~ ✅
4. ~~Add edit/delete commands to CommandPalette~~ ✅

### Remaining Quick Wins
1. Implement Dashboard screen with project/task overview
2. Add ListBox OnSelectionChanged to other list-based components
3. Create FilePickerDialog using TreeView (when ported)

### Foundation Improvements (Can be done in parallel)
1. Add EventBus for decoupled communication
2. Port ShortcutManager for centralized key handling
3. Port StateManager for application state
4. Create FocusManager service

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