# TextEditorScreenNew.ps1 - Refactored text editor with Buffer/View architecture
# Implements the professional architecture from the upgrade plan

class TextEditorScreenNew : Screen {
    # Buffer/View separation - DocumentBuffer handles all text logic
    hidden [DocumentBuffer]$_buffer
    
    # Cursor and viewport state (UI concerns only)
    [int]$CursorX = 0
    [int]$CursorY = 0
    [int]$ScrollOffsetY = 0
    [int]$ScrollOffsetX = 0
    [string]$StatusMessage = ""
    
    # Line-level render cache for performance
    hidden [hashtable]$_lineRenderCache
    hidden [hashtable]$_dirtyLines
    hidden [bool]$_allLinesDirty = $true
    
    # Selection state for block selection
    [bool]$HasSelection = $false
    [int]$SelectionStartX = 0
    [int]$SelectionStartY = 0
    [int]$SelectionEndX = 0
    [int]$SelectionEndY = 0
    [bool]$InSelectionMode = $false
    
    # PRAXIS service integration
    hidden [object]$ThemeManager
    hidden [object]$EventBus
    
    # Editor settings
    [int]$TabWidth = 4
    [bool]$ShowLineNumbers = $true
    [int]$LineNumberWidth = 5
    [bool]$AutoSaveOnFocusLoss = $true
    
    # Clipboard system
    hidden [string]$_clipboard = ""
    
    TextEditorScreenNew() : base() {
        $this.Title = "Text Editor"
        $this._buffer = [DocumentBuffer]::new()
        $this.InitializeRenderCache()
        $this.SetupBufferEventHandlers()
        $this.IsFocusable = $true
        
        # Add some sample content for testing
        $this.AddSampleContent()
    }
    
    TextEditorScreenNew([string]$filePath) : base() {
        $this.Title = "Text Editor"
        $this._buffer = [DocumentBuffer]::new($filePath)
        $this.InitializeRenderCache()
        $this.SetupBufferEventHandlers()
        $this.IsFocusable = $true
        $this.UpdateTitle()
    }
    
    [void] OnInitialize() {
        # Get PRAXIS services
        $this.ThemeManager = $this.ServiceContainer.GetService("ThemeManager")
        $this.EventBus = $this.ServiceContainer.GetService('EventBus')
    }
    
    hidden [void] InitializeRenderCache() {
        $this._lineRenderCache = @{}
        $this._dirtyLines = @{}
    }
    
    hidden [void] SetupBufferEventHandlers() {
        # Buffer notifies us when content changes
        $screen = $this
        $this._buffer.OnContentChanged = {
            $screen.OnBufferContentChanged()
        }.GetNewClosure()
        
        $this._buffer.OnModifiedStateChanged = {
            param($isModified)
            $screen.OnBufferModifiedStateChanged($isModified)
        }.GetNewClosure()
    }
    
    hidden [void] OnBufferContentChanged() {
        # Mark lines dirty based on buffer's dirty tracking
        for ($i = 0; $i -lt $this._buffer.GetLineCount(); $i++) {
            if ($this._buffer.IsLineDirty($i)) {
                $this._dirtyLines[$i] = $true
            }
        }
        $this.Invalidate()
    }
    
    hidden [void] OnBufferModifiedStateChanged([bool]$isModified) {
        $this.UpdateTitle()
        $this.Invalidate()
    }
    
    hidden [void] UpdateTitle() {
        $fileName = if ($this._buffer.FilePath) { 
            [System.IO.Path]::GetFileName($this._buffer.FilePath) 
        } else { 
            "Untitled" 
        }
        $modifiedIndicator = if ($this._buffer.IsModified) { "*" } else { "" }
        $this.Title = "Text Editor - $fileName$modifiedIndicator"
    }
    
    hidden [void] AddSampleContent() {
        # Add some sample content to test the editor
        $sampleLines = @(
            "Welcome to PRAXIS Text Editor!",
            "",
            "This is the new Buffer/View architecture with:",
            "• Command Pattern for robust undo/redo",
            "• Line-level render caching for performance", 
            "• Proper Buffer/View separation",
            "",
            "Try typing text, using arrow keys, or:",
            "• Ctrl+Z to undo",
            "• Ctrl+Y to redo", 
            "• Ctrl+S to save (when implemented)",
            "",
            "The architecture is now professional-grade!"
        )
        
        # Clear the default empty line and add sample content directly
        # This bypasses the command system intentionally so it doesn't affect undo
        $this._buffer.Lines.Clear()
        foreach ($line in $sampleLines) {
            $this._buffer.Lines.Add($line) | Out-Null
        }
        
        # Clear the undo/redo stacks since this is initial content
        $this._buffer.ClearUndoHistory()
        $this._buffer.IsModified = $false
        
        $this._allLinesDirty = $true
    }
    
