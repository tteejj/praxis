# TextEditor.ps1 - Simple text editor for task notes
# Based on Praxis text editor but simplified

class TextEditor {
    [string[]]$Lines
    [int]$CursorX = 0
    [int]$CursorY = 0
    [int]$ScrollTop = 0
    [int]$ScrollLeft = 0
    [int]$Width
    [int]$Height
    [int]$X
    [int]$Y
    [bool]$Modified = $false
    [System.Collections.Generic.Stack[object]]$UndoStack
    [System.Collections.Generic.Stack[object]]$RedoStack
    
    TextEditor() {
        $this.Lines = @("")
        $this.UndoStack = [System.Collections.Generic.Stack[object]]::new()
        $this.RedoStack = [System.Collections.Generic.Stack[object]]::new()
    }
    
    [void] SetBounds([int]$x, [int]$y, [int]$width, [int]$height) {
        $this.X = $x
        $this.Y = $y
        $this.Width = $width
        $this.Height = $height
    }
    
    [void] SetText([string]$text) {
        if ([string]::IsNullOrEmpty($text)) {
            $this.Lines = @("")
        } else {
            $this.Lines = $text -split "`n"
        }
        $this.CursorX = 0
        $this.CursorY = 0
        $this.ScrollTop = 0
        $this.ScrollLeft = 0
        $this.Modified = $false
    }
    
    [string] GetText() {
        return $this.Lines -join "`n"
    }
    
    [string] Render() {
        $sb = [System.Text.StringBuilder]::new()
        
        # Calculate visible range
        $visibleLines = [Math]::Min($this.Height, $this.Lines.Count - $this.ScrollTop)
        
        for ($i = 0; $i -lt $this.Height; $i++) {
            $lineIndex = $this.ScrollTop + $i
            [void]$sb.Append([VT]::MoveTo($this.X, $this.Y + $i))
            
            if ($lineIndex -lt $this.Lines.Count) {
                $line = $this.Lines[$lineIndex]
                
                # Handle horizontal scrolling
                if ($this.ScrollLeft -lt $line.Length) {
                    $visibleText = $line.Substring($this.ScrollLeft)
                    if ($visibleText.Length -gt $this.Width) {
                        $visibleText = $visibleText.Substring(0, $this.Width)
                    }
                    [void]$sb.Append($visibleText)
                }
            }
            
            # Clear rest of line
            [void]$sb.Append([VT]::ClearToEnd())
        }
        
        # Position cursor
        $cursorScreenX = $this.X + $this.CursorX - $this.ScrollLeft
        $cursorScreenY = $this.Y + $this.CursorY - $this.ScrollTop
        
        if ($cursorScreenX -ge $this.X -and $cursorScreenX -lt ($this.X + $this.Width) -and
            $cursorScreenY -ge $this.Y -and $cursorScreenY -lt ($this.Y + $this.Height)) {
            [void]$sb.Append([VT]::MoveTo($cursorScreenX, $cursorScreenY))
        }
        
        return $sb.ToString()
    }
    
    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        $handled = $true
        $this.SaveState()
        
