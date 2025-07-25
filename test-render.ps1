#!/usr/bin/env pwsh

# Test TimeEntryScreen rendering

. ./Start.ps1 -Test 2>$null

try {
    Write-Host "Creating TimeEntryScreen..." -ForegroundColor Cyan
    $screen = [TimeEntryScreen]::new()
    $screen.Initialize($global:ServiceContainer)
    $screen.SetBounds(0, 0, 120, 40)
    
    Write-Host "TimeEntryScreen created. Testing render..." -ForegroundColor Cyan
    
    # Force invalidation
    $screen.Invalidate()
    
    # Get render output
    $rendered = $screen.Render()
    
    Write-Host "`nRender output length: $($rendered.Length)" -ForegroundColor Yellow
    
    if ($rendered.Length -gt 0) {
        Write-Host "`nFirst 500 characters of render output:" -ForegroundColor Green
        Write-Host ($rendered.Substring(0, [Math]::Min(500, $rendered.Length)))
        
        # Check if it contains expected content
        if ($rendered -match "Time Entry") {
            Write-Host "`n✓ Contains 'Time Entry' text" -ForegroundColor Green
        } else {
            Write-Host "`n✗ Does NOT contain 'Time Entry' text" -ForegroundColor Red
        }
        
        if ($rendered -match "Mon|Tue|Wed") {
            Write-Host "✓ Contains day headers" -ForegroundColor Green
        } else {
            Write-Host "✗ Does NOT contain day headers" -ForegroundColor Red
        }
    } else {
        Write-Host "`n✗ Render output is empty!" -ForegroundColor Red
    }
    
    # Check children
    Write-Host "`nChildren count: $($screen.Children.Count)" -ForegroundColor Cyan
    foreach ($child in $screen.Children) {
        Write-Host "  - $($child.GetType().Name): Visible=$($child.Visible), Bounds=($($child.X),$($child.Y),$($child.Width),$($child.Height))" -ForegroundColor White
    }
    
} catch {
    Write-Host "`nERROR: $_" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
}