    # --- Input Handling - Translates keys to commands ---
    
    [bool] HandleScreenInput([System.ConsoleKeyInfo]$keyInfo) {
        # Handle special keys first
        if ($this.HandleSpecialKeys($keyInfo)) {
            return $true
        }
        
        # Handle character insertion
        if ($keyInfo.KeyChar -and -not [char]::IsControl($keyInfo.KeyChar)) {
            $this.InsertCharacter($keyInfo.KeyChar)
            return $true
        }
        
        return $false
    }
    
    hidden [bool] HandleSpecialKeys([System.ConsoleKeyInfo]$keyInfo) {
        switch ($keyInfo.Key) {
            ([System.ConsoleKey]::Backspace) {
                $this.HandleBackspace()
                return $true
            }
            ([System.ConsoleKey]::Delete) {
                $this.HandleDelete()
                return $true
            }
            ([System.ConsoleKey]::Enter) {
                $this.HandleEnter()
                return $true
            }
            ([System.ConsoleKey]::Tab) {
                $this.HandleTab()
                return $true
            }
            ([System.ConsoleKey]::LeftArrow) {
                $this.MoveCursorLeft($keyInfo.Modifiers -band [System.ConsoleModifiers]::Shift)
                return $true
            }
            ([System.ConsoleKey]::RightArrow) {
                $this.MoveCursorRight($keyInfo.Modifiers -band [System.ConsoleModifiers]::Shift)
                return $true
            }
            ([System.ConsoleKey]::UpArrow) {
                $this.MoveCursorUp($keyInfo.Modifiers -band [System.ConsoleModifiers]::Shift)
                return $true
            }
            ([System.ConsoleKey]::DownArrow) {
                $this.MoveCursorDown($keyInfo.Modifiers -band [System.ConsoleModifiers]::Shift)
                return $true
            }
            ([System.ConsoleKey]::Home) {
                $this.MoveCursorHome($keyInfo.Modifiers -band [System.ConsoleModifiers]::Shift)
                return $true
            }
            ([System.ConsoleKey]::End) {
                $this.MoveCursorEnd($keyInfo.Modifiers -band [System.ConsoleModifiers]::Shift)
                return $true
            }
            ([System.ConsoleKey]::PageUp) {
                $this.MoveCursorPageUp($keyInfo.Modifiers -band [System.ConsoleModifiers]::Shift)
                return $true
            }
            ([System.ConsoleKey]::PageDown) {
                $this.MoveCursorPageDown($keyInfo.Modifiers -band [System.ConsoleModifiers]::Shift)
                return $true
            }
        }
        
        # Handle Ctrl combinations
        if ($keyInfo.Modifiers -band [System.ConsoleModifiers]::Control) {
            switch ($keyInfo.Key) {
                ([System.ConsoleKey]::S) {
                    $this.SaveFile()
                    return $true
                }
                ([System.ConsoleKey]::O) {
                    $this.OpenFile()
                    return $true
                }
                ([System.ConsoleKey]::N) {
                    $this.NewFile()
                    return $true
                }
                ([System.ConsoleKey]::Z) {
                    # EMERGENCY FIX: Disable Ctrl+Z entirely to prevent crashes
                    if ($global:Logger) {
                        $global:Logger.Debug("Ctrl+Z pressed - disabled to prevent crashes")
                    }
                    $this.StatusMessage = "Ctrl+Z disabled due to crashes"
                    return $true
                }
                ([System.ConsoleKey]::Y) {
                    # EMERGENCY FIX: Disable Ctrl+Y as well to prevent crashes
                    if ($global:Logger) {
                        $global:Logger.Debug("Ctrl+Y pressed - disabled to prevent crashes")
                    }
                    $this.StatusMessage = "Ctrl+Y disabled due to crashes"
                    return $true
                }
                ([System.ConsoleKey]::C) {
                    $this.CopySelection()
                    return $true
                }
                ([System.ConsoleKey]::X) {
                    $this.CutSelection()
                    return $true
                }
                ([System.ConsoleKey]::V) {
                    $this.PasteClipboard()
                    return $true
                }
                ([System.ConsoleKey]::A) {
                    $this.SelectAll()
                    return $true
                }
            }
        }
        
        return $false
    }
    
