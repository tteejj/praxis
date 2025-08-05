#!/usr/bin/env pwsh
# test-simpletaskpro-f2.ps1 - Test SimpleTaskPro F2 switching (non-interactive)

Write-Host "Testing SimpleTaskPro F2 switching (simulation)..." -ForegroundColor Cyan
Write-Host ""

try {
    # Load SimpleTaskPro dependencies
    . "./TaskPro/Core/StringCache.ps1"
    . "./TaskPro/Components/Shared/VT100.ps1"
    . "./TaskPro/Services/PraxisDataService.ps1"
    . "./TaskPro/Services/AppManager.ps1"
    
    # Initialize theme system
    . "./TaskPro/Services/UnifiedThemeService.ps1"
    . "./TaskPro/Screens/ColorPickerDialog.ps1"
    . "./TaskPro/Screens/HybridColorPickerDialog.ps1"
    . "./TaskPro/Screens/EnhancedThemeSettingsScreen.ps1"
    
    # Initialize themes early
    $userDataPath = "./TaskPro/Data"
    if (-not (Test-Path $userDataPath)) {
        New-Item -ItemType Directory -Path $userDataPath -Force | Out-Null
    }
    [UnifiedThemeService]::Initialize($userDataPath)
    
    # Load remaining SimpleTaskPro components
    . "./TaskPro/Core/GapBuffer.ps1"
    . "./TaskPro/Core/FullNotesEditor.ps1"
    . "./TaskPro/Core/TagEditor.ps1"
    . "./TaskPro/Models/SimpleTask.ps1"
    . "./TaskPro/Services/ColorThemeService.ps1"
    . "./TaskPro/Services/SimpleTaskService.ps1"
    . "./TaskPro/Screens/TaskListScreen.ps1"
    . "./TaskPro/Screens/KanbanTaskListScreen.ps1"
    . "./TaskPro/Core/SimpleTaskProApp.ps1"
    
    Write-Host "✓ All components loaded" -ForegroundColor Green
    
    # Create SimpleTaskProApp
    $app = [SimpleTaskProApp]::new()
    Write-Host "✓ SimpleTaskProApp created" -ForegroundColor Green
    
    # Simulate F2 key press (switch to CommandLibrary)
    Write-Host ""
    Write-Host "Simulating F2 key press (CommandLibrary switch)..." -ForegroundColor Yellow
    
    $f2Key = [System.ConsoleKeyInfo]::new([char]0, [System.ConsoleKey]::F2, $false, $false, $false)
    $switchResult = $app.HandleAppSwitchKeys($f2Key)
    
    if ($switchResult) {
        Write-Host "✓ F2 switch successful" -ForegroundColor Green
        Write-Host "✓ Current app: $($app.CurrentApp)" -ForegroundColor Green
        Write-Host "✓ Current screen: $($app.CurrentScreen.GetType().Name)" -ForegroundColor Green
        
        # Test screen rendering
        try {
            $output = $app.CurrentScreen.Render()
            if ($output) {
                Write-Host "✓ CommandLibrary screen renders successfully ($($output.Length) chars)" -ForegroundColor Green
            } else {
                Write-Host "⚠ CommandLibrary screen rendered empty output" -ForegroundColor Yellow
            }
        } catch {
            Write-Host "✗ CommandLibrary screen render failed: $_" -ForegroundColor Red
        }
        
        # Test switching back to TaskPro
        Write-Host ""
        Write-Host "Simulating F1 key press (back to TaskPro)..." -ForegroundColor Yellow
        $f1Key = [System.ConsoleKeyInfo]::new([char]0, [System.ConsoleKey]::F1, $false, $false, $false)
        $switchBack = $app.HandleAppSwitchKeys($f1Key)
        
        if ($switchBack) {
            Write-Host "✓ F1 switch back successful" -ForegroundColor Green
            Write-Host "✓ Current app: $($app.CurrentApp)" -ForegroundColor Green
            Write-Host "✓ Current screen: $($app.CurrentScreen.GetType().Name)" -ForegroundColor Green
        } else {
            Write-Host "✗ F1 switch back failed" -ForegroundColor Red
        }
        
    } else {
        Write-Host "✗ F2 switch failed" -ForegroundColor Red
    }
    
    Write-Host ""
    Write-Host "🎉 SimpleTaskPro F2 switching test completed!" -ForegroundColor Green
    
} catch {
    Write-Host "✗ Test failed: $_" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor DarkGray
}