# Praxis TUI Development Memory & Agent Instructions

## Project Overview
Praxis is a PowerShell-based TUI application for project/task/time management. Solo developer project focused on speed, flicker-free performance, and professional text editing capabilities.

## CRITICAL STATUS: ARCHITECTURAL CRISIS - EMERGENCY IMPLEMENTATION REQUIRED
**PRIMARY ISSUE**: SimpleTaskPro codebase has deviated catastrophically from plan_final.md vision
**EVIDENCE**: 5,113 screen lines vs 1,000 planned (411% over), 4 competing ServiceContainer implementations, 354+ debug file I/O operations causing performance degradation
**ACTION REQUIRED**: IMMEDIATELY implement the_plan/plan_plan.md step-by-step

## Master Plan Reference
**DEFINITIVE IMPLEMENTATION PLAN**: `simpletaskpro/the_plan/plan_plan.md`
**ORIGINAL VISION**: `simpletaskpro/the_plan/plan_final.md` 
**CURRENT STATE**: Critical architectural violations requiring surgical correction

### Key Implementation Requirements
1. **ALWAYS refer to plan_plan.md** before making ANY changes to SimpleTaskPro
2. **Follow the 5-phase approach** - Emergency Stabilization → Service Unification → Screen Migration → Performance → Validation
3. **Track progress** - Update plan_plan.md with completion status and any discoveries
4. **Measure success** - Validate line count reductions and performance improvements
5. **Maintain debug capability** - Conditional debug I/O only when $global:Debug enabled

## Actual Screens in Use (7 Main + Dialogs)
**Main Screens:**
1. ProjectsScreen.ps1 - Main projects management  
2. TaskScreen.ps1 - Task management
3. TimeEntryScreen.ps1 - Time tracking
4. TextEditorScreenNew.ps1 - Text editor (KEEP UNCHANGED - works perfectly)
5. FileBrowserScreen.ps1 - File browser
6. CommandLibraryScreen.ps1 - Command management  
7. VisualMacroFactoryScreen.ps1 - Macro creation

**CRUD Dialogs:**
- Project: NewProjectDialog.ps1, EditProjectDialog.ps1, CleanNewProjectDialog.ps1
- Task: NewTaskDialog.ps1, EditTaskDialog.ps1  
- Time: TimeEntryDialog.ps1, QuickTimeEntryDialog.ps1, ManualTimeEntryDialog.ps1, TimeEntryOptionsDialog.ps1
- Command: CommandEditDialog.ps1
- Utility: TextInputDialog.ps1, ConfirmationDialog.ps1

## Core Pain Points Identified

### 1. Service Injection Hell
**Problem**: 25-40 lines per screen of manual service setup
**Pattern**: Every screen has identical GetService() calls and event subscription boilerplate
**Solution**: Auto-injecting CRUDScreen base class

### 2. Bounds Management Nightmare  
**Problem**: Every screen has unique, fragile OnBoundsChanged() implementation
**Pattern**: Manual percentage calculations and child positioning
**Solution**: Declarative layout system

### 3. Event Handling Duplication
**Problem**: 50+ lines of identical CRUD shortcuts per screen
**Pattern**: Same HandleScreenInput() switch statements everywhere
**Solution**: Standard CRUD base class with built-in shortcuts

### 4. Dialog Architecture Chaos
**Problem**: 3 different dialog systems (BaseDialog, SimpleDialog, CleanDialog) used inconsistently
**Pattern**: Theme issues, different APIs, unpredictable behavior
**Solution**: Single UnifiedDialog system

### 5. Component Integration Complexity
**Problem**: Manual focus management, activation, bounds handling
**Pattern**: Complex OnActivated() methods with fallback logic
**Solution**: ComponentManager auto-wiring system

## Implementation Plan - Phase Approach

### Phase 1: Foundation (Week 1)
**Priority 1.1**: UnifiedDialog class
- Replaces BaseDialog, SimpleDialog, CleanDialog  
- Guarantees theme consistency and border handling
- File: Base/UnifiedDialog.ps1

**Priority 1.2**: CRUDScreen base class
- Auto service injection
- Standard CRUD shortcuts built-in  
- Event subscription management
- File: Base/CRUDScreen.ps1

**Priority 1.3**: Validation
- Convert 1-2 existing screens to test
- Ensure performance preserved

