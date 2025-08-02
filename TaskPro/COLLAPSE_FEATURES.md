# TaskPro Collapse Features

## Overview
TaskPro now supports collapsing/expanding subtasks both globally and per-task.

## Visual Indicators
- **▼** (down arrow) = Task has subtasks and they're expanded
- **▶** (right arrow) = Task has subtasks and they're collapsed  
- **  ** (spaces) = Task has no subtasks

## Keyboard Controls

### Individual Task Collapse
- **C** = Toggle collapse/expand for the currently selected parent task
- Only works when a parent task (with subtasks) is selected
- State is saved per-task and persists between sessions

### Global Collapse  
- **G** = Toggle global collapse/expand for ALL subtasks
- Overrides individual task settings when active
- Affects all tasks immediately

## Behavior

### Priority System
1. **Global collapse ON** = All subtasks hidden (regardless of individual settings)
2. **Global collapse OFF** = Individual task settings respected
3. **No subtasks** = No visual indicator shown

### Navigation
- When subtasks are collapsed, cursor skips over hidden subtasks
- Selection automatically adjusts to visible items only
- Smooth navigation between visible parent tasks

### Data Persistence
- Individual collapse states saved to tasks.json
- Global collapse state resets on app restart (session-only)
- All safety features (auto-save, atomic saves, backups) preserved

## Use Cases

### Focus Mode
- Press **G** to hide all subtasks for overview of main tasks
- Press **G** again to restore detailed view

### Task Management
- Press **C** on busy parent tasks to reduce clutter
- Keep important subtasks visible while hiding completed ones

### Quick Navigation
- Collapse completed projects to focus on active work
- Expand only the tasks you're currently working on

## Status Bar
Updated status shows: `C:Collapse  G:Global` for quick reference.

All existing features (notes editing, auto-save, etc.) work normally with collapsed/expanded tasks.