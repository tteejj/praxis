#!/usr/bin/env pwsh

# TimeTrackerFixed.ps1 - Fixed version with better input handling
# Based on the TimeTracker.ps1 but with console input issues resolved

# Set error handling
$ErrorActionPreference = "Stop"

# Global debug flag
$global:Debug = $true

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

# Initialize global logger (console + file logger)
$logFile = "$PSScriptRoot/Data/timetracker.log"
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
    Warn = { 
        param($message) 
        $logEntry = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [WARN] $message"
        Write-Host $logEntry -ForegroundColor Magenta
        Add-Content -Path $logFile -Value $logEntry -ErrorAction SilentlyContinue
    }
}

function Test-ConsoleAvailable {
    try {
        # Test if we can use Console.ReadKey
        $null = [Console]::KeyAvailable
        return $true
    } catch {
        return $false
    }
}

function Get-InputKey {
    if (Test-ConsoleAvailable) {
        & $global:Logger.Debug "Using Console.ReadKey for input"
        return [Console]::ReadKey($true)
    } else {
        & $global:Logger.Debug "Console not available, using Read-Host fallback"
        Write-Host "Enter command (↑=u ↓=d ←=l →=r E=e A=a D=d C=c Q=q): " -NoNewline
        $input = Read-Host
        
        if ([string]::IsNullOrEmpty($input)) {
            $input = "q"  # Default to quit if empty
        }
        
        # Convert string input to mock ConsoleKeyInfo
        $key = switch ($input.ToLower()) {
            'u' { [System.ConsoleKey]::UpArrow }
            'd' { [System.ConsoleKey]::DownArrow }
            'l' { [System.ConsoleKey]::LeftArrow }
            'r' { [System.ConsoleKey]::RightArrow }
            'e' { [System.ConsoleKey]::E }
            'a' { [System.ConsoleKey]::A }
            'del' { [System.ConsoleKey]::D }
            'c' { [System.ConsoleKey]::C }
            'q' { [System.ConsoleKey]::Q }
            default { [System.ConsoleKey]::Escape }
        }
        
        $keyChar = if ($input.Length -gt 0) { $input[0] } else { 'q' }
        
        # Create a mock ConsoleKeyInfo object
        return [System.ConsoleKeyInfo]::new($keyChar, $key, $false, $false, $false)
    }
}

function Initialize-TimeTracker {
    & $global:Logger.Info "Initializing TimeTracker application"
    
    # Clear screen and hide cursor initially (only if console is available)
    if (Test-ConsoleAvailable) {
        [Console]::Clear()
        [Console]::CursorVisible = $false
        & $global:Logger.Debug "Console cleared and cursor hidden"
    } else {
        Clear-Host
        & $global:Logger.Debug "Used Clear-Host instead of Console.Clear"
    }
    
    # Create the time list screen
    & $global:Logger.Debug "Creating TimeListScreen"
    $timeScreen = [TimeListScreen]::new()
    
    $width = if (Test-ConsoleAvailable) { [Console]::WindowWidth } else { 80 }
    $height = if (Test-ConsoleAvailable) { [Console]::WindowHeight } else { 24 }
    
    & $global:Logger.Debug "Initializing screen with dimensions: $width x $height"
    $timeScreen.Initialize($width, $height)
    
    & $global:Logger.Info "TimeTracker initialization complete"
    return $timeScreen
}

function Start-TimeTracker {
    param($screen)
    
    & $global:Logger.Info "Starting TimeTracker main loop"
    
    try {
        # Main application loop
        while ($true) {
            # Render screen only if console is available
            if (Test-ConsoleAvailable) {
                $output = $screen.Render()
                [Console]::SetCursorPosition(0, 0)
                Write-Host -NoNewline $output
            } else {
                # Simplified output for non-console environments
                Clear-Host
                Write-Host "TimeTracker - Current Week Entries:" -ForegroundColor Cyan
                $entries = $screen.TimeService.GetCurrentWeekEntries()
                foreach ($entry in $entries) {
                    Write-Host "$($entry.ProjectCode) - $($entry.Description) [Total: $($entry.Total)]" -ForegroundColor White
                }
                Write-Host "`nCommands: A=Add, E=Edit, D=Delete, Q=Quit" -ForegroundColor Yellow
            }
            
            # Handle input
            $key = Get-InputKey
            & $global:Logger.Debug "Main loop: Key received, calling HandleInput"
            if (-not $screen.HandleInput($key)) {
                & $global:Logger.Info "Exit requested from HandleInput"
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
        & $global:Logger.Info "Cleaning up and closing TimeTracker"
        if (Test-ConsoleAvailable) {
            [Console]::CursorVisible = $true
            [Console]::Clear()
        } else {
            Clear-Host
        }
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