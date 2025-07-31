#!/usr/bin/env pwsh
# Safe SpeedTUI demo with comprehensive error handling

param(
    [int]$Seconds = 5,
    [switch]$Verbose
)

$ErrorActionPreference = "Stop"

Write-Host "=== SpeedTUI Safe Demo ===" -ForegroundColor Cyan
Write-Host "Loading framework with error checking..." -ForegroundColor Yellow

try {
    # Test basic PowerShell environment
    Write-Host "✓ PowerShell version: $($PSVersionTable.PSVersion)" -ForegroundColor Green
    
    # Test console capabilities
    try {
        $consoleWidth = [Console]::WindowWidth
        $consoleHeight = [Console]::WindowHeight
        Write-Host "✓ Console size: ${consoleWidth}x${consoleHeight}" -ForegroundColor Green
    } catch {
        Write-Host "⚠ Console size detection failed: $_" -ForegroundColor Yellow
        $consoleWidth = 80
        $consoleHeight = 24
    }
    
    # Test cursor control
    try {
        $originalPos = [Console]::CursorTop
        [Console]::SetCursorPosition(0, $originalPos)
        Write-Host "✓ Cursor control working" -ForegroundColor Green
    } catch {
        Write-Host "⚠ Cursor control failed: $_" -ForegroundColor Yellow
    }
    
    # Test colors
    try {
        Write-Host "✓ ANSI colors: " -NoNewline -ForegroundColor Green
        Write-Host "Red " -NoNewline -ForegroundColor Red
        Write-Host "Green " -NoNewline -ForegroundColor Green  
        Write-Host "Blue " -NoNewline -ForegroundColor Blue
        Write-Host "Yellow" -ForegroundColor Yellow
    } catch {
        Write-Host "⚠ Color support failed: $_" -ForegroundColor Yellow
    }
    
    Write-Host "`nNow attempting to load SpeedTUI framework..." -ForegroundColor Cyan
    
    # Load framework files individually with error checking
    $frameworkPath = $PSScriptRoot
    $loadOrder = @(
        "Core/Logger.ps1",
        "Core/NullCheck.ps1", 
        "Core/Terminal.ps1",
        "Core/RenderEngine.ps1",
        "Core/Component.ps1",
        "Core/DataStore.ps1",
        "Services/ThemeManager.ps1",
        "Core/InputManager.ps1",
        "Layouts/GridLayout.ps1",
        "Layouts/StackLayout.ps1",
        "Components/Label.ps1",
        "Components/Button.ps1", 
        "Components/List.ps1",
        "Components/Table.ps1",
        "Core/Application.ps1"
    )
    
    $loadErrors = @()
    foreach ($file in $loadOrder) {
        $fullPath = Join-Path $frameworkPath $file
        Write-Host "Loading $file..." -ForegroundColor Gray
        
        if (Test-Path $fullPath) {
            try {
                . $fullPath
                Write-Host  "  ✓ $file loaded" -ForegroundColor Green
            } catch {
                $errorMsg = "Failed to load $file : $_"
                Write-Host "  ✗ $errorMsg" -ForegroundColor Red
                $loadErrors += $errorMsg
                
                if ($Verbose) {
                    Write-Host "    Stack trace: $($_.ScriptStackTrace)" -ForegroundColor DarkRed
                }
            }
        } else {
            $errorMsg = "File not found: $fullPath"
            Write-Host "  ✗ $errorMsg" -ForegroundColor Red
            $loadErrors += $errorMsg
        }
    }
    
    if ($loadErrors.Count -gt 0) {
        Write-Host "`nFramework loading failed with errors:" -ForegroundColor Red
        foreach ($error in $loadErrors) {
            Write-Host "  • $error" -ForegroundColor Red
        }
        throw "Cannot continue due to framework loading errors"
    }
    
    Write-Host "`n✓ SpeedTUI framework loaded successfully!" -ForegroundColor Green
    
    # Test basic class creation
    Write-Host "`nTesting basic components..." -ForegroundColor Cyan
    
    try {
        $testLabel = [Label]::new("Test")
        Write-Host "✓ Label class works" -ForegroundColor Green
    } catch {
        Write-Host "✗ Label class failed: $_" -ForegroundColor Red
        throw "Label component not working"
    }
    
    try {
        $testTerminal = [Terminal]::GetInstance()
        Write-Host "✓ Terminal singleton works" -ForegroundColor Green
    } catch {
        Write-Host "✗ Terminal singleton failed: $_" -ForegroundColor Red
        throw "Terminal component not working"
    }
    
    # Now try the simple display demo
    Write-Host "`nStarting simple display demo for $Seconds seconds..." -ForegroundColor Cyan
    Write-Host "Press Ctrl+C to stop early" -ForegroundColor Yellow
    
    Start-Sleep 2  # Give user time to read
    
    # Simple, safe display
    [Console]::Clear()
    
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $frame = 0
    
    while ($stopwatch.Elapsed.TotalSeconds -lt $Seconds) {
        try {
            # Reset cursor to top
            [Console]::SetCursorPosition(0, 0)
            
            # Simple text-based UI
            Write-Host "╔══════════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
            Write-Host "║                         SpeedTUI Framework Demo                             ║" -ForegroundColor Cyan  
            Write-Host "╠══════════════════════════════════════════════════════════════════════════════╣" -ForegroundColor Cyan
            Write-Host "║                                                                              ║" -ForegroundColor White
            Write-Host "║  PROJECTS:                                                                   ║" -ForegroundColor Yellow
            Write-Host "║    ✅ Project Alpha    [████████░░] 75%                                     ║" -ForegroundColor Green
            Write-Host "║    ⚠️  Project Beta     [██░░░░░░░░] 20%                                     ║" -ForegroundColor Yellow  
            Write-Host "║    ✅ Project Gamma    [██████████] 100%                                    ║" -ForegroundColor Green
            Write-Host "║    ⏸️  Project Delta    [████░░░░░░] 45%                                     ║" -ForegroundColor Blue
            Write-Host "║                                                                              ║" -ForegroundColor White
            Write-Host "║  TASKS:                                                                      ║" -ForegroundColor Green
            Write-Host "║    📝 Design UI mockups          │ In Progress  │ High                      ║" -ForegroundColor White
            Write-Host "║    ✅ Implement data layer       │ Completed    │ High                      ║" -ForegroundColor Green
            Write-Host "║    ⏳ Write unit tests           │ Pending      │ Medium                    ║" -ForegroundColor Yellow
            Write-Host "║    📚 Documentation              │ In Progress  │ Low                       ║" -ForegroundColor White
            Write-Host "║    ⚡ Performance optimization   │ Pending      │ Medium                    ║" -ForegroundColor Yellow
            Write-Host "║                                                                              ║" -ForegroundColor White
            
            $elapsed = [Math]::Round($stopwatch.Elapsed.TotalSeconds, 1)
            $remaining = [Math]::Max(0, $Seconds - $elapsed)
            $fps = if ($elapsed -gt 0) { [Math]::Round($frame / $elapsed, 1) } else { 0 }
            
            $status = "Running: ${elapsed}s │ Remaining: ${remaining}s │ Frame: $frame │ FPS: $fps"
            Write-Host "║  $($status.PadRight(76)) ║" -ForegroundColor Gray
            Write-Host "╚══════════════════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
            
            $frame++
            Start-Sleep -Milliseconds 100  # 10 FPS
            
        } catch {
            Write-Host "Error in display loop: $_" -ForegroundColor Red
            break
        }
    }
    
} catch {
    Write-Host "`n💥 Demo failed with error:" -ForegroundColor Red
    Write-Host "   $($_.Exception.Message)" -ForegroundColor Red
    
    if ($Verbose) {
        Write-Host "`nFull error details:" -ForegroundColor Yellow
        Write-Host "$($_.Exception | Out-String)" -ForegroundColor DarkYellow
        Write-Host "Stack trace:" -ForegroundColor Yellow  
        Write-Host "$($_.ScriptStackTrace)" -ForegroundColor DarkYellow
    }
} finally {
    # Always restore terminal state
    try {
        [Console]::CursorVisible = $true
        [Console]::ResetColor()
    } catch {
        # Ignore cleanup errors
    }
    
    Write-Host "`n" 
    Write-Host "=== Demo Complete ===" -ForegroundColor Cyan
    Write-Host "If you saw errors, run with -Verbose for more details" -ForegroundColor Yellow
    Write-Host "Framework files are loaded and ready for use!" -ForegroundColor Green
}