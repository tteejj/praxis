# NotesEditor.ps1 - Full-featured text editor for task notes
# Uses the complete text editor from Praxis with gap buffer, undo/redo, etc.

class NotesEditor {
    # The actual buffer with gap buffer implementation
    hidden [GapBufferDocumentBuffer]$_buffer
    
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
    
    # Undo/redo
    hidden [System.Collections.ArrayList]$_undoStack
    hidden [System.Collections.ArrayList]$_redoStack
    
    # Editor settings
    [int]$TabWidth = 4
    [bool]$Modified = $false
    
    NotesEditor() {
        $this._buffer = [GapBufferDocumentBuffer]::new()
        $this._undoStack = [System.Collections.ArrayList]::new()
        $this._redoStack = [System.Collections.ArrayList]::new()
    }
    
    [void] SetBounds([int]$x, [int]$y, [int]$width, [int]$height) {
        $this.X = $x
        $this.Y = $y
        $this.Width = $width
        $this.Height = $height
    }
    
    [void] SetText([string]$text) {
        $this._buffer.LoadFromText($text)
        $this.CursorX = 0
        $this.CursorY = 0
        $this.ScrollOffsetY = 0
        $this.ScrollOffsetX = 0
        $this.Modified = $false
        $this._undoStack.Clear()
        $this._redoStack.Clear()
    }
    
    [string] GetText() {
        return $this._buffer.GetText()
    }
    
