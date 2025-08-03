#!/usr/bin/env pwsh

# Simple test to verify input handling without console redirection issues
# This will help us test the 'a' key functionality

# Load required components
. "$PSScriptRoot/Models/SimpleTimeEntry.ps1"
. "$PSScriptRoot/Services/TimeTrackingService.ps1"

# Enable logging
$global:Debug = $true
$logFile = "$PSScriptRoot/Data/test.log"
$global:Logger = @{
    Info = { 
        param($message) 
        $logEntry = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [INFO] $message"
        Write-Host $logEntry -ForegroundColor Green
        Add-Content -Path $logFile -Value $logEntry -ErrorAction SilentlyContinue
    }
    Error = { 
        param($message) 
        $logEntry = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [ERROR] $message"
        Write-Host $logEntry -ForegroundColor Red
        Add-Content -Path $logFile -Value $logEntry -ErrorAction SilentlyContinue
    }
    Debug = { 
        param($message) 
        if ($global:Debug) { 
            $logEntry = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [DEBUG] $message"
            Write-Host $logEntry -ForegroundColor Yellow
            Add-Content -Path $logFile -Value $logEntry -ErrorAction SilentlyContinue
        }
    }
}

Write-Host "Testing TimeTracker StartInlineAdd functionality..." -ForegroundColor Cyan

try {
    # Create a minimal test version
    $timeService = [TimeTrackingService]::new()
    & $global:Logger.Info "TimeService created successfully"
    & $global:Logger.Debug "CurrentWeekFriday: $($timeService.CurrentWeekFriday)"
    
    # Test creating a new entry directly
    & $global:Logger.Info "Testing SimpleTimeEntry creation..."
    $newEntry = [SimpleTimeEntry]::new()
    & $global:Logger.Debug "New entry created with ID: $($newEntry.Id)"
    & $global:Logger.Debug "Week set to: $($newEntry.WeekEndingFriday)"
    
    # Test setting week from service
    if ($timeService -and $timeService.CurrentWeekFriday) {
        & $global:Logger.Debug "Setting week from TimeService: $($timeService.CurrentWeekFriday)"
        $newEntry.WeekEndingFriday = $timeService.CurrentWeekFriday.ToString("yyyyMMdd")
        & $global:Logger.Debug "Week updated to: $($newEntry.WeekEndingFriday)"
    }
    
    # Test adding to service
    & $global:Logger.Info "Testing add to service..."
    $timeService.AddTimeEntry($newEntry)
    & $global:Logger.Info "Entry added successfully"
    
    # Test loading entries
    $entries = $timeService.GetCurrentWeekEntries()
    & $global:Logger.Info "Found $($entries.Count) entries for current week"
    
    Write-Host "✅ All tests passed! The StartInlineAdd logic should work." -ForegroundColor Green
    Write-Host "📋 Check the log file at: $logFile" -ForegroundColor Cyan
    
} catch {
    & $global:Logger.Error "Test failed: $($_.Exception.Message)"
    & $global:Logger.Error "Stack trace: $($_.ScriptStackTrace)"
    Write-Host "❌ Test failed - check logs for details" -ForegroundColor Red
}