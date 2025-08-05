#!/usr/bin/env pwsh

# TimeTracker.ps1 - Standalone Time Tracking Application
# Based on the TaskPro inline editing approach

# Set error handling
$ErrorActionPreference = "Stop"

# Global debug flag
$global:Debug = $false

# Load required models and services
try {
    . "$PSScriptRoot/Models/SimpleTimeEntry.ps1"
    . "$PSScriptRoot/Services/TimeTrackingService.ps1"
    . "$PSScriptRoot/Core/VT100.ps1"
    . "$PSScriptRoot/Screens/TimeListScreen.ps1"
} catch {
    Write-Host "Error loading components: $_" -ForegroundColor Red
    exit 1
}

# Initialize minimal logger (file only for performance)
$logFile = "$PSScriptRoot/Data/timetracker.log"
$global:Logger = @{
    Info = { 
        param($message) 
        # File logging only for performance
        $logEntry = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [INFO] $message"
        Add-Content -Path $logFile -Value $logEntry -ErrorAction SilentlyContinue
    }
    Error = { 
        param($message) 
        # Show errors on console but also log to file
        $logEntry = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [ERROR] $message"
        Write-Host $logEntry -ForegroundColor Red
        Add-Content -Path $logFile -Value $logEntry -ErrorAction SilentlyContinue
    }
    Debug = { 
        param($message) 
        # File logging only, no console output for performance
        if ($global:Debug) { 
            $logEntry = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [DEBUG] $message"
            Add-Content -Path $logFile -Value $logEntry -ErrorAction SilentlyContinue
        }
    }
    Warn = { 
        param($message) 
        # File logging only for performance
        $logEntry = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [WARN] $message"
        Add-Content -Path $logFile -Value $logEntry -ErrorAction SilentlyContinue
    }
}

function Initialize-TimeTracker {
    # Clear screen and hide cursor initially
    [Console]::Clear()
    [Console]::CursorVisible = $false
    
    # Create the time list screen
    $timeScreen = [TimeListScreen]::new()
    $timeScreen.Initialize([Console]::WindowWidth, [Console]::WindowHeight)
    
    return $timeScreen
}

function Start-TimeTracker {
    param($screen)
    
    try {
        # Main application loop
        while ($true) {
            # Render screen
            $output = $screen.Render()
            [Console]::SetCursorPosition(0, 0)
            Write-Host -NoNewline $output
            
            # Handle input
            $key = [Console]::ReadKey($true)
            if (-not $screen.HandleInput($key)) {
                break  # Exit requested
            }
        }
    }
    catch {
        & $global:Logger.Error "Application error in main loop: $($_.Exception.Message)"
        & $global:Logger.Error "Stack trace: $($_.ScriptStackTrace)"
        Write-Host "Application error: $_" -ForegroundColor Red
    }
    finally {
        # Cleanup
        [Console]::CursorVisible = $true
        [Console]::Clear()
        Write-Host "TimeTracker closed." -ForegroundColor Green
    }
}

# Main execution
try {
    $screen = Initialize-TimeTracker
    Start-TimeTracker $screen
}
catch {
    Write-Host "Failed to start TimeTracker: $_" -ForegroundColor Red
    exit 1
}