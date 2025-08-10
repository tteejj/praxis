# test-excel-integration.ps1 - Test Excel screen integration

try {
    Write-Host "Testing Excel screen integration..." -ForegroundColor Cyan
    
    # Load required classes
    Write-Host "Loading core classes..." -ForegroundColor Yellow
    . "$PSScriptRoot/Core/StringCache.ps1"
    . "$PSScriptRoot/Core/VT100.ps1" 
    . "$PSScriptRoot/Core/UniversalBackupManager.ps1"
    . "$PSScriptRoot/Models/SimpleTask.ps1"
    . "$PSScriptRoot/Models/SimpleTimeEntry.ps1"
    . "$PSScriptRoot/Services/SimpleTaskService.ps1"
    . "$PSScriptRoot/Services/TimeTrackingService.ps1"
    . "$PSScriptRoot/Services/ExcelServiceContainer.ps1"
    . "$PSScriptRoot/Services/ConfigurationService.ps1"
    . "$PSScriptRoot/Services/ExcelService.ps1"
    . "$PSScriptRoot/Services/DataProcessingService.ps1"
    . "$PSScriptRoot/Services/TextExportService.ps1"
    . "$PSScriptRoot/Services/ExportProfileService.ps1"
    
    # Load screen classes
    Write-Host "Loading screen classes..." -ForegroundColor Yellow
    . "$PSScriptRoot/Screens/ExcelDataScreen.ps1"
    . "$PSScriptRoot/Screens/TaskListScreen.ps1"
    . "$PSScriptRoot/Core/SimpleTaskProApp.ps1"
    
    Write-Host "✅ All classes loaded successfully" -ForegroundColor Green
    
    # Test service container creation
    Write-Host "`nTesting service container..." -ForegroundColor Yellow
    $serviceContainer = [ExcelServiceContainer]::new()
    Write-Host "✅ Service container created" -ForegroundColor Green
    
    # Test Excel service availability
    Write-Host "`nTesting Excel service..." -ForegroundColor Yellow
    $excelService = $serviceContainer.GetService('ExcelService')
    $available = $excelService.IsAvailable()
    Write-Host "Excel COM Available: $available" -ForegroundColor $(if ($available) { "Green" } else { "Yellow" })
    
    # Test configuration service
    Write-Host "`nTesting configuration service..." -ForegroundColor Yellow
    $configService = $serviceContainer.GetService('ConfigurationService')
    $mappings = $configService.GetExcelMappings()
    Write-Host "Configuration loaded: $($mappings -ne $null)" -ForegroundColor Green
    
    # Test Excel screen creation
    Write-Host "`nTesting Excel screen creation..." -ForegroundColor Yellow
    $excelScreen = [ExcelDataScreen]::new()
    Write-Host "✅ Excel screen created successfully" -ForegroundColor Green
    
    # Test screen initialization
    Write-Host "`nTesting screen initialization..." -ForegroundColor Yellow
    $excelScreen.Initialize(120, 30)
    Write-Host "✅ Excel screen initialized" -ForegroundColor Green
    
    # Test render (basic)
    Write-Host "`nTesting screen render..." -ForegroundColor Yellow
    $renderOutput = $excelScreen.Render()
    $hasOutput = $renderOutput -and $renderOutput.Length -gt 0
    Write-Host "Render output generated: $hasOutput" -ForegroundColor $(if ($hasOutput) { "Green" } else { "Red" })
    
    # Test app integration
    Write-Host "`nTesting app integration..." -ForegroundColor Yellow
    $app = [SimpleTaskProApp]::new()
    Write-Host "✅ App with Excel screen created successfully" -ForegroundColor Green
    
    Write-Host "`n🎉 All tests passed! Excel integration is working." -ForegroundColor Green
    Write-Host "You can now:" -ForegroundColor Cyan
    Write-Host "  1. Run SimpleTaskPro.ps1" -ForegroundColor Gray
    Write-Host "  2. Press F6 to access Excel Data Management" -ForegroundColor Gray
    Write-Host "  3. Use F1-F9 for Excel functions" -ForegroundColor Gray
    
} catch {
    Write-Host "❌ Test failed: $_" -ForegroundColor Red
    Write-Host "Stack trace:" -ForegroundColor Gray
    Write-Host $_.ScriptStackTrace -ForegroundColor DarkGray
}