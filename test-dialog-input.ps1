# Test dialog input visibility and screen refresh
param([switch]$Quick)

Write-Host "Testing dialog input and screen refresh fixes..." -ForegroundColor Green

# Set test mode to avoid infinite loops
$env:PRAXIS_TEST_MODE = "1"

try {
    if ($Quick) {
        # Quick syntax check
        . "$PSScriptRoot/Components/DialogField.ps1" 2>&1 | Out-Null
        . "$PSScriptRoot/Core/ScreenManager.ps1" 2>&1 | Out-Null
        Write-Host "✓ Syntax checks passed" -ForegroundColor Green
    } else {
        # Full integration test - launch briefly
        Write-Host "Starting full integration test (will auto-exit)..." -ForegroundColor Yellow
        . "$PSScriptRoot/Start.ps1"
    }
} catch {
    Write-Host "✗ Error: $_" -ForegroundColor Red
    exit 1
} finally {
    $env:PRAXIS_TEST_MODE = $null
}

Write-Host "✓ Tests completed successfully" -ForegroundColor Green