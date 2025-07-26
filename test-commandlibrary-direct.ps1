#!/usr/bin/env pwsh

# Test CommandLibraryScreen directly
Write-Host "Testing CommandLibraryScreen directly..." -ForegroundColor Cyan

# Load framework
. "$PSScriptRoot/Start.ps1" -LoadOnly

try {
    Write-Host "Creating CommandLibraryScreen..." -ForegroundColor Yellow
    $screen = [CommandLibraryScreen]::new()
    
    Write-Host "Initializing screen..." -ForegroundColor Yellow  
    $screen.Initialize($global:ServiceContainer)
    
    Write-Host "Screen created successfully" -ForegroundColor Green
    Write-Host "  CommandList exists: $($null -ne $screen.CommandList)" -ForegroundColor Cyan
    
    if ($screen.CommandList) {
        Write-Host "  CommandList Items count: $($screen.CommandList.Items.Count)" -ForegroundColor Cyan
        Write-Host "  CommandList _filteredItems count: $($screen.CommandList._filteredItems.Count)" -ForegroundColor Cyan
        
        Write-Host "  Commands from service:" -ForegroundColor Cyan
        $commands = $screen.CommandService.GetAllCommands()
        Write-Host "    CommandService.GetAllCommands() count: $($commands.Count)" -ForegroundColor Cyan
        
        foreach ($cmd in $commands) {
            Write-Host "    - $($cmd.Title): $($cmd.Description)" -ForegroundColor DarkGray
        }
    }
    
    # Test bounds
    Write-Host "Setting test bounds..." -ForegroundColor Yellow
    $screen.SetBounds(0, 0, 80, 20)
    Write-Host "  Screen bounds: $($screen.X),$($screen.Y) - $($screen.Width)x$($screen.Height)" -ForegroundColor Cyan
    
    if ($screen.CommandList) {
        Write-Host "  CommandList bounds: $($screen.CommandList.X),$($screen.CommandList.Y) - $($screen.CommandList.Width)x$($screen.CommandList.Height)" -ForegroundColor Cyan
    }
    
} catch {
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack: $($_.ScriptStackTrace)" -ForegroundColor DarkRed
}

Write-Host "Test completed!" -ForegroundColor Green