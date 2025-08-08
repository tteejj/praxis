# FullNotesEditor.ps1 - Full-featured text editor wrapper for task notes
# Uses the complete text editor from Praxis with gap buffer, undo/redo, etc.
# NOTE: UniversalBackupManager is loaded by main SimpleTaskPro.ps1

class FullNotesEditor {
    # The actual text content using gap buffer
    hidden [GapBuffer]$_gapBuffer
    
    # Line tracking for efficient operations
    hidden [System.Collections.ArrayList]$_lineStarts
    hidden [bool]$_lineIndexDirty = $true
    
    # UI state
    [int]$X
    [int]$Y  
    [int]$Width
    [int]$Height
    [int]$CursorX = 0
    [int]$CursorY = 0
    [int]$ScrollOffsetY = 0
    [int]$ScrollOffsetX = 0
    
    # Selection state
    [bool]$HasSelection = $false
    [int]$SelectionStartX = 0
    [int]$SelectionStartY = 0
    [int]$SelectionEndX = 0
    [int]$SelectionEndY = 0
    
    # Undo/redo with full state tracking
    hidden [System.Collections.ArrayList]$_undoStack
    hidden [System.Collections.ArrayList]$_redoStack
    
    # Editor settings
    [int]$TabWidth = 4
    [bool]$Modified = $false
    
    # Auto-save and safety features
    [bool]$AutoSaveOnFocusLoss = $true
    [bool]$CreateBackupOnOpen = $true
    [string]$BackupDirectory = ""
    hidden [string]$_originalText = ""
    hidden [datetime]$_lastSaveTime = [datetime]::MinValue
    
    FullNotesEditor() {
        $this._gapBuffer = [GapBuffer]::new()
        $this._gapBuffer.Insert(0, "")  # Start with empty content
        $this._lineStarts = [System.Collections.ArrayList]::new()
        $this._undoStack = [System.Collections.ArrayList]::new()
        $this._redoStack = [System.Collections.ArrayList]::new()
        $this.BuildLineIndex()
        
        # Initialize universal backup system
        [UniversalBackupManager]::Initialize($PSScriptRoot + "/..")
        
        # Set up legacy backup directory (for compatibility)
        $this.BackupDirectory = Join-Path $PSScriptRoot ".." "Data" "backups"
        if (-not (Test-Path $this.BackupDirectory)) {
            New-Item -ItemType Directory -Path $this.BackupDirectory -Force | Out-Null
        }
    }
    
    [void] SetBounds([int]$x, [int]$y, [int]$width, [int]$height) {
        $this.X = $x
        $this.Y = $y
        $this.Width = $width
        $this.Height = $height
    }
    
    [void] SetText([string]$text) {
        # Store original text for comparison
        $this._originalText = $text
        
        # Create backup if text is not empty
        if (-not [string]::IsNullOrEmpty($text) -and $this.CreateBackupOnOpen) {
            $this.CreateBackup($text)
        }
        
        # Clear buffer and insert new text
        $this._gapBuffer.Delete(0, $this._gapBuffer.GetLength())
        if ([string]::IsNullOrEmpty($text)) {
            $this._gapBuffer.Insert(0, "")
        } else {
            $this._gapBuffer.Insert(0, $text)
        }
        
        $this.BuildLineIndex()
        $this.CursorX = 0
        $this.CursorY = 0
        $this.ScrollOffsetY = 0
        $this.ScrollOffsetX = 0
        $this.Modified = $false
        $this._undoStack.Clear()
        $this._redoStack.Clear()
        $this._lastSaveTime = [datetime]::Now
    }
    
    [string] GetText() {
        return $this._gapBuffer.GetText()
    }
    
    # BULLETPROOF FILE EDITING: Auto-save on ANY exit
    [void] EnableAutoSaveForFile([string]$filePath, [string]$identifier = "") {
        $autoSaveKey = "notes_$filePath"
        
        # Register auto-save action
        $editorInstance = $this  # Capture the current instance
        [UniversalBackupManager]::RegisterAutoSave(
            $autoSaveKey,
            $filePath,
            { 
                $content = $editorInstance.GetText()
                [UniversalBackupManager]::AtomicSave($filePath, $content, "notes", $identifier)
            }.GetNewClosure(),
            "notes"
        )
    }
    
