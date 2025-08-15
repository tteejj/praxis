# TaskProPro Design Document

## Project Goals

### Primary Objective
Port the **standalone/taskpro/** PowerShell TUI application to use **embedded C#** for professional-grade performance and user experience while maintaining the exact functionality and workflow that worked.

### Problems Being Solved
1. **Flicker** - PowerShell TUI flickered on every screen update
2. **Input Limitations** - PowerShell had poor key handling, no Ctrl+shortcuts
3. **Layout Struggles** - Manual cursor positioning, no proper text fields
4. **Performance** - Slow list rendering, text editing, data operations
5. **Professional UX** - Wanted desktop-class experience, not "PowerShell script feel"

### Success Criteria
- **Zero flicker** rendering
- **Professional input handling** (Ctrl+A, Ctrl+C/V, arrow keys, etc.)
- **Smooth navigation** through task lists
- **Real text editing** with proper cursor positioning
- **Same workflow** as original TaskPro but better
- **Single user, personal productivity** focus (not enterprise software)

## Original TaskPro Analysis

### Core Workflow (What Actually Worked)
```
Main Screen: Hierarchical Task List
├── Parent Task 1                    ☐ H  2025-01-15  Review project docs [work, urgent]
│   ├── Subtask 1.1                 ☐ M             └─ Update API documentation  
│   └── Subtask 1.2                 ☐ L             └─ Fix code examples
├── Parent Task 2                    ■ H  2025-01-10  Fix rendering bug [bug, high]
└── Parent Task 3                    ☐ T  Today       Weekly planning [personal]

Status Bar: Filter: All | Tasks: 15 | Selected: 1
Help: ↑↓:Nav | N:New | Enter:Notes | F:Filter | T:Tags | D:Delete | Q:Quit
```

### Key Features That Must Be Preserved
1. **Hierarchical Display** - Parent tasks with collapsible subtasks
2. **Rich Visual Design** - Status icons (☐■), priority indicators (H/M/L/T), dates, colors
3. **Pillbox Selection** - Selected item gets highlighted border box
4. **Tree Indentation** - Visual hierarchy with └─ characters
5. **Filtering System** - All/Today/High/Medium/Low priority filters + tag filtering
6. **Quick Actions** - Single-key shortcuts (N=New, D=Delete, etc.)
7. **Notes Editing** - Press Enter for full-screen notes editor
8. **Tag Management** - Press T for tag editing with completion
9. **Real-time Updates** - Changes save immediately, list updates instantly

### Original Input Patterns
- **Arrow Keys** - Navigate up/down through hierarchical list
- **Enter** - Edit notes for selected task (full-screen editor)
- **N** - Create new task (with immediate title editing)
- **D** - Delete current task (with confirmation)
- **T** - Edit tags for current task
- **F** - Cycle through filters (All → Today → High → Medium → Low)
- **Space** - Toggle completion status
- **Escape** - Exit/cancel operations
- **Tab** - Switch between different screens/modes

### Data Model (What We're Managing)
```csharp
class SimpleTask {
    string Id, Title, Notes
    bool Completed
    DateTime CreatedDate, ModifiedDate, DueDate
    string Priority  // "High", "Medium", "Low", "Today"
    List<string> Tags
    string ID1, ID2  // Project codes
    string ParentId
    List<SimpleTask> Subtasks
    bool SubtasksCollapsed
    int SortOrder
}
```

## TaskProPro Architecture Design

### Hybrid Architecture Split
**80% C# (Performance-Critical)** + **20% PowerShell (Integration)**

#### C# Components (CSharp/)
```
Core/
├── InputEvent.cs        - Clean input detection (Ctrl+A, arrows, etc.)
├── InputManager.cs      - Professional key handling
├── ScreenBuffer.cs      - Zero-flicker rendering
└── DataManager.cs       - Fast task operations, search, save

UI/  
├── TextInputField.cs    - Professional text editing with cursor
├── ListWidget.cs        - Rich hierarchical list display
├── TaskListWidget.cs    - Specialized for task display
└── NotesEditor.cs       - Full-screen text editor

Data/
├── TaskManager.cs       - Fast CRUD operations
├── TaskPersistence.cs   - JSON save/load with backup
├── TaskFilter.cs        - Fast filtering and search
└── TaskExport.cs        - Export functionality
```

#### PowerShell Layer (Application/)
```
TaskProPro.ps1          - Main application entry point
TaskProApp.ps1          - Application loop and screen management
ScreenManager.ps1       - Screen switching and layout
DataIntegration.ps1     - PowerShell data integration
ConfigManager.ps1       - Settings and configuration
```

### Screen Layout Design

#### Main Task List Screen (Primary Interface)
```
┌─ TaskProPro - Professional Task Manager ────────────────────────────────┐
│                                                                          │
│ Filter: All ▼    Search: [                    ]    Tasks: 15    Page: 1  │
│ ──────────────────────────────────────────────────────────────────────── │
│                                                                          │
│ St Pri  Due        Title                                    Tags         │
│ ──────────────────────────────────────────────────────────────────────── │
│ ☐  H   2025-01-15  Review project documentation             [work,urgent]│
│    └─ ☐  M         └─ Update API documentation              [docs]       │
│    └─ ☐  L         └─ Fix code examples                     [code]       │
│╭■  H   2025-01-10  Fix rendering bug in TaskPro             [bug,high]  ╮│  <- Pillbox selection
│╰                                                                        ╯│
│ ☐  T   Today       Weekly planning session                  [personal]   │
│ ☐  M   2025-01-20  Research new frameworks                  [learning]   │
│                                                                          │
│ ──────────────────────────────────────────────────────────────────────── │
│ Status: Ready | Ctrl+N:New | Enter:Notes | F:Filter | T:Tags | Ctrl+Q:Exit│
└──────────────────────────────────────────────────────────────────────────┘
```

#### Full-Screen Notes Editor
```
┌─ Notes Editor - Fix rendering bug in TaskPro ───────────────────────────┐
│                                                                          │
│ Investigation notes:                                                     │
│ - PowerShell TUI was flickering on every screen update                  │
│ - Manual cursor positioning causing layout issues                       │ <- Cursor here
│ - Need to implement single-write rendering buffer                       │
│ - C# components should handle all screen operations                     │
│                                                                          │
│                                                                          │
│                                                                          │
│                                                                          │
│ ──────────────────────────────────────────────────────────────────────── │
│ Ctrl+S:Save | Escape:Cancel | Line: 4, Col: 54                         │
└──────────────────────────────────────────────────────────────────────────┘
```

#### Tag Editor Modal
```
┌─ Edit Tags ──────────────────────────────┐
│                                          │
│ Task: Fix rendering bug in TaskPro       │
│ ──────────────────────────────────────── │
│                                          │
│ Tags: [bug, high, ui, performance      ]│ <- Text input with cursor
│                                          │
│ Available: work, urgent, personal,       │
│           docs, code, learning...        │
│                                          │
│ ──────────────────────────────────────── │
│ Enter:Save | Escape:Cancel               │
└──────────────────────────────────────────┘
```

## Implementation Plan

### Phase 1: Core Data Management (Week 1)
- **TaskManager.cs** - Fast CRUD operations for tasks
- **TaskPersistence.cs** - JSON save/load with atomic writes and backup
- **TaskFilter.cs** - Fast filtering by priority, tags, search terms
- **PowerShell integration layer** - Load C# components, data binding

### Phase 2: Professional UI Components (Week 2)  
- **TaskListWidget.cs** - Hierarchical task display with pillbox selection
- **NotesEditor.cs** - Full-screen text editor with gap buffer
- **Modal dialogs** - Tag editor, task creation forms
- **Screen management** - PowerShell orchestration of C# UI

### Phase 3: Main Application (Week 3)
- **TaskProPro.ps1** - Main entry point and application loop
- **Input routing** - Map keys to actions, handle modes
- **Screen transitions** - Task list ↔ Notes editor ↔ Dialogs  
- **Status management** - Real-time status updates, error handling

### Phase 4: Polish and Features (Week 4)
- **Visual polish** - Colors, borders, animations
- **Advanced features** - Bulk operations, export, search
- **Performance optimization** - Rendering speed, memory usage
- **Testing and refinement** - Real-world usage testing

## Technical Specifications

### Performance Requirements
- **Zero flicker** rendering (single screen buffer write)
- **Instant response** to key presses (< 16ms)
- **Smooth scrolling** through large task lists (> 1000 items)
- **Fast search** over all tasks (< 100ms)
- **Reliable saves** with automatic backup

### Compatibility Requirements
- **PowerShell 7+** on Windows/Linux/macOS
- **Console applications** - no GUI dependencies
- **UTF-8 support** for special characters and colors
- **Terminal compatibility** - Windows Terminal, iTerm2, etc.

### Data Requirements
- **JSON persistence** - human-readable, version-controllable
- **Atomic saves** - no data corruption on crashes
- **Automatic backups** - keep recent versions safe
- **Fast loading** - < 500ms for typical datasets

## Success Metrics

### User Experience
- **Zero learning curve** - identical workflow to original TaskPro
- **Professional feel** - desktop application quality
- **Responsive interaction** - no lag or delays
- **Visual polish** - clean, organized, purposeful design

### Technical Achievement
- **Architecture success** - clean C#/PowerShell separation
- **Performance win** - measurably faster than original
- **Reliability** - no crashes, no data loss
- **Maintainability** - clean code, easy to extend

This is **personal productivity software** for **one user** (you), not enterprise software. The focus is on **getting the job done efficiently** with a **professional experience**.

## Next Steps

1. **Complete this design review** - ensure all requirements captured
2. **Function analysis** - map original TaskListScreen methods to new architecture  
3. **Create detailed technical specs** - method signatures, data flows
4. **Begin implementation** - start with TaskManager.cs core data operations

This design document should guide all implementation decisions and keep the project focused on delivering the professional task management experience you want.