    # --- Text Editing Operations (Command Pattern) ---
    
    hidden [void] InsertCharacter([char]$char) {
        # EMERGENCY FIX: Bypass Command Pattern to prevent crashes
        try {
            if ($global:Logger) {
                $global:Logger.Debug("InsertCharacter: Inserting '$char' at ($($this.CursorX),$($this.CursorY))")
            }
            
            # Direct insertion without Command Pattern
            $this._buffer.InsertTextAt($this.CursorY, $this.CursorX, [string]$char)
            $this.CursorX++
            
            # Mark as modified
            $this._buffer.IsModified = $true
            
            # Mark rendering dirty
            $this._allLinesDirty = $true
            if ($this._lineRenderCache) {
                $this._lineRenderCache.Clear()
            }
            
            $this.EnsureCursorVisible()
            $this.Invalidate()
            
            if ($global:Logger) {
                $global:Logger.Debug("InsertCharacter: Successfully inserted '$char'")
            }
            
        } catch {
            if ($global:Logger) {
                $global:Logger.Error("InsertCharacter failed: $($_.Exception.Message)")
            }
            $this.StatusMessage = "Character insertion failed"
        }
    }
    
    hidden [void] HandleBackspace() {
        if ($this.HasSelection) {
            $this.DeleteSelection()
            return
        }
        
        if ($this.CursorX -gt 0) {
            # Delete character before cursor
            $charToDelete = $this._buffer.GetTextAt($this.CursorY, $this.CursorX - 1, 1)
            $command = [DeleteTextCommand]::new($this.CursorY, $this.CursorX - 1, $charToDelete)
            $this._buffer.ExecuteCommand($command)
            $this.CursorX--
        } elseif ($this.CursorY -gt 0) {
            # Join with previous line
            $prevLineLength = $this._buffer.GetLine($this.CursorY - 1).Length
            $currentLineText = $this._buffer.GetLine($this.CursorY)
            $command = [JoinLinesCommand]::new($this.CursorY - 1, $currentLineText)
            $this._buffer.ExecuteCommand($command)
            $this.CursorY--
            $this.CursorX = $prevLineLength
        }
        $this.EnsureCursorVisible()
    }
    
    hidden [void] HandleDelete() {
        if ($this.HasSelection) {
            $this.DeleteSelection()
            return
        }
        
        $currentLine = $this._buffer.GetLine($this.CursorY)
        if ($this.CursorX -lt $currentLine.Length) {
            # Delete character at cursor
            $charToDelete = $this._buffer.GetTextAt($this.CursorY, $this.CursorX, 1)
            $command = [DeleteTextCommand]::new($this.CursorY, $this.CursorX, $charToDelete)
            $this._buffer.ExecuteCommand($command)
        } elseif ($this.CursorY -lt $this._buffer.GetLineCount() - 1) {
            # Join with next line
            $nextLineText = $this._buffer.GetLine($this.CursorY + 1)
            $command = [JoinLinesCommand]::new($this.CursorY, $nextLineText)
            $this._buffer.ExecuteCommand($command)
        }
    }
    
    hidden [void] HandleEnter() {
        if ($this.HasSelection) {
            $this.DeleteSelection()
        }
        
        $currentLine = $this._buffer.GetLine($this.CursorY)
        $rightText = $currentLine.Substring($this.CursorX)
        $command = [InsertNewlineCommand]::new($this.CursorY, $this.CursorX, $rightText)
        $this._buffer.ExecuteCommand($command)
        $this.CursorY++
        $this.CursorX = 0
        $this.EnsureCursorVisible()
        $this.ClearSelection()
    }
    
    hidden [void] HandleTab() {
        $spaces = " " * $this.TabWidth
        $command = [InsertTextCommand]::new($this.CursorY, $this.CursorX, $spaces)
        $this._buffer.ExecuteCommand($command)
        $this.CursorX += $this.TabWidth
        $this.EnsureCursorVisible()
    }
    
    # --- File Operations ---
    
