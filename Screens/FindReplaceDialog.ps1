# FindReplaceDialog.ps1 - Find and replace functionality for text editor
# Provides search and replace capabilities with various options

class FindReplaceDialog : BaseDialog {
    # UI Controls
    [MinimalTextBox]$FindTextBox
    [MinimalTextBox]$ReplaceTextBox
    [MinimalButton]$FindNextButton
    [MinimalButton]$FindPreviousButton
    [MinimalButton]$ReplaceButton
    [MinimalButton]$ReplaceAllButton
    
    # Search options (could be checkboxes in future)
    [bool]$MatchCase = $false
    [bool]$WholeWord = $false
    [bool]$RegexMode = $false
    
    # Search state
    hidden [int]$_lastFoundLine = -1
    hidden [int]$_lastFoundColumn = -1
    hidden [string]$_lastSearchTerm = ""
    
    # Reference to the text editor
    hidden [object]$_textEditor
    hidden [object]$_buffer
    
    # Callback for when dialog closes
    [scriptblock]$OnClose = {}
    
    FindReplaceDialog([object]$textEditor) : base("Find & Replace", 70, 16) {
        $this._textEditor = $textEditor
        $this._buffer = $textEditor._buffer
        
        # Configure dialog buttons
        $this.PrimaryButtonText = "Find Next"
        $this.SecondaryButtonText = "Close"
    }
    
    [void] InitializeContent() {
        # Find text box
        $this.FindTextBox = [MinimalTextBox]::new()
        $this.FindTextBox.Placeholder = "Text to find..."
        $this.FindTextBox.Width = 50
        $this.AddContentControl($this.FindTextBox, 1)
        
        # Replace text box  
        $this.ReplaceTextBox = [MinimalTextBox]::new()
        $this.ReplaceTextBox.Placeholder = "Replace with..."
        $this.ReplaceTextBox.Width = 50
        $this.AddContentControl($this.ReplaceTextBox, 2)
        
        # Find buttons
        $this.FindNextButton = [MinimalButton]::new("Find Next")
        $this.FindNextButton.OnClick = {
            $this.FindNext()
        }.GetNewClosure()
        $this.AddContentControl($this.FindNextButton, 3)
        
        $this.FindPreviousButton = [MinimalButton]::new("Find Previous")
        $this.FindPreviousButton.OnClick = {
            $this.FindPrevious()
        }.GetNewClosure()
        $this.AddContentControl($this.FindPreviousButton, 4)
        
        # Replace buttons
        $this.ReplaceButton = [MinimalButton]::new("Replace")
        $this.ReplaceButton.OnClick = {
            $this.ReplaceNext()
        }.GetNewClosure()
        $this.AddContentControl($this.ReplaceButton, 5)
        
        $this.ReplaceAllButton = [MinimalButton]::new("Replace All")
        $this.ReplaceAllButton.OnClick = {
            $this.ReplaceAll()
        }.GetNewClosure()
        $this.AddContentControl($this.ReplaceAllButton, 6)
        
        # Set initial focus to find text box
        $this.FindTextBox.Focus()
        
        # Pre-populate with selected text if available
        if ($this._textEditor.HasSelection) {
            $selectedText = $this.GetSelectedText()
            if ($selectedText -and $selectedText.Length -lt 100) {
                $this.FindTextBox.SetText($selectedText)
            }
        }
    }
    
    [string] GetSelectedText() {
        if (-not $this._textEditor.HasSelection) {
            return ""
        }
        
        $bounds = $this._textEditor.GetSelectionBounds()
        if ($bounds.StartY -eq $bounds.EndY) {
            # Single line selection
            $line = $this._buffer.GetLine($bounds.StartY)
            return $line.Substring($bounds.StartX, $bounds.EndX - $bounds.StartX)
        } else {
            # Multi-line selection - just return first line for simplicity
            $line = $this._buffer.GetLine($bounds.StartY)
            return $line.Substring($bounds.StartX)
        }
    }
    
    [void] HandlePrimaryAction() {
        # Primary action is Find Next
        $this.FindNext()
    }
    
    [void] HandleSecondaryAction() {
        # Secondary action is Close
        if ($this.OnClose) {
            & $this.OnClose
        }
        $this.CloseDialog()
    }
    
    [bool] HandleScreenInput([System.ConsoleKeyInfo]$key) {
        # Handle F3 for Find Next
        if ($key.Key -eq [System.ConsoleKey]::F3) {
            if ($key.Modifiers -band [System.ConsoleModifiers]::Shift) {
                $this.FindPrevious()
            } else {
                $this.FindNext()
            }
            return $true
        }
        
        # Handle Ctrl+H for Replace
        if ($key.Key -eq [System.ConsoleKey]::H -and ($key.Modifiers -band [System.ConsoleModifiers]::Control)) {
            $this.ReplaceNext()
            return $true
        }
        
        # Let base class handle other keys
        return ([BaseDialog]$this).HandleScreenInput($key)
    }
    
