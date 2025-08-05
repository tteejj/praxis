#!/usr/bin/env pwsh
# Test VT100 consolidation - verify all needed methods work

Write-Host "Testing VT100 Consolidation..." -ForegroundColor Cyan
Write-Host ""

# Load dependencies first
try {
    . "$PSScriptRoot/TaskPro/Core/StringCache.ps1"
    Write-Host "✓ StringCache loaded" -ForegroundColor Green
} catch {
    Write-Host "✗ Failed to load StringCache: $_" -ForegroundColor Red
    exit 1
}

# Load consolidated VT100
try {
    . "$PSScriptRoot/TaskPro/Components/Shared/VT100.ps1"
    Write-Host "✓ VT100 loaded successfully" -ForegroundColor Green
} catch {
    Write-Host "✗ Failed to load VT100: $_" -ForegroundColor Red
    exit 1
}

# Test basic methods
Write-Host "Testing basic methods..." -ForegroundColor Yellow

$tests = @(
    # Cursor movement
    @{ Method = "MoveTo"; Args = @(10, 5); Expected = "`e[5;10H" }
    @{ Method = "Clear"; Args = @(); Expected = "`e[2J" }
    @{ Method = "ClearLine"; Args = @(); Expected = "`e[2K" }
    
    # Colors needed by components
    @{ Method = "Red"; Args = @(); Expected = "`e[91m" }
    @{ Method = "Green"; Args = @(); Expected = "`e[92m" }
    @{ Method = "Yellow"; Args = @(); Expected = "`e[93m" }
    @{ Method = "Gray"; Args = @(); Expected = "`e[90m" }
    @{ Method = "Reverse"; Args = @(); Expected = "`e[7m" }
    @{ Method = "Reset"; Args = @(); Expected = "`e[0m" }
    @{ Method = "Bold"; Args = @(); Expected = "`e[1m" }
    
    # Box drawing needed by components
    @{ Method = "BoxTopLeft"; Args = @(); Expected = "┌" }
    @{ Method = "BoxTopRight"; Args = @(); Expected = "┐" }
    @{ Method = "BoxBottomLeft"; Args = @(); Expected = "└" }
    @{ Method = "BoxBottomRight"; Args = @(); Expected = "┘" }
    @{ Method = "BoxHorizontal"; Args = @(); Expected = "─" }
    @{ Method = "BoxVertical"; Args = @(); Expected = "│" }
    @{ Method = "BoxTeeRight"; Args = @(); Expected = "├" }
    @{ Method = "BoxTeeLeft"; Args = @(); Expected = "┤" }
)

$passed = 0
$failed = 0

foreach ($test in $tests) {
    try {
        if ($test.Args.Count -eq 0) {
            $result = [VT]::($test.Method).Invoke()
        } else {
            $result = [VT]::($test.Method).Invoke($test.Args)
        }
        
        if ($result -eq $test.Expected) {
            Write-Host "  ✓ $($test.Method)" -ForegroundColor Green
            $passed++
        } else {
            Write-Host "  ✗ $($test.Method): Expected '$($test.Expected)', got '$result'" -ForegroundColor Red
            $failed++
        }
    } catch {
        Write-Host "  ✗ $($test.Method): Exception - $_" -ForegroundColor Red
        $failed++
    }
}

Write-Host ""
Write-Host "Test Results:" -ForegroundColor Cyan
Write-Host "  Passed: $passed" -ForegroundColor Green
Write-Host "  Failed: $failed" -ForegroundColor Red

if ($failed -eq 0) {
    Write-Host ""
    Write-Host "✓ All VT100 methods working correctly!" -ForegroundColor Green
    Write-Host "VT100 consolidation successful." -ForegroundColor Cyan
    exit 0
} else {
    Write-Host ""
    Write-Host "✗ Some VT100 methods failed. Check implementation." -ForegroundColor Red
    exit 1
}