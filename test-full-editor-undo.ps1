#!/usr/bin/env pwsh

# Test the full TextEditorScreenNew undo crash
$script:PraxisRoot = $PSScriptRoot
Set-Location $script:PraxisRoot

Write-Host "Testing full TextEditorScreenNew undo crash..." -ForegroundColor Red

# Load all required dependencies in correct order
. "$PSScriptRoot/Core/StringCache.ps1"
. "$PSScriptRoot/Core/VT100.ps1"
. "$PSScriptRoot/Core/ServiceContainer.ps1"
. "$PSScriptRoot/Core/StringBuilderPool.ps1"
. "$PSScriptRoot/Core/DocumentBuffer.ps1"
. "$PSScriptRoot/Core/EditorCommands.ps1"
. "$PSScriptRoot/Services/Logger.ps1"
. "$PSScriptRoot/Services/EventBus.ps1"
. "$PSScriptRoot/Services/ThemeManager.ps1"
. "$PSScriptRoot/Base/UIElement.ps1"
. "$PSScriptRoot/Base/Container.ps1"
. "$PSScriptRoot/Base/Screen.ps1"
. "$PSScriptRoot/Screens/TextEditorScreenNew.ps1"

# Initialize services like PRAXIS does
$global:ServiceContainer = [ServiceContainer]::new()
$logger = [Logger]::new()
$global:Logger = $logger
$global:ServiceContainer.Register("Logger", $logger)

$eventBus = [EventBus]::new()
$global:ServiceContainer.Register("EventBus", $eventBus)

$themeManager = [ThemeManager]::new()
$global:ServiceContainer.Register("ThemeManager", $themeManager)

Write-Host "✓ All dependencies loaded and services initialized"

# Create editor exactly like PRAXIS does
Write-Host "`nCreating TextEditorScreenNew..." 
try {
    $editor = [TextEditorScreenNew]::new()
    $editor.Initialize($global:ServiceContainer)
    $editor.SetBounds(0, 0, 80, 24)
    Write-Host "✓ Editor created and initialized"
} catch {
    Write-Host "✗ Failed to create editor: $_" -ForegroundColor Red
    exit 1
}

# Show initial state
Write-Host "`nInitial state:"
Write-Host "  Cursor: ($($editor.CursorX),$($editor.CursorY))"
Write-Host "  Lines: $($editor._buffer.GetLineCount())"
Write-Host "  Line 0: '$($editor._buffer.GetLine(0))'"
Write-Host "  Can undo: $($editor._buffer.CanUndo())"

# Simulate typing exactly like the real editor
Write-Host "`nSimulating typing 'A'..."
try {
    $keyInfo = [System.ConsoleKeyInfo]::new('A', [System.ConsoleKey]::A, $false, $false, $false)
    $handled = $editor.HandleScreenInput($keyInfo)
    Write-Host "✓ Character typed, handled: $handled"
    Write-Host "  New cursor: ($($editor.CursorX),$($editor.CursorY))"
    Write-Host "  Line 0: '$($editor._buffer.GetLine(0))'"
    Write-Host "  Can undo: $($editor._buffer.CanUndo())"
} catch {
    Write-Host "✗ Failed to type character: $_" -ForegroundColor Red
    exit 1
}

# Now try to undo - this is where it should crash
Write-Host "`nAttempting undo (this may crash)..."
try {
    Write-Host "  Calling editor.UndoEdit()..."
    $editor.UndoEdit()
    Write-Host "  ✓ Undo completed successfully!"
    Write-Host "  Final cursor: ($($editor.CursorX),$($editor.CursorY))" 
    Write-Host "  Line 0: '$($editor._buffer.GetLine(0))'"
    Write-Host "  Status: '$($editor.StatusMessage)'"
} catch {
    Write-Host "  ✗ UNDO CRASHED IN FULL EDITOR!" -ForegroundColor Red
    Write-Host "  Exception Type: $($_.Exception.GetType().Name)" -ForegroundColor Red
    Write-Host "  Message: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "  Inner Exception: $($_.Exception.InnerException)" -ForegroundColor Red
    Write-Host "  Stack Trace:" -ForegroundColor Red
    $_.ScriptStackTrace -split "`n" | ForEach-Object { Write-Host "    $_" -ForegroundColor Red }
    
    Write-Host "`n  Additional debug info:" -ForegroundColor Yellow
    Write-Host "  Editor cursor: ($($editor.CursorX),$($editor.CursorY))"
    Write-Host "  Buffer lines: $($editor._buffer.GetLineCount())"
    Write-Host "  Buffer can undo: $($editor._buffer.CanUndo())"
    Write-Host "  Editor status: '$($editor.StatusMessage)'"
    
    exit 1
}

Write-Host "`nTest completed successfully!" -ForegroundColor Green