    [void] FindNext() {
        $searchTerm = $this.FindTextBox.Text.Trim()
        if ([string]::IsNullOrEmpty($searchTerm)) {
            $this._textEditor.StatusMessage = "Please enter text to find"
            return
        }
        
        # Start search from current cursor position or after last found position
        $startLine = $this._textEditor.CursorY
        $startCol = $this._textEditor.CursorX
        
        # If we're searching for the same term and found it before, start after the last find
        if ($searchTerm -eq $this._lastSearchTerm -and $this._lastFoundLine -ge 0) {
            $startLine = $this._lastFoundLine
            $startCol = $this._lastFoundColumn + $searchTerm.Length
        }
        
        $result = $this.SearchForward($searchTerm, $startLine, $startCol)
        $this.HandleSearchResult($result, $searchTerm)
    }
    
    [void] FindPrevious() {
        $searchTerm = $this.FindTextBox.Text.Trim()
        if ([string]::IsNullOrEmpty($searchTerm)) {
            $this._textEditor.StatusMessage = "Please enter text to find"
            return
        }
        
        # Start search from current cursor position or before last found position
        $startLine = $this._textEditor.CursorY
        $startCol = $this._textEditor.CursorX
        
        # If we're searching for the same term and found it before, start before the last find
        if ($searchTerm -eq $this._lastSearchTerm -and $this._lastFoundLine -ge 0) {
            $startLine = $this._lastFoundLine
            $startCol = $this._lastFoundColumn - 1
        }
        
        $result = $this.SearchBackward($searchTerm, $startLine, $startCol)
        $this.HandleSearchResult($result, $searchTerm)
    }
    
    [hashtable] SearchForward([string]$searchTerm, [int]$startLine, [int]$startCol) {
        $lineCount = $this._buffer.GetLineCount()
        
        # Search from starting position to end of document
        for ($line = $startLine; $line -lt $lineCount; $line++) {
            $lineText = $this._buffer.GetLine($line)
            $searchStart = if ($line -eq $startLine) { $startCol } else { 0 }
            
            $index = $this.FindInLine($lineText, $searchTerm, $searchStart)
            if ($index -ge 0) {
                return @{
                    Found = $true
                    Line = $line
                    Column = $index
                }
            }
        }
        
        # Wrap around - search from beginning to start position
        for ($line = 0; $line -lt $startLine; $line++) {
            $lineText = $this._buffer.GetLine($line)
            $searchEnd = if ($line -eq $startLine - 1) { $startCol } else { $lineText.Length }
            
            $index = $this.FindInLine($lineText, $searchTerm, 0)
            if ($index -ge 0 -and $index -lt $searchEnd) {
                return @{
                    Found = $true
                    Line = $line
                    Column = $index
                    Wrapped = $true
                }
            }
        }
        
        return @{ Found = $false }
    }
    
    [hashtable] SearchBackward([string]$searchTerm, [int]$startLine, [int]$startCol) {
        # Search from starting position to beginning of document
        for ($line = $startLine; $line -ge 0; $line--) {
            $lineText = $this._buffer.GetLine($line)
            $searchEnd = if ($line -eq $startLine) { $startCol } else { $lineText.Length }
            
            $index = $this.FindInLineBackward($lineText, $searchTerm, $searchEnd)
            if ($index -ge 0) {
                return @{
                    Found = $true
                    Line = $line
                    Column = $index
                }
            }
        }
        
        # Wrap around - search from end to start position
        $lineCount = $this._buffer.GetLineCount()
        for ($line = $lineCount - 1; $line -gt $startLine; $line--) {
            $lineText = $this._buffer.GetLine($line)
            
            $index = $this.FindInLineBackward($lineText, $searchTerm, $lineText.Length)
            if ($index -ge 0) {
                return @{
                    Found = $true
                    Line = $line
                    Column = $index
                    Wrapped = $true
                }
            }
        }
        
        return @{ Found = $false }
    }
    
    [int] FindInLine([string]$line, [string]$searchTerm, [int]$startIndex) {
        if ($this.MatchCase) {
            return $line.IndexOf($searchTerm, $startIndex)
        } else {
            return $line.ToLower().IndexOf($searchTerm.ToLower(), $startIndex)
        }
    }
    
    [int] FindInLineBackward([string]$line, [string]$searchTerm, [int]$endIndex) {
        if ($endIndex -le 0) { return -1 }
        
        $searchableText = $line.Substring(0, $endIndex)
        if ($this.MatchCase) {
            return $searchableText.LastIndexOf($searchTerm)
        } else {
            return $searchableText.ToLower().LastIndexOf($searchTerm.ToLower())
        }
    }
    
    [void] HandleSearchResult([hashtable]$result, [string]$searchTerm) {
        if ($result.Found) {
            # Move cursor to found position
            $this._textEditor.CursorY = $result.Line
            $this._textEditor.CursorX = $result.Column
            $this._textEditor.EnsureCursorVisible()
            
            # Select the found text
            $this._textEditor.StartSelection()
            $this._textEditor.SelectionStartX = $result.Column
            $this._textEditor.SelectionStartY = $result.Line
            $this._textEditor.SelectionEndX = $result.Column + $searchTerm.Length
            $this._textEditor.SelectionEndY = $result.Line
            $this._textEditor.CursorX = $result.Column + $searchTerm.Length
            
            # Update last found position
            $this._lastFoundLine = $result.Line
            $this._lastFoundColumn = $result.Column
            $this._lastSearchTerm = $searchTerm
            
            # Set status message
            $wrapMsg = if ($result.Wrapped) { " (wrapped)" } else { "" }
            $this._textEditor.StatusMessage = "Found at line $($result.Line + 1), column $($result.Column + 1)$wrapMsg"
        } else {
            $this._textEditor.StatusMessage = "Text not found: '$searchTerm'"
            $this._lastFoundLine = -1
            $this._lastFoundColumn = -1
        }
        
        $this._textEditor.Invalidate()
    }
    
