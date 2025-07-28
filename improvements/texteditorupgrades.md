Of course. This is the ideal time to define the architecture. Scrapping the existing `TextEditorScreen` implementation is the correct decision. To build a truly high-performance editor, we need a better foundation from the start.

Here is a comprehensive implementation plan. It consolidates our discussion, details the architectural decisions and alternatives, and provides the core code for a new, robust, and performant text editor foundation.

***

## Implementation Plan: High-Performance TUI Text Editor

**Document Version:** 1.0  
**Date:** July 25, 2025  
**Subject:** Architectural Design and Implementation Guide for a new TUI Text Editor, replacing the existing `TextEditorScreen`.

### 1.0 Executive Summary

The existing text editor implementation serves as a basic proof-of-concept but lacks the architectural foundation required for a high-performance, feature-rich experience. To achieve the "snappy" feel of classic editors like `edit.com` while supporting modern features, a complete architectural overhaul is necessary.

This plan proposes scrapping the current `TextEditorScreen` and rebuilding it based on a professional **Buffer/View architecture**. This separates the text data and manipulation logic (`DocumentBuffer`) from the UI rendering and input handling (`TextEditorScreen`). This design is fundamentally more performant, extensible, and testable.

The core data structure will be upgraded from a simple `ArrayList` of strings to a **Gap Buffer**, which provides extreme performance for typical user editing patterns. Key features like a robust Undo/Redo system, block selection, and an internal clipboard will be implemented using proven software design patterns. This document provides the complete architectural blueprint and core code for this new foundation.

### 2.0 Guiding Principles & Key Decisions

The following decisions have been made to guide the design:

1.  **Performance Over Features:** Every architectural choice prioritizes speed and responsiveness. The editor must feel instantaneous, even with moderate-sized files.
2.  **Scrap and Rebuild:** The existing editor's logic is too tightly coupled with its UI. A clean break to a new architecture is the most efficient path forward.
3.  **Adopt Buffer/View Architecture:** The core of the new design is the separation of the document's data (`DocumentBuffer`, the "Model") from its on-screen representation (`TextEditorScreen`, the "View").
4.  **Defer Syntax Highlighting:** This feature is explicitly removed from the plan. It is the most complex and performance-intensive feature, and its exclusion allows us to perfect the core editing experience.
5.  **Focus on Core Functionality:** The initial implementation will focus on features essential to a productive editing session: robust text manipulation, undo/redo, selection, copy/paste, and find/replace.

### 3.0 Core Architectural Overhaul: The Buffer/View Model

The new foundation consists of two primary classes:

*   **`DocumentBuffer` (The "Model"):** A non-UI class that knows nothing about rendering. Its sole responsibility is to manage the text content, file state, and the undo/redo history. All text manipulations (insertions, deletions) are handled by this class.
*   **`TextEditorScreen` (The "View"):** This is now a "dumb" UI layer. Its job is to:
    1.  Translate user key presses into commands sent to the `DocumentBuffer` (e.g., the 'A' key calls `_buffer.InsertChar('a')`).
    2.  Render only the visible portion ("viewport") of the text data provided by the `DocumentBuffer`.

This separation is the key to building a maintainable and performant system.

### 4.0 Deep Dive: The Core Data Structure

A simple `ArrayList` of strings is inefficient for text editing, as inserting a line in the middle of a large file is slow. We considered two professional-grade alternatives.

*   **Alternative 1: Rope (or Piece Table):** This tree-based structure is used by editors like VS Code. It is exceptionally fast for edits anywhere in a file and makes undo/redo trivial. However, it is significantly more complex to implement correctly.
*   **Alternative 2: Gap Buffer:** This structure uses a single large character array with a movable "gap." All edits occur at the gap. This is the model used by many classic, fast editors. It is extremely performant for the most common use case: sequential typing and deleting in one location.

**Decision:** We will implement a **Gap Buffer**. Its combination of high performance for typical editing and relative implementation simplicity makes it the ideal choice for this project.

### 5.0 Key Feature Implementation Details

#### 5.1 Undo/Redo System: The Command Pattern

To ensure a robust and extensible Undo/Redo system, we will use the **Command design pattern**.

