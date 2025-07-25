# TextEditorScreen - Multi-line text editor screen
# Proper PRAXIS architecture implementation

class TextEditorScreen : Screen {
    # Text content and cursor state
    [System.Collections.ArrayList]$Lines
    [int]$CursorX = 0
    [int]$CursorY = 0
    [int]$ScrollOffsetY = 0
    [int]$ScrollOffsetX = 0
    [string]$FilePath = ""
    [bool]$Modified = $false
    [string]$StatusMessage = ""
    
    # Undo system - line-based grouping
    hidden [System.Collections.ArrayList]$_undoStates
    hidden [int]$_maxUndoStates = 25
    hidden [int]$_currentUndoIndex = -1
    hidden [int]$_maxFileSizeForUndo = 100KB
    hidden [bool]$_undoEnabled = $true
    
    # Auto-save on focus loss
    [bool]$AutoSaveOnFocusLoss = $true
    hidden [bool]$_lastFocusState = $true
    
    # PRAXIS service integration
    hidden [object]$ThemeManager
    hidden [object]$EventBus
    
    # Editor settings
    [int]$TabWidth = 4
    [bool]$ShowLineNumbers = $true
    [int]$LineNumberWidth = 5
    
    # Mode system
    [bool]$InTextMode = $true  # Start in text mode
    
    TextEditorScreen() : base() {
        $this.Title = "Text Editor"
        $this.Lines = [System.Collections.ArrayList]::new()
        $this.Lines.Add("") | Out-Null
        $this.IsFocusable = $true  # TextEditor itself is focusable
        $this.InitializeUndoSystem()
    }
    
    TextEditorScreen([string]$filePath) : base() {
        $this.Title = "Text Editor"
        $this.FilePath = $filePath
        $this.Lines = [System.Collections.ArrayList]::new()
        $this.IsFocusable = $true  # TextEditor itself is focusable
        $this.InitializeUndoSystem()
    }
    
    [void] InitializeUndoSystem() {
        $this._undoStates = [System.Collections.ArrayList]::new()
        # Save initial state
        $this.SaveUndoState()
    }
    
    [void] SaveUndoState() {
        if (-not $this._undoEnabled) { return }
        
        # Check file size limit
        $docSize = ($this.Lines | ForEach-Object { $_.Length } | Measure-Object -Sum).Sum
        if ($docSize -gt $this._maxFileSizeForUndo) {
            $this._undoEnabled = $false
            $this.StatusMessage = "Undo disabled - file too large"
            return
        }
        
        $state = @{
            Lines = $this.Lines.Clone()
            CursorX = $this.CursorX
            CursorY = $this.CursorY
            ScrollOffsetX = $this.ScrollOffsetX
            ScrollOffsetY = $this.ScrollOffsetY
        }
        
        # Remove any redo states if we're not at the end
        if ($this._currentUndoIndex -lt $this._undoStates.Count - 1) {
            $removeCount = $this._undoStates.Count - $this._currentUndoIndex - 1
            for ($i = 0; $i -lt $removeCount; $i++) {
                $this._undoStates.RemoveAt($this._undoStates.Count - 1)
            }
        }
        
        $this._undoStates.Add($state) | Out-Null
        $this._currentUndoIndex = $this._undoStates.Count - 1
        
        # Limit undo history
        if ($this._undoStates.Count -gt $this._maxUndoStates) {
            $this._undoStates.RemoveAt(0)
            $this._currentUndoIndex--
        }
        
        # Publish buffer state change event
        if ($this.EventBus) {
            try {
                $this.EventBus.Publish('editor.buffer.state-saved', @{
                    FilePath = $this.FilePath
                    UndoStates = $this._undoStates.Count
                    CurrentIndex = $this._currentUndoIndex
                })
            }
            catch {
                # Ignore event publishing errors to avoid disrupting editing
            }
        }
    }
    
    [void] PerformUndo() {
        if ($this._currentUndoIndex -le 0) { return }
        
        $this._currentUndoIndex--
        $state = $this._undoStates[$this._currentUndoIndex]
        
        $this.Lines = $state.Lines.Clone()
        $this.CursorX = $state.CursorX
        $this.CursorY = $state.CursorY
        $this.ScrollOffsetX = $state.ScrollOffsetX
        $this.ScrollOffsetY = $state.ScrollOffsetY
        
        $this.Modified = $true
        $this.Invalidate()
    }
    
