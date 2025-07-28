# TextEditorScreenNew.ps1 - Refactored text editor with Buffer/View architecture
# Implements the professional architecture from the upgrade plan

class TextEditorScreenNew : Screen {
    # Buffer/View separation - DocumentBuffer or GapBufferDocumentBuffer handles all text logic
    hidden [object]$_buffer
    
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
    
    # Proper undo system - tracks complete document state
    hidden [System.Collections.ArrayList]$_undoStack
    hidden [System.Collections.ArrayList]$_redoStack
    hidden [bool]$_groupingInserts = $false
    hidden [datetime]$_lastActionTime = [datetime]::MinValue
    
    # Editor settings
    [int]$TabWidth = 4
    [bool]$ShowLineNumbers = $true
    [int]$LineNumberWidth = 5
    [bool]$AutoSaveOnFocusLoss = $true
    
    # Auto-save and crash recovery settings
    [bool]$AutoSaveEnabled = $true
    [int]$AutoSaveIntervalSeconds = 30  # Auto-save every 30 seconds
    [string]$AutoSaveDirectory = ""     # Set during initialization
    hidden [datetime]$_lastAutoSave = [datetime]::MinValue
    hidden [datetime]$_lastModification = [datetime]::MinValue
    hidden [System.Timers.Timer]$_autoSaveTimer
    hidden [bool]$_needsAutoSave = $false
    
    # Clipboard system
    hidden [string]$_clipboard = ""
    
    TextEditorScreenNew() : base() {
        $this.Title = "Text Editor"
        $this._buffer = [GapBufferDocumentBuffer]::new()
        $this.InitializeRenderCache()
        $this.SetupBufferEventHandlers()
        $this.IsFocusable = $true
        
        # Initialize simple undo system
        $this._undoStack = [System.Collections.ArrayList]::new()
        $this._redoStack = [System.Collections.ArrayList]::new()
        
        # Add some sample content for testing
        $this.AddSampleContent()
    }
    
    TextEditorScreenNew([string]$filePath) : base() {
        $this.Title = "Text Editor"
        $this._buffer = [GapBufferDocumentBuffer]::new($filePath)
        $this.InitializeRenderCache()
        $this.SetupBufferEventHandlers()
        $this.IsFocusable = $true
        $this.UpdateTitle()
    }
    
    TextEditorScreenNew([string]$filePath, [bool]$useGapBuffer) : base() {
        $this.Title = "Text Editor"
        if ($useGapBuffer) {
            $this._buffer = [GapBufferDocumentBuffer]::new($filePath)
        } else {
            $this._buffer = [DocumentBuffer]::new($filePath)
        }
        $this.InitializeRenderCache()
        $this.SetupBufferEventHandlers()
        $this.IsFocusable = $true
        $this.UpdateTitle()
    }
    
    [void] OnInitialize() {
        # Get PRAXIS services
        $this.ThemeManager = $this.ServiceContainer.GetService("ThemeManager")
        $this.EventBus = $this.ServiceContainer.GetService('EventBus')
        
        # Load editor settings from config
        $this.LoadEditorSettings()
        
        # Initialize auto-save and crash recovery
        $this.InitializeAutoSave()
        $this.CheckForCrashRecovery()
        
        # Subscribe to configuration changes
        if ($this.EventBus) {
            $screen = $this
            $this.EventBus.Subscribe([EventNames]::ConfigChanged, {
                param($sender, $eventData)
                if ($eventData.Path -match "^Editor\.") {
                    $screen.LoadEditorSettings()
                    $screen.InvalidateAllLines()
                    $screen.Invalidate()
                }
            }.GetNewClosure())
        }
    }
    
    hidden [void] InitializeRenderCache() {
        $this._lineRenderCache = @{}
        $this._dirtyLines = @{}
    }
    