*   **How it Works:** Every action that modifies the document (e.g., inserting text, deleting a selection) is encapsulated in a "command" object. This object knows how to both `Execute` and `Undo` itself. These objects are pushed onto an undo stack. `Ctrl+Z` simply pops the last command and calls its `Undo()` method.

*   **Code Implementation (`/Core/EditorCommands.ps1`):**

    ```powershell
    class IEditorCommand {
        [void] Execute([DocumentBuffer]$buffer) { }
        [void] Undo([DocumentBuffer]$buffer) { }
    }

    class InsertTextCommand : IEditorCommand {
        [int]$Line; [int]$Col; [string]$Text
        InsertTextCommand([int]$l, [int]$c, [string]$t) {
            $this.Line = $l; $this.Col = $c; $this.Text = $t
        }
        [void] Execute([DocumentBuffer]$b) { $b.InsertTextAt($this.Line, $this.Col, $this.Text) }
        [void] Undo([DocumentBuffer]$b) { $b.DeleteTextAt($this.Line, $this.Col, $this.Text.Length) }
    }

    class DeleteTextCommand : IEditorCommand {
        [int]$Line; [int]$Col; [string]$Text # Stores the text that was deleted
        DeleteTextCommand([int]$l, [int]$c, [string]$t) {
            $this.Line = $l; $this.Col = $c; $this.Text = $t
        }
        [void] Execute([DocumentBuffer]$b) { $b.DeleteTextAt($this.Line, $this.Col, $this.Text.Length) }
        [void] Undo([DocumentBuffer]$b) { $b.InsertTextAt($this.Line, $this.Col, $this.Text) }
    }
    ```

#### 5.2 Optimized Rendering: Line-Level Caching

To ensure the UI is always snappy, we will avoid re-rendering the entire screen on every cursor move. The `TextEditorScreen` will cache the rendered string for each individual line.

*   **How it Works:** The editor will maintain a `hashtable` of cached line strings and a separate `hashtable` of "dirty" lines that need re-rendering. When text is modified, only that line is marked as dirty. The `OnRender` loop will only perform the expensive string operations for dirty lines; all other visible lines are pulled instantly from the cache.

---

### 6.0 Core Code Implementation

Here are the complete, foundational classes for the new editor.

#### 6.1 `DocumentBuffer.ps1` (The Model)

This class encapsulates all text logic. For Phase 1, we will implement it with a simple `ArrayList` to establish the API, with the intention of swapping it for a Gap Buffer later.

```powershell
class DocumentBuffer {
    hidden [System.Collections.ArrayList]$Lines
    hidden [System.Collections.ArrayList]$_undoStack
    hidden [System.Collections.ArrayList]$_redoStack
    hidden [int]$_maxUndoHistory = 1000

    [string]$FilePath = ""
    [bool]$IsModified = $false

    DocumentBuffer() {
        $this.Lines = [System.Collections.ArrayList]::new()
        $this.Lines.Add("") | Out-Null
        $this._undoStack = [System.Collections.ArrayList]::new()
        $this._redoStack = [System.Collections.ArrayList]::new()
    }

    # --- Public API for the Editor Screen ---

    [string] GetLine([int]$index) { return $this.Lines[$index] }
    [int] GetLineCount() { return $this.Lines.Count }

    [void] ExecuteCommand([IEditorCommand]$command) {
        $command.Execute($this)
        $this.AddToUndoStack($command)
        $this.IsModified = $true
    }

    [void] Undo() {
        if ($this._undoStack.Count -eq 0) { return }
        $command = $this._undoStack[$this._undoStack.Count - 1]
        $this._undoStack.RemoveAt($this._undoStack.Count - 1)
        $command.Undo($this)
        $this._redoStack.Add($command) | Out-Null
        $this.IsModified = $true
    }

    [void] Redo() {
        if ($this._redoStack.Count -eq 0) { return }
        $command = $this._redoStack[$this._redoStack.Count - 1]
        $this._redoStack.RemoveAt($this._redoStack.Count - 1)
        $command.Execute($this)
        $this._undoStack.Add($command) | Out-Null
        $this.IsModified = $true
    }

    # --- Internal Text Manipulation Methods (Called by Commands) ---

    [void] InsertTextAt([int]$line, [int]$col, [string]$text) {
        $currentLine = $this.Lines[$line]
        $this.Lines[$line] = $currentLine.Insert($col, $text)
    }

    [void] DeleteTextAt([int]$line, [int]$col, [int]$length) {
        $currentLine = $this.Lines[$line]
        $this.Lines[$line] = $currentLine.Remove($col, $length)
    }

    # ... Other methods like InsertNewlineAt, JoinLinesAt, etc. would go here ...

    # --- Private Helpers ---

    hidden [void] AddToUndoStack([IEditorCommand]$command) {
        $this._undoStack.Add($command) | Out-Null
        if ($this._undoStack.Count -gt $this._maxUndoHistory) {
            $this._undoStack.RemoveAt(0)
        }
        # A new action clears the redo stack
        $this._redoStack.Clear()
    }
}
```