    [void] PerformRedo() {
        if ($this._currentUndoIndex -ge $this._undoStates.Count - 1) { return }
        
        $this._currentUndoIndex++
        $state = $this._undoStates[$this._currentUndoIndex]
        
        $this.Lines = $state.Lines.Clone()
        $this.CursorX = $state.CursorX
        $this.CursorY = $state.CursorY
        $this.ScrollOffsetX = $state.ScrollOffsetX
        $this.ScrollOffsetY = $state.ScrollOffsetY
        
        $this.Modified = $true
        $this.Invalidate()
    }
    
    [bool] ShouldSaveUndoForLine() {
        # For line-based undo, save state when cursor moves to a different line
        # or if this is the very first edit
        if ($this._undoStates.Count -eq 0) { return $true }
        
        $lastState = $this._undoStates[$this._currentUndoIndex]
        return ($lastState.CursorY -ne $this.CursorY)
    }
    
    [void] OnApplicationFocusChanged([bool]$hasFocus) {
        # Called by PRAXIS framework when window focus changes
        if ($this._lastFocusState -and -not $hasFocus) {
            # Lost focus - trigger auto-save if enabled and file is modified
            if ($this.AutoSaveOnFocusLoss -and $this.Modified -and $this.FilePath) {
                $this.AutoSave()
            }
        }
        $this._lastFocusState = $hasFocus
    }
    
    [void] AutoSave() {
        try {
            $content = $this.Lines -join "`n"
            $autoSavePath = "$($this.FilePath).autosave"
            Set-Content -Path $autoSavePath -Value $content -NoNewline -ErrorAction Stop
            $this.StatusMessage = "Auto-saved on focus loss"
            if ($global:Logger) {
                $global:Logger.Debug("TextEditor: Auto-saved to $autoSavePath")
            }
        }
        catch {
            $this.StatusMessage = "Auto-save failed: $_"
            if ($global:Logger) {
                $global:Logger.Error("TextEditor: Auto-save failed: $_")
            }
        }
        $this.Invalidate()
    }
    
    [void] OnInitialize() {
        # Get PRAXIS services
        try {
            $this.ThemeManager = $this.ServiceContainer.GetService('ThemeManager')
            $this.EventBus = $this.ServiceContainer.GetService('EventBus')
        }
        catch {
            if ($global:Logger) {
                $global:Logger.Warning("TextEditor: Could not get PRAXIS services: $_")
            }
        }
        
        # Load file if specified
        if ($this.FilePath -and (Test-Path $this.FilePath)) {
            $this.LoadFile()
        } elseif (-not $this.Lines.Count) {
            $this.Lines.Add("") | Out-Null
        }
        
        # Update title
        if ($this.FilePath) {
            $this.Title = "Text Editor - $([System.IO.Path]::GetFileName($this.FilePath))"
        }
        
        # Subscribe to focus change events if EventBus is available
        if ($this.EventBus) {
            try {
                $this.EventBus.Subscribe('application.focus.changed', $this.OnApplicationFocusChanged.GetNewClosure())
            }
            catch {
                if ($global:Logger) {
                    $global:Logger.Warning("TextEditor: Could not subscribe to focus events: $_")
                }
            }
        }
    }
    
    [void] OnActivated() {
        ([Screen]$this).OnActivated()
        # TextEditor itself is the focusable element
        $this.Focus()
    }
    
    [void] LoadFile() {
        try {
            $content = Get-Content -Path $this.FilePath -Raw -ErrorAction Stop
            if ($content) {
                $this.Lines.Clear()
                $lineArray = $content -split "`r?`n"
                foreach ($line in $lineArray) {
                    $this.Lines.Add($line) | Out-Null
                }
            } else {
                $this.Lines.Clear()
                $this.Lines.Add("") | Out-Null
            }
            $this.Modified = $false
            $this.StatusMessage = "File loaded: $([System.IO.Path]::GetFileName($this.FilePath))"
            
            # Publish file loaded event
            if ($this.EventBus) {
                try {
                    $this.EventBus.Publish('editor.file.loaded', @{
                        FilePath = $this.FilePath
                        LineCount = $this.Lines.Count
                    })
                }
                catch {
                    # Ignore event publishing errors
                }
            }
        }
        catch {
            $this.StatusMessage = "Error loading file: $_"
            if (-not $this.Lines.Count) {
                $this.Lines.Add("") | Out-Null
            }
        }
        $this.Invalidate()
    }
    
