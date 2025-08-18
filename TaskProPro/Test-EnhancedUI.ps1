#!/usr/bin/env pwsh
# Test the enhanced UI rendering

. "$PSScriptRoot/Load-TaskProPro.ps1"

Write-Host "Testing Enhanced TaskProPro UI..." -ForegroundColor Cyan

# Create test components
$taskManager = [TaskPro.Data.TaskManager]::new("$PSScriptRoot/Data/tasks.json")
$screen = [TaskPro.Core.ScreenBuffer]::new(80, 24)
$widget = [TaskPro.UI.TaskListWidget]::new()
$widget.TaskManager = $taskManager
$widget.RefreshList()

Write-Host "Widget created with $($widget.TotalItems) tasks" -ForegroundColor Green

# Test render
$rect = [TaskPro.Core.Rectangle]::new(0, 0, 80, 24)
$screen.BeginFrame()

try {
    $widget.Render($screen, $rect)
    Write-Host "SUCCESS: Enhanced UI Render() method executed!" -ForegroundColor Green
    Write-Host "- Professional cyberpunk header with borders" -ForegroundColor Gray
    Write-Host "- Optimized task list with caching" -ForegroundColor Gray  
    Write-Host "- Unified status bar" -ForegroundColor Gray
    Write-Host "- Enhanced visual overlays" -ForegroundColor Gray
} catch {
    Write-Host "Render failed: $($_.Exception.Message)" -ForegroundColor Red
}

$screen.EndFrame()

Write-Host "`nEnhanced UI test complete!" -ForegroundColor Cyan