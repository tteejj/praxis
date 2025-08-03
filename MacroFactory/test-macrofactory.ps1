#!/usr/bin/env pwsh
# test-macrofactory.ps1 - Quick test script for MacroFactory

Write-Host "Testing MacroFactory components..." -ForegroundColor Cyan

try {
    # Load components
    . "$PSScriptRoot/Core/VT100.ps1"
    . "$PSScriptRoot/Core/Logger.ps1"
    . "$PSScriptRoot/Models/BaseAction.ps1"
    . "$PSScriptRoot/Models/SampleActions.ps1"
    . "$PSScriptRoot/Services/MacroContextManager.ps1"
    . "$PSScriptRoot/Services/MacroService.ps1"
    
    Write-Host "✓ Components loaded successfully" -ForegroundColor Green
    
    # Test creating actions
    Write-Host "`nTesting action creation..." -ForegroundColor Yellow
    $summarizeAction = [SummarizationAction]::new()
    $appendAction = [AppendFieldAction]::new()
    $exportAction = [ExportToExcelAction]::new()
    
    Write-Host "✓ Created $($summarizeAction.Name)" -ForegroundColor Green
    Write-Host "✓ Created $($appendAction.Name)" -ForegroundColor Green
    Write-Host "✓ Created $($exportAction.Name)" -ForegroundColor Green
    
    # Test context manager
    Write-Host "`nTesting MacroContextManager..." -ForegroundColor Yellow
    $contextManager = [MacroContextManager]::new()
    
    # Configure and add actions
    $summarizeAction.Parameters["database"] = "ActiveDatabase"
    $summarizeAction.Parameters["fieldToSummarize"] = "CUSTOMER_ID"
    $summarizeAction.Parameters["outputName"] = "customerSummary"
    $contextManager.AddAction($summarizeAction)
    
    $appendAction.Parameters["database"] = "customerSummary"
    $appendAction.Parameters["fieldName"] = "RISK_SCORE"
    $appendAction.Parameters["fieldType"] = "Numeric"
    $contextManager.AddAction($appendAction)
    
    $exportAction.Parameters["database"] = "customerSummary"
    $exportAction.Parameters["filename"] = "test_export.xlsx"
    $exportAction.Parameters["includeHeader"] = "True"
    $contextManager.AddAction($exportAction)
    
    Write-Host "✓ Added 3 actions to context manager" -ForegroundColor Green
    
    # Test script generation
    Write-Host "`nTesting script generation..." -ForegroundColor Yellow
    $script = $contextManager.GenerateScript()
    
    Write-Host "✓ Generated script ($($script.Length) characters)" -ForegroundColor Green
    Write-Host "`nGenerated IDEAScript Preview:" -ForegroundColor Cyan
    Write-Host "=================================" -ForegroundColor DarkGray
    $script -split "`n" | Select-Object -First 20 | ForEach-Object {
        Write-Host $_ -ForegroundColor Gray
    }
    Write-Host "... (truncated)" -ForegroundColor DarkGray
    Write-Host "=================================" -ForegroundColor DarkGray
    
    # Test macro save/load
    Write-Host "`nTesting macro save/load..." -ForegroundColor Yellow
    $macroService = [MacroService]::new()
    $macroService.SaveMacro("Test Macro", $contextManager, "Test macro for validation")
    Write-Host "✓ Saved macro successfully" -ForegroundColor Green
    
    $loadedContext = $macroService.LoadMacro("Test_Macro.json")
    Write-Host "✓ Loaded macro with $($loadedContext.Actions.Count) actions" -ForegroundColor Green
    
    # List available macros
    $macros = $macroService.GetAvailableMacros()
    Write-Host "✓ Found $($macros.Count) saved macro(s)" -ForegroundColor Green
    
    Write-Host "`nAll tests passed! ✨" -ForegroundColor Green
    Write-Host "Run ./MacroFactory.ps1 to start the full application" -ForegroundColor Cyan
    
} catch {
    Write-Host "`n✗ Test failed: $_" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor DarkGray
    exit 1
}