    [void] SaveFile() {
        if (-not $this.FilePath) {
            # Open file browser for save location
            $this.OpenFileBrowser()
            return
        }
        
        try {
            $content = $this.Lines -join "`n"
            Set-Content -Path $this.FilePath -Value $content -NoNewline -ErrorAction Stop
            $this.Modified = $false
            $this.StatusMessage = "File saved: $([System.IO.Path]::GetFileName($this.FilePath))"
            
            # Publish file saved event
            if ($this.EventBus) {
                try {
                    $this.EventBus.Publish('editor.file.saved', @{
                        FilePath = $this.FilePath
                        LineCount = $this.Lines.Count
                    })
                }
                catch {
                    # Ignore event publishing errors
                }
            }
        }
        catch {
            $this.StatusMessage = "Error saving file: $_"
        }
        $this.Invalidate()
    }
    
    [void] OpenFileBrowser() {
        # Open file browser for file selection
        try {
            $fileBrowserType = [type]"FileBrowserScreen"
            if ($fileBrowserType) {
                $fileBrowser = $fileBrowserType::new()
                
                # Set up callback for file selection
                $editor = $this
                $fileBrowser.FileSelectedCallback = {
                    param($filePath)
                    if ($filePath -and (Test-Path $filePath)) {
                        $item = Get-Item $filePath -ErrorAction SilentlyContinue
                        if ($item -and -not $item.PSIsContainer) {
                            # File selected - either save current content or load new file
                            if ($editor.StatusMessage -eq "SELECT_SAVE_LOCATION") {
                                # Save current content to selected file
                                $editor.FilePath = $filePath
                                $editor.SaveFile()
                            } else {
                                # Load selected file
                                $editor.FilePath = $filePath
                                $editor.LoadFile()
                            }
                        }
                    }
                    
                    # Close the file browser
                    $screenManager = $editor.ServiceContainer.GetService("ScreenManager")
                    $screenManager.Pop() | Out-Null
                }.GetNewClosure()
                
                # Push the file browser
                $screenManager = $this.ServiceContainer.GetService("ScreenManager")
                $screenManager.Push($fileBrowser)
            }
        } catch {
            $this.StatusMessage = "FileBrowser not available"
            $this.Invalidate()
        }
    }
    
