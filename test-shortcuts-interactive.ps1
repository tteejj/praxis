#!/usr/bin/env pwsh
# Interactive test to debug shortcuts

Write-Host "`nPRAXIS Shortcut Debugging" -ForegroundColor Cyan
Write-Host "========================" -ForegroundColor Cyan
Write-Host @"
This will run PRAXIS and monitor the log for shortcut-related messages.

Instructions:
1. Navigate to Projects screen (screen 1)
2. Press 'e' or 'd' keys
3. Watch this window for debug output
4. Press Ctrl+C in this window to stop monitoring

"@ -ForegroundColor Yellow

# Clear the log first
if (Test-Path "_Logs/praxis.log") {
    Clear-Content "_Logs/praxis.log"
}

# Start PRAXIS in debug mode in background
$praxis = Start-Process pwsh -ArgumentList "-File", "Start.ps1", "-Debug" -PassThru

Write-Host "PRAXIS started (PID: $($praxis.Id)). Monitoring log..." -ForegroundColor Green
Write-Host "Press Ctrl+C to stop monitoring" -ForegroundColor Gray
Write-Host ""

# Monitor the log file
try {
    Get-Content "_Logs/praxis.log" -Wait | Where-Object {
        $_ -match "Shortcut|RegisterShortcuts|HandleKeyPress|Key pressed|OnActivated" -or
        $_ -match "Key=E|Char='e'|Key=D|Char='d'"
    } | ForEach-Object {
        if ($_ -match "ERROR") {
            Write-Host $_ -ForegroundColor Red
        } elseif ($_ -match "RegisterShortcuts|OnActivated") {
            Write-Host $_ -ForegroundColor Cyan
        } elseif ($_ -match "Key pressed|HandleKeyPress") {
            Write-Host $_ -ForegroundColor Yellow
        } elseif ($_ -match "Executing shortcut|Key handled") {
            Write-Host $_ -ForegroundColor Green
        } else {
            Write-Host $_ -ForegroundColor Gray
        }
    }
}
finally {
    if (-not $praxis.HasExited) {
        Write-Host "`nStopping PRAXIS..." -ForegroundColor Yellow
        $praxis.Kill()
    }
}