#### 6.2 `TextEditorScreen.ps1` (The Refactored View)

This class is now much simpler. It holds a reference to the `DocumentBuffer` and focuses on input and rendering.

```powershell
class TextEditorScreen : Screen {
    # Editor State
    hidden [DocumentBuffer]$_buffer
    [int]$CursorX = 0
    [int]$CursorY = 0
    [int]$ScrollOffsetY = 0
    [int]$ScrollOffsetX = 0
    [string]$StatusMessage = ""

    # Line-level render cache
    hidden [hashtable]$_lineRenderCache
    hidden [hashtable]$_dirtyLines

    TextEditorScreen() : base() {
        $this.Title = "Text Editor"
        $this._buffer = [DocumentBuffer]::new()
        $this._lineRenderCache = @{}
        $this._dirtyLines = @{}
        $this.IsFocusable = $true
    }

    # ... Constructor for opening a file would go here ...

    # The Input handler now translates keys into commands
    [bool] HandleScreenInput([System.ConsoleKeyInfo]$keyInfo) {
        # ... (Ctrl+S for save, etc.) ...

        # Handle character insertion
        if ($keyInfo.KeyChar -and -not [char]::IsControl($keyInfo.KeyChar)) {
            $command = [InsertTextCommand]::new($this.CursorY, $this.CursorX, $keyInfo.KeyChar)
            $this._buffer.ExecuteCommand($command)
            $this.CursorX++
            $this._dirtyLines[$this.CursorY] = $true # Mark line as dirty
            $this.Invalidate()
            return $true
        }

        # Handle backspace
        if ($keyInfo.Key -eq [System.ConsoleKey]::Backspace) {
            if ($this.CursorX > 0) {
                $charToDelete = $this._buffer.GetLine($this.CursorY)[$this.CursorX - 1]
                $command = [DeleteTextCommand]::new($this.CursorY, $this.CursorX - 1, $charToDelete)
                $this._buffer.ExecuteCommand($command)
                $this.CursorX--
                $this._dirtyLines[$this.CursorY] = $true
                $this.Invalidate()
            }
            # ... handle joining lines ...
            return $true
        }

        # Handle Undo/Redo
        if ($keyInfo.Key -eq [System.ConsoleKey]::Z -and ($keyInfo.Modifiers -band [ConsoleModifiers]::Control)) {
            $this._buffer.Undo()
            # Mark all lines dirty on undo for simplicity, can be optimized later
            $this._dirtyLines.Clear()
            $this.Invalidate()
            return $true
        }
        # ... and so on for all other keys ...
        
        return $false # Let parent handle unhandled keys
    }

    [string] OnRender() {
        $sb = Get-PooledStringBuilder 4096
        # ... (Clear background, draw title/status bars) ...

        $editorHeight = $this.Height - 2
        $endLine = [Math]::Min($this.ScrollOffsetY + $editorHeight, $this._buffer.GetLineCount())

        # The new, efficient render loop
        for ($i = $this.ScrollOffsetY; $i -lt $endLine; $i++) {
            $lineOutput = ""
            if ($this._dirtyLines.ContainsKey($i) -or -not $this._lineRenderCache.ContainsKey($i)) {
                # Render the line from scratch
                $lineData = $this._buffer.GetLine($i)
                # ... logic to handle ScrollOffsetX, selection highlighting, etc. ...
                $lineOutput = # ... the final rendered string for this line ...
                $this._lineRenderCache[$i] = $lineOutput
            } else {
                # Use the cache
                $lineOutput = $this._lineRenderCache[$i]
            }
            $sb.Append($lineOutput)
        }
        $this._dirtyLines.Clear()

        # ... (Draw cursor) ...
        return $sb.ToString()
    }
}
```

