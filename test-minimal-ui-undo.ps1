#!/usr/bin/env pwsh

# Minimal reproduction of the UI undo crash
$script:PraxisRoot = $PSScriptRoot
Set-Location $script:PraxisRoot

# Load dependencies first
. "$PSScriptRoot/Core/DocumentBuffer.ps1"
. "$PSScriptRoot/Core/EditorCommands.ps1"

# Create a minimal class that mimics the exact pattern from TextEditorScreenNew
class MinimalEditor {
    hidden [object]$_buffer
    [int]$CursorX = 0
    [int]$CursorY = 0
    [string]$StatusMessage = ""
    
    MinimalEditor() {
        
        $this._buffer = [DocumentBuffer]::new()
        
        # Exactly mimic AddSampleContent
        $sampleLines = @(
            "Welcome to PRAXIS Text Editor!",
            "",
            "This is the new Buffer/View architecture with:",
            "• Command Pattern for robust undo/redo"
        )
        
        $this._buffer.Lines.Clear()
        foreach ($line in $sampleLines) {
            $this._buffer.Lines.Add($line) | Out-Null
        }
        $this._buffer.ClearUndoHistory()
        $this._buffer.IsModified = $false
    }
    
    [void] TypeCharacter([char]$char) {
        Write-Host "Typing '$char' at ($($this.CursorX),$($this.CursorY))"
        $command = [InsertTextCommand]::new($this.CursorY, $this.CursorX, [string]$char)
        $this._buffer.ExecuteCommand($command)
        $this.CursorX++
        Write-Host "  After typing: Line 0 = '$($this._buffer.GetLine(0))'"
        Write-Host "  Can undo: $($this._buffer.CanUndo())"
    }
    
    [void] UndoEdit() {
        Write-Host "Starting undo operation..."
        
        if (-not $this._buffer.CanUndo()) {
            Write-Host "  Nothing to undo"
            return
        }
        
        try {
            Write-Host "  Calling buffer.Undo()..."
            $this._buffer.Undo()
            Write-Host "  Buffer undo completed"
            
            Write-Host "  Validating cursor position..."
            $this.ValidateCursorPosition()
            Write-Host "  Cursor validation completed"
            
            $this.StatusMessage = "Undo"
            Write-Host "  ✓ Undo operation completed successfully"
            Write-Host "  Final state: Line 0 = '$($this._buffer.GetLine(0))'"
            Write-Host "  Final cursor: ($($this.CursorX),$($this.CursorY))"
            
        } catch {
            Write-Host "  ✗ UNDO CRASHED!" -ForegroundColor Red
            Write-Host "  Exception: $($_.Exception.GetType().Name)" -ForegroundColor Red
            Write-Host "  Message: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host "  Stack: $($_.ScriptStackTrace)" -ForegroundColor Red
            throw $_
        }
    }
    
    [void] ValidateCursorPosition() {
        $lineCount = $this._buffer.GetLineCount()
        if ($lineCount -eq 0) {
            $this.CursorX = 0
            $this.CursorY = 0
            return
        }
        
        $this.CursorY = [Math]::Max(0, [Math]::Min($this.CursorY, $lineCount - 1))
        $currentLine = $this._buffer.GetLine($this.CursorY)
        $this.CursorX = [Math]::Max(0, [Math]::Min($this.CursorX, $currentLine.Length))
    }
}

Write-Host "Creating minimal editor..." -ForegroundColor Yellow
$editor = [MinimalEditor]::new()

Write-Host "`nInitial state:"
Write-Host "  Cursor: ($($editor.CursorX),$($editor.CursorY))"
Write-Host "  Line 0: '$($editor._buffer.GetLine(0))'"

Write-Host "`nTyping character 'X'..." -ForegroundColor Green
$editor.TypeCharacter('X')

Write-Host "`nAttempting undo..." -ForegroundColor Red
$editor.UndoEdit()

Write-Host "`nTest completed!" -ForegroundColor Green