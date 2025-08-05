#!/usr/bin/env pwsh
# test-f2-switch.ps1 - Test F2 CommandLibrary switching from SimpleTaskPro

Write-Host "Testing F2 CommandLibrary switching..." -ForegroundColor Cyan
Write-Host ""

try {
    # Load dependencies in correct order
    . "./TaskPro/Core/StringCache.ps1"
    . "./TaskPro/Components/Shared/VT100.ps1" 
    . "./TaskPro/Services/PraxisDataService.ps1"
    . "./TaskPro/Services/AppManager.ps1"
    
    # Initialize PraxisDataService first
    if (-not [PraxisDataService]::IsInitialized) {
        [PraxisDataService]::Initialize('./_ProjectData')
    }
    
    # Initialize AppManager
    [AppManager]::Initialize('./TaskPro')
    Write-Host "✓ AppManager initialized" -ForegroundColor Green
    
    # Test getting CommandLibrary screen (simulates F2 press)
    Write-Host ""
    Write-Host "Testing F2 CommandLibrary screen loading..." -ForegroundColor Yellow
    $commandScreen = [AppManager]::GetScreen("CommandLibrary")
    
    if ($commandScreen) {
        Write-Host "✓ CommandLibrary screen loaded successfully: $($commandScreen.GetType().Name)" -ForegroundColor Green
        
        # Test screen initialization
        $commandScreen.Initialize(80, 24)
        Write-Host "✓ CommandLibrary screen initialized" -ForegroundColor Green
        
        # Test screen rendering (just to make sure it doesn't crash)
        try {
            $output = $commandScreen.Render()
            if ($output) {
                Write-Host "✓ CommandLibrary screen renders successfully ($($output.Length) chars)" -ForegroundColor Green
            } else {
                Write-Host "⚠ CommandLibrary screen rendered empty output" -ForegroundColor Yellow
            }
        } catch {
            Write-Host "✗ CommandLibrary screen render failed: $_" -ForegroundColor Red
        }
    } else {
        Write-Host "✗ Failed to load CommandLibrary screen" -ForegroundColor Red
    }
    
    Write-Host ""
    Write-Host "🎉 F2 CommandLibrary switching test completed!" -ForegroundColor Green
    
} catch {
    Write-Host "✗ Test failed: $_" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor DarkGray
}