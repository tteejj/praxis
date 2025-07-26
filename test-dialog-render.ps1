#!/usr/bin/env pwsh

# Test dialog rendering to make sure no substring errors
Write-Host "Testing CommandEditDialog rendering..." -ForegroundColor Cyan

# Load framework
. "$PSScriptRoot/Start.ps1" -LoadOnly

try {
    Write-Host "Creating and initializing CommandEditDialog..." -ForegroundColor Yellow
    $dialog = [CommandEditDialog]::new()
    $dialog.Initialize($global:ServiceContainer)
    $dialog.SetBounds(0, 0, 120, 40)  # Give it plenty of space
    
    Write-Host "Testing OnBoundsChanged..." -ForegroundColor Yellow
    $dialog.OnBoundsChanged()
    Write-Host "  ✓ OnBoundsChanged successful" -ForegroundColor Green
    
    Write-Host "Testing SetCommand(null)..." -ForegroundColor Yellow
    $dialog.SetCommand($null)
    Write-Host "  ✓ SetCommand successful" -ForegroundColor Green
    
    Write-Host "Testing dialog rendering..." -ForegroundColor Yellow
    $rendered = $dialog.Render()
    if ($rendered -and $rendered.Length -gt 0) {
        Write-Host "  ✓ Dialog rendered successfully (length: $($rendered.Length))" -ForegroundColor Green
    } else {
        Write-Host "  ✗ Dialog render returned empty or null" -ForegroundColor Red
    }
    
    Write-Host "Testing with existing command..." -ForegroundColor Yellow
    $commandService = $global:ServiceContainer.GetService("CommandService")
    $commands = $commandService.GetAllCommands()
    if ($commands.Count -gt 0) {
        $dialog.SetCommand($commands[0])
        $rendered2 = $dialog.Render()
        if ($rendered2 -and $rendered2.Length -gt 0) {
            Write-Host "  ✓ Dialog with existing command rendered successfully" -ForegroundColor Green
        } else {
            Write-Host "  ✗ Dialog with existing command failed to render" -ForegroundColor Red
        }
    }
    
} catch {
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack: $($_.ScriptStackTrace)" -ForegroundColor DarkRed
}

Write-Host "`nTest completed!" -ForegroundColor Green