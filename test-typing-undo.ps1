#!/usr/bin/env pwsh

# Test typing and undo scenario
$script:PraxisRoot = $PSScriptRoot
Set-Location $script:PraxisRoot

# Load essential components
. "$PSScriptRoot/Core/StringCache.ps1"
. "$PSScriptRoot/Core/VT100.ps1"
. "$PSScriptRoot/Core/ServiceContainer.ps1"
. "$PSScriptRoot/Core/DocumentBuffer.ps1"
. "$PSScriptRoot/Core/EditorCommands.ps1"
. "$PSScriptRoot/Services/Logger.ps1"
. "$PSScriptRoot/Services/ThemeManager.ps1"
. "$PSScriptRoot/Base/UIElement.ps1"
. "$PSScriptRoot/Base/Container.ps1"
. "$PSScriptRoot/Base/Screen.ps1"
. "$PSScriptRoot/Screens/TextEditorScreenNew.ps1"

# Initialize services
$global:ServiceContainer = [ServiceContainer]::new()
$logger = [Logger]::new()
$global:Logger = $logger
$global:ServiceContainer.Register("Logger", $logger)
$themeManager = [ThemeManager]::new()
$global:ServiceContainer.Register("ThemeManager", $themeManager)

Write-Host "Testing typing and undo scenario..." -ForegroundColor Yellow

# Create editor like PRAXIS does
$editor = [TextEditorScreenNew]::new()
$editor.Initialize($global:ServiceContainer)
$editor.SetBounds(0, 0, 80, 24)

Write-Host "✓ Editor created and initialized"
Write-Host "Initial cursor position: ($($editor.CursorX),$($editor.CursorY))"
Write-Host "Buffer line count: $($editor._buffer.GetLineCount())"
Write-Host "Can undo: $($editor._buffer.CanUndo())"

# Simulate typing some text
Write-Host "`nSimulating typing 'Hello'..."
$testChars = @('H', 'e', 'l', 'l', 'o')
foreach ($char in $testChars) {
    $keyInfo = [System.ConsoleKeyInfo]::new($char, [System.ConsoleKey]::$char, $false, $false, $false)
    try {
        $handled = $editor.HandleScreenInput($keyInfo)
        Write-Host "  Typed '$char', handled: $handled"
    } catch {
        Write-Host "  ✗ Error typing '$char': $_" -ForegroundColor Red
    }
}

Write-Host "After typing:"
Write-Host "  Cursor position: ($($editor.CursorX),$($editor.CursorY))"
Write-Host "  Line 0: '$($editor._buffer.GetLine(0))'"
Write-Host "  Can undo: $($editor._buffer.CanUndo())"

# Try to undo
Write-Host "`nTesting undo..."
try {
    $editor.UndoEdit()
    Write-Host "✓ Undo 1 completed"
    Write-Host "  Line 0: '$($editor._buffer.GetLine(0))'"
    Write-Host "  Cursor: ($($editor.CursorX),$($editor.CursorY))"
    
    $editor.UndoEdit()
    Write-Host "✓ Undo 2 completed" 
    Write-Host "  Line 0: '$($editor._buffer.GetLine(0))'"
    Write-Host "  Cursor: ($($editor.CursorX),$($editor.CursorY))"
    
} catch {
    Write-Host "✗ Undo crashed: $_" -ForegroundColor Red
    Write-Host "Exception: $($_.Exception.GetType().Name)" -ForegroundColor Red
    Write-Host "Message: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack trace: $($_.ScriptStackTrace)" -ForegroundColor Red
}

Write-Host "`nTest completed!" -ForegroundColor Green