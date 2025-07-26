#!/usr/bin/env pwsh

Write-Host "Testing tab 7 bounds by starting PRAXIS, going to tab 7, and checking logs..." -ForegroundColor Cyan

# Start PRAXIS in background
$job = Start-Job -ScriptBlock {
    Set-Location $using:PSScriptRoot
    . "./Start.ps1" -Debug
}

# Wait for startup
Start-Sleep -Seconds 3

# Try to send key 7 to switch to tab 7 (this might not work reliably)
Write-Host "PRAXIS should be running. Manually press '7' to go to tab 7, then 'q' to quit." -ForegroundColor Yellow
Write-Host "Press Enter here when you've tested tab 7..." -ForegroundColor Green
Read-Host

# Stop the job
Stop-Job $job -Force
Remove-Job $job -Force

# Check recent logs for VisualMacroFactory
Write-Host "`nRecent VisualMacroFactory log entries:" -ForegroundColor Cyan
$logContent = Get-Content "/home/teej/projects/github/praxis/_Logs/praxis.log" -Tail 100
$relevantEntries = $logContent | Where-Object { $_ -match "VisualMacroFactory|LoadAvailable|ComponentLibrary|OnBoundsChanged.*Width" }

if ($relevantEntries) {
    $relevantEntries | ForEach-Object { Write-Host $_ -ForegroundColor Yellow }
} else {
    Write-Host "No VisualMacroFactory entries found in recent logs" -ForegroundColor Red
}

Write-Host "`nTest completed!" -ForegroundColor Cyan