    [void] ReplaceNext() {
        $searchTerm = $this.FindTextBox.Text.Trim()
        $replaceText = $this.ReplaceTextBox.Text
        
        if ([string]::IsNullOrEmpty($searchTerm)) {
            $this._textEditor.StatusMessage = "Please enter text to find"
            return
        }
        
        # If we have a selection that matches the search term, replace it
        if ($this._textEditor.HasSelection) {
            $selectedText = $this.GetSelectedText()
            $matchesSearch = if ($this.MatchCase) { 
                $selectedText -eq $searchTerm 
            } else { 
                $selectedText.ToLower() -eq $searchTerm.ToLower() 
            }
            
            if ($matchesSearch) {
                # Replace the selected text
                $this._textEditor.SaveDocumentState()
                $this._textEditor.DeleteSelection()
                if ($replaceText) {
                    $this._textEditor._buffer.InsertTextAt($this._textEditor.CursorY, $this._textEditor.CursorX, $replaceText)
                    $this._textEditor.CursorX += $replaceText.Length
                }
                $this._textEditor._buffer.IsModified = $true
                $this._textEditor._allLinesDirty = $true
                $this._textEditor.Invalidate()
                $this._textEditor.StatusMessage = "Replaced 1 occurrence"
                
                # Find next occurrence
                $this.FindNext()
                return
            }
        }
        
        # No selection or selection doesn't match - just find next
        $this.FindNext()
    }
    
    [void] ReplaceAll() {
        $searchTerm = $this.FindTextBox.Text.Trim()
        $replaceText = $this.ReplaceTextBox.Text
        
        if ([string]::IsNullOrEmpty($searchTerm)) {
            $this._textEditor.StatusMessage = "Please enter text to find"
            return
        }
        
        $this._textEditor.SaveDocumentState()
        $replacements = 0
        $lineCount = $this._buffer.GetLineCount()
        
        # Search through all lines
        for ($line = 0; $line -lt $lineCount; $line++) {
            $lineText = $this._buffer.GetLine($line)
            $originalText = $lineText
            
            # Keep replacing until no more matches in this line
            $modified = $false
            do {
                $index = $this.FindInLine($lineText, $searchTerm, 0)
                if ($index -ge 0) {
                    # Replace the occurrence
                    $before = $lineText.Substring(0, $index)
                    $after = $lineText.Substring($index + $searchTerm.Length)
                    $lineText = $before + $replaceText + $after
                    $replacements++
                    $modified = $true
                } else {
                    break
                }
            } while ($true)
            
            # Update the line if it was modified
            if ($modified) {
                $this._buffer.Lines[$line] = $lineText
            }
        }
        
        if ($replacements -gt 0) {
            $this._buffer.IsModified = $true
            $this._textEditor._allLinesDirty = $true
            $this._textEditor.Invalidate()
            $this._textEditor.StatusMessage = "Replaced $replacements occurrence(s)"
        } else {
            $this._textEditor.StatusMessage = "No occurrences found to replace"
        }
    }
    
    # Override OnRender to add field labels
    [string] OnRender() {
        # Get base dialog rendering first
        $baseRender = ([BaseDialog]$this).OnRender()
        
        # Add field labels over the dialog content
        $sb = [System.Text.StringBuilder]::new($baseRender)
        
        if ($this._dialogBounds.Count -gt 0) {
            $dialogX = $this._dialogBounds.X
            $dialogY = $this._dialogBounds.Y
            $labelColor = $this.Theme.GetColor("dialog.text")
            
            # Add labels for each field
            $fieldY = $dialogY + $this.DialogPadding
            
            # Find label
            $sb.Append([VT]::MoveTo($dialogX + 2, $fieldY))
            $sb.Append($labelColor)
            $sb.Append("Find:")
            $fieldY += 4
            
            # Replace label  
            $sb.Append([VT]::MoveTo($dialogX + 2, $fieldY))
            $sb.Append("Replace:")
            
            # Add status about search options if any are enabled
            if ($this.MatchCase -or $this.WholeWord -or $this.RegexMode) {
                $options = @()
                if ($this.MatchCase) { $options += "Match Case" }
                if ($this.WholeWord) { $options += "Whole Word" }
                if ($this.RegexMode) { $options += "Regex" }
                
                $sb.Append([VT]::MoveTo($dialogX + 2, $dialogY + $this.DialogHeight - 4))
                $sb.Append("Options: $($options -join ', ')")
            }
        }
        
        return $sb.ToString()
    }
}