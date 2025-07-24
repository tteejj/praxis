#!/usr/bin/env pwsh
# Debug script for shortcuts

param(
    [string]$LogPath = "_Logs/praxis.log"
)

Write-Host "Testing ShortcutManager Registration..." -ForegroundColor Cyan

# Watch the log file
if (Test-Path $LogPath) {
    Write-Host "Monitoring log file: $LogPath" -ForegroundColor Yellow
    Write-Host "Look for these patterns:" -ForegroundColor Gray
    Write-Host "  - 'Registered shortcut:' when screens activate" -ForegroundColor Gray
    Write-Host "  - 'ShortcutManager.HandleKeyPress:' when you press keys" -ForegroundColor Gray
    Write-Host "  - 'Found X matching shortcuts' to see if keys match" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Press Ctrl+C to stop monitoring" -ForegroundColor Yellow
    
    Get-Content $LogPath -Wait -Tail 50 | Where-Object { 
        $_ -match 'shortcut|HandleKeyPress|Registered|Screen.*activated'
    }
} else {
    Write-Host "Log file not found at: $LogPath" -ForegroundColor Red
}