    [void] DisableAutoSaveForFile([string]$filePath) {
        $autoSaveKey = "notes_$filePath"
        [UniversalBackupManager]::UnregisterAutoSave($autoSaveKey)
    }
    
    # Build line index for efficient line operations
    hidden [void] BuildLineIndex() {
        $this._lineStarts.Clear()
        $this._lineStarts.Add(0) | Out-Null  # First line starts at position 0
        
        $length = $this._gapBuffer.GetLength()
        for ($i = 0; $i -lt $length; $i++) {
            if ($this._gapBuffer.GetChar($i) -eq "`n") {
                $this._lineStarts.Add($i + 1) | Out-Null
            }
        }
        
        # Add a final line if text doesn't end with newline
        if ($length -gt 0 -and $this._gapBuffer.GetChar($length - 1) -ne "`n") {
            # Last line already counted
        }
        
        $this._lineIndexDirty = $false
    }
    
    [int] GetLineCount() {
        if ($this._lineIndexDirty) {
            $this.BuildLineIndex()
        }
        return [Math]::Max(1, $this._lineStarts.Count)
    }
    
    [string] GetLine([int]$lineIndex) {
        if ($this._lineIndexDirty) {
            $this.BuildLineIndex()
        }
        
        if ($lineIndex -lt 0 -or $lineIndex -ge $this.GetLineCount()) {
            return ""
        }
        
        $lineStart = $this._lineStarts[$lineIndex]
        $lineEnd = if ($lineIndex + 1 -lt $this._lineStarts.Count) {
            $this._lineStarts[$lineIndex + 1] - 1
        } else {
            $this._gapBuffer.GetLength()
        }
        
        # Exclude the newline character
        if ($lineEnd -gt $lineStart -and $this._gapBuffer.GetChar($lineEnd - 1) -eq "`n") {
            $lineEnd--
        }
        
        $lineLength = [Math]::Max(0, $lineEnd - $lineStart)
        if ($lineLength -eq 0) {
            return ""
        }
        
        return $this._gapBuffer.GetText($lineStart, $lineLength)
    }
    
    # Get position in buffer from line/column
    hidden [int] GetPositionFromLineCol([int]$line, [int]$col) {
        if ($this._lineIndexDirty) {
            $this.BuildLineIndex()
        }
        
        if ($line -lt 0 -or $line -ge $this.GetLineCount()) {
            return -1
        }
        
        $lineStart = $this._lineStarts[$line]
        $lineText = $this.GetLine($line)
        $actualCol = [Math]::Min($col, $lineText.Length)
        
        return $lineStart + $actualCol
    }
    
    [string] Render() {
        $sb = [System.Text.StringBuilder]::new()
        
        # Get visible lines
        $lineCount = $this.GetLineCount()
        $visibleLines = [Math]::Min($this.Height, $lineCount - $this.ScrollOffsetY)
        
        # Render each visible line
        for ($i = 0; $i -lt $this.Height; $i++) {
            $lineIndex = $this.ScrollOffsetY + $i
            [void]$sb.Append([VT]::MoveTo($this.X, $this.Y + $i))
            
            if ($lineIndex -lt $lineCount) {
                $line = $this.GetLine($lineIndex)
                
                # Handle horizontal scrolling
                if ($this.ScrollOffsetX -lt $line.Length) {
                    $visibleText = $line.Substring($this.ScrollOffsetX)
                    if ($visibleText.Length -gt $this.Width) {
                        $visibleText = $visibleText.Substring(0, $this.Width)
                    }
                    
                    # Handle selection highlighting
                    if ($this.HasSelection) {
                        $this.RenderLineWithSelection($sb, $visibleText, $lineIndex)
                    } else {
                        [void]$sb.Append($visibleText)
                    }
                }
            }
            
            # Clear rest of line
            [void]$sb.Append([VT]::ClearToEnd())
        }
        
        # Position cursor
        $cursorScreenX = $this.X + $this.CursorX - $this.ScrollOffsetX
        $cursorScreenY = $this.Y + $this.CursorY - $this.ScrollOffsetY
        
        if ($cursorScreenX -ge $this.X -and $cursorScreenX -lt ($this.X + $this.Width) -and
            $cursorScreenY -ge $this.Y -and $cursorScreenY -lt ($this.Y + $this.Height)) {
            [void]$sb.Append([VT]::MoveTo($cursorScreenX, $cursorScreenY))
            [void]$sb.Append([VT]::ShowCursor())
        }
        
        return $sb.ToString()
    }
    
