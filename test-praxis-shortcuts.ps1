#!/usr/bin/env pwsh
# Test PRAXIS with shortcut debugging

param(
    [switch]$MonitorOnly
)

if (-not $MonitorOnly) {
    Write-Host "`nPRAXIS Shortcut Test" -ForegroundColor Cyan
    Write-Host "===================" -ForegroundColor Cyan
    Write-Host @"
This test will:
1. Clear the log
2. Start PRAXIS in debug mode  
3. Monitor shortcut-related log entries

Instructions:
- Navigate to Projects screen (1)
- Press 'e' or 'd' 
- Watch for debug output

"@ -ForegroundColor Yellow

    # Clear log
    if (Test-Path "_Logs/praxis.log") {
        Clear-Content "_Logs/praxis.log"
        Write-Host "Log cleared" -ForegroundColor Green
    }

    # Start monitoring in separate window
    Start-Process pwsh -ArgumentList "-File", "$PSCommandPath", "-MonitorOnly" -WindowStyle Normal

    # Wait a moment for monitor to start
    Start-Sleep -Seconds 1

    # Start PRAXIS
    Write-Host "Starting PRAXIS..." -ForegroundColor Cyan
    pwsh -File Start.ps1 -Debug
}
else {
    # Monitor mode
    Write-Host "PRAXIS Log Monitor - Shortcuts" -ForegroundColor Cyan
    Write-Host "==============================" -ForegroundColor Cyan
    Write-Host "Monitoring for shortcut activity..." -ForegroundColor Yellow
    Write-Host ""

    try {
        Get-Content "_Logs/praxis.log" -Wait | ForEach-Object {
            # Filter for relevant messages
            if ($_ -match "Shortcut|RegisterShortcuts|UnregisterShortcut|HandleKeyPress|OnActivated|Key pressed" -or
                $_ -match "Key=E|Char='e'|Key=D|Char='d'|Matches|Executing") {
                
                # Color coding
                if ($_ -match "ERROR") {
                    Write-Host $_ -ForegroundColor Red
                }
                elseif ($_ -match "UnregisterShortcut") {
                    Write-Host $_ -ForegroundColor Magenta
                }
                elseif ($_ -match "RegisterShortcuts|Registered shortcut") {
                    Write-Host $_ -ForegroundColor Cyan
                }
                elseif ($_ -match "OnActivated") {
                    Write-Host $_ -ForegroundColor Blue
                }
                elseif ($_ -match "Key pressed|HandleKeyPress|Calling ShortcutManager") {
                    Write-Host $_ -ForegroundColor Yellow
                }
                elseif ($_ -match "Matches|Matched") {
                    Write-Host $_ -ForegroundColor Green
                }
                elseif ($_ -match "Executing shortcut|Key handled by ShortcutManager|EDIT ACTION") {
                    Write-Host $_ -ForegroundColor Green -BackgroundColor DarkGreen
                }
                elseif ($_ -match "NOT handled|Skipped") {
                    Write-Host $_ -ForegroundColor Red
                }
                else {
                    Write-Host $_ -ForegroundColor Gray
                }
            }
        }
    }
    catch {
        Write-Host "Monitor stopped" -ForegroundColor Red
    }
}