    # Override HandleScreenInput for text editor controls
    [bool] HandleScreenInput([System.ConsoleKeyInfo]$keyInfo) {
        # Clear status message on input (except for certain messages)
        if ($this.StatusMessage -and -not $this.StatusMessage.StartsWith("Error") -and $this.StatusMessage -ne "SELECT_SAVE_LOCATION") {
            $this.StatusMessage = ""
        }
        
        if ($global:Logger) {
            $global:Logger.Debug("TextEditorScreen.HandleScreenInput: Key=$($keyInfo.Key) Char='$($keyInfo.KeyChar)' InTextMode=$($this.InTextMode)")
        }
        
        # ESC toggles between text mode and command mode
        if ($keyInfo.Key -eq [ConsoleKey]::Escape) {
            $this.InTextMode = -not $this.InTextMode
            $this.StatusMessage = if ($this.InTextMode) { "TEXT MODE" } else { "COMMAND MODE" }
            if ($global:Logger) {
                $global:Logger.Debug("TextEditorScreen: ESC pressed, InTextMode=$($this.InTextMode)")
            }
            $this.Invalidate()
            return $true
        }
        
        # In command mode, let number keys bubble up for tab switching
        if (-not $this.InTextMode -and $keyInfo.KeyChar -ge '1' -and $keyInfo.KeyChar -le '9') {
            if ($global:Logger) {
                $global:Logger.Debug("TextEditorScreen: In command mode, not handling number key '$($keyInfo.KeyChar)'")
            }
            return $false  # Let parent handle tab switching
        }
        
        # Handle control key combinations
        if ($keyInfo.Modifiers -band [ConsoleModifiers]::Control) {
            switch ($keyInfo.Key) {
                ([ConsoleKey]::S) { 
                    $this.SaveFile()
                    return $true 
                }
                ([ConsoleKey]::O) { 
                    $this.OpenFileBrowser()
                    return $true 
                }
                ([ConsoleKey]::Z) {
                    if ($keyInfo.Modifiers -band [ConsoleModifiers]::Shift) {
                        $this.PerformRedo()
                    } else {
                        $this.PerformUndo()
                    }
                    return $true
                }
                ([ConsoleKey]::Y) {
                    $this.PerformRedo()
                    return $true
                }
                ([ConsoleKey]::Q) { 
                    if ($this.Modified) {
                        $this.StatusMessage = "Unsaved changes! Press Ctrl+Q again to quit"
                        $this.Invalidate()
                    } else {
                        $this.Active = $false
                    }
                    return $true
                }
            }
        }
        
        # Handle regular keys
        switch ($keyInfo.Key) {
            # Navigation
            ([ConsoleKey]::UpArrow) { $this.MoveCursor(0, -1); return $true }
            ([ConsoleKey]::DownArrow) { $this.MoveCursor(0, 1); return $true }
            ([ConsoleKey]::LeftArrow) { $this.MoveCursor(-1, 0); return $true }
            ([ConsoleKey]::RightArrow) { $this.MoveCursor(1, 0); return $true }
            ([ConsoleKey]::Home) { $this.CursorX = 0; $this.EnsureCursorVisible(); $this.Invalidate(); return $true }
            ([ConsoleKey]::End) { 
                if ($this.CursorY -lt $this.Lines.Count) {
                    $this.CursorX = $this.Lines[$this.CursorY].Length
                }
                $this.EnsureCursorVisible()
                $this.Invalidate()
                return $true
            }
            ([ConsoleKey]::PageUp) { $this.PageUp(); return $true }
            ([ConsoleKey]::PageDown) { $this.PageDown(); return $true }
            
            # Editing
            ([ConsoleKey]::Enter) { $this.InsertNewline(); return $true }
            ([ConsoleKey]::Backspace) { $this.Backspace(); return $true }
            ([ConsoleKey]::Delete) { $this.Delete(); return $true }
            ([ConsoleKey]::Tab) { $this.InsertTab(); return $true }
        }
        
        # Insert printable characters only in text mode
        if ($this.InTextMode -and $keyInfo.KeyChar -and [char]::IsControl($keyInfo.KeyChar) -eq $false) {
            $this.InsertChar($keyInfo.KeyChar)
            return $true
        }
        
        # Let base class handle other input (like tab switching)
        return $false
    }
    
    # Text editor specific methods
    [void] MoveCursor([int]$dx, [int]$dy) {
        $this.CursorY = [Math]::Max(0, [Math]::Min($this.Lines.Count - 1, $this.CursorY + $dy))
        
        if ($dx -ne 0) {
            $this.CursorX = [Math]::Max(0, $this.CursorX + $dx)
            $lineLength = $this.Lines[$this.CursorY].Length
            $this.CursorX = [Math]::Min($lineLength, $this.CursorX)
        } else {
            # Vertical movement - try to maintain column
            $lineLength = $this.Lines[$this.CursorY].Length
            $this.CursorX = [Math]::Min($lineLength, $this.CursorX)
        }
        
        $this.EnsureCursorVisible()
        $this.Invalidate()
    }
    
    [void] InsertChar([char]$char) {
        # Save undo state if this is the first edit on this line
        if ($this.ShouldSaveUndoForLine()) {
            $this.SaveUndoState()
        }
        
        $line = $this.Lines[$this.CursorY]
        $this.Lines[$this.CursorY] = $line.Insert($this.CursorX, $char)
        $this.CursorX++
        $this.Modified = $true
        $this.EnsureCursorVisible()
        $this.Invalidate()
    }
    
    [void] InsertNewline() {
        # Always save undo state before creating a new line
        $this.SaveUndoState()
        
        $line = $this.Lines[$this.CursorY]
        $before = if ($this.CursorX -gt 0) { $line.Substring(0, $this.CursorX) } else { "" }
        $after = if ($this.CursorX -lt $line.Length) { $line.Substring($this.CursorX) } else { "" }
        
        $this.Lines[$this.CursorY] = $before
        $this.Lines.Insert($this.CursorY + 1, $after)
        
        $this.CursorY++
        $this.CursorX = 0
        $this.Modified = $true
        $this.EnsureCursorVisible()
        $this.Invalidate()
    }
    