    [void] LoadEditorSettings() {
        $configService = $this.ServiceContainer.GetService("ConfigurationService")
        if (-not $configService) { return }
        
        # Load all editor settings
        $editorConfig = $configService.Get("Editor")
        if ($editorConfig) {
            # Apply settings
            if ($editorConfig.ContainsKey("TabSize")) {
                $this.TabWidth = [int]$editorConfig.TabSize
            }
            if ($editorConfig.ContainsKey("ShowLineNumbers")) {
                $this.ShowLineNumbers = [bool]$editorConfig.ShowLineNumbers
                # Adjust line number width if needed
                $this.InvalidateAllLines()
            }
            if ($editorConfig.ContainsKey("AutoSaveInterval")) {
                # TODO: Implement auto-save timer
            }
            # Additional settings can be applied here
        }
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
    
    [void] InvalidateAllLines() {
        # Mark all lines as dirty
        $this._allLinesDirty = $true
        # Clear the line render cache
        if ($this._lineRenderCache) {
            $this._lineRenderCache.Clear()
        }
        # Invalidate the component
        $this.Invalidate()
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
        $sampleText = @"
PRAXIS Text Editor

High-performance text editing with professional features:
• Gap Buffer for efficient text operations
• Full undo/redo support (Ctrl+Z / Ctrl+Y)
• Block selection (Shift+Arrow keys)
• Find and Replace (Ctrl+F / Ctrl+H)

Keyboard shortcuts:
• Ctrl+C/X/V     Copy/Cut/Paste
• Ctrl+A         Select all
• Ctrl+Z         Undo (or Ctrl+U)
• Ctrl+Y         Redo (or Ctrl+R)
• Ctrl+F         Find
• Ctrl+H         Find and Replace
• Ctrl+S         Save (when file loaded)
• Shift+Arrows   Block selection
• Delete/Backspace  Delete text
• ESC            Clear selection

All operations support full undo/redo!
"@
        
        # Set the content using the buffer's proper interface
        # This bypasses the command system intentionally so it doesn't affect undo
        if ($this._buffer.GetType().Name -eq "GapBufferDocumentBuffer") {
            # Use GapBuffer's SetText method
            $this._buffer._gapBuffer.SetText($sampleText + "`n")
            $this._buffer.InvalidateLineIndex()
        } else {
            # Use DocumentBuffer's Lines property
            $this._buffer.Lines.Clear()
            $lines = $sampleText -split "`r?`n"
            foreach ($line in $lines) {
                $this._buffer.Lines.Add($line) | Out-Null
            }
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
                $extend = $keyInfo.Modifiers -band [System.ConsoleModifiers]::Shift
                $this.MoveCursorLeft($extend)
                return $true
            }
            ([System.ConsoleKey]::RightArrow) {
                $extend = $keyInfo.Modifiers -band [System.ConsoleModifiers]::Shift
                $this.MoveCursorRight($extend)
                return $true
            }
            ([System.ConsoleKey]::UpArrow) {
                $extend = $keyInfo.Modifiers -band [System.ConsoleModifiers]::Shift
                $this.MoveCursorUp($extend)
                return $true
            }
            ([System.ConsoleKey]::DownArrow) {
                $extend = $keyInfo.Modifiers -band [System.ConsoleModifiers]::Shift
                $this.MoveCursorDown($extend)
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
                ([System.ConsoleKey]::U) {
                    $this.UndoEdit()
                    return $true
                }
                ([System.ConsoleKey]::R) {
                    $this.RedoEdit()
                    return $true
                }
                ([System.ConsoleKey]::Z) {
                    $this.UndoEdit()
                    return $true
                }
                ([System.ConsoleKey]::Y) {
                    $this.RedoEdit()
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
                ([System.ConsoleKey]::F) {
                    $this.ShowFindReplaceDialog()
                    return $true
                }
                ([System.ConsoleKey]::H) {
                    $this.ShowFindReplaceDialog()
                    return $true
                }
                ([System.ConsoleKey]::I) {
                    $this.ShowBufferInfo()
                    return $true
                }
            }
        }
        
        return $false
    }
    
    # --- Text Editing Operations (Command Pattern) ---
    
    hidden [void] InsertCharacter([char]$char) {
        try {
            # Delete selection first if it exists (standard text editor behavior)
            if ($this.HasSelection) {
                $this.DeleteSelection()
            }
            
            # Check if we should group this insert with previous ones
            $now = [datetime]::Now
            $timeDiff = $now - $this._lastActionTime
            $shouldGroup = $this._groupingInserts -and $timeDiff.TotalMilliseconds -lt 1000
            
            if (-not $shouldGroup) {
                # Save complete document state before making changes
                $this.SaveDocumentState()
                $this._groupingInserts = $true
            }
            
            # Insert character using command for GapBuffer
            if ($this._buffer.GetType().Name -eq "GapBufferDocumentBuffer") {
                $command = [InsertTextCommand]::new($this.CursorY, $this.CursorX, [string]$char)
                $this._buffer.ExecuteCommand($command)
            } else {
                $this._buffer.InsertTextAt($this.CursorY, $this.CursorX, [string]$char)
            }
            $this.CursorX++
            $this._lastActionTime = $now
            
            # Mark as modified
            $this._buffer.IsModified = $true
            $this._allLinesDirty = $true
            if ($this._lineRenderCache) {
                $this._lineRenderCache.Clear()
            }
            
            $this.EnsureCursorVisible()
            $this.Invalidate()
            
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
        
        # Stop grouping inserts when user starts deleting
        $this._groupingInserts = $false
        $this.SaveDocumentState()
        
        if ($this.CursorX -gt 0) {
            # Delete character before cursor using command for GapBuffer
            if ($this._buffer.GetType().Name -eq "GapBufferDocumentBuffer") {
                $charToDelete = $this._buffer.GetTextAt($this.CursorY, $this.CursorX - 1, 1)
                $command = [DeleteTextCommand]::new($this.CursorY, $this.CursorX - 1, $charToDelete)
                $this._buffer.ExecuteCommand($command)
            } else {
                $this._buffer.DeleteTextAt($this.CursorY, $this.CursorX - 1, 1)
            }
            $this.CursorX--
        } elseif ($this.CursorY -gt 0) {
            # Join with previous line
            $prevLineLength = $this._buffer.GetLine($this.CursorY - 1).Length
            if ($this._buffer.GetType().Name -eq "GapBufferDocumentBuffer") {
                $currentLineText = $this._buffer.GetLine($this.CursorY)
                $command = [JoinLinesCommand]::new($this.CursorY - 1, $currentLineText)
                $this._buffer.ExecuteCommand($command)
            } else {
                $currentLineText = $this._buffer.GetLine($this.CursorY)
                $this._buffer.JoinLinesAt($this.CursorY - 1, "")
            }
            $this.CursorY--
            $this.CursorX = $prevLineLength
        }
        
        $this._buffer.IsModified = $true
        $this._allLinesDirty = $true
        if ($this._lineRenderCache) {
            $this._lineRenderCache.Clear()
        }
        $this.EnsureCursorVisible()
        $this.Invalidate()
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
        # Delete selection first if it exists
        if ($this.HasSelection) {
            $this.DeleteSelection()
        }
        
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
    
    # --- Find/Replace Dialog ---
    
    [void] ShowFindReplaceDialog() {
        try {
            # Create the find/replace dialog
            $findDialog = [FindReplaceDialog]::new($this)
            
            # Set up callback for when dialog closes
            $editor = $this
            $findDialog.OnClose = {
                # Focus returns to editor when dialog closes
                $editor.Focus()
            }.GetNewClosure()
            
            # Push the dialog onto the screen stack
            $screenManager = $this.ServiceContainer.GetService("ScreenManager")
            if ($screenManager) {
                $screenManager.Push($findDialog)
            } else {
                $this.StatusMessage = "Cannot open find dialog: ScreenManager not available"
            }
            
        } catch {
            if ($global:Logger) {
                $global:Logger.Error("ShowFindReplaceDialog failed: $($_.Exception.Message)")
            }
            $this.StatusMessage = "Error opening find dialog: $($_.Exception.Message)"
        }
    }
    
    # --- Buffer Information ---
    
    [void] ShowBufferInfo() {
        try {
            if ($this._buffer.GetType().Name -eq "GapBufferDocumentBuffer") {
                $stats = $this._buffer.GetStatistics()
                $gapStats = $stats.GapBuffer
                
                $info = @"
Gap Buffer Performance Statistics:

Buffer Info:
• Length: $($gapStats.Length) characters
• Capacity: $($gapStats.Capacity) characters  
• Gap Size: $($gapStats.GapSize) characters
• Gap Position: $($gapStats.GapStart)-$($gapStats.GapEnd)

Operations:
• Inserts: $($gapStats.InsertCount)
• Deletes: $($gapStats.DeleteCount)  
• Gap Moves: $($gapStats.MoveCount)
• Buffer Grows: $($gapStats.GrowCount)
• Efficiency: $($gapStats.Efficiency) ops/move

Document Info:
• Lines: $($stats.LineCount)
• Line Index Rebuilds: $($stats.LineIndexRebuildCount)
• Undo Stack: $($stats.UndoStackSize)
• Redo Stack: $($stats.RedoStackSize)
"@
            } else {
                $info = @"
ArrayList Document Buffer:

Buffer Info:
• Lines: $($this._buffer.GetLineCount())
• Total Characters: $($this._buffer.Lines | ForEach-Object { $_.Length } | Measure-Object -Sum | Select-Object -ExpandProperty Sum)
• Undo Stack: $($this._buffer._undoStack.Count)
• Redo Stack: $($this._buffer._redoStack.Count)

Note: Using basic ArrayList implementation.
Switch to GapBufferDocumentBuffer for better performance.
"@
            }
            
            $this.StatusMessage = "Buffer statistics shown. Press any key to continue editing."
            $this.Invalidate()
            
            # Simple info display in status - in a real implementation you might want a dialog
            if ($global:Logger) {
                $global:Logger.Info("Buffer Statistics:`n$info")
            }
            
        } catch {
            if ($global:Logger) {
                $global:Logger.Error("ShowBufferInfo failed: $($_.Exception.Message)")
            }
            $this.StatusMessage = "Error retrieving buffer information"
        }
    }
    
    # --- Undo/Redo ---
    
    [void] UndoEdit() {
        # Use the buffer's undo system if it supports it
        if ($this._buffer.GetType().Name -eq "GapBufferDocumentBuffer") {
            if ($this._buffer.CanUndo()) {
                $this._buffer.Undo()
                $this.StatusMessage = "Undo"
                $this._allLinesDirty = $true
                $this.Invalidate()
                # Update cursor position based on buffer state
                $this.EnsureCursorValid()
            } else {
                $this.StatusMessage = "Nothing to undo"
            }
        } else {
            # Fallback to editor's own undo for basic buffers
            if ($this._undoStack.Count -eq 0) {
                $this.StatusMessage = "Nothing to undo"
                return
            }
            
            try {
                $this._groupingInserts = $false
                
                $currentState = $this.GetDocumentState()
                $this._redoStack.Add($currentState) | Out-Null
                
                $previousState = $this._undoStack[$this._undoStack.Count - 1]
                $this._undoStack.RemoveAt($this._undoStack.Count - 1)
                
                $this.RestoreDocumentState($previousState)
                $this.StatusMessage = "Undo"
            } catch {
                if ($global:Logger) {
                    $global:Logger.Error("UndoEdit failed: $($_.Exception.Message)")
                }
                $this.StatusMessage = "Undo failed"
            }
        }
    }
    
    [void] RedoEdit() {
        # Use the buffer's redo system if it supports it
        if ($this._buffer.GetType().Name -eq "GapBufferDocumentBuffer") {
            if ($this._buffer.CanRedo()) {
                $this._buffer.Redo()
                $this.StatusMessage = "Redo"
                $this._allLinesDirty = $true
                $this.Invalidate()
                # Update cursor position based on buffer state
                $this.EnsureCursorValid()
            } else {
                $this.StatusMessage = "Nothing to redo"
            }
        } else {
            # Fallback to editor's own redo for basic buffers
            if ($this._redoStack.Count -eq 0) {
                $this.StatusMessage = "Nothing to redo"
                return
            }
            
            try {
                $this._groupingInserts = $false
                
                $currentState = $this.GetDocumentState()
                $this._undoStack.Add($currentState) | Out-Null
                
                $redoState = $this._redoStack[$this._redoStack.Count - 1]
                $this._redoStack.RemoveAt($this._redoStack.Count - 1)
                
                $this.RestoreDocumentState($redoState)
                $this.StatusMessage = "Redo"
            } catch {
                if ($global:Logger) {
                    $global:Logger.Error("RedoEdit failed: $($_.Exception.Message)")
                }
                $this.StatusMessage = "Redo failed"
            }
        }
    }
    
    hidden [void] SaveDocumentState() {
        # Only save state for non-GapBuffer implementations
        # GapBuffer handles its own undo internally through commands
        if ($this._buffer.GetType().Name -ne "GapBufferDocumentBuffer") {
            $state = $this.GetDocumentState()
            $this._undoStack.Add($state) | Out-Null
            
            # Clear redo stack when new action is performed
            $this._redoStack.Clear()
            
            # Limit undo history
            if ($this._undoStack.Count -gt 50) {
                $this._undoStack.RemoveAt(0)
            }
        }
    }
    
    hidden [hashtable] GetDocumentState() {
        # Create a deep copy of the document state
        $linesCopy = [System.Collections.ArrayList]::new()
        foreach ($line in $this._buffer.Lines) {
            $linesCopy.Add([string]$line) | Out-Null
        }
        
        return @{
            Lines = $linesCopy
            CursorX = $this.CursorX
            CursorY = $this.CursorY
            ScrollOffsetX = $this.ScrollOffsetX
            ScrollOffsetY = $this.ScrollOffsetY
            IsModified = $this._buffer.IsModified
        }
    }
    
    hidden [void] RestoreDocumentState([hashtable]$state) {
        # Restore the complete document state
        $this._buffer.Lines.Clear()
        foreach ($line in $state.Lines) {
            $this._buffer.Lines.Add([string]$line) | Out-Null
        }
        
        $this.CursorX = $state.CursorX
        $this.CursorY = $state.CursorY
        $this.ScrollOffsetX = $state.ScrollOffsetX
        $this.ScrollOffsetY = $state.ScrollOffsetY
        $this._buffer.IsModified = $state.IsModified
        
        # Mark all lines dirty and refresh
        $this._allLinesDirty = $true
        if ($this._lineRenderCache) {
            $this._lineRenderCache.Clear()
        }
        $this.EnsureCursorVisible()
        $this.Invalidate()
    }
    
    
    # --- Selection and Clipboard (Stub implementations) ---
    
    hidden [void] ClearSelection() {
        $this.HasSelection = $false
        $this.InSelectionMode = $false
        $this.SelectionStartX = 0
        $this.SelectionStartY = 0
        $this.SelectionEndX = 0
        $this.SelectionEndY = 0
    }
    
    hidden [void] StartSelection() {
        $this.HasSelection = $true
        $this.InSelectionMode = $true
        $this.SelectionStartX = $this.CursorX
        $this.SelectionStartY = $this.CursorY
        $this.SelectionEndX = $this.CursorX
        $this.SelectionEndY = $this.CursorY
    }
    
    hidden [void] UpdateSelection() {
        if ($this.HasSelection) {
            $this.SelectionEndX = $this.CursorX
            $this.SelectionEndY = $this.CursorY
            $this._allLinesDirty = $true  # Selection changes require full redraw
            $this.Invalidate()
        }
    }
    
    hidden [void] DeleteSelection() {
        if (-not $this.HasSelection) {
            return
        }
        
        # Get normalized selection bounds
        $bounds = $this.GetSelectionBounds()
        
        # Save state for undo
        $this.SaveDocumentState()
        
        # For GapBuffer, we need to calculate the total character range to delete
        if ($this._buffer.GetType().Name -eq "GapBufferDocumentBuffer") {
            # Get the selected text first (for potential undo)
            $selectedText = $this.GetSelectedText($bounds)
            
            # Calculate total characters to delete including newlines
            $deleteCount = 0
            
            if ($bounds.StartY -eq $bounds.EndY) {
                # Single line - simple case
                $deleteCount = $bounds.EndX - $bounds.StartX
            } else {
                # Multi-line selection
                # First line: from StartX to end of line + newline
                $firstLine = $this._buffer.GetLine($bounds.StartY)
                $deleteCount += ($firstLine.Length - $bounds.StartX) + 1  # +1 for newline
                
                # Middle lines: entire lines including newlines
                for ($y = $bounds.StartY + 1; $y -lt $bounds.EndY; $y++) {
                    $line = $this._buffer.GetLine($y)
                    $deleteCount += $line.Length + 1  # +1 for newline
                }
                
                # Last line: from start to EndX (no newline)
                $deleteCount += $bounds.EndX
            }
            
            # Delete using buffer's delete method with calculated length
            if ($deleteCount -gt 0) {
                # For multi-line, we need to delete line by line from bottom to top
                if ($bounds.StartY -eq $bounds.EndY) {
                    # Single line - simple delete
                    $this._buffer.DeleteTextAt($bounds.StartY, $bounds.StartX, $deleteCount)
                } else {
                    # Multi-line - more complex
                    # First, get text that will remain after deletion
                    $firstLine = $this._buffer.GetLine($bounds.StartY)
                    $lastLine = $this._buffer.GetLine($bounds.EndY)
                    $keepBefore = $firstLine.Substring(0, $bounds.StartX)
                    $keepAfter = if ($bounds.EndX -lt $lastLine.Length) { $lastLine.Substring($bounds.EndX) } else { "" }
                    
                    # Delete from last line backwards
                    for ($y = $bounds.EndY; $y -ge $bounds.StartY; $y--) {
                        if ($y -eq $bounds.EndY -and $y -eq $bounds.StartY) {
                            # Single line (shouldn't happen here)
                            $this._buffer.DeleteTextAt($y, $bounds.StartX, $bounds.EndX - $bounds.StartX)
                        } elseif ($y -eq $bounds.EndY) {
                            # Last line - delete from start to EndX, then the newline before it
                            $this._buffer.DeleteTextAt($y, 0, $bounds.EndX)
                            if ($y -gt 0) {
                                # Delete the newline at end of previous line
                                $prevLine = $this._buffer.GetLine($y - 1)
                                $this._buffer.DeleteTextAt($y - 1, $prevLine.Length, 1)
                            }
                        } elseif ($y -eq $bounds.StartY) {
                            # First line - delete from StartX to end (newline was already removed)
                            $line = $this._buffer.GetLine($y)
                            $deleteLen = $line.Length - $bounds.StartX
                            if ($deleteLen -gt 0) {
                                $this._buffer.DeleteTextAt($y, $bounds.StartX, $deleteLen)
                            }
                            # Now append the keepAfter text
                            if ($keepAfter.Length -gt 0) {
                                $this._buffer.InsertTextAt($y, $bounds.StartX, $keepAfter)
                            }
                        } else {
                            # Middle line - delete entire line by deleting from previous line's newline
                            if ($y -gt 0) {
                                $prevLine = $this._buffer.GetLine($y - 1)
                                $this._buffer.DeleteTextAt($y - 1, $prevLine.Length, 1)
                            }
                        }
                    }
                }
            }
        } else {
            # Fallback for non-GapBuffer buffers
            if ($bounds.StartY -eq $bounds.EndY) {
                # Single line selection
                $this._buffer.DeleteTextAt($bounds.StartY, $bounds.StartX, $bounds.EndX - $bounds.StartX)
            } else {
                # Multi-line selection - build the text to keep
                $firstLine = $this._buffer.GetLine($bounds.StartY)
                $lastLine = $this._buffer.GetLine($bounds.EndY)
                
                # Keep the part before selection and after selection
                $keepBefore = $firstLine.Substring(0, $bounds.StartX)
                $keepAfter = if ($bounds.EndX -lt $lastLine.Length) { $lastLine.Substring($bounds.EndX) } else { "" }
                
                # Replace the first line with combined text
                $this._buffer.SetLine($bounds.StartY, $keepBefore + $keepAfter)
                
                # Remove all lines between start and end
                $linesToRemove = $bounds.EndY - $bounds.StartY
                for ($i = 0; $i -lt $linesToRemove; $i++) {
                    $this._buffer.RemoveLine($bounds.StartY + 1)
                }
            }
        }
        
        # Move cursor to selection start
        $this.CursorX = $bounds.StartX
        $this.CursorY = $bounds.StartY
        
        # Ensure cursor is valid
        $this.EnsureCursorValid()
        
        $this.ClearSelection()
        $this._buffer.IsModified = $true
        $this._allLinesDirty = $true
        if ($this._lineRenderCache) {
            $this._lineRenderCache.Clear()
        }
        $this.Invalidate()
    }
    
    hidden [string] GetSelectedText([hashtable]$bounds) {
        if ($bounds.StartY -eq $bounds.EndY) {
            # Single line selection
            $line = $this._buffer.GetLine($bounds.StartY)
            return $line.Substring($bounds.StartX, $bounds.EndX - $bounds.StartX)
        } else {
            # Multi-line selection
            $text = ""
            for ($y = $bounds.StartY; $y -le $bounds.EndY; $y++) {
                $line = $this._buffer.GetLine($y)
                if ($y -eq $bounds.StartY) {
                    # First line - from StartX to end
                    $text += $line.Substring($bounds.StartX)
                } elseif ($y -eq $bounds.EndY) {
                    # Last line - from start to EndX
                    $text += "`n" + $line.Substring(0, $bounds.EndX)
                } else {
                    # Middle lines - entire line
                    $text += "`n" + $line
                }
            }
            return $text
        }
    }
    
    hidden [hashtable] GetSelectionBounds() {
        if (-not $this.HasSelection) {
            return @{ StartX = 0; StartY = 0; EndX = 0; EndY = 0 }
        }
        
        # Normalize selection (start should be before end)
        if ($this.SelectionStartY -lt $this.SelectionEndY -or 
            ($this.SelectionStartY -eq $this.SelectionEndY -and $this.SelectionStartX -le $this.SelectionEndX)) {
            return @{
                StartX = $this.SelectionStartX
                StartY = $this.SelectionStartY
                EndX = $this.SelectionEndX
                EndY = $this.SelectionEndY
            }
        } else {
            return @{
                StartX = $this.SelectionEndX
                StartY = $this.SelectionEndY
                EndX = $this.SelectionStartX
                EndY = $this.SelectionStartY
            }
        }
    }
    
    [void] CopySelection() {
        if (-not $this.HasSelection) {
            $this.StatusMessage = "No selection to copy"
            return
        }
        
        $bounds = $this.GetSelectionBounds()
        $copiedText = ""
        
        if ($bounds.StartY -eq $bounds.EndY) {
            # Single line selection
            $line = $this._buffer.GetLine($bounds.StartY)
            $copiedText = $line.Substring($bounds.StartX, $bounds.EndX - $bounds.StartX)
        } else {
            # Multi-line selection
            $lines = [System.Collections.ArrayList]::new()
            
            for ($y = $bounds.StartY; $y -le $bounds.EndY; $y++) {
                $line = $this._buffer.GetLine($y)
                if ($y -eq $bounds.StartY) {
                    # First line - from StartX to end
                    $lines.Add($line.Substring($bounds.StartX)) | Out-Null
                } elseif ($y -eq $bounds.EndY) {
                    # Last line - from start to EndX
                    $lines.Add($line.Substring(0, $bounds.EndX)) | Out-Null
                } else {
                    # Middle lines - entire line
                    $lines.Add($line) | Out-Null
                }
            }
            $copiedText = $lines -join "`n"
        }
        
        # Store in global clipboard
        if (-not $global:TuiClipboard) {
            $global:TuiClipboard = ""
        }
        $global:TuiClipboard = $copiedText
        $this._clipboard = $copiedText
        
        $this.StatusMessage = "Copied to clipboard"
    }
    
    [void] CutSelection() {
        if (-not $this.HasSelection) {
            $this.StatusMessage = "No selection to cut"
            return
        }
        
        # Copy first, then delete
        $this.CopySelection()
        $this.DeleteSelection()
        $this.StatusMessage = "Cut to clipboard"
    }
    
    [void] PasteClipboard() {
        # Get text from global clipboard or internal clipboard
        $textToPaste = ""
        if ($global:TuiClipboard) {
            $textToPaste = $global:TuiClipboard
        } elseif ($this._clipboard) {
            $textToPaste = $this._clipboard
        } else {
            $this.StatusMessage = "Clipboard is empty"
            return
        }
        
        # Delete any existing selection first
        if ($this.HasSelection) {
            $this.DeleteSelection()
        }
        
        # Save state for undo
        $this.SaveDocumentState()
        
        # Insert the pasted text
        $lines = $textToPaste -split "`n"
        if ($lines.Count -eq 1) {
            # Single line paste
            $this._buffer.InsertTextAt($this.CursorY, $this.CursorX, $textToPaste)
            $this.CursorX += $textToPaste.Length
        } else {
            # Multi-line paste
            $currentLine = $this._buffer.GetLine($this.CursorY)
            $leftPart = $currentLine.Substring(0, $this.CursorX)
            $rightPart = $currentLine.Substring($this.CursorX)
            
            # Replace current line with first line of paste
            $this._buffer.Lines[$this.CursorY] = $leftPart + $lines[0]
            
            # Insert middle lines
            for ($i = 1; $i -lt $lines.Count - 1; $i++) {
                $this._buffer.Lines.Insert($this.CursorY + $i, $lines[$i])
            }
            
            # Insert last line and append remaining text
            if ($lines.Count -gt 1) {
                $lastLine = $lines[$lines.Count - 1] + $rightPart
                $this._buffer.Lines.Insert($this.CursorY + $lines.Count - 1, $lastLine)
                $this.CursorY += $lines.Count - 1
                $this.CursorX = $lines[$lines.Count - 1].Length
            }
        }
        
        $this._buffer.IsModified = $true
        $this._allLinesDirty = $true
        if ($this._lineRenderCache) {
            $this._lineRenderCache.Clear()
        }
        $this.EnsureCursorVisible()
        $this.Invalidate()
        $this.StatusMessage = "Pasted from clipboard"
    }
    
    [void] SelectAll() {
        $this.StartSelection()
        
        # Set selection to entire document
        $this.SelectionStartX = 0
        $this.SelectionStartY = 0
        
        $lastLineIndex = $this._buffer.GetLineCount() - 1
        $this.SelectionEndY = $lastLineIndex
        $this.SelectionEndX = $this._buffer.GetLine($lastLineIndex).Length
        
        # Move cursor to end
        $this.CursorY = $this.SelectionEndY
        $this.CursorX = $this.SelectionEndX
        
        $this._allLinesDirty = $true
        $this.Invalidate()
        $this.StatusMessage = "Selected all text"
    }
    
    # --- Cursor Movement (Stub implementations) ---
    
    hidden [void] MoveCursorLeft([bool]$extend) {
        # Start selection if shift is held and no selection exists
        if ($extend -and -not $this.HasSelection) {
            $this.StartSelection()
        }
        
        if ($this.CursorX -gt 0) {
            $this.CursorX--
        } elseif ($this.CursorY -gt 0) {
            $this.CursorY--
            $this.CursorX = $this._buffer.GetLine($this.CursorY).Length
        }
        
        # Update or clear selection
        if ($extend) {
            $this.UpdateSelection()
        } else {
            $this.ClearSelection()
        }
        
        $this.EnsureCursorVisible()
    }
    
    hidden [void] MoveCursorRight([bool]$extend) {
        if ($extend -and -not $this.HasSelection) {
            $this.StartSelection()
        }
        
        $currentLine = $this._buffer.GetLine($this.CursorY)
        if ($this.CursorX -lt $currentLine.Length) {
            $this.CursorX++
        } elseif ($this.CursorY -lt $this._buffer.GetLineCount() - 1) {
            $this.CursorY++
            $this.CursorX = 0
        }
        
        if ($extend) {
            $this.UpdateSelection()
        } else {
            $this.ClearSelection()
        }
        
        $this.EnsureCursorVisible()
    }
    
    hidden [void] MoveCursorUp([bool]$extend) {
        if ($extend -and -not $this.HasSelection) {
            $this.StartSelection()
        }
        
        if ($this.CursorY -gt 0) {
            $this.CursorY--
            $prevLine = $this._buffer.GetLine($this.CursorY)
            $this.CursorX = [Math]::Min($this.CursorX, $prevLine.Length)
        }
        
        if ($extend) {
            $this.UpdateSelection()
        } else {
            $this.ClearSelection()
        }
        
        $this.EnsureCursorVisible()
    }
    
    hidden [void] MoveCursorDown([bool]$extend) {
        if ($extend -and -not $this.HasSelection) {
            $this.StartSelection()
        }
        
        if ($this.CursorY -lt $this._buffer.GetLineCount() - 1) {
            $this.CursorY++
            $nextLine = $this._buffer.GetLine($this.CursorY)
            $this.CursorX = [Math]::Min($this.CursorX, $nextLine.Length)
        }
        
        if ($extend) {
            $this.UpdateSelection()
        } else {
            $this.ClearSelection()
        }
        
        $this.EnsureCursorVisible()
    }
    
    hidden [void] MoveCursorHome([bool]$extend) {
        if ($extend -and -not $this.HasSelection) {
            $this.StartSelection()
        }
        
        $this.CursorX = 0
        
        if ($extend) {
            $this.UpdateSelection()
        } else {
            $this.ClearSelection()
        }
        
        $this.EnsureCursorVisible()
    }
    
    hidden [void] MoveCursorEnd([bool]$extend) {
        if ($extend -and -not $this.HasSelection) {
            $this.StartSelection()
        }
        
        $this.CursorX = $this._buffer.GetLine($this.CursorY).Length
        
        if ($extend) {
            $this.UpdateSelection()
        } else {
            $this.ClearSelection()
        }
        
        $this.EnsureCursorVisible()
    }
    
    hidden [void] MoveCursorPageUp([bool]$extend) {
        if ($extend -and -not $this.HasSelection) {
            $this.StartSelection()
        }
        
        $pageSize = $this.Height - 4
        $this.CursorY = [Math]::Max(0, $this.CursorY - $pageSize)
        
        # Ensure cursor X is within bounds of the new line
        $currentLine = $this._buffer.GetLine($this.CursorY)
        $this.CursorX = [Math]::Min($this.CursorX, $currentLine.Length)
        
        if ($extend) {
            $this.UpdateSelection()
        } else {
            $this.ClearSelection()
        }
        
        $this.EnsureCursorVisible()
    }
    
    hidden [void] MoveCursorPageDown([bool]$extend) {
        if ($extend -and -not $this.HasSelection) {
            $this.StartSelection()
        }
        
        $pageSize = $this.Height - 4
        $this.CursorY = [Math]::Min($this._buffer.GetLineCount() - 1, $this.CursorY + $pageSize)
        
        # Ensure cursor X is within bounds of the new line
        $currentLine = $this._buffer.GetLine($this.CursorY)
        $this.CursorX = [Math]::Min($this.CursorX, $currentLine.Length)
        
        if ($extend) {
            $this.UpdateSelection()
        } else {
            $this.ClearSelection()
        }
        
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
    
    hidden [void] EnsureCursorValid() {
        # Ensure cursor Y is within valid range
        $lineCount = $this._buffer.GetLineCount()
        if ($this.CursorY -ge $lineCount) {
            $this.CursorY = [Math]::Max(0, $lineCount - 1)
        }
        if ($this.CursorY -lt 0) {
            $this.CursorY = 0
        }
        
        # Ensure cursor X is within valid range for current line
        if ($this.CursorY -lt $lineCount) {
            $currentLine = $this._buffer.GetLine($this.CursorY)
            if ($this.CursorX -gt $currentLine.Length) {
                $this.CursorX = $currentLine.Length
            }
        }
        if ($this.CursorX -lt 0) {
            $this.CursorX = 0
        }
        
        # Make sure cursor is visible
        $this.EnsureCursorVisible()
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
        $bgColor = if ($this.ThemeManager) { $this.ThemeManager.GetBgColor('surface.background') } else { "" }
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
        
        # Render cursor if focused and visible
        if ($this.IsFocused) {
            $this.RenderCursor($sb, $lineNumWidth, $editorHeight)
        }
        
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
        $textColor = if ($this.ThemeManager) { $this.ThemeManager.GetColor('text.primary') } else { "" }
        $lineNumColor = if ($this.ThemeManager) { $this.ThemeManager.GetColor('editor.linenumber') } else { $textColor }
        $bgColor = if ($this.ThemeManager) { $this.ThemeManager.GetBgColor('surface.background') } else { "" }
        $selectionBgColor = if ($this.ThemeManager) { $this.ThemeManager.GetBgColor("selection") } else { "\e[0;7m" }
        $selectionTextColor = if ($this.ThemeManager) { $this.ThemeManager.GetColor("selection.text") } else { "" }
        
        # Apply background color
        $sb.Append($bgColor)
        
        # Line number
        if ($this.ShowLineNumbers) {
            $sb.Append($lineNumColor)
            $lineNumText = ($lineNumber + 1).ToString().PadLeft($lineNumberWidth - 1) + " "
            $sb.Append($lineNumText)
        }
        
        # Get line text and determine what's visible
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
        
        # Check if this line has selection
        if ($this.HasSelection) {
            $bounds = $this.GetSelectionBounds()
            
            # Check if current line intersects with selection
            if ($lineNumber -ge $bounds.StartY -and $lineNumber -le $bounds.EndY) {
                # Line has selection - render with highlighting
                $this.RenderLineWithSelection($sb, $lineNumber, $visibleText, $textWidth, $bounds, $textColor, $selectionBgColor, $selectionTextColor)
            } else {
                # No selection on this line - render normally
                $sb.Append($textColor)
                $sb.Append($visibleText)
            }
        } else {
            # No selection at all - render normally
            $sb.Append($textColor)
            $sb.Append($visibleText)
        }
        
        # Pad to full width
        $totalRendered = $lineNumberWidth + $visibleText.Length
        if ($totalRendered -lt $this.Width) {
            $sb.Append($bgColor)  # Ensure padding uses background color
            $sb.Append([StringCache]::GetSpaces($this.Width - $totalRendered))
        }
        
        return $sb.ToString()
    }
    
    hidden [void] RenderLineWithSelection([System.Text.StringBuilder]$sb, [int]$lineNumber, [string]$visibleText, [int]$textWidth, [hashtable]$bounds, [string]$textColor, [string]$selectionBgColor, [string]$selectionTextColor) {
        if ($bounds.StartY -eq $bounds.EndY -and $bounds.StartY -eq $lineNumber) {
            # Single line selection
            $selStart = [Math]::Max(0, $bounds.StartX - $this.ScrollOffsetX)
            $selEnd = [Math]::Min($visibleText.Length, $bounds.EndX - $this.ScrollOffsetX)
            
            if ($selStart -ge 0 -and $selStart -lt $visibleText.Length) {
                # Before selection
                if ($selStart -gt 0) {
                    $sb.Append($textColor)
                    $sb.Append($visibleText.Substring(0, $selStart))
                }
                
                # Selection
                if ($selEnd -gt $selStart) {
                    $sb.Append($selectionBgColor)
                    $sb.Append($selectionTextColor)
                    $sb.Append($visibleText.Substring($selStart, $selEnd - $selStart))
                    $sb.Append($textColor)  # Reset to normal colors
                }
                
                # After selection
                if ($selEnd -lt $visibleText.Length) {
                    $sb.Append($visibleText.Substring($selEnd))
                }
            } else {
                # Selection not visible on this part of the line
                $sb.Append($textColor)
                $sb.Append($visibleText)
            }
        } elseif ($lineNumber -eq $bounds.StartY) {
            # First line of multi-line selection
            $selStart = [Math]::Max(0, $bounds.StartX - $this.ScrollOffsetX)
            
            if ($selStart -ge 0 -and $selStart -lt $visibleText.Length) {
                # Before selection
                if ($selStart -gt 0) {
                    $sb.Append($textColor)
                    $sb.Append($visibleText.Substring(0, $selStart))
                }
                
                # Selection from start to end of visible text
                $sb.Append($selectionBgColor)
                $sb.Append($selectionTextColor)
                $sb.Append($visibleText.Substring($selStart))
            } else {
                # Selection starts beyond visible area - whole line is selected
                $sb.Append($selectionBgColor)
                $sb.Append($selectionTextColor)
                $sb.Append($visibleText)
            }
        } elseif ($lineNumber -eq $bounds.EndY) {
            # Last line of multi-line selection
            $selEnd = [Math]::Min($visibleText.Length, $bounds.EndX - $this.ScrollOffsetX)
            
            if ($selEnd -gt 0) {
                # Selection from start to EndX
                $sb.Append($selectionBgColor)
                $sb.Append($selectionTextColor)
                $sb.Append($visibleText.Substring(0, $selEnd))
                $sb.Append($textColor)  # Reset colors
                
                # After selection
                if ($selEnd -lt $visibleText.Length) {
                    $sb.Append($visibleText.Substring($selEnd))
                }
            } else {
                # Selection ends before visible area - no selection on visible part
                $sb.Append($textColor)
                $sb.Append($visibleText)
            }
        } else {
            # Middle line of multi-line selection - entire line is selected
            $sb.Append($selectionBgColor)
            $sb.Append($selectionTextColor)
            $sb.Append($visibleText)
        }
    }
    
    hidden [void] RenderCursor([System.Text.StringBuilder]$sb, [int]$lineNumWidth, [int]$editorHeight) {
        # Check if cursor is within visible viewport
        if ($this.CursorY -lt $this.ScrollOffsetY -or $this.CursorY -ge $this.ScrollOffsetY + $editorHeight) {
            return  # Cursor not visible
        }
        
        # Calculate cursor screen position
        $cursorScreenY = $this.Y + ($this.CursorY - $this.ScrollOffsetY)
        $cursorScreenX = $this.X + $lineNumWidth + ($this.CursorX - $this.ScrollOffsetX)
        
        # Ensure cursor X is within visible area
        $editorWidth = $this.Width - $lineNumWidth
        if ($this.CursorX -lt $this.ScrollOffsetX -or $this.CursorX -ge $this.ScrollOffsetX + $editorWidth) {
            return  # Cursor not horizontally visible
        }
        
        # Get colors
        $cursorBgColor = if ($this.ThemeManager) { $this.ThemeManager.GetBgColor("cursor") } else { "\e[0;7m" }
        $cursorTextColor = if ($this.ThemeManager) { $this.ThemeManager.GetColor("cursor.text") } else { "" }
        
        # Get character under cursor
        $charUnderCursor = " "
        if ($this.CursorY -lt $this._buffer.GetLineCount()) {
            $currentLine = $this._buffer.GetLine($this.CursorY)
            if ($this.CursorX -lt $currentLine.Length) {
                $charUnderCursor = $currentLine[$this.CursorX]
            }
        }
        
        # Render cursor
        $sb.Append([VT]::MoveTo($cursorScreenX, $cursorScreenY))
        $sb.Append($cursorBgColor)
        $sb.Append($cursorTextColor)
        $sb.Append($charUnderCursor)
        
        # Reset colors
        $resetColor = if ($this.ThemeManager) { $this.ThemeManager.GetColor('text.primary') } else { "\e[0m" }
        $sb.Append($resetColor)
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
        
        # Add buffer type indicator
        $bufferType = if ($this._buffer.GetType().Name -eq "GapBufferDocumentBuffer") { " [GapBuffer]" } else { " [ArrayList]" }
        
        # Add selection indicator
        $selectionStatus = if ($this.HasSelection) { " [Selection]" } else { "" }
        
        $status = "Line $line/$total, Col $col$modified$undoStatus$bufferType$selectionStatus"
        if ($this.StatusMessage) {
            $status += " | $($this.StatusMessage)"
        }
        
        return $status
    }
    
    # === AUTO-SAVE AND CRASH RECOVERY METHODS ===
    
    [void] InitializeAutoSave() {
        # Set up auto-save directory within PRAXIS directory for portability
        $praxisRoot = if ($global:PraxisRoot) { $global:PraxisRoot } else { (Get-Location).Path }
        $this.AutoSaveDirectory = Join-Path $praxisRoot "_AutoSave"
        if (-not (Test-Path $this.AutoSaveDirectory)) {
            New-Item -ItemType Directory -Path $this.AutoSaveDirectory -Force | Out-Null
        }
        
        # Set up auto-save timer if enabled
        if ($this.AutoSaveEnabled) {
            $this._autoSaveTimer = [System.Timers.Timer]::new()
            $this._autoSaveTimer.Interval = $this.AutoSaveIntervalSeconds * 1000
            $this._autoSaveTimer.AutoReset = $true
            
            # Timer event handler
            $editor = $this
            $this._autoSaveTimer.add_Elapsed({
                $editor.PerformAutoSave()
            })
            
            $this._autoSaveTimer.Start()
        }
        
        # Hook into buffer content changes to track modifications
        $this._buffer.OnContentChanged = {
            $this.OnContentChangedForAutoSave()
        }.GetNewClosure()
    }
    
    [void] OnContentChangedForAutoSave() {
        $this._lastModification = [datetime]::Now
        $this._needsAutoSave = $true
        
        # Call original content changed handler if it exists
        $this.OnBufferContentChanged()
    }
    
    [void] PerformAutoSave() {
        try {
            # Only auto-save if there are unsaved changes and enough time has passed
            if (-not $this._needsAutoSave -or $this._buffer.IsModified -eq $false) {
                return
            }
            
            # Check if enough time has passed since last modification (avoid excessive saves during active typing)
            $timeSinceLastMod = ([datetime]::Now - $this._lastModification).TotalSeconds
            if ($timeSinceLastMod -lt 5) {
                return  # Wait at least 5 seconds after last keystroke
            }
            
            $autoSaveFile = $this.GetAutoSaveFilePath()
            if ([string]::IsNullOrEmpty($autoSaveFile)) {
                return
            }
            
            # Save content to auto-save file with metadata
            $content = $this._buffer.GetText()
            $metadata = @{
                OriginalFile = $this._buffer.FilePath
                SaveTime = [datetime]::Now
                EditorVersion = "PRAXIS_v1"
                PID = [System.Diagnostics.Process]::GetCurrentProcess().Id
            } | ConvertTo-Json
            
            # Write with header
            $autoSaveContent = "### PRAXIS AUTO-SAVE FILE ###`n$metadata`n### CONTENT BEGINS ###`n$content"
            Set-Content -Path $autoSaveFile -Value $autoSaveContent -NoNewline
            
            $this._lastAutoSave = [datetime]::Now
            $this._needsAutoSave = $false
            
            if ($global:Logger) {
                $global:Logger.Debug("Auto-saved to: $autoSaveFile")
            }
            
        } catch {
            if ($global:Logger) {
                $global:Logger.Error("Auto-save failed: $($_.Exception.Message)")
            }
        }
    }
    
    [string] GetAutoSaveFilePath() {
        if ([string]::IsNullOrEmpty($this._buffer.FilePath)) {
            # For untitled files, use a generic name with timestamp
            $timestamp = [datetime]::Now.ToString("yyyyMMdd_HHmmss")
            return Join-Path $this.AutoSaveDirectory "Untitled_$timestamp.auto"
        } else {
            # For named files, use original name with .auto extension
            $fileName = [System.IO.Path]::GetFileName($this._buffer.FilePath)
            $safeFileName = $fileName -replace '[<>:"/\\|?*]', '_'  # Replace invalid chars
            return Join-Path $this.AutoSaveDirectory "$safeFileName.auto"
        }
    }
    
    [void] CheckForCrashRecovery() {
        try {
            if (-not (Test-Path $this.AutoSaveDirectory)) {
                return
            }
            
            # Look for auto-save files
            $autoSaveFiles = Get-ChildItem -Path $this.AutoSaveDirectory -Filter "*.auto" | Where-Object {
                $_.LastWriteTime -gt ([datetime]::Now.AddDays(-1))  # Only check files from last 24 hours
            }
            
            if ($autoSaveFiles.Count -eq 0) {
                return
            }
            
            # Check if any auto-save files are newer than their original files
            $recoveryNeeded = @()
            foreach ($autoFile in $autoSaveFiles) {
                $metadata = $this.ParseAutoSaveMetadata($autoFile.FullName)
                if ($metadata -and $metadata.OriginalFile) {
                    if (-not (Test-Path $metadata.OriginalFile)) {
                        # Original file is missing
                        $recoveryNeeded += @{
                            AutoSaveFile = $autoFile.FullName
                            OriginalFile = $metadata.OriginalFile
                            Reason = "Original file missing"
                            SaveTime = $metadata.SaveTime
                        }
                    } elseif ($autoFile.LastWriteTime -gt (Get-Item $metadata.OriginalFile).LastWriteTime) {
                        # Auto-save is newer than original
                        $recoveryNeeded += @{
                            AutoSaveFile = $autoFile.FullName
                            OriginalFile = $metadata.OriginalFile
                            Reason = "Auto-save newer than original"
                            SaveTime = $metadata.SaveTime
                        }
                    }
                }
            }
            
            if ($recoveryNeeded.Count -gt 0) {
                $this.ShowCrashRecoveryDialog($recoveryNeeded)
            }
            
        } catch {
            if ($global:Logger) {
                $global:Logger.Error("Crash recovery check failed: $($_.Exception.Message)")
            }
        }
    }
    
    [hashtable] ParseAutoSaveMetadata([string]$filePath) {
        try {
            $content = Get-Content -Path $filePath -Raw
            $lines = $content -split "`n"
            
            if ($lines.Count -lt 3 -or $lines[0] -ne "### PRAXIS AUTO-SAVE FILE ###") {
                return $null
            }
            
            # Find the metadata section
            $metadataStart = 1
            $metadataEnd = -1
            for ($i = 1; $i -lt $lines.Count; $i++) {
                if ($lines[$i] -eq "### CONTENT BEGINS ###") {
                    $metadataEnd = $i - 1
                    break
                }
            }
            
            if ($metadataEnd -eq -1) {
                return $null
            }
            
            $metadataJson = $lines[$metadataStart..$metadataEnd] -join "`n"
            return $metadataJson | ConvertFrom-Json -AsHashtable
            
        } catch {
            return $null
        }
    }
    
    [void] ShowCrashRecoveryDialog([array]$recoveryItems) {
        $message = "Crash recovery available for $($recoveryItems.Count) file(s):`n`n"
        foreach ($item in $recoveryItems) {
            $fileName = [System.IO.Path]::GetFileName($item.OriginalFile)
            $message += "• $fileName ($($item.Reason))`n"
        }
        $message += "`nRecover auto-saved changes?"
        
        try {
            $dialog = [ConfirmationDialog]::new($message)
            $dialog.ConfirmText = "Recover"
            $dialog.CancelText = "Ignore"
            
            $screenManager = $this.ServiceContainer.GetService("ScreenManager")
            $screenManager.Push($dialog)
            
            $editor = $this
            $dialog.OnConfirm = {
                $editor.RecoverAutoSaveFiles($recoveryItems)
            }.GetNewClosure()
            
            $dialog.OnCancel = {
                $editor.CleanupAutoSaveFiles($recoveryItems)
            }.GetNewClosure()
            
        } catch {
            if ($global:Logger) {
                $global:Logger.Error("Failed to show crash recovery dialog: $($_.Exception.Message)")
            }
        }
    }
    
    [void] RecoverAutoSaveFiles([array]$recoveryItems) {
        foreach ($item in $recoveryItems) {
            try {
                # Load the auto-saved content
                $content = Get-Content -Path $item.AutoSaveFile -Raw
                $lines = $content -split "`n"
                
                # Find content start
                $contentStart = -1
                for ($i = 0; $i -lt $lines.Count; $i++) {
                    if ($lines[$i] -eq "### CONTENT BEGINS ###") {
                        $contentStart = $i + 1
                        break
                    }
                }
                
                if ($contentStart -ne -1) {
                    $recoveredContent = $lines[$contentStart..($lines.Count-1)] -join "`n"
                    
                    # If this is the current file being edited, load the content
                    if ($this._buffer.FilePath -eq $item.OriginalFile) {
                        $this._buffer.SetText($recoveredContent)
                        $this._buffer.SetModified($true)
                        $this.StatusMessage = "Recovered from auto-save"
                    } else {
                        # Save recovered content to original file
                        Set-Content -Path $item.OriginalFile -Value $recoveredContent -NoNewline
                    }
                }
                
                # Clean up the auto-save file
                Remove-Item -Path $item.AutoSaveFile -Force -ErrorAction SilentlyContinue
                
            } catch {
                if ($global:Logger) {
                    $global:Logger.Error("Failed to recover file $($item.OriginalFile): $($_.Exception.Message)")
                }
            }
        }
    }
    
    [void] CleanupAutoSaveFiles([array]$recoveryItems) {
        foreach ($item in $recoveryItems) {
            try {
                Remove-Item -Path $item.AutoSaveFile -Force -ErrorAction SilentlyContinue
            } catch {
                # Ignore cleanup errors
            }
        }
    }
    
    [void] OnLostFocus() {
        ([Screen]$this).OnLostFocus()
        
        # Auto-save on focus loss if enabled
        if ($this.AutoSaveOnFocusLoss -and $this._buffer.IsModified) {
            try {
                if (-not [string]::IsNullOrEmpty($this._buffer.FilePath)) {
                    $this._buffer.SaveToFile()
                    $this.StatusMessage = "Auto-saved on focus loss"
                }
            } catch {
                $this.StatusMessage = "Auto-save failed: $($_.Exception.Message)"
            }
        }
    }
    
    # Cleanup on screen destruction
    [void] Cleanup() {
        if ($this._autoSaveTimer) {
            $this._autoSaveTimer.Stop()
            $this._autoSaveTimer.Dispose()
        }
    }
}