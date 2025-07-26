# GapBufferDocumentBuffer.ps1 - High-performance document buffer using Gap Buffer
# Drop-in replacement for DocumentBuffer with identical public interface but better performance

class GapBufferDocumentBuffer {
    # Gap buffer for high-performance text storage
    hidden [GapBuffer]$_gapBuffer
    
    # Line index tracking for efficient line operations
    hidden [System.Collections.ArrayList]$_lineStarts
    hidden [bool]$_lineIndexDirty = $true
    
    # Command-based undo/redo system  
    hidden [System.Collections.ArrayList]$_undoStack
    hidden [System.Collections.ArrayList]$_redoStack
    hidden [int]$_maxUndoHistory = 1000
    
    # File state
    [string]$FilePath = ""
    [bool]$IsModified = $false
    [datetime]$LastModified = [datetime]::MinValue
    
    # Change tracking for render optimization
    hidden [System.Collections.Generic.HashSet[int]]$_dirtyLines
    hidden [bool]$_allLinesDirty = $true
    
    # Events for UI updates
    [scriptblock]$OnContentChanged = {}
    [scriptblock]$OnModifiedStateChanged = {}
    
    # Performance tracking
    [int]$LineIndexRebuildCount = 0
    
    GapBufferDocumentBuffer() {
        $this._gapBuffer = [GapBuffer]::new()
        $this._gapBuffer.Insert(0, "`n")  # Start with one empty line
        $this._lineStarts = [System.Collections.ArrayList]::new()
        $this._undoStack = [System.Collections.ArrayList]::new()
        $this._redoStack = [System.Collections.ArrayList]::new()
        $this._dirtyLines = [System.Collections.Generic.HashSet[int]]::new()
        $this.BuildLineIndex()
        $this.UpdateLinesProperty()
    }
    
    GapBufferDocumentBuffer([string]$filePath) {
        $this._gapBuffer = [GapBuffer]::new()
        $this._lineStarts = [System.Collections.ArrayList]::new()
        $this._undoStack = [System.Collections.ArrayList]::new()
        $this._redoStack = [System.Collections.ArrayList]::new()
        $this._dirtyLines = [System.Collections.Generic.HashSet[int]]::new()
        $this.FilePath = $filePath
        $this.LoadFromFile($filePath)
        $this.UpdateLinesProperty()
    }
    
    # --- Line Index Management ---
    
    hidden [void] BuildLineIndex() {
        $this._lineStarts.Clear()
        $this._lineStarts.Add(0) | Out-Null  # First line starts at position 0
        
        $length = $this._gapBuffer.GetLength()
        for ($i = 0; $i -lt $length; $i++) {
            if ($this._gapBuffer.GetChar($i) -eq "`n") {
                $this._lineStarts.Add($i + 1) | Out-Null
            }
        }
        
        $this._lineIndexDirty = $false
        $this.LineIndexRebuildCount++
    }
    
    hidden [void] EnsureLineIndex() {
        if ($this._lineIndexDirty) {
            $this.BuildLineIndex()
        }
    }
    
    hidden [void] InvalidateLineIndex() {
        $this._lineIndexDirty = $true
        $this._allLinesDirty = $true
    }
    
    # --- Public API for TextEditorScreen (Compatible with DocumentBuffer) ---
    
    [string] GetLine([int]$index) {
        $this.EnsureLineIndex()
        
        if ($index -lt 0 -or $index -ge $this._lineStarts.Count) {
            return ""
        }
        
        $lineStart = $this._lineStarts[$index]
        
        # Find line end
        if ($index -eq $this._lineStarts.Count - 1) {
            # Last line - goes to end of buffer
            $lineEnd = $this._gapBuffer.GetLength()
        } else {
            # Line ends at the position before next line start (excluding the newline)
            $lineEnd = $this._lineStarts[$index + 1] - 1
        }
        
        $lineLength = $lineEnd - $lineStart
        if ($lineLength -le 0) {
            return ""
        }
        
        return $this._gapBuffer.GetText($lineStart, $lineLength)
    }
    
    [int] GetLineCount() {
        $this.EnsureLineIndex()
        return $this._lineStarts.Count
    }
    
    [bool] IsLineDirty([int]$line) {
        return $this._allLinesDirty -or $this._dirtyLines.Contains($line)
    }
    
    [void] ClearDirtyLines() {
        $this._dirtyLines.Clear()
        $this._allLinesDirty = $false
    }
    