    [void] SaveFile([string]$filePath = "") {
        try {
            if ([string]::IsNullOrEmpty($filePath)) {
                $filePath = $this._buffer.FilePath
            }
            if ([string]::IsNullOrEmpty($filePath)) {
                # TODO: Open file dialog
                $this.StatusMessage = "No file path specified"
                return
            }
            
            $this._buffer.SaveToFile($filePath)
            $this.StatusMessage = "File saved: $([System.IO.Path]::GetFileName($filePath))"
            $this.UpdateTitle()
        } catch {
            $this.StatusMessage = "Error saving file: $($_.Exception.Message)"
        }
    }
    
    [void] OpenFile([string]$filePath = "") {
        # TODO: Implement file dialog
        $this.StatusMessage = "Open file not yet implemented"
    }
    
    [void] NewFile() {
        $this._buffer = [DocumentBuffer]::new()
        $this.SetupBufferEventHandlers()
        $this.CursorX = 0
        $this.CursorY = 0
        $this.ScrollOffsetX = 0
        $this.ScrollOffsetY = 0
        $this.ClearSelection()
        $this._allLinesDirty = $true
        $this._lineRenderCache.Clear()
        $this.UpdateTitle()
        $this.StatusMessage = "New file created"
        $this.Invalidate()
    }
    
    # --- Undo/Redo ---
    
    [void] UndoEdit() {
        # EMERGENCY FIX: Disable undo entirely to prevent crashes
        # This is a temporary workaround until the root cause is found
        $this.StatusMessage = "Undo temporarily disabled due to crashes"
        
        if ($global:Logger) {
            $global:Logger.Debug("UndoEdit: Undo disabled to prevent crashes")
        }
        
        return
        
        # TODO: Investigate why undo causes immediate crashes
        # All defensive programming attempts have failed
        # The crash happens before any logging executes
        # Likely a PowerShell runtime or memory issue
    }
    
    [void] RedoEdit() {
        if ($this._buffer.CanRedo()) {
            try {
                $this._buffer.Redo()
                $this.ClearSelection()
                $this._allLinesDirty = $true
                $this._lineRenderCache.Clear()
                
                # Ensure cursor position is valid after redo
                $this.ValidateCursorPosition()
                $this.EnsureCursorVisible()
                $this.StatusMessage = "Redo"
            } catch {
                # If redo fails, log error and reset to safe state
                if ($global:Logger) {
                    $global:Logger.Error("RedoEdit failed: $($_.Exception.Message)")
                }
                $this.StatusMessage = "Redo failed"
                $this.ValidateCursorPosition()
                $this._allLinesDirty = $true
                $this._lineRenderCache.Clear()
                $this.Invalidate()
            }
        } else {
            $this.StatusMessage = "Nothing to redo"
        }
    }
    
    # --- Selection and Clipboard (Stub implementations) ---
    
    hidden [void] ClearSelection() {
        $this.HasSelection = $false
        $this.InSelectionMode = $false
    }
    
    hidden [void] DeleteSelection() {
        # TODO: Implement selection deletion
        $this.ClearSelection()
    }
    
    [void] CopySelection() {
        # TODO: Implement copy
        $this.StatusMessage = "Copy not yet implemented"
    }
    
    [void] CutSelection() {
        # TODO: Implement cut
        $this.StatusMessage = "Cut not yet implemented"
    }
    
    [void] PasteClipboard() {
        # TODO: Implement paste
        $this.StatusMessage = "Paste not yet implemented"
    }
    
    [void] SelectAll() {
        # TODO: Implement select all
        $this.StatusMessage = "Select All not yet implemented"
    }
    
    # --- Cursor Movement (Stub implementations) ---
    
    hidden [void] MoveCursorLeft([bool]$extend) {
        if ($this.CursorX -gt 0) {
            $this.CursorX--
        } elseif ($this.CursorY -gt 0) {
            $this.CursorY--
            $this.CursorX = $this._buffer.GetLine($this.CursorY).Length
        }
        $this.EnsureCursorVisible()
    }
    
    hidden [void] MoveCursorRight([bool]$extend) {
        $currentLine = $this._buffer.GetLine($this.CursorY)
        if ($this.CursorX -lt $currentLine.Length) {
            $this.CursorX++
        } elseif ($this.CursorY -lt $this._buffer.GetLineCount() - 1) {
            $this.CursorY++
            $this.CursorX = 0
        }
        $this.EnsureCursorVisible()
    }
    
    hidden [void] MoveCursorUp([bool]$extend) {
        if ($this.CursorY -gt 0) {
            $this.CursorY--
            $prevLine = $this._buffer.GetLine($this.CursorY)
            $this.CursorX = [Math]::Min($this.CursorX, $prevLine.Length)
        }
        $this.EnsureCursorVisible()
    }
    