    [void] RenderLineWithSelection([System.Text.StringBuilder]$sb, [string]$text, [int]$lineIndex) {
        # Simplified selection rendering - just show the text for now
        [void]$sb.Append($text)
    }
    
    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        $handled = $true
        
        # Save state for undo before modifications
        if (-not ($key.Key -in @([System.ConsoleKey]::LeftArrow, [System.ConsoleKey]::RightArrow, 
                                  [System.ConsoleKey]::UpArrow, [System.ConsoleKey]::DownArrow,
                                  [System.ConsoleKey]::Home, [System.ConsoleKey]::End))) {
            $this.SaveUndoState()
        }
        
        switch ($key.Key) {
            # Navigation
            ([System.ConsoleKey]::LeftArrow) { 
                if ($key.Modifiers -band [System.ConsoleModifiers]::Control) {
                    $this.MoveCursorWordLeft()
                } else {
                    $this.MoveCursorLeft() 
                }
            }
            ([System.ConsoleKey]::RightArrow) { 
                if ($key.Modifiers -band [System.ConsoleModifiers]::Control) {
                    $this.MoveCursorWordRight()
                } else {
                    $this.MoveCursorRight() 
                }
            }
            ([System.ConsoleKey]::UpArrow) { $this.MoveCursorUp() }
            ([System.ConsoleKey]::DownArrow) { $this.MoveCursorDown() }
            ([System.ConsoleKey]::Home) { 
                if ($key.Modifiers -band [System.ConsoleModifiers]::Control) {
                    $this.CursorX = 0
                    $this.CursorY = 0
                    $this.EnsureCursorVisible()
                } else {
                    $this.CursorX = 0
                    $this.EnsureCursorVisible()
                }
            }
            ([System.ConsoleKey]::End) { 
                if ($key.Modifiers -band [System.ConsoleModifiers]::Control) {
                    $this.CursorY = $this.GetLineCount() - 1
                    $this.CursorX = $this.GetLine($this.CursorY).Length
                    $this.EnsureCursorVisible()
                } else {
                    $this.CursorX = $this.GetLine($this.CursorY).Length
                    $this.EnsureCursorVisible()
                }
            }
            ([System.ConsoleKey]::PageUp) {
                $this.CursorY = [Math]::Max(0, $this.CursorY - $this.Height)
                $this.EnsureCursorVisible()
            }
            ([System.ConsoleKey]::PageDown) {
                $this.CursorY = [Math]::Min($this.GetLineCount() - 1, $this.CursorY + $this.Height)
                $this.EnsureCursorVisible()
            }
            
            # Editing
            ([System.ConsoleKey]::Enter) { $this.InsertNewLine() }
            ([System.ConsoleKey]::Backspace) { $this.Backspace() }
            ([System.ConsoleKey]::Delete) { $this.Delete() }
            ([System.ConsoleKey]::Tab) { $this.InsertTab() }
            
            # Undo/Redo
            ([System.ConsoleKey]::Z) {
                if ($key.Modifiers -band [System.ConsoleModifiers]::Control) {
                    $this.Undo()
                } else {
                    $this.InsertChar($key.KeyChar)
                }
            }
            ([System.ConsoleKey]::Y) {
                if ($key.Modifiers -band [System.ConsoleModifiers]::Control) {
                    $this.Redo()
                } else {
                    $this.InsertChar($key.KeyChar)
                }
            }
            
            # Select All
            ([System.ConsoleKey]::A) {
                if ($key.Modifiers -band [System.ConsoleModifiers]::Control) {
                    $this.SelectAll()
                } else {
                    $this.InsertChar($key.KeyChar)
                }
            }
            
            default {
                if ($key.KeyChar -and -not [char]::IsControl($key.KeyChar)) {
                    $this.InsertChar($key.KeyChar)
                } else {
                    $handled = $false
                }
            }
        }
        