    [void] ExecuteCommand([object]$command) {
        $command.Execute($this)
        $this.AddToUndoStack($command)
        $this.SetModified($true)
        $this.NotifyContentChanged()
    }
    
    [bool] CanUndo() {
        return $this._undoStack.Count -gt 0
    }
    
    [bool] CanRedo() {
        return $this._redoStack.Count -gt 0
    }
    
    [void] ClearUndoHistory() {
        $this._undoStack.Clear()
        $this._redoStack.Clear()
    }
    
    [void] Undo() {
        if ($this._undoStack.Count -eq 0) { return }
        
        try {
            $command = $this._undoStack[$this._undoStack.Count - 1]
            $this._undoStack.RemoveAt($this._undoStack.Count - 1)
            $command.Undo($this)
            $this._redoStack.Add($command) | Out-Null
            $this.SetModified($true)
            $this.InvalidateLineIndex()
            $this.NotifyContentChanged()
        } catch {
            # If undo fails, clear the problematic command from the stack
            if ($global:Logger) {
                $global:Logger.Error("Undo failed: $($_.Exception.Message)")
            }
        }
    }
    
    [void] Redo() {
        if ($this._redoStack.Count -eq 0) { return }
        
        try {
            $command = $this._redoStack[$this._redoStack.Count - 1]
            $this._redoStack.RemoveAt($this._redoStack.Count - 1)
            $command.Execute($this)
            $this._undoStack.Add($command) | Out-Null
            $this.SetModified($true)
            $this.InvalidateLineIndex()
            $this.NotifyContentChanged()
        } catch {
            # If redo fails, clear the problematic command from the stack
            if ($global:Logger) {
                $global:Logger.Error("Redo failed: $($_.Exception.Message)")
            }
        }
    }
    
    [void] LoadFromFile([string]$filePath) {
        if (-not (Test-Path $filePath)) {
            # File doesn't exist, start with empty content
            $this._gapBuffer.SetText("`n")
            $this.InvalidateLineIndex()
            $this.SetModified($false)
            return
        }
        
        try {
            $content = Get-Content $filePath -Raw
            if ($content) {
                # Ensure content ends with newline for consistent line handling
                if (-not $content.EndsWith("`n")) {
                    $content += "`n"
                }
                $this._gapBuffer.SetText($content)
            } else {
                $this._gapBuffer.SetText("`n")
            }
            
            $this.InvalidateLineIndex()
            $this.SetModified($false)
            $this.LastModified = (Get-Item $filePath).LastWriteTime
        } catch {
            throw "Failed to load file '$filePath': $($_.Exception.Message)"
        }
    }
    
    [void] SaveToFile([string]$filePath = "") {
        if ([string]::IsNullOrEmpty($filePath)) {
            $saveFilePath = $this.FilePath
        } else {
            $saveFilePath = $filePath
        }
        if ([string]::IsNullOrEmpty($saveFilePath)) {
            throw "No file path specified for save"
        }
        
        try {
            $content = $this._gapBuffer.GetText()
            # Remove trailing newline for cleaner file output
            if ($content.EndsWith("`n")) {
                $content = $content.Substring(0, $content.Length - 1)
            }
            Set-Content -Path $saveFilePath -Value $content -NoNewline
            $this.FilePath = $saveFilePath
            $this.SetModified($false)
            $this.LastModified = [datetime]::Now
        } catch {
            throw "Failed to save file '$saveFilePath': $($_.Exception.Message)"
        }
    }
    
    # --- Internal Text Manipulation Methods (Called by Commands) ---
    
    [void] InsertTextAt([int]$line, [int]$col, [string]$text) {
        if ($line -lt 0) { return }
        if ([string]::IsNullOrEmpty($text)) { return }
        
        $position = $this.GetBufferPosition($line, $col)
        if ($position -ge 0) {
            $this._gapBuffer.Insert($position, $text)
            $this.InvalidateLineIndex()
            $this._dirtyLines.Add($line) | Out-Null
        }
    }
    
    [void] DeleteTextAt([int]$line, [int]$col, [int]$length) {
        if ($line -lt 0 -or $length -le 0) { return }
        
        $position = $this.GetBufferPosition($line, $col)
        if ($position -ge 0) {
            $this._gapBuffer.Delete($position, $length)
            $this.InvalidateLineIndex()
            $this._dirtyLines.Add($line) | Out-Null
        }
    }
    
