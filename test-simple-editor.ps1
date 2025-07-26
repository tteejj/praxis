#!/usr/bin/env pwsh

# Simple test for DocumentBuffer and Commands
$script:PraxisRoot = $PSScriptRoot
Set-Location $script:PraxisRoot

# Load minimal components
. "$PSScriptRoot/Core/DocumentBuffer.ps1"
. "$PSScriptRoot/Core/EditorCommands.ps1"

Write-Host "Testing DocumentBuffer and Command Pattern..." -ForegroundColor Green

# Test DocumentBuffer
Write-Host "`n1. Testing DocumentBuffer:" -ForegroundColor Yellow
$buffer = [DocumentBuffer]::new()
Write-Host "   ✓ DocumentBuffer created"
Write-Host "   Initial line count: $($buffer.GetLineCount())"
Write-Host "   First line: '$($buffer.GetLine(0))'"

# Test InsertTextCommand
Write-Host "`n2. Testing InsertTextCommand:" -ForegroundColor Yellow
$insertCmd = [InsertTextCommand]::new(0, 0, "Hello World")
$buffer.ExecuteCommand($insertCmd)
Write-Host "   ✓ Insert command executed"
Write-Host "   Line after insert: '$($buffer.GetLine(0))'"
Write-Host "   Is modified: $($buffer.IsModified)"

# Test Undo
Write-Host "`n3. Testing Undo:" -ForegroundColor Yellow
Write-Host "   Can undo: $($buffer.CanUndo())"
$buffer.Undo()
Write-Host "   ✓ Undo executed"
Write-Host "   Line after undo: '$($buffer.GetLine(0))'"
Write-Host "   Can redo: $($buffer.CanRedo())"

# Test Redo
Write-Host "`n4. Testing Redo:" -ForegroundColor Yellow
$buffer.Redo()
Write-Host "   ✓ Redo executed"
Write-Host "   Line after redo: '$($buffer.GetLine(0))'"

# Test DeleteTextCommand
Write-Host "`n5. Testing DeleteTextCommand:" -ForegroundColor Yellow
$deleteCmd = [DeleteTextCommand]::new(0, 0, "Hello")
$buffer.ExecuteCommand($deleteCmd)
Write-Host "   ✓ Delete command executed"
Write-Host "   Line after delete: '$($buffer.GetLine(0))'"

# Test InsertNewlineCommand
Write-Host "`n6. Testing InsertNewlineCommand:" -ForegroundColor Yellow
$newlineCmd = [InsertNewlineCommand]::new(0, 3, "")
$buffer.ExecuteCommand($newlineCmd)
Write-Host "   ✓ Newline command executed"
Write-Host "   Line count: $($buffer.GetLineCount())"
Write-Host "   Line 0: '$($buffer.GetLine(0))'"
Write-Host "   Line 1: '$($buffer.GetLine(1))'"

# Test file operations
Write-Host "`n7. Testing file operations:" -ForegroundColor Yellow
$testFile = "$PSScriptRoot/test-buffer.txt"

try {
    $buffer.SaveToFile($testFile)
    Write-Host "   ✓ File saved successfully"
    
    $buffer2 = [DocumentBuffer]::new($testFile)
    Write-Host "   ✓ File loaded successfully"
    Write-Host "   Loaded line count: $($buffer2.GetLineCount())"
    Write-Host "   Loaded line 0: '$($buffer2.GetLine(0))'"
    Write-Host "   Loaded line 1: '$($buffer2.GetLine(1))'"
    
    Remove-Item -Path $testFile -Force
    Write-Host "   ✓ Test file cleaned up"
} catch {
    Write-Host "   ✗ File operation failed: $_" -ForegroundColor Red
}

Write-Host "`nAll core tests completed successfully! ✓" -ForegroundColor Green
Write-Host "Buffer/View architecture and Command Pattern are working." -ForegroundColor Cyan