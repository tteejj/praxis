# DocumentBuffer.ps1 - Model class for text editor content
# Implements Buffer/View separation - this class knows nothing about UI

class DocumentBuffer {
    # Text content storage (Phase 1: ArrayList, Phase 3: Gap Buffer)
    hidden [System.Collections.ArrayList]$Lines
    
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
    
    DocumentBuffer() {
        $this.Lines = [System.Collections.ArrayList]::new()
        $this.Lines.Add("") | Out-Null  # Always have at least one empty line
        $this._undoStack = [System.Collections.ArrayList]::new()
        $this._redoStack = [System.Collections.ArrayList]::new()
        $this._dirtyLines = [System.Collections.Generic.HashSet[int]]::new()
    }
    
    DocumentBuffer([string]$filePath) {
        $this.Lines = [System.Collections.ArrayList]::new()
        $this._undoStack = [System.Collections.ArrayList]::new()
        $this._redoStack = [System.Collections.ArrayList]::new()
        $this._dirtyLines = [System.Collections.Generic.HashSet[int]]::new()
        $this.FilePath = $filePath
        $this.LoadFromFile($filePath)
    }
    
    # --- Public API for TextEditorScreen ---
    
    [string] GetLine([int]$index) {
        if ($index -lt 0 -or $index -ge $this.Lines.Count) {
            return ""
        }
        return $this.Lines[$index]
    }
    
    [int] GetLineCount() {
        return $this.Lines.Count
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
            $this._allLinesDirty = $true  # Mark all lines dirty after undo
            $this.NotifyContentChanged()
        } catch {
            # If undo fails, clear the problematic command from the stack
            if ($global:Logger) {
                $global:Logger.Error("Undo failed: $($_.Exception.Message)")
            }
            # Don't add the failed command to redo stack
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
            $this._allLinesDirty = $true  # Mark all lines dirty after redo
            $this.NotifyContentChanged()
        } catch {
            # If redo fails, clear the problematic command from the stack
            if ($global:Logger) {
                $global:Logger.Error("Redo failed: $($_.Exception.Message)")
            }
            # Don't add the failed command to undo stack
        }
    }
    
    [void] LoadFromFile([string]$filePath) {
        if (-not (Test-Path $filePath)) {
            # File doesn't exist, start with empty content
            $this.Lines.Clear()
            $this.Lines.Add("") | Out-Null
            $this.SetModified($false)
            return
        }
        
        try {
            $content = Get-Content $filePath -Raw
            if ($content) {
                $lineArray = $content -split "`r?`n"
                $this.Lines.Clear()
                foreach ($line in $lineArray) {
                    $this.Lines.Add($line) | Out-Null
                }
                # Ensure we always have at least one line
                if ($this.Lines.Count -eq 0) {
                    $this.Lines.Add("") | Out-Null
                }
            } else {
                $this.Lines.Clear()
                $this.Lines.Add("") | Out-Null
            }
            $this.SetModified($false)
            $this.LastModified = (Get-Item $filePath).LastWriteTime
            $this._allLinesDirty = $true
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
            $content = $this.Lines -join "`n"
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
        $this.EnsureLineExists($line)
        $currentLine = $this.Lines[$line]
        $col = [Math]::Max(0, [Math]::Min($col, $currentLine.Length))
        $this.Lines[$line] = $currentLine.Insert($col, $text)
        $this._dirtyLines.Add($line) | Out-Null
    }
    
    [void] DeleteTextAt([int]$line, [int]$col, [int]$length) {
        if ($line -lt 0 -or $line -ge $this.Lines.Count) { return }
        $currentLine = $this.Lines[$line]
        $col = [Math]::Max(0, [Math]::Min($col, $currentLine.Length))
        $length = [Math]::Min($length, $currentLine.Length - $col)
        if ($length -gt 0) {
            $this.Lines[$line] = $currentLine.Remove($col, $length)
            $this._dirtyLines.Add($line) | Out-Null
        }
    }
    
    [void] InsertNewlineAt([int]$line, [int]$col) {
        if ($line -lt 0) { return }
        $this.EnsureLineExists($line)
        $currentLine = $this.Lines[$line]
        $col = [Math]::Max(0, [Math]::Min($col, $currentLine.Length))
        
        $leftPart = $currentLine.Substring(0, $col)
        $rightPart = $currentLine.Substring($col)
        
        $this.Lines[$line] = $leftPart
        $this.Lines.Insert($line + 1, $rightPart)
        
        # Mark affected lines as dirty
        $this._dirtyLines.Add($line) | Out-Null
        $this._dirtyLines.Add($line + 1) | Out-Null
        # All lines after the insert point shift, so mark all dirty
        $this._allLinesDirty = $true
    }
    
    [void] JoinLinesAt([int]$line, [string]$separator = "") {
        if ($line -lt 0 -or $line -ge $this.Lines.Count -or $line + 1 -ge $this.Lines.Count) {
            return  # Can't join if invalid line or no next line
        }
        
        $currentLine = $this.Lines[$line]
        $nextLine = $this.Lines[$line + 1]
        $this.Lines[$line] = $currentLine + $separator + $nextLine
        $this.Lines.RemoveAt($line + 1)
        
        # Mark affected line as dirty
        $this._dirtyLines.Add($line) | Out-Null
        # All lines after the removal shift, so mark all dirty
        $this._allLinesDirty = $true
    }
    
    [string] GetTextAt([int]$line, [int]$col, [int]$length) {
        if ($line -lt 0 -or $line -ge $this.Lines.Count) { return "" }
        $currentLine = $this.Lines[$line]
        $col = [Math]::Max(0, [Math]::Min($col, $currentLine.Length))
        $length = [Math]::Min($length, $currentLine.Length - $col)
        if ($length -le 0) {
            return ""
        }
        return $currentLine.Substring($col, $length)
    }
    
    # --- Private Helper Methods ---
    
    hidden [void] EnsureLineExists([int]$line) {
        while ($this.Lines.Count -le $line) {
            $this.Lines.Add("") | Out-Null
        }
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
    }
    
    hidden [void] NotifyContentChanged() {
        if ($this.OnContentChanged) {
            & $this.OnContentChanged
        }
    }
}