    [void] Backspace() {
        if ($this.CursorX -gt 0) {
            # Save undo state if this is first edit on this line
            if ($this.ShouldSaveUndoForLine()) {
                $this.SaveUndoState()
            }
            # Delete character before cursor
            $line = $this.Lines[$this.CursorY]
            $this.Lines[$this.CursorY] = $line.Remove($this.CursorX - 1, 1)
            $this.CursorX--
        } elseif ($this.CursorY -gt 0) {
            # Always save undo state before joining lines
            $this.SaveUndoState()
            # Join with previous line
            $prevLine = $this.Lines[$this.CursorY - 1]
            $currentLine = $this.Lines[$this.CursorY]
            $this.CursorX = $prevLine.Length
            $this.Lines[$this.CursorY - 1] = $prevLine + $currentLine
            $this.Lines.RemoveAt($this.CursorY)
            $this.CursorY--
        }
        
        $this.Modified = $true
        $this.EnsureCursorVisible()
        $this.Invalidate()
    }
    
    [void] Delete() {
        $line = $this.Lines[$this.CursorY]
        
        if ($this.CursorX -lt $line.Length) {
            # Save undo state if this is first edit on this line
            if ($this.ShouldSaveUndoForLine()) {
                $this.SaveUndoState()
            }
            # Delete character at cursor
            $this.Lines[$this.CursorY] = $line.Remove($this.CursorX, 1)
        } elseif ($this.CursorY -lt $this.Lines.Count - 1) {
            # Always save undo state before joining lines
            $this.SaveUndoState()
            # Join with next line
            $nextLine = $this.Lines[$this.CursorY + 1]
            $this.Lines[$this.CursorY] = $line + $nextLine
            $this.Lines.RemoveAt($this.CursorY + 1)
        }
        
        $this.Modified = $true
        $this.Invalidate()
    }
    
    [void] InsertTab() {
        for ($i = 0; $i -lt $this.TabWidth; $i++) {
            $this.InsertChar(' ')
        }
    }
    
    [void] PageUp() {
        $pageSize = $this.Height - 6
        $this.CursorY = [Math]::Max(0, $this.CursorY - $pageSize)
        $this.EnsureCursorVisible()
        $this.Invalidate()
    }
    
    [void] PageDown() {
        $pageSize = $this.Height - 6
        $this.CursorY = [Math]::Min($this.Lines.Count - 1, $this.CursorY + $pageSize)
        $this.EnsureCursorVisible()
        $this.Invalidate()
    }
    
    [void] EnsureCursorVisible() {
        $editorHeight = $this.Height - 6
        $editorWidth = $this.Width - $this.LineNumberWidth
        
        # Vertical scrolling
        if ($this.CursorY -lt $this.ScrollOffsetY) {
            $this.ScrollOffsetY = $this.CursorY
        } elseif ($this.CursorY -ge $this.ScrollOffsetY + $editorHeight) {
            $this.ScrollOffsetY = $this.CursorY - $editorHeight + 1
        }
        
        # Horizontal scrolling
        if ($this.CursorX -lt $this.ScrollOffsetX) {
            $this.ScrollOffsetX = $this.CursorX
        } elseif ($this.CursorX -ge $this.ScrollOffsetX + $editorWidth) {
            $this.ScrollOffsetX = $this.CursorX - $editorWidth + 1
        }
    }
    
    [void] OnBoundsChanged() {
        # When bounds change, ensure cursor is still visible
        $this.EnsureCursorVisible()
        $this.Invalidate()
    }
    