### Phase 2: Advanced Helpers (Week 2)  
**Priority 2.1**: ComponentManager
- Auto-handles component focus management
- File: Core/ComponentManager.ps1

**Priority 2.2**: ScreenLayoutBuilder
- Declarative layouts replace manual bounds
- File: Core/ScreenLayoutBuilder.ps1

### Phase 3: Migration (Week 3-4)
- Migrate remaining 5 screens
- Performance validation
- Documentation

## What Must Be Preserved
- **Speed/Performance**: StringCache, RenderHelper optimizations
- **Flicker-free rendering**: Line-level caching, VT100 optimizations  
- **TextEditor excellence**: Buffer/View separation, undo/redo, professional features
- **Service container architecture**: Event-driven design that works
- **Existing data services**: ProjectService, TaskService, etc.

## Agent Usage Instructions

### Architecture Agent
**Use for**: Designing and implementing base classes (UnifiedDialog, CRUDScreen, ComponentManager)
**Context needed**: Current base class implementations, component patterns
**Deliverables**: New base classes with complete implementation

### Migration Agent  
**Use for**: Converting existing screens to new architecture one by one
**Context needed**: Specific screen to migrate, new base class APIs
**Deliverables**: Migrated screen with before/after comparison

### Testing Agent
**Use for**: Validating each phase preserves performance and functionality
**Context needed**: Original screen behavior, new implementation
**Deliverables**: Performance metrics, functionality verification

### Documentation Agent
**Use for**: Creating examples and developer guides
**Context needed**: New base classes, migration patterns
**Deliverables**: Usage examples, migration guides

## Progress Tracking - UPDATED FOR SIMPLETASKPRO CRISIS

**CRITICAL STATUS**: SimpleTaskPro requires complete implementation of plan_plan.md
**CURRENT PHASE**: Emergency Stabilization (Phase 1 of 5)

### SimpleTaskPro Implementation Status
- **Phase 1**: Emergency Stabilization ❌ NOT STARTED
  - Step 1.1: Fix Service Method Mismatch (SaveTask → AddTask/UpdateTask)
  - Step 1.2: Conditional Debug I/O (354+ debug operations)
  - Step 1.3: Entry Point Cleanup (85 lines → 20 lines)

- **Phase 2**: Service Container Unification ❌ NOT STARTED 
  - Step 2.1: Investigate 4 competing ServiceContainer implementations
  - Step 2.2: Select primary container
  - Step 2.3: Delete obsolete containers
  - Step 2.4: Update service registration

- **Phase 3**: Screen Architecture Compliance ❌ NOT STARTED
  - TaskListScreen: 582 lines → 50 lines target (91% reduction)
  - TimeEntryScreen: 858 lines → 200 lines target
  - CommandLibraryScreen: 1,314 lines → 200 lines target
  - ExcelMappingScreen: 1,307 lines → 200 lines target

- **Phase 4**: Performance Optimization ❌ NOT STARTED
- **Phase 5**: Architectural Validation ❌ NOT STARTED

**IMMEDIATE ACTION REQUIRED**: Begin Phase 1 implementation immediately

### Legacy Praxis Progress (COMPLETED)
**PHASE 1 COMPLETE ✅**
- Phase 1.1: UnifiedDialog class ✅ (Base/UnifiedDialog.ps1)
- Phase 1.2: CRUDScreen base class ✅ (Base/CRUDScreen.ps1)  
- Phase 1.3: Architecture validation ✅ (Tests/Phase1ValidationReport.md)

**VALIDATION RESULTS:**
- ProjectsScreen: 527 → 96 lines (82% reduction) ✅
- NewProjectDialog: 150 → 50 lines (67% reduction) ✅
- EditProjectDialog: 165 → 61 lines (63% reduction) ✅
- **Total boilerplate eliminated: 635 lines**
- All functionality preserved with improved reliability

## Developer Notes
- Solo developer project - prioritize maintainability over enterprise patterns
- PowerShell-specific constraints - closure scoping, type system limitations  
- Domain-specific: CAA/T2020 paths, Excel integration, time tracking workflows
- Keep explicit, debuggable code over magic abstractions

## Success Metrics
- New CRUD screen: 200+ lines → 50 lines (75% reduction)
- New dialog: 150+ lines → 25 lines (85% reduction)  
- Border/theme issues: Eliminated systematically
- Development time: New screen 2-3 hours → 30 minutes