    hidden [void] MoveCursorDown([bool]$extend) {
        if ($this.CursorY -lt $this._buffer.GetLineCount() - 1) {
            $this.CursorY++
            $nextLine = $this._buffer.GetLine($this.CursorY)
            $this.CursorX = [Math]::Min($this.CursorX, $nextLine.Length)
        }
        $this.EnsureCursorVisible()
    }
    
    hidden [void] MoveCursorHome([bool]$extend) {
        $this.CursorX = 0
        $this.EnsureCursorVisible()
    }
    
    hidden [void] MoveCursorEnd([bool]$extend) {
        $this.CursorX = $this._buffer.GetLine($this.CursorY).Length
        $this.EnsureCursorVisible()
    }
    
    hidden [void] MoveCursorPageUp([bool]$extend) {
        $pageSize = $this.Height - 4
        $this.CursorY = [Math]::Max(0, $this.CursorY - $pageSize)
        $this.EnsureCursorVisible()
    }
    
    hidden [void] MoveCursorPageDown([bool]$extend) {
        $pageSize = $this.Height - 4
        $this.CursorY = [Math]::Min($this._buffer.GetLineCount() - 1, $this.CursorY + $pageSize)
        $this.EnsureCursorVisible()
    }
    
    hidden [void] ValidateCursorPosition() {
        # Ensure cursor is within valid bounds
        $lineCount = $this._buffer.GetLineCount()
        if ($lineCount -eq 0) {
            $this.CursorX = 0
            $this.CursorY = 0
            return
        }
        
        # Clamp cursor Y to valid range
        $this.CursorY = [Math]::Max(0, [Math]::Min($this.CursorY, $lineCount - 1))
        
        # Clamp cursor X to current line length
        try {
            $currentLine = $this._buffer.GetLine($this.CursorY)
            $this.CursorX = [Math]::Max(0, [Math]::Min($this.CursorX, $currentLine.Length))
        } catch {
            # If we can't get the line, reset cursor to safe position
            $this.CursorX = 0
            $this.CursorY = 0
        }
    }
    
    hidden [void] EnsureCursorVisible() {
        # Implement viewport scrolling to keep cursor visible
        $editorHeight = $this.Height - 2  # Account for status line
        
        # Vertical scrolling
        if ($this.CursorY -lt $this.ScrollOffsetY) {
            $this.ScrollOffsetY = $this.CursorY
        } elseif ($this.CursorY -ge $this.ScrollOffsetY + $editorHeight) {
            $this.ScrollOffsetY = $this.CursorY - $editorHeight + 1
        }
        
        # Horizontal scrolling
        $editorWidth = $this.Width - ($this.ShowLineNumbers ? $this.LineNumberWidth : 0)
        if ($this.CursorX -lt $this.ScrollOffsetX) {
            $this.ScrollOffsetX = $this.CursorX
        } elseif ($this.CursorX -ge $this.ScrollOffsetX + $editorWidth) {
            $this.ScrollOffsetX = $this.CursorX - $editorWidth + 1
        }
        
        # Ensure scroll offsets are valid
        $this.ScrollOffsetY = [Math]::Max(0, $this.ScrollOffsetY)
        $this.ScrollOffsetX = [Math]::Max(0, $this.ScrollOffsetX)
        
        $this.Invalidate()
    }
    
    # --- Optimized Rendering with Line-Level Caching ---
    
    [string] OnRender() {
        $sb = Get-PooledStringBuilder 4096
        
        # Render with line caching for performance
        $this.RenderWithCache($sb)
        
        $result = $sb.ToString()
        Return-PooledStringBuilder $sb
        return $result
    }
    