        return $handled
    }
    
    # Cursor movement methods
    [void] MoveCursorLeft() {
        if ($this.CursorX -gt 0) {
            $this.CursorX--
        } elseif ($this.CursorY -gt 0) {
            $this.CursorY--
            $this.CursorX = $this.GetLine($this.CursorY).Length
        }
        $this.EnsureCursorVisible()
    }
    
    [void] MoveCursorRight() {
        $lineLength = $this.GetLine($this.CursorY).Length
        if ($this.CursorX -lt $lineLength) {
            $this.CursorX++
        } elseif ($this.CursorY -lt ($this.GetLineCount() - 1)) {
            $this.CursorY++
            $this.CursorX = 0
        }
        $this.EnsureCursorVisible()
    }
    
    [void] MoveCursorUp() {
        if ($this.CursorY -gt 0) {
            $this.CursorY--
            $lineLength = $this.GetLine($this.CursorY).Length
            $this.CursorX = [Math]::Min($this.CursorX, $lineLength)
        }
        $this.EnsureCursorVisible()
    }
    
    [void] MoveCursorDown() {
        if ($this.CursorY -lt ($this.GetLineCount() - 1)) {
            $this.CursorY++
            $lineLength = $this.GetLine($this.CursorY).Length
            $this.CursorX = [Math]::Min($this.CursorX, $lineLength)
        }
        $this.EnsureCursorVisible()
    }
    
    [void] MoveCursorWordLeft() {
        # Move to previous word boundary
        $line = $this.GetLine($this.CursorY)
        if ($this.CursorX -gt 0) {
            # Skip current word
            while ($this.CursorX -gt 0 -and $line[$this.CursorX - 1] -match '\w') {
                $this.CursorX--
            }
            # Skip whitespace
            while ($this.CursorX -gt 0 -and $line[$this.CursorX - 1] -match '\s') {
                $this.CursorX--
            }
            # Move to start of previous word
            while ($this.CursorX -gt 0 -and $line[$this.CursorX - 1] -match '\w') {
                $this.CursorX--
            }
        } elseif ($this.CursorY -gt 0) {
            $this.MoveCursorLeft()
        }
        $this.EnsureCursorVisible()
    }
    
    [void] MoveCursorWordRight() {
        # Move to next word boundary
        $line = $this.GetLine($this.CursorY)
        if ($this.CursorX -lt $line.Length) {
            # Skip current word
            while ($this.CursorX -lt $line.Length -and $line[$this.CursorX] -match '\w') {
                $this.CursorX++
            }
            # Skip whitespace
            while ($this.CursorX -lt $line.Length -and $line[$this.CursorX] -match '\s') {
                $this.CursorX++
            }
        } elseif ($this.CursorY -lt ($this.GetLineCount() - 1)) {
            $this.MoveCursorRight()
        }
        $this.EnsureCursorVisible()
    }
    
    # Editing methods using gap buffer
    [void] InsertChar([char]$char) {
        $position = $this.GetPositionFromLineCol($this.CursorY, $this.CursorX)
        $this._gapBuffer.Insert($position, $char.ToString())
        $this._lineIndexDirty = $true
        $this.CursorX++
        $this.Modified = $true
        $this.EnsureCursorVisible()
    }
    
    [void] InsertNewLine() {
        $position = $this.GetPositionFromLineCol($this.CursorY, $this.CursorX)
        $this._gapBuffer.Insert($position, "`n")
        $this._lineIndexDirty = $true
        $this.CursorY++
        $this.CursorX = 0
        $this.Modified = $true
        $this.EnsureCursorVisible()
    }
    
    [void] InsertTab() {
        $spaces = " " * $this.TabWidth
        $position = $this.GetPositionFromLineCol($this.CursorY, $this.CursorX)
        $this._gapBuffer.Insert($position, $spaces)
        $this._lineIndexDirty = $true
        $this.CursorX += $this.TabWidth
        $this.Modified = $true
        $this.EnsureCursorVisible()
    }
    
    [void] Backspace() {
        if ($this.CursorX -gt 0) {
            $position = $this.GetPositionFromLineCol($this.CursorY, $this.CursorX - 1)
            $this._gapBuffer.Delete($position, 1)
            $this._lineIndexDirty = $true
            $this.CursorX--
            $this.Modified = $true
        } elseif ($this.CursorY -gt 0) {
            # Join with previous line
            $this.CursorY--
            $this.CursorX = $this.GetLine($this.CursorY).Length
            $position = $this.GetPositionFromLineCol($this.CursorY, $this.CursorX)
            $this._gapBuffer.Delete($position, 1)  # Delete the newline
            $this._lineIndexDirty = $true
            $this.Modified = $true
        }
        $this.EnsureCursorVisible()
    }
    
    [void] Delete() {
        $lineLength = $this.GetLine($this.CursorY).Length
        if ($this.CursorX -lt $lineLength) {
            $position = $this.GetPositionFromLineCol($this.CursorY, $this.CursorX)
            $this._gapBuffer.Delete($position, 1)
            $this._lineIndexDirty = $true
            $this.Modified = $true
        } elseif ($this.CursorY -lt ($this.GetLineCount() - 1)) {
            # Join with next line
            $position = $this.GetPositionFromLineCol($this.CursorY, $this.CursorX)
            $this._gapBuffer.Delete($position, 1)  # Delete the newline
            $this._lineIndexDirty = $true
            $this.Modified = $true
        }
    }
    
    # Selection
    [void] SelectAll() {
        $this.HasSelection = $true
        $this.SelectionStartX = 0
        $this.SelectionStartY = 0
        $lastLine = $this.GetLineCount() - 1
        $this.SelectionEndY = $lastLine
        $this.SelectionEndX = $this.GetLine($lastLine).Length
    }
    
    # Undo/Redo
    [void] SaveUndoState() {
        $state = @{
            Text = $this._gapBuffer.GetText()
            CursorX = $this.CursorX
            CursorY = $this.CursorY
        }
        $this._undoStack.Add($state)
        $this._redoStack.Clear()
        
        # Limit undo stack size
        if ($this._undoStack.Count -gt 100) {
            $this._undoStack.RemoveAt(0)
        }
    }
    
    [void] Undo() {
        if ($this._undoStack.Count -gt 0) {
            # Save current state to redo stack
            $currentState = @{
                Text = $this._gapBuffer.GetText()
                CursorX = $this.CursorX
                CursorY = $this.CursorY
            }
            $this._redoStack.Add($currentState)
            
            # Restore previous state
            $state = $this._undoStack[$this._undoStack.Count - 1]
            $this._undoStack.RemoveAt($this._undoStack.Count - 1)
            
            $this.SetText($state.Text)
            $this.CursorX = $state.CursorX
            $this.CursorY = $state.CursorY
            $this.Modified = $true
            $this.EnsureCursorVisible()
        }
    }
    
    [void] Redo() {
        if ($this._redoStack.Count -gt 0) {
            # Save current state to undo stack
            $currentState = @{
                Text = $this._gapBuffer.GetText()
                CursorX = $this.CursorX
                CursorY = $this.CursorY
            }
            $this._undoStack.Add($currentState)
            
            # Restore next state
            $state = $this._redoStack[$this._redoStack.Count - 1]
            $this._redoStack.RemoveAt($this._redoStack.Count - 1)
            
            $this.SetText($state.Text)
            $this.CursorX = $state.CursorX
            $this.CursorY = $state.CursorY
            $this.Modified = $true
            $this.EnsureCursorVisible()
        }
    }
    
    [void] EnsureCursorVisible() {
        # Vertical scrolling
        if ($this.CursorY -lt $this.ScrollOffsetY) {
            $this.ScrollOffsetY = $this.CursorY
        } elseif ($this.CursorY -ge ($this.ScrollOffsetY + $this.Height)) {
            $this.ScrollOffsetY = $this.CursorY - $this.Height + 1
        }
        
        # Horizontal scrolling
        if ($this.CursorX -lt $this.ScrollOffsetX) {
            $this.ScrollOffsetX = $this.CursorX
        } elseif ($this.CursorX -ge ($this.ScrollOffsetX + $this.Width)) {
            $this.ScrollOffsetX = $this.CursorX - $this.Width + 1
        }
    }
    
    # Safety features
    [void] CreateBackup([string]$content) {
        # Use UniversalBackupManager for bulletproof backups
        try {
            # Create temporary file for backup
            $tempFile = Join-Path ([System.IO.Path]::GetTempPath()) "notes_temp_$([Guid]::NewGuid().ToString('N')[0..7] -join '').txt"
            [System.IO.File]::WriteAllText($tempFile, $content)
            
            # Use universal backup system
            [UniversalBackupManager]::CreateBackup("notes", $tempFile, "editor")
            
            # Cleanup temp file
            Remove-Item -Path $tempFile -Force -ErrorAction SilentlyContinue
        } catch {
            # Silently fail - don't interrupt editing
        }
    }
    
    [string] AtomicSave([string]$content, [string]$targetPath) {
        $tempFile = "$targetPath.tmp"
        try {
            # Write to temp file
            [System.IO.File]::WriteAllText($tempFile, $content)
            
            # Atomic rename
            Move-Item -Path $tempFile -Destination $targetPath -Force
            
            $this._lastSaveTime = [datetime]::Now
            return ""  # Success
        } catch {
            # Clean up temp file if it exists
            if (Test-Path $tempFile) {
                Remove-Item -Path $tempFile -Force -ErrorAction SilentlyContinue
            }
            return $_.Exception.Message
        }
    }
    
    [bool] HasUnsavedChanges() {
        if (-not $this.Modified) {
            return $false
        }
        
        $currentText = $this.GetText()
        return $currentText -ne $this._originalText
    }
    
    [void] AutoSaveIfNeeded([string]$taskId = "") {
        if ($this.HasUnsavedChanges()) {
            # Create task-specific auto-save file
            $autoSaveFileName = if ($taskId) { "autosave_notes_$taskId.txt" } else { "autosave_notes.txt" }
            $autoSaveFile = Join-Path $this.BackupDirectory $autoSaveFileName
            $this.AtomicSave($this.GetText(), $autoSaveFile)
        }
    }
    
    [string] RecoverAutoSave([string]$taskId = "") {
        # Try task-specific autosave first, then general autosave
        $autoSaveFiles = @()
        if ($taskId) {
            $autoSaveFiles += Join-Path $this.BackupDirectory "autosave_notes_$taskId.txt"
        }
        $autoSaveFiles += Join-Path $this.BackupDirectory "autosave_notes.txt"
        
        foreach ($autoSaveFile in $autoSaveFiles) {
            if (Test-Path $autoSaveFile) {
                try {
                    $content = [System.IO.File]::ReadAllText($autoSaveFile)
                    # Delete auto-save after recovery
                    Remove-Item -Path $autoSaveFile -Force
                    return $content
                } catch {
                    continue
                }
            }
        }
        return ""
    }
    
    [void] OnFocusLost([string]$taskId = "") {
        if ($this.AutoSaveOnFocusLoss -and $this.HasUnsavedChanges()) {
            $this.AutoSaveIfNeeded($taskId)
        }
    }
    
    [void] OnExit([string]$taskId = "") {
        # Always auto-save on exit if there are changes
        if ($this.HasUnsavedChanges()) {
            $this.AutoSaveIfNeeded($taskId)
        }
    }
}