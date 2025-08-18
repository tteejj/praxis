#!/usr/bin/env pwsh
# test-border-fix.ps1 - Test the fixed border rendering

param([switch]$Debug)
$global:Debug = $Debug.IsPresent

Write-Host "Testing FIXED BorderDrawingSystem..." -ForegroundColor Cyan

try {
    # Load DLL
    $dllPath = "$PSScriptRoot/TaskPro.dll"
    Add-Type -Path $dllPath
    Write-Host "✓ DLL loaded" -ForegroundColor Green
    
    # Create border system
    $borderSystem = [TaskPro.Core.BorderDrawingSystem]::new()
    $borderSystem.Initialize(50, 10)
    
    # Create column manager
    $columnManager = [TaskPro.UI.TaskListColumnManager]::new()
    $columnManager.CalculateLayout(50)
    
    Write-Host "✓ Components created" -ForegroundColor Green
    
    # Test the fixed content rendering
    Write-Host "Testing FIXED content rendering..." -ForegroundColor Yellow
    
    # Get header content WITHOUT separators
    $headerContent = $columnManager.GetHeaderRowWithoutSeparators()
    Write-Host "Header content: '$headerContent'" -ForegroundColor Cyan
    
    # Calculate column positions
    $positions = @()
    $currentX = 1
    for ($i = 0; $i -lt ($columnManager.Columns.Length - 1); $i++) {
        $currentX += $columnManager.Columns[$i].Width
        $positions += $currentX
        $currentX++
    }
    
    Write-Host "Column positions: $($positions -join ', ')" -ForegroundColor Cyan
    
    # Test rendering with fixed BorderDrawingSystem
    $renderedLine = $borderSystem.RenderContentLine($headerContent, $positions)
    Write-Host "Rendered header: '$renderedLine'" -ForegroundColor Green
    Write-Host "Length: $($renderedLine.Length)" -ForegroundColor Green
    
    # Test with task data
    $task = [TaskPro.Data.SimpleTask]::new()
    $task.Title = "Test Task"
    $task.Priority = [TaskPro.Data.Priority]::High
    $task.ID1 = "T1"
    $task.ID2 = "PROJECT-123"
    
    $taskContent = $columnManager.FormatTaskRowWithoutSeparators($task)
    Write-Host "Task content: '$taskContent'" -ForegroundColor Cyan
    
    $renderedTask = $borderSystem.RenderContentLine($taskContent, $positions)
    Write-Host "Rendered task: '$renderedTask'" -ForegroundColor Green
    Write-Host "Length: $($renderedTask.Length)" -ForegroundColor Green
    
    Write-Host ""
    Write-Host "VISUAL TEST - Should show proper column alignment:" -ForegroundColor Yellow
    Write-Host "╔════════════════════════════════════════════════╗"
    Write-Host "$renderedLine"
    Write-Host "$renderedTask"  
    Write-Host "╚════════════════════════════════════════════════╝"
    
    Write-Host ""
    Write-Host "✓ Border fix test completed successfully!" -ForegroundColor Green
    Write-Host "The columns should now be properly aligned without double separators." -ForegroundColor Cyan
    
} catch {
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host $_.Exception.ToString() -ForegroundColor Red
    exit 1
}