        switch ($key.Key) {
            # Navigation
            ([System.ConsoleKey]::LeftArrow) { $this.MoveCursorLeft() }
            ([System.ConsoleKey]::RightArrow) { $this.MoveCursorRight() }
            ([System.ConsoleKey]::UpArrow) { $this.MoveCursorUp() }
            ([System.ConsoleKey]::DownArrow) { $this.MoveCursorDown() }
            ([System.ConsoleKey]::Home) { $this.CursorX = 0; $this.EnsureCursorVisible() }
            ([System.ConsoleKey]::End) { 
                $this.CursorX = $this.Lines[$this.CursorY].Length
                $this.EnsureCursorVisible()
            }
            
            # Editing
            ([System.ConsoleKey]::Enter) { $this.InsertNewLine() }
            ([System.ConsoleKey]::Backspace) { $this.Backspace() }
            ([System.ConsoleKey]::Delete) { $this.Delete() }
            ([System.ConsoleKey]::Tab) { $this.InsertText("    ") }
            
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
    
    [void] MoveCursorLeft() {
        if ($this.CursorX -gt 0) {
            $this.CursorX--
        } elseif ($this.CursorY -gt 0) {
            $this.CursorY--
            $this.CursorX = $this.Lines[$this.CursorY].Length
        }
        $this.EnsureCursorVisible()
    }
    
    [void] MoveCursorRight() {
        if ($this.CursorX -lt $this.Lines[$this.CursorY].Length) {
            $this.CursorX++
        } elseif ($this.CursorY -lt ($this.Lines.Count - 1)) {
            $this.CursorY++
            $this.CursorX = 0
        }
        $this.EnsureCursorVisible()
    }
    
    [void] MoveCursorUp() {
        if ($this.CursorY -gt 0) {
            $this.CursorY--
            $this.CursorX = [Math]::Min($this.CursorX, $this.Lines[$this.CursorY].Length)
        }
        $this.EnsureCursorVisible()
    }
    
    [void] MoveCursorDown() {
        if ($this.CursorY -lt ($this.Lines.Count - 1)) {
            $this.CursorY++
            $this.CursorX = [Math]::Min($this.CursorX, $this.Lines[$this.CursorY].Length)
        }
        $this.EnsureCursorVisible()
    }
    
    [void] InsertChar([char]$char) {
        $line = $this.Lines[$this.CursorY]
        $this.Lines[$this.CursorY] = $line.Insert($this.CursorX, $char)
        $this.CursorX++
        $this.Modified = $true
        $this.EnsureCursorVisible()
    }
    
    [void] InsertText([string]$text) {
        foreach ($char in $text.ToCharArray()) {
            $this.InsertChar($char)
        }
    }
    
    [void] InsertNewLine() {
        $currentLine = $this.Lines[$this.CursorY]
        $beforeCursor = $currentLine.Substring(0, $this.CursorX)
        $afterCursor = $currentLine.Substring($this.CursorX)
        
        $this.Lines[$this.CursorY] = $beforeCursor
        $newLines = [System.Collections.ArrayList]@()
        for ($i = 0; $i -le $this.CursorY; $i++) {
            [void]$newLines.Add($this.Lines[$i])
        }
        [void]$newLines.Add($afterCursor)
        for ($i = $this.CursorY + 1; $i -lt $this.Lines.Count; $i++) {
            [void]$newLines.Add($this.Lines[$i])
        }
        
        $this.Lines = $newLines.ToArray()
        $this.CursorY++
        $this.CursorX = 0
        $this.Modified = $true
        $this.EnsureCursorVisible()
    }
    
    [void] Backspace() {
        if ($this.CursorX -gt 0) {
            $line = $this.Lines[$this.CursorY]
            $this.Lines[$this.CursorY] = $line.Remove($this.CursorX - 1, 1)
            $this.CursorX--
            $this.Modified = $true
        } elseif ($this.CursorY -gt 0) {
            # Join with previous line
            $prevLine = $this.Lines[$this.CursorY - 1]
            $currentLine = $this.Lines[$this.CursorY]
            $this.Lines[$this.CursorY - 1] = $prevLine + $currentLine
            
            # Remove current line
            $newLines = [System.Collections.ArrayList]@()
            for ($i = 0; $i -lt $this.Lines.Count; $i++) {
                if ($i -ne $this.CursorY) {
                    [void]$newLines.Add($this.Lines[$i])
                }
            }
            
            $this.Lines = $newLines.ToArray()
            $this.CursorY--
            $this.CursorX = $prevLine.Length
            $this.Modified = $true
        }
        $this.EnsureCursorVisible()
    }
    
    [void] Delete() {
        if ($this.CursorX -lt $this.Lines[$this.CursorY].Length) {
            $line = $this.Lines[$this.CursorY]
            $this.Lines[$this.CursorY] = $line.Remove($this.CursorX, 1)
            $this.Modified = $true
        } elseif ($this.CursorY -lt ($this.Lines.Count - 1)) {
            # Join with next line
            $this.Lines[$this.CursorY] = $this.Lines[$this.CursorY] + $this.Lines[$this.CursorY + 1]
            
            # Remove next line
            $newLines = [System.Collections.ArrayList]@()
            for ($i = 0; $i -lt $this.Lines.Count; $i++) {
                if ($i -ne ($this.CursorY + 1)) {
                    [void]$newLines.Add($this.Lines[$i])
                }
            }
            
            $this.Lines = $newLines.ToArray()
            $this.Modified = $true
        }
    }
    
    [void] EnsureCursorVisible() {
        # Vertical scrolling
        if ($this.CursorY -lt $this.ScrollTop) {
            $this.ScrollTop = $this.CursorY
        } elseif ($this.CursorY -ge ($this.ScrollTop + $this.Height)) {
            $this.ScrollTop = $this.CursorY - $this.Height + 1
        }
        
        # Horizontal scrolling
        if ($this.CursorX -lt $this.ScrollLeft) {
            $this.ScrollLeft = $this.CursorX
        } elseif ($this.CursorX -ge ($this.ScrollLeft + $this.Width)) {
            $this.ScrollLeft = $this.CursorX - $this.Width + 1
        }
    }
    
    [void] SaveState() {
        $state = @{
            Lines = $this.Lines.Clone()
            CursorX = $this.CursorX
            CursorY = $this.CursorY
        }
        $this.UndoStack.Push($state)
        $this.RedoStack.Clear()
    }
    
    [void] Undo() {
        if ($this.UndoStack.Count -gt 0) {
            $state = $this.UndoStack.Pop()
            $currentState = @{
                Lines = $this.Lines.Clone()
                CursorX = $this.CursorX
                CursorY = $this.CursorY
            }
            $this.RedoStack.Push($currentState)
            
            $this.Lines = $state.Lines
            $this.CursorX = $state.CursorX
            $this.CursorY = $state.CursorY
            $this.EnsureCursorVisible()
        }
    }
    
    [void] Redo() {
        if ($this.RedoStack.Count -gt 0) {
            $state = $this.RedoStack.Pop()
            $currentState = @{
                Lines = $this.Lines.Clone()
                CursorX = $this.CursorX
                CursorY = $this.CursorY
            }
            $this.UndoStack.Push($currentState)
            
            $this.Lines = $state.Lines
            $this.CursorX = $state.CursorX
            $this.CursorY = $state.CursorY
            $this.EnsureCursorVisible()
        }
    }
}