#!/usr/bin/env pwsh
# Simple SpeedTUI demo with static positioning

param([int]$Seconds = 10)

# Load the framework (without running example)
. "$PSScriptRoot/Start.ps1"

Write-Host "Running SpeedTUI Simple Demo for $Seconds seconds..." -ForegroundColor Cyan
Write-Host ""

[Console]::Clear()
[Console]::CursorVisible = $false

try {
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $frameCount = 0
    
    while ($stopwatch.Elapsed.TotalSeconds -lt $Seconds) {
        [Console]::SetCursorPosition(0, 0)
        
        # Header
        [Console]::Write("`e[1;36m=== SpeedTUI Framework Demo ===`e[0m")
        [Console]::SetCursorPosition(0, 1)
        [Console]::Write("`e[90m" + ("─" * 80) + "`e[0m")
        
        # Projects section
        [Console]::SetCursorPosition(0, 3)
        [Console]::Write("`e[1;33mPROJECTS:`e[0m")
        [Console]::SetCursorPosition(2, 4)
        [Console]::Write("`e[32m✓ Project Alpha    [████████░░] 75%`e[0m")
        [Console]::SetCursorPosition(2, 5)
        [Console]::Write("`e[33m⚠ Project Beta     [██░░░░░░░░] 20%`e[0m")
        [Console]::SetCursorPosition(2, 6)
        [Console]::Write("`e[32m✓ Project Gamma    [██████████] 100%`e[0m")
        [Console]::SetCursorPosition(2, 7)
        [Console]::Write("`e[34m⏸ Project Delta    [████░░░░░░] 45%`e[0m")
        
        # Separator
        [Console]::SetCursorPosition(0, 9)
        [Console]::Write("`e[90m" + ("─" * 80) + "`e[0m")
        
        # Tasks section
        [Console]::SetCursorPosition(0, 11)
        [Console]::Write("`e[1;32mTASKS:`e[0m")
        [Console]::SetCursorPosition(2, 12)
        [Console]::Write("`e[37mDesign UI mockups          | In Progress  | High`e[0m")
        [Console]::SetCursorPosition(2, 13)
        [Console]::Write("`e[32mImplement data layer       | Completed    | High`e[0m")
        [Console]::SetCursorPosition(2, 14)
        [Console]::Write("`e[33mWrite unit tests           | Pending      | Medium`e[0m")
        [Console]::SetCursorPosition(2, 15)
        [Console]::Write("`e[37mDocumentation              | In Progress  | Low`e[0m")
        [Console]::SetCursorPosition(2, 16)
        [Console]::Write("`e[33mPerformance optimization   | Pending      | Medium`e[0m")
        
        # Status bar with live updates
        $elapsed = [Math]::Round($stopwatch.Elapsed.TotalSeconds, 1)
        $remaining = [Math]::Round($Seconds - $stopwatch.Elapsed.TotalSeconds, 1)
        $fps = if ($elapsed -gt 0) { [Math]::Round($frameCount / $elapsed, 1) } else { 0 }
        
        [Console]::SetCursorPosition(0, 20)
        [Console]::Write("`e[90m" + ("─" * 80) + "`e[0m")
        [Console]::SetCursorPosition(0, 21)
        [Console]::Write("`e[90mRunning: ${elapsed}s | Remaining: ${remaining}s | Frame: $frameCount | FPS: $fps | Ctrl+C to exit`e[0m")
        
        # Frame timing
        [System.Threading.Thread]::Sleep(50)  # ~20 FPS
        $frameCount++
        
        # Check for input (non-blocking)
        if ([Console]::KeyAvailable) {
            $key = [Console]::ReadKey($true)
            if ($key.Key -eq [System.ConsoleKey]::Q -and $key.Modifiers -eq [System.ConsoleModifiers]::Control) {
                break
            }
        }
    }
    
} finally {
    [Console]::CursorVisible = $true
    [Console]::SetCursorPosition(0, 23)
    Write-Host ""
    Write-Host "SpeedTUI Demo completed! Framework is working correctly." -ForegroundColor Green
    Write-Host "Total frames rendered: $frameCount" -ForegroundColor Cyan
}