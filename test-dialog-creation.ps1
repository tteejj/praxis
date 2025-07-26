#!/usr/bin/env pwsh

# Test dialog creation and initialization
Write-Host "Testing dialog creation and initialization..." -ForegroundColor Cyan

# Load framework
. "$PSScriptRoot/Start.ps1" -LoadOnly

try {
    Write-Host "Creating CommandEditDialog..." -ForegroundColor Yellow
    $dialog = [CommandEditDialog]::new()
    $dialog.Initialize($global:ServiceContainer)
    $dialog.SetBounds(0, 0, 80, 25)
    
    Write-Host "  ✓ CommandEditDialog created and initialized successfully" -ForegroundColor Green
    
    # Test SetCommand
    Write-Host "`nTesting SetCommand with null (new command)..." -ForegroundColor Yellow
    try {
        $dialog.SetCommand($null)
        Write-Host "  ✓ SetCommand(null) successful" -ForegroundColor Green
    } catch {
        Write-Host "  ✗ SetCommand(null) failed: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    # Test with existing command
    Write-Host "`nTesting SetCommand with existing command..." -ForegroundColor Yellow
    $commandService = $global:ServiceContainer.GetService("CommandService")
    $commands = $commandService.GetAllCommands()
    if ($commands.Count -gt 0) {
        try {
            $dialog.SetCommand($commands[0])
            Write-Host "  ✓ SetCommand(existing) successful" -ForegroundColor Green
        } catch {
            Write-Host "  ✗ SetCommand(existing) failed: $($_.Exception.Message)" -ForegroundColor Red
        }
    } else {
        Write-Host "  - No commands available to test with" -ForegroundColor Yellow
    }
    
} catch {
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack: $($_.ScriptStackTrace)" -ForegroundColor DarkRed
}

Write-Host "`nTest completed!" -ForegroundColor Green