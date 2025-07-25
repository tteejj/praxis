#!/usr/bin/env pwsh

# Test script to verify TimeEntryScreen loads properly

. ./Start.ps1 -Test

try {
    Write-Host "Testing TimeEntryScreen initialization..." -ForegroundColor Green
    
    # Create TimeEntryScreen
    $screen = [TimeEntryScreen]::new()
    Write-Host "✓ TimeEntryScreen created" -ForegroundColor Green
    
    # Initialize with services
    $screen.Initialize($global:ServiceContainer)
    Write-Host "✓ TimeEntryScreen initialized" -ForegroundColor Green
    
    # Set bounds
    $screen.SetBounds(0, 0, 120, 40)
    Write-Host "✓ Bounds set" -ForegroundColor Green
    
    # Check components
    Write-Host "`nComponents:" -ForegroundColor Cyan
    Write-Host "  - TimeGrid: $($screen.TimeGrid -ne $null)" -ForegroundColor White
    Write-Host "  - PrevWeekButton: $($screen.PrevWeekButton -ne $null)" -ForegroundColor White
    Write-Host "  - NextWeekButton: $($screen.NextWeekButton -ne $null)" -ForegroundColor White
    Write-Host "  - CurrentWeekButton: $($screen.CurrentWeekButton -ne $null)" -ForegroundColor White
    Write-Host "  - QuickEntryButton: $($screen.QuickEntryButton -ne $null)" -ForegroundColor White
    Write-Host "  - Children Count: $($screen.Children.Count)" -ForegroundColor White
    
    # Check services
    Write-Host "`nServices:" -ForegroundColor Cyan
    Write-Host "  - TimeService: $($screen.TimeService -ne $null)" -ForegroundColor White
    Write-Host "  - ProjectService: $($screen.ProjectService -ne $null)" -ForegroundColor White
    Write-Host "  - EventBus: $($screen.EventBus -ne $null)" -ForegroundColor White
    
    # Check grid items
    if ($screen.TimeGrid -and $screen.TimeGrid.Items) {
        Write-Host "`nTimeGrid Items: $($screen.TimeGrid.Items.Count)" -ForegroundColor Cyan
    }
    
    # Try to render
    Write-Host "`nAttempting render..." -ForegroundColor Yellow
    $rendered = $screen.Render()
    if ($rendered) {
        Write-Host "✓ Render successful (length: $($rendered.Length))" -ForegroundColor Green
    } else {
        Write-Host "✗ Render failed" -ForegroundColor Red
    }
    
    Write-Host "`nTimeEntryScreen test completed successfully!" -ForegroundColor Green
    
} catch {
    Write-Host "`nERROR: $_" -ForegroundColor Red
    Write-Host "Stack trace:" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
}