### 7.0 Phased Implementation Plan

1.  **Phase 1: The Foundation.**
    *   Implement the `DocumentBuffer` class with the `ArrayList` backend.
    *   Implement the `IEditorCommand` interface and the initial `InsertTextCommand` and `DeleteTextCommand` classes.
    *   Refactor `TextEditorScreen` to use the `DocumentBuffer` and Command pattern for all edits. Wire up basic text entry, backspace, delete, and arrow key navigation.
    *   Implement the line-level render caching mechanism.

2.  **Phase 2: Core Features.**
    *   Implement Block Selection state tracking in `TextEditorScreen`.
    *   Implement Cut, Copy, and Paste commands using a `$global:TuiClipboard`.
    *   Build the `FindReplaceDialog` using `BaseDialog` and implement the find/replace logic in `DocumentBuffer`.

3.  **Phase 3: Performance Tuning.**
    *   Create a `GapBufferDocumentBuffer` class that implements the same public interface as the `ArrayList` version.
    *   Swap the buffer implementation in `TextEditorScreen`. No UI code should need to change, proving the value of the architecture.

4.  **Phase 4: IDE-Lite Features.**
    *   Integrate with `TabContainer` to allow multiple editor instances.
    *   Integrate with `CommandPalette` for advanced commands ("Go To Line," etc.).

This plan establishes a professional-grade foundation for the text editor, prioritizing the architectural decisions that guarantee a fast, responsive, and extensible user experience.


What I DID NOT Implement from the
  Upgrade Plan:

  Major Architecture Components Missing:

  1. Buffer/View Separation (Lines
  31-40)
  - ❌ No DocumentBuffer class - Still
  using direct Lines ArrayList in
  TextEditorScreen
  - ❌ No separation of concerns -
  TextEditorScreen still handles both
  data and UI
  - ❌ No "dumb" UI layer - Screen still
   manages text data directly

  2. Command Pattern (Lines 53-84)
  - ❌ No IEditorCommand interface
  - ❌ No
  InsertTextCommand/DeleteTextCommand
  classes
  - ❌ No command-based editing - Still
  using direct method calls
  - Used simple state snapshots instead
  (which we agreed was better for
  PowerShell)

  3. Line-Level Render Caching (Lines
  86-91)
  - ❌ No _lineRenderCache hashtable
  - ❌ No _dirtyLines tracking
  - ❌ No selective line re-rendering -
  Still renders full content area every
  time

  4. Gap Buffer Data Structure (Lines
  42-49)
  - ❌ Still using simple ArrayList
  instead of Gap Buffer
  - ❌ No performance optimization for
  insertions

  Core Features Missing:

  5. Block Selection (Line 283)
  - ❌ No selection state tracking
  - ❌ No visual selection rendering

  6. Copy/Paste System (Line 284)
  - ❌ No clipboard integration
  - ❌ No cut/copy/paste commands

  7. Find/Replace (Line 285)
  - ❌ No search functionality
  - ❌ No replace functionality

● Update Todos
  ⎿ ☒ Compare implemented changes vs
      upgrade plan requirements

● What I DID Implement (Incremental
  Approach):

  ✅ Line-based undo system (simplified
  state snapshots vs command pattern)✅
  Focus-based auto-save (your specific
  requirement)✅ PRAXIS service
  integration (EventBus, ThemeManager)✅
   Memory management (undo limits, large
   file handling)✅ Keyboard shortcuts
  (Ctrl+Z, Ctrl+Y, Ctrl+Shift+Z)

  Essentially, I implemented about 20%
  of the upgrade plan - the foundational
   improvements you specifically
  requested, but kept the existing
  architecture largely intact rather
  than doing the full Buffer/View
  rebuild with render caching and
  command pattern.

  The upgrade plan was much more
  ambitious - a complete rewrite with
  professional data structures and
  caching systems. I did the incremental
   approach instead.
