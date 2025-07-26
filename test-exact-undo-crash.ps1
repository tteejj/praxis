#!/usr/bin/env pwsh

# Test exact TextEditorScreenNew scenario that crashes
$script:PraxisRoot = $PSScriptRoot
Set-Location $script:PraxisRoot

# Load only what we need
. "$PSScriptRoot/Core/DocumentBuffer.ps1"
. "$PSScriptRoot/Core/EditorCommands.ps1"

Write-Host "Reproducing exact TextEditorScreenNew undo scenario..." -ForegroundColor Red

# Create buffer exactly like TextEditorScreenNew constructor
Write-Host "Step 1: Creating buffer with empty line..."
$buffer = [DocumentBuffer]::new()
Write-Host "  Initial lines: $($buffer.GetLineCount())"
Write-Host "  Line 0: '$($buffer.GetLine(0))'"
Write-Host "  Can undo: $($buffer.CanUndo())"

# Simulate AddSampleContent exactly like TextEditorScreenNew does
Write-Host "`nStep 2: Simulating AddSampleContent()..."
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

# This is what AddSampleContent does
$buffer.Lines.Clear()
foreach ($line in $sampleLines) {
    $buffer.Lines.Add($line) | Out-Null
}
$buffer.ClearUndoHistory()
$buffer.IsModified = $false

Write-Host "  After sample content:"
Write-Host "  Lines: $($buffer.GetLineCount())"
Write-Host "  Line 0: '$($buffer.GetLine(0))'"
Write-Host "  Can undo: $($buffer.CanUndo()) (should be false)"

# Now simulate typing a character like InsertCharacter does
Write-Host "`nStep 3: Simulating typing 'H' at position (0,0)..."
$insertCmd = [InsertTextCommand]::new(0, 0, "H")
$buffer.ExecuteCommand($insertCmd)

Write-Host "  After insert:"
Write-Host "  Line 0: '$($buffer.GetLine(0))'"  
Write-Host "  Can undo: $($buffer.CanUndo()) (should be true)"

# Now try undo - this is where it might crash
Write-Host "`nStep 4: Attempting undo (this might crash)..."
try {
    Write-Host "  Calling buffer.Undo()..."
    $buffer.Undo()
    Write-Host "  ✓ Undo completed successfully!"
    Write-Host "  Line 0 after undo: '$($buffer.GetLine(0))'"
    Write-Host "  Can undo: $($buffer.CanUndo())"
    Write-Host "  Can redo: $($buffer.CanRedo())"
} catch {
    Write-Host "  ✗ UNDO CRASHED!" -ForegroundColor Red
    Write-Host "  Exception Type: $($_.Exception.GetType().Name)" -ForegroundColor Red
    Write-Host "  Message: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "  Stack Trace:" -ForegroundColor Red
    Write-Host "  $($_.ScriptStackTrace)" -ForegroundColor Red
    
    # Show the command details that failed
    Write-Host "`n  Debug info:" -ForegroundColor Yellow
    Write-Host "  Undo stack count: $($buffer._undoStack.Count)"
    if ($buffer._undoStack.Count -gt 0) {
        $lastCmd = $buffer._undoStack[$buffer._undoStack.Count - 1]
        Write-Host "  Last command type: $($lastCmd.GetType().Name)"
        Write-Host "  Command Line: $($lastCmd.Line)"
        Write-Host "  Command Col: $($lastCmd.Col)" 
        Write-Host "  Command Text: '$($lastCmd.Text)'"
    }
}

Write-Host "`nTest completed!" -ForegroundColor Green