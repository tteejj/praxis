#!/usr/bin/env pwsh

# Test if the crash is related to the keypress handling context
$script:PraxisRoot = $PSScriptRoot
Set-Location $script:PraxisRoot

Write-Host "Testing keypress context undo crash..." -ForegroundColor Red

# Load the full editor with all dependencies
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

# Initialize services
$global:ServiceContainer = [ServiceContainer]::new()
$logger = [Logger]::new()
$global:Logger = $logger
$global:ServiceContainer.Register("Logger", $logger)
$eventBus = [EventBus]::new()
$global:ServiceContainer.Register("EventBus", $eventBus)
$themeManager = [ThemeManager]::new()
$global:ServiceContainer.Register("ThemeManager", $themeManager)

# Create editor
$editor = [TextEditorScreenNew]::new()
$editor.Initialize($global:ServiceContainer)
$editor.SetBounds(0, 0, 80, 24)

Write-Host "Editor initialized. Initial state:"
Write-Host "  Line 0: '$($editor._buffer.GetLine(0))'"
Write-Host "  Can undo: $($editor._buffer.CanUndo())"

# Type a character using HandleScreenInput (the actual input mechanism)
Write-Host "`nTyping 'T' using HandleScreenInput..."
$keyInfo = [System.ConsoleKeyInfo]::new('T', [System.ConsoleKey]::T, $false, $false, $false)
$handled = $editor.HandleScreenInput($keyInfo)
Write-Host "Character handled: $handled"
Write-Host "After typing: '$($editor._buffer.GetLine(0))'"
Write-Host "Can undo: $($editor._buffer.CanUndo())"

# Now simulate the exact Ctrl+Z keypress that crashes in the real app
Write-Host "`nSimulating Ctrl+Z keypress using HandleScreenInput..."
Write-Host "This might crash immediately..."

try {
    # Create the exact same keypress as the real application would receive
    $ctrlZ = [System.ConsoleKeyInfo]::new([char]26, [System.ConsoleKey]::Z, $false, $false, $true)
    Write-Host "Created Ctrl+Z keyinfo: Key=$($ctrlZ.Key), Modifiers=$($ctrlZ.Modifiers)"
    
    Write-Host "Calling HandleScreenInput with Ctrl+Z..."
    $handled = $editor.HandleScreenInput($ctrlZ)
    
    Write-Host "✓ Ctrl+Z handled successfully: $handled"
    Write-Host "Final state: '$($editor._buffer.GetLine(0))'"
    Write-Host "Status: '$($editor.StatusMessage)'"
    
} catch {
    Write-Host "✗ CTRL+Z CRASHED!" -ForegroundColor Red
    Write-Host "Exception Type: $($_.Exception.GetType().Name)" -ForegroundColor Red
    Write-Host "Message: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Inner Exception: $($_.Exception.InnerException)" -ForegroundColor Red
    $_.ScriptStackTrace -split "`n" | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
}

Write-Host "`nTest completed!" -ForegroundColor Green