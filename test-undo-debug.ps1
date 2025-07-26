#!/usr/bin/env pwsh

# Debug script for undo crash
$script:PraxisRoot = $PSScriptRoot
Set-Location $script:PraxisRoot

# Load minimal components
. "$PSScriptRoot/Core/DocumentBuffer.ps1"
. "$PSScriptRoot/Core/EditorCommands.ps1"

Write-Host "Testing undo crash scenario..." -ForegroundColor Red

# Create buffer like TextEditorScreenNew does
$buffer = [DocumentBuffer]::new()
Write-Host "Initial buffer created with $($buffer.GetLineCount()) lines"

# Simulate AddSampleContent
$sampleLines = @("Line 1", "Line 2", "Line 3")
$buffer.Lines.Clear()
foreach ($line in $sampleLines) {
    $buffer.Lines.Add($line) | Out-Null
}
$buffer.ClearUndoHistory()
$buffer.IsModified = $false

Write-Host "Sample content added: $($buffer.GetLineCount()) lines"
Write-Host "Can undo: $($buffer.CanUndo())"
Write-Host "Can redo: $($buffer.CanRedo())"

# Try to undo - this should be safe since we cleared history
Write-Host "`nTrying to undo (should be safe)..."
try {
    $buffer.Undo()
    Write-Host "✓ Undo completed successfully"
} catch {
    Write-Host "✗ Undo crashed: $_" -ForegroundColor Red
    Write-Host "Exception: $($_.Exception.GetType().Name)" -ForegroundColor Red
    Write-Host "Message: $($_.Exception.Message)" -ForegroundColor Red
}

# Now add some real content and try undo
Write-Host "`nAdding real content via command..."
$insertCmd = [InsertTextCommand]::new(0, 0, "TEST")
$buffer.ExecuteCommand($insertCmd)
Write-Host "Line 0 after insert: '$($buffer.GetLine(0))'"
Write-Host "Can undo: $($buffer.CanUndo())"

# Try to undo the real command
Write-Host "`nTrying to undo real command..."
try {
    $buffer.Undo()
    Write-Host "✓ Undo completed successfully"
    Write-Host "Line 0 after undo: '$($buffer.GetLine(0))'"
} catch {
    Write-Host "✗ Undo crashed: $_" -ForegroundColor Red
    Write-Host "Exception: $($_.Exception.GetType().Name)" -ForegroundColor Red
    Write-Host "Message: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack trace: $($_.ScriptStackTrace)" -ForegroundColor Red
}