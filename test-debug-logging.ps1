#!/usr/bin/env pwsh
# Test debug logging functionality

param(
    [switch]$Debug
)

# Set debug mode FIRST
if ($Debug) {
    $global:PraxisDebug = $true
    Write-Host "Debug mode enabled - global:PraxisDebug = $global:PraxisDebug" -ForegroundColor Green
}

# Set up paths
$script:PraxisRoot = $PSScriptRoot
$global:PraxisRoot = $PSScriptRoot
Set-Location $script:PraxisRoot

# Load Logger
. ./Services/Logger.ps1

# Create logger and verify debug mode
$logger = [Logger]::new()
Write-Host "`nLogger created:" -ForegroundColor Cyan
Write-Host "  MinimumLevel: $($logger.MinimumLevel)" -ForegroundColor $(if ($logger.MinimumLevel -eq "Debug") { "Green" } else { "Red" })
Write-Host "  LogPath: $($logger.LogPath)" -ForegroundColor Gray

# Test different log levels
Write-Host "`nTesting log levels:" -ForegroundColor Cyan
$logger.Trace("This is a TRACE message - should only appear if level is Trace")
$logger.Debug("This is a DEBUG message - should appear if -Debug flag was used")
$logger.Info("This is an INFO message - should always appear")
$logger.Warning("This is a WARNING message - should always appear")
$logger.Error("This is an ERROR message - should always appear")

# Flush and show log
$logger.Flush()

Write-Host "`nLast 10 lines of log:" -ForegroundColor Cyan
Get-Content $logger.LogPath -Tail 10 | ForEach-Object { 
    if ($_ -match "DEBUG") {
        Write-Host "  $_" -ForegroundColor Green
    } elseif ($_ -match "ERROR") {
        Write-Host "  $_" -ForegroundColor Red
    } elseif ($_ -match "WARNING") {
        Write-Host "  $_" -ForegroundColor Yellow
    } else {
        Write-Host "  $_" -ForegroundColor Gray
    }
}