    [string] Render() {
        $sb = [System.Text.StringBuilder]::new()
        
        # Get visible lines
        $lineCount = $this._buffer.GetLineCount()
        $visibleLines = [Math]::Min($this.Height, $lineCount - $this.ScrollOffsetY)
        
        # Render each visible line
        for ($i = 0; $i -lt $this.Height; $i++) {
            $lineIndex = $this.ScrollOffsetY + $i
            [void]$sb.Append([VT]::MoveTo($this.X, $this.Y + $i))
            
            if ($lineIndex -lt $lineCount) {
                $line = $this._buffer.GetLine($lineIndex)
                
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
        # Simplified selection rendering
        [void]$sb.Append($text)
    }
    
    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        $handled = $true
        
        # Save state for undo
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
                    $this.CursorY = $this._buffer.GetLineCount() - 1
                    $this.CursorX = $this._buffer.GetLine($this.CursorY).Length
                    $this.EnsureCursorVisible()
                } else {
                    $this.CursorX = $this._buffer.GetLine($this.CursorY).Length
                    $this.EnsureCursorVisible()
                }
            }
            ([System.ConsoleKey]::PageUp) {
                $this.CursorY = [Math]::Max(0, $this.CursorY - $this.Height)
                $this.EnsureCursorVisible()
            }
            ([System.ConsoleKey]::PageDown) {
                $this.CursorY = [Math]::Min($this._buffer.GetLineCount() - 1, $this.CursorY + $this.Height)
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
            $this.CursorX = $this._buffer.GetLine($this.CursorY).Length
        }
        $this.EnsureCursorVisible()
    }
    
    [void] MoveCursorRight() {
        $lineLength = $this._buffer.GetLine($this.CursorY).Length
        if ($this.CursorX -lt $lineLength) {
            $this.CursorX++
        } elseif ($this.CursorY -lt ($this._buffer.GetLineCount() - 1)) {
            $this.CursorY++
            $this.CursorX = 0
        }
        $this.EnsureCursorVisible()
    }
    
    [void] MoveCursorUp() {
        if ($this.CursorY -gt 0) {
            $this.CursorY--
            $lineLength = $this._buffer.GetLine($this.CursorY).Length
            $this.CursorX = [Math]::Min($this.CursorX, $lineLength)
        }
        $this.EnsureCursorVisible()
    }
    
    [void] MoveCursorDown() {
        if ($this.CursorY -lt ($this._buffer.GetLineCount() - 1)) {
            $this.CursorY++
            $lineLength = $this._buffer.GetLine($this.CursorY).Length
            $this.CursorX = [Math]::Min($this.CursorX, $lineLength)
        }
        $this.EnsureCursorVisible()
    }
    
    [void] MoveCursorWordLeft() {
        # Move to previous word boundary
        $line = $this._buffer.GetLine($this.CursorY)
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
        $line = $this._buffer.GetLine($this.CursorY)
        if ($this.CursorX -lt $line.Length) {
            # Skip current word
            while ($this.CursorX -lt $line.Length -and $line[$this.CursorX] -match '\w') {
                $this.CursorX++
            }
            # Skip whitespace
            while ($this.CursorX -lt $line.Length -and $line[$this.CursorX] -match '\s') {
                $this.CursorX++
            }
        } elseif ($this.CursorY -lt ($this._buffer.GetLineCount() - 1)) {
            $this.MoveCursorRight()
        }
        $this.EnsureCursorVisible()
    }
    
    # Editing methods
    [void] InsertChar([char]$char) {
        $this._buffer.InsertText($this.CursorY, $this.CursorX, $char.ToString())
        $this.CursorX++
        $this.Modified = $true
        $this.EnsureCursorVisible()
    }
    
    [void] InsertNewLine() {
        $this._buffer.InsertNewLine($this.CursorY, $this.CursorX)
        $this.CursorY++
        $this.CursorX = 0
        $this.Modified = $true
        $this.EnsureCursorVisible()
    }
    
    [void] InsertTab() {
        $spaces = " " * $this.TabWidth
        $this._buffer.InsertText($this.CursorY, $this.CursorX, $spaces)
        $this.CursorX += $this.TabWidth
        $this.Modified = $true
        $this.EnsureCursorVisible()
    }
    
    [void] Backspace() {
        if ($this.CursorX -gt 0) {
            $this._buffer.DeleteText($this.CursorY, $this.CursorX - 1, 1)
            $this.CursorX--
            $this.Modified = $true
        } elseif ($this.CursorY -gt 0) {
            # Join with previous line
            $prevLineLength = $this._buffer.GetLine($this.CursorY - 1).Length
            $this._buffer.JoinLines($this.CursorY - 1)
            $this.CursorY--
            $this.CursorX = $prevLineLength
            $this.Modified = $true
        }
        $this.EnsureCursorVisible()
    }
    
    [void] Delete() {
        $lineLength = $this._buffer.GetLine($this.CursorY).Length
        if ($this.CursorX -lt $lineLength) {
            $this._buffer.DeleteText($this.CursorY, $this.CursorX, 1)
            $this.Modified = $true
        } elseif ($this.CursorY -lt ($this._buffer.GetLineCount() - 1)) {
            # Join with next line
            $this._buffer.JoinLines($this.CursorY)
            $this.Modified = $true
        }
    }
    
    # Selection
    [void] SelectAll() {
        $this.HasSelection = $true
        $this.SelectionStartX = 0
        $this.SelectionStartY = 0
        $lastLine = $this._buffer.GetLineCount() - 1
        $this.SelectionEndY = $lastLine
        $this.SelectionEndX = $this._buffer.GetLine($lastLine).Length
    }
    
    # Undo/Redo
    [void] SaveUndoState() {
        $state = @{
            Text = $this._buffer.GetText()
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
                Text = $this._buffer.GetText()
                CursorX = $this.CursorX
                CursorY = $this.CursorY
            }
            $this._redoStack.Add($currentState)
            
            # Restore previous state
            $state = $this._undoStack[$this._undoStack.Count - 1]
            $this._undoStack.RemoveAt($this._undoStack.Count - 1)
            
            $this._buffer.LoadFromText($state.Text)
            $this.CursorX = $state.CursorX
            $this.CursorY = $state.CursorY
            $this.EnsureCursorVisible()
        }
    }
    
    [void] Redo() {
        if ($this._redoStack.Count -gt 0) {
            # Save current state to undo stack
            $currentState = @{
                Text = $this._buffer.GetText()
                CursorX = $this.CursorX
                CursorY = $this.CursorY
            }
            $this._undoStack.Add($currentState)
            
            # Restore next state
            $state = $this._redoStack[$this._redoStack.Count - 1]
            $this._redoStack.RemoveAt($this._redoStack.Count - 1)
            
            $this._buffer.LoadFromText($state.Text)
            $this.CursorX = $state.CursorX
            $this.CursorY = $state.CursorY
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
}