    [void] InsertNewlineAt([int]$line, [int]$col) {
        if ($line -lt 0) { return }
        
        $position = $this.GetBufferPosition($line, $col)
        if ($position -ge 0) {
            $this._gapBuffer.Insert($position, "`n")
            $this.InvalidateLineIndex()
            $this._dirtyLines.Add($line) | Out-Null
        }
    }
    
    [void] JoinLinesAt([int]$line, [string]$separator = "") {
        $this.EnsureLineIndex()
        if ($line -lt 0 -or $line -ge $this._lineStarts.Count - 1) {
            return  # Can't join if invalid line or no next line
        }
        
        # Find the newline between the lines and delete it
        $nextLineStart = $this._lineStarts[$line + 1]
        $newlinePos = $nextLineStart - 1
        
        $this._gapBuffer.Delete($newlinePos, 1)
        
        # Insert separator if provided
        if (-not [string]::IsNullOrEmpty($separator)) {
            $this._gapBuffer.Insert($newlinePos, $separator)
        }
        
        $this.InvalidateLineIndex()
        $this._dirtyLines.Add($line) | Out-Null
    }
    
    [string] GetTextAt([int]$line, [int]$col, [int]$length) {
        if ($line -lt 0 -or $length -le 0) { return "" }
        
        $position = $this.GetBufferPosition($line, $col)
        if ($position -ge 0) {
            return $this._gapBuffer.GetText($position, $length)
        }
        return ""
    }
    
    # --- Helper Methods ---
    
    hidden [int] GetBufferPosition([int]$line, [int]$col) {
        $this.EnsureLineIndex()
        
        if ($line -lt 0 -or $line -ge $this._lineStarts.Count) {
            return -1
        }
        
        $lineStart = $this._lineStarts[$line]
        $position = $lineStart + $col
        
        # Clamp position to line bounds
        if ($line -eq $this._lineStarts.Count - 1) {
            # Last line - clamp to buffer end
            $maxPos = $this._gapBuffer.GetLength()
            $position = [Math]::Min($position, $maxPos)
        } else {
            # Clamp to line end (before newline)
            $lineEnd = $this._lineStarts[$line + 1] - 1
            $position = [Math]::Min($position, $lineEnd)
        }
        
        return $position
    }
    
    hidden [void] AddToUndoStack([object]$command) {
        $this._undoStack.Add($command) | Out-Null
        if ($this._undoStack.Count -gt $this._maxUndoHistory) {
            $this._undoStack.RemoveAt(0)
        }
        # A new action clears the redo stack
        $this._redoStack.Clear()
    }
    
    hidden [void] SetModified([bool]$modified) {
        if ($this.IsModified -ne $modified) {
            $this.IsModified = $modified
            if ($this.OnModifiedStateChanged) {
                & $this.OnModifiedStateChanged $modified
            }
        }
        # Update Lines property for compatibility
        $this.UpdateLinesProperty()
    }
    
    hidden [void] NotifyContentChanged() {
        if ($this.OnContentChanged) {
            & $this.OnContentChanged
        }
    }
    
    # --- Performance and Debugging ---
    
    [hashtable] GetStatistics() {
        $gapStats = $this._gapBuffer.GetStatistics()
        return @{
            GapBuffer = $gapStats
            LineCount = $this.GetLineCount()
            LineIndexRebuildCount = $this.LineIndexRebuildCount
            LineIndexDirty = $this._lineIndexDirty
            UndoStackSize = $this._undoStack.Count
            RedoStackSize = $this._redoStack.Count
            DirtyLinesCount = $this._dirtyLines.Count
            AllLinesDirty = $this._allLinesDirty
        }
    }
    
    [void] ResetStatistics() {
        $this._gapBuffer.ResetStatistics()
        $this.LineIndexRebuildCount = 0
    }
    
    # For compatibility with ArrayList-based DocumentBuffer
    [System.Collections.ArrayList] get_Lines() {
        # Return a virtual ArrayList-like interface
        $linesList = [System.Collections.ArrayList]::new()
        $lineCount = $this.GetLineCount()
        for ($i = 0; $i -lt $lineCount; $i++) {
            $linesList.Add($this.GetLine($i)) | Out-Null
        }
        return $linesList
    }
    
    # PowerShell property syntax for Lines
    [System.Collections.ArrayList]$Lines = $null
    
    hidden [void] UpdateLinesProperty() {
        $this.Lines = $this.get_Lines()
    }
}