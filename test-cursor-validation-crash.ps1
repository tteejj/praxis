#!/usr/bin/env pwsh

# Test cursor validation crash scenario
$script:PraxisRoot = $PSScriptRoot
Set-Location $script:PraxisRoot

# Load dependencies
. "$PSScriptRoot/Core/DocumentBuffer.ps1"
. "$PSScriptRoot/Core/EditorCommands.ps1"

Write-Host "Testing cursor validation after undo..." -ForegroundColor Red

# Create the scenario
$buffer = [DocumentBuffer]::new()

# Add sample content
$sampleLines = @(
    "Welcome to PRAXIS Text Editor!",
    "",
    "This is line 2"
)
$buffer.Lines.Clear()
foreach ($line in $sampleLines) {
    $buffer.Lines.Add($line) | Out-Null
}
$buffer.ClearUndoHistory()
$buffer.IsModified = $false

# Set cursor position like editor would
$CursorX = 0
$CursorY = 0

Write-Host "Initial state:"
Write-Host "  Lines: $($buffer.GetLineCount())"
Write-Host "  Cursor: ($CursorX,$CursorY)"

# Type a character
Write-Host "`nTyping 'H' at cursor position..."
$insertCmd = [InsertTextCommand]::new($CursorY, $CursorX, "H")
$buffer.ExecuteCommand($insertCmd)
$CursorX++  # Move cursor like editor does

Write-Host "After typing:"
Write-Host "  Line 0: '$($buffer.GetLine(0))'"
Write-Host "  Cursor: ($CursorX,$CursorY)"

# Now undo and validate cursor like TextEditorScreenNew.UndoEdit() does
Write-Host "`nPerforming undo with cursor validation..."
try {
    # This is what UndoEdit does
    $buffer.Undo()
    
    # Simulate ValidateCursorPosition
    Write-Host "Validating cursor position..."
    $lineCount = $buffer.GetLineCount()
    if ($lineCount -eq 0) {
        $CursorX = 0
        $CursorY = 0
    } else {
        # Clamp cursor Y
        $CursorY = [Math]::Max(0, [Math]::Min($CursorY, $lineCount - 1))
        
        # Get current line for X validation
        Write-Host "  Getting line $CursorY..."
        $currentLine = $buffer.GetLine($CursorY)
        Write-Host "  Current line: '$currentLine'"
        Write-Host "  Current line length: $($currentLine.Length)"
        Write-Host "  Cursor X before clamp: $CursorX"
        
        # Clamp cursor X
        $CursorX = [Math]::Max(0, [Math]::Min($CursorX, $currentLine.Length))
        Write-Host "  Cursor X after clamp: $CursorX"
    }
    
    Write-Host "✓ Undo and validation completed successfully!"
    Write-Host "  Final cursor: ($CursorX,$CursorY)"
    Write-Host "  Line 0: '$($buffer.GetLine(0))'"
    
} catch {
    Write-Host "✗ CRASH during undo/validation!" -ForegroundColor Red
    Write-Host "Exception: $($_.Exception.GetType().Name)" -ForegroundColor Red
    Write-Host "Message: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack Trace: $($_.ScriptStackTrace)" -ForegroundColor Red
}

Write-Host "`nTest completed!" -ForegroundColor Green