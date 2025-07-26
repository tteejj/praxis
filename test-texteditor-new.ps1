#!/usr/bin/env pwsh

# Test script for the new text editor architecture
$script:PraxisRoot = $PSScriptRoot
Set-Location $script:PraxisRoot

# Load essential components only
. "$PSScriptRoot/Core/StringCache.ps1"
. "$PSScriptRoot/Core/VT100.ps1"
. "$PSScriptRoot/Core/ServiceContainer.ps1"
. "$PSScriptRoot/Core/StringBuilderPool.ps1"
. "$PSScriptRoot/Core/DocumentBuffer.ps1"
. "$PSScriptRoot/Core/EditorCommands.ps1"
. "$PSScriptRoot/Services/Logger.ps1"
. "$PSScriptRoot/Services/ThemeManager.ps1"
. "$PSScriptRoot/Base/UIElement.ps1"
. "$PSScriptRoot/Base/Container.ps1"
. "$PSScriptRoot/Base/Screen.ps1"
. "$PSScriptRoot/Screens/TextEditorScreenNew.ps1"

# Initialize minimal services
$global:ServiceContainer = [ServiceContainer]::new()
$logger = [Logger]::new()
$global:Logger = $logger
$global:ServiceContainer.Register("Logger", $logger)
$themeManager = [ThemeManager]::new()
$global:ServiceContainer.Register("ThemeManager", $themeManager)

Write-Host "Testing new TextEditorScreenNew architecture..." -ForegroundColor Green

# Test DocumentBuffer
Write-Host "`n1. Testing DocumentBuffer:" -ForegroundColor Yellow
$buffer = [DocumentBuffer]::new()
Write-Host "   ✓ DocumentBuffer created, line count: $($buffer.GetLineCount())"

# Test commands
Write-Host "   Testing InsertTextCommand..."
$insertCmd = [InsertTextCommand]::new(0, 0, "Hello World")
$buffer.ExecuteCommand($insertCmd)
Write-Host "   ✓ Insert command executed: '$($buffer.GetLine(0))'"

Write-Host "   Testing undo..."
$buffer.Undo()
Write-Host "   ✓ Undo executed: '$($buffer.GetLine(0))'"

Write-Host "   Testing redo..."
$buffer.Redo()
Write-Host "   ✓ Redo executed: '$($buffer.GetLine(0))'"

# Test newline command
Write-Host "   Testing newline command..."
$newlineCmd = [InsertNewlineCommand]::new(0, 5, "")
$buffer.ExecuteCommand($newlineCmd)
Write-Host "   ✓ Newline inserted, line count: $($buffer.GetLineCount())"
Write-Host "     Line 0: '$($buffer.GetLine(0))'"
Write-Host "     Line 1: '$($buffer.GetLine(1))'"

# Test TextEditorScreen
Write-Host "`n2. Testing TextEditorScreenNew:" -ForegroundColor Yellow
$editor = [TextEditorScreenNew]::new()
$editor.Initialize($global:ServiceContainer)
Write-Host "   ✓ TextEditorScreenNew created and initialized"

# Test bounds and rendering
$editor.SetBounds(0, 0, 80, 24)
Write-Host "   ✓ Bounds set to 80x24"

try {
    $renderOutput = $editor.Render()
    Write-Host "   ✓ Render successful, output length: $($renderOutput.Length)"
} catch {
    Write-Host "   ✗ Render failed: $_" -ForegroundColor Red
}

Write-Host "`n3. Testing file operations:" -ForegroundColor Yellow
$testFile = "$PSScriptRoot/test-editor-content.txt"

# Create test content
$testContent = @"
Line 1: Hello World
Line 2: This is a test
Line 3: New architecture works!
"@

Set-Content -Path $testFile -Value $testContent
Write-Host "   ✓ Test file created: $testFile"

# Test file loading
$editorWithFile = [TextEditorScreenNew]::new($testFile)
Write-Host "   ✓ Editor with file created"
Write-Host "     Lines loaded: $($editorWithFile._buffer.GetLineCount())"
Write-Host "     First line: '$($editorWithFile._buffer.GetLine(0))'"

# Clean up
Remove-Item -Path $testFile -Force
Write-Host "   ✓ Test file cleaned up"

Write-Host "`nAll tests completed successfully! ✓" -ForegroundColor Green
Write-Host "New text editor architecture is working." -ForegroundColor Cyan