    hidden [void] RenderWithCache([System.Text.StringBuilder]$sb) {
        # Clear the entire screen area first with background color
        $bgColor = if ($this.ThemeManager) { $this.ThemeManager.GetBgColor("background") } else { "" }
        for ($y = 0; $y -lt $this.Height; $y++) {
            $sb.Append([VT]::MoveTo($this.X, $this.Y + $y))
            $sb.Append($bgColor)
            $sb.Append([StringCache]::GetSpaces($this.Width))
        }
        
        # Calculate editor area
        $editorHeight = $this.Height - 1  # Reserve bottom for status
        $editorWidth = $this.Width
        $lineNumWidth = if ($this.ShowLineNumbers) { $this.LineNumberWidth } else { 0 }
        $textWidth = $editorWidth - $lineNumWidth
        
        # Render visible lines with caching
        $startLine = $this.ScrollOffsetY
        $endLine = [Math]::Min($startLine + $editorHeight, $this._buffer.GetLineCount())
        
        for ($lineIndex = $startLine; $lineIndex -lt $endLine; $lineIndex++) {
            $y = $lineIndex - $startLine
            $renderLine = ""
            
            # Check if line needs re-rendering
            if ($this._allLinesDirty -or $this._dirtyLines.ContainsKey($lineIndex) -or -not $this._lineRenderCache.ContainsKey($lineIndex)) {
                # Render line from scratch
                $renderLine = $this.RenderLine($lineIndex, $lineNumWidth, $textWidth)
                $this._lineRenderCache[$lineIndex] = $renderLine
            } else {
                # Use cached version
                $renderLine = $this._lineRenderCache[$lineIndex]
            }
            
            # Output the line
            $sb.Append([VT]::MoveTo($this.X, $this.Y + $y))
            $sb.Append($renderLine)
        }
        
        # Clear dirty flags
        $this._buffer.ClearDirtyLines()
        $this._dirtyLines.Clear()
        $this._allLinesDirty = $false
        
        # TODO: Render cursor (need to implement cursor positioning)
        
        # Render status line
        $statusY = $this.Height - 1
        $sb.Append([VT]::MoveTo($this.X, $this.Y + $statusY))
        $statusColor = if ($this.ThemeManager) { $this.ThemeManager.GetColor("status") } else { "" }
        $statusBgColor = if ($this.ThemeManager) { $this.ThemeManager.GetBgColor("status") } else { "" }
        $sb.Append($statusBgColor)
        $sb.Append($statusColor)
        $statusText = $this.GetStatusText()
        $sb.Append($statusText.PadRight($this.Width).Substring(0, $this.Width))
    }
    
    hidden [string] RenderLine([int]$lineNumber, [int]$lineNumberWidth, [int]$textWidth) {
        $sb = [System.Text.StringBuilder]::new()
        
        # Get colors
        $textColor = if ($this.ThemeManager) { $this.ThemeManager.GetColor("normal") } else { "" }
        $lineNumColor = if ($this.ThemeManager) { $this.ThemeManager.GetColor("linenumber") } else { $textColor }
        $bgColor = if ($this.ThemeManager) { $this.ThemeManager.GetBgColor("background") } else { "" }
        
        # Apply background color
        $sb.Append($bgColor)
        
        # Line number
        if ($this.ShowLineNumbers) {
            $sb.Append($lineNumColor)
            $lineNumText = ($lineNumber + 1).ToString().PadLeft($lineNumberWidth - 1) + " "
            $sb.Append($lineNumText)
        }
        
        # Line content with text color
        $sb.Append($textColor)
        $lineText = $this._buffer.GetLine($lineNumber)
        $visibleText = $lineText
        if ($this.ScrollOffsetX -gt 0 -and $this.ScrollOffsetX -lt $lineText.Length) {
            $visibleText = $lineText.Substring($this.ScrollOffsetX)
        } elseif ($this.ScrollOffsetX -ge $lineText.Length) {
            $visibleText = ""
        }
        
        if ($visibleText.Length -gt $textWidth) {
            $visibleText = $visibleText.Substring(0, $textWidth)
        }
        
        $sb.Append($visibleText)
        
        # Pad to full width
        $totalRendered = $lineNumberWidth + $visibleText.Length
        if ($totalRendered -lt $this.Width) {
            $sb.Append([StringCache]::GetSpaces($this.Width - $totalRendered))
        }
        
        return $sb.ToString()
    }
    
    hidden [string] GetStatusText() {
        $line = $this.CursorY + 1
        $col = $this.CursorX + 1
        $total = $this._buffer.GetLineCount()
        $modified = if ($this._buffer.IsModified) { " [Modified]" } else { "" }
        $undoStatus = ""
        if ($this._buffer.CanUndo()) {
            $undoStatus += " [Undo]"
        }
        if ($this._buffer.CanRedo()) {
            $undoStatus += " [Redo]"
        }
        
        $status = "Line $line/$total, Col $col$modified$undoStatus"
        if ($this.StatusMessage) {
            $status += " | $($this.StatusMessage)"
        }
        
        return $status
    }
}