    [string] OnRender() {
        $sb = Get-PooledStringBuilder 4096  # Text editor can have large content
        
        # Get theme colors
        $bgColor = if ($this.Theme) { $this.Theme.GetBgColor("background") } else { "" }
        $fgColor = if ($this.Theme) { $this.Theme.GetColor("foreground") } else { "" }
        $lineNumColor = if ($this.Theme) { $this.Theme.GetColor("linenumber") } else { $fgColor }
        $statusBg = if ($this.Theme) { $this.Theme.GetBgColor("status") } else { $bgColor }
        $statusFg = if ($this.Theme) { $this.Theme.GetColor("status.foreground") } else { $fgColor }
        $cursorBg = if ($this.Theme) { $this.Theme.GetBgColor("cursor") } else { $fgColor }
        
        # Calculate content area
        $contentHeight = $this.Height - 3  # Reserve space for title and status
        $contentWidth = $this.Width - ($this.ShowLineNumbers ? $this.LineNumberWidth : 0)
        $contentStartX = $this.X + ($this.ShowLineNumbers ? $this.LineNumberWidth : 0)
        $contentStartY = $this.Y + 1
        
        # Clear background
        for ($y = 0; $y -lt $this.Height; $y++) {
            $sb.Append([VT]::MoveTo($this.X, $this.Y + $y))
            $sb.Append($bgColor)
            $sb.Append([StringCache]::GetSpaces($this.Width))
        }
        
        # Draw title
        $sb.Append([VT]::MoveTo($this.X, $this.Y))
        $sb.Append($statusBg)
        $sb.Append($statusFg)
        $titleText = $this.Title
        if ($this.Modified) { $titleText += " *" }
        $titleText = $titleText.PadRight($this.Width).Substring(0, $this.Width)
        $sb.Append($titleText)
        
        # Render text lines
        $endY = [Math]::Min($this.ScrollOffsetY + $contentHeight, $this.Lines.Count)
        for ($lineIdx = $this.ScrollOffsetY; $lineIdx -lt $endY; $lineIdx++) {
            $screenY = $contentStartY + ($lineIdx - $this.ScrollOffsetY)
            $line = $this.Lines[$lineIdx]
            
            # Draw line numbers if enabled
            if ($this.ShowLineNumbers) {
                $sb.Append([VT]::MoveTo($this.X, $screenY))
                $sb.Append($lineNumColor)
                $lineNum = ($lineIdx + 1).ToString().PadLeft($this.LineNumberWidth - 1) + " "
                $sb.Append($lineNum)
            }
            
            # Draw line content
            $sb.Append([VT]::MoveTo($contentStartX, $screenY))
            $sb.Append($fgColor)
            
            if ($line.Length -gt $this.ScrollOffsetX) {
                $visibleText = $line.Substring($this.ScrollOffsetX)
                if ($visibleText.Length -gt $contentWidth) {
                    $visibleText = $visibleText.Substring(0, $contentWidth)
                }
                $sb.Append($visibleText)
            }
        }
        
        # Draw cursor if this screen is focused
        if ($this.IsFocused) {
            $cursorScreenX = $contentStartX + ($this.CursorX - $this.ScrollOffsetX)
            $cursorScreenY = $contentStartY + ($this.CursorY - $this.ScrollOffsetY)
            
            # Only draw cursor if it's visible
            if ($cursorScreenX -ge $contentStartX -and $cursorScreenX -lt $contentStartX + $contentWidth -and
                $cursorScreenY -ge $contentStartY -and $cursorScreenY -lt $contentStartY + $contentHeight) {
                
                $sb.Append([VT]::MoveTo($cursorScreenX, $cursorScreenY))
                $sb.Append($cursorBg)
                
                # Get character under cursor
                $charUnderCursor = " "
                if ($this.CursorY -lt $this.Lines.Count) {
                    $line = $this.Lines[$this.CursorY]
                    if ($this.CursorX -lt $line.Length) {
                        $charUnderCursor = $line[$this.CursorX]
                    }
                }
                $sb.Append($charUnderCursor)
            }
        }
        
        # Draw status line
        $statusY = $this.Y + $this.Height - 1
        $sb.Append([VT]::MoveTo($this.X, $statusY))
        $sb.Append($statusBg)
        $sb.Append($statusFg)
        
        $statusText = ""
        if ($this.StatusMessage) {
            $statusText = $this.StatusMessage
        } else {
            $modeText = if ($this.InTextMode) { "[TEXT]" } else { "[COMMAND]" }
            $statusText = "$modeText Line $($this.CursorY + 1), Col $($this.CursorX + 1)"
            if ($this.FilePath) {
                $statusText += " | $([System.IO.Path]::GetFileName($this.FilePath))"
            }
        }
        $statusText = $statusText.PadRight($this.Width).Substring(0, $this.Width)
        $sb.Append($statusText)
        
        $sb.Append([VT]::Reset())
        $result = $sb.ToString()
        Return-PooledStringBuilder $sb
        return $result
    }
}