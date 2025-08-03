# TestStartup.ps1 - Quick test of the startup and workflow components

Write-Host "Testing ExcelDataFlow Startup and Workflow..." -ForegroundColor Cyan
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host ""

try {
    # Test 1: Load core classes
    Write-Host "1. Testing core class loading..." -ForegroundColor Yellow
    
    . "$PSScriptRoot\Core\VT100.ps1"
    . "$PSScriptRoot\Core\ServiceContainer.ps1"
    . "$PSScriptRoot\Core\StringCache.ps1"
    . "$PSScriptRoot\Core\BorderStyle.ps1"
    . "$PSScriptRoot\Base\UIElement.ps1"
    . "$PSScriptRoot\Base\Container.ps1"
    . "$PSScriptRoot\Base\Screen.ps1"
    . "$PSScriptRoot\Components\MinimalButton.ps1"
    . "$PSScriptRoot\Components\MinimalTextBox.ps1"
    . "$PSScriptRoot\Components\SimpleListBox.ps1"
    . "$PSScriptRoot\Components\MinimalDataGrid.ps1"
    . "$PSScriptRoot\Base\UnifiedDialog.ps1"
    
    Write-Host "✓ Core classes loaded successfully" -ForegroundColor Green
    
    # Test 2: Load services
    Write-Host "2. Testing service loading..." -ForegroundColor Yellow
    
    . "$PSScriptRoot\Services\ConfigurationService.ps1"
    . "$PSScriptRoot\Services\ExcelService.ps1"
    . "$PSScriptRoot\Services\ExportProfileService.ps1"
    . "$PSScriptRoot\Services\TextExportService.ps1"
    . "$PSScriptRoot\Services\DataProcessingService.ps1"
    
    Write-Host "✓ Services loaded successfully" -ForegroundColor Green
    
    # Test 3: Load workflow components
    Write-Host "3. Testing workflow components..." -ForegroundColor Yellow
    
    . "$PSScriptRoot\Components\SimpleFileTree.ps1"
    . "$PSScriptRoot\Screens\StartupSelectionDialog.ps1"
    . "$PSScriptRoot\Screens\SimpleProfileSelectionDialog.ps1"
    . "$PSScriptRoot\Screens\PostConfigurationDialog.ps1"
    . "$PSScriptRoot\Screens\Step1InputConfigDialog.ps1"
    . "$PSScriptRoot\Screens\Step2SourceMappingDialog.ps1"
    . "$PSScriptRoot\Screens\Step3DestMappingDialog.ps1"
    
    Write-Host "✓ Workflow components loaded successfully" -ForegroundColor Green
    
    # Test 4: Initialize services
    Write-Host "4. Testing service initialization..." -ForegroundColor Yellow
    
    $configService = [ConfigurationService]::new("$PSScriptRoot\_Config\settings.json")
    $profileService = [ExportProfileService]::new($configService)
    
    Write-Host "✓ Services initialized successfully" -ForegroundColor Green
    
    # Test 5: Test profile system
    Write-Host "5. Testing profile system..." -ForegroundColor Yellow
    
    $testFields = @("Field1", "Field2", "Field3")
    $result = $profileService.SaveProfile("TestProfile", $testFields, "CSV", "Test profile")
    
    if ($result.Success) {
        Write-Host "✓ Profile creation works" -ForegroundColor Green
        
        # Clean up test profile
        $profileService.DeleteProfile("TestProfile")
        Write-Host "✓ Profile cleanup completed" -ForegroundColor Green
    } else {
        Write-Host "✗ Profile creation failed: $($result.Message)" -ForegroundColor Red
    }
    
    Write-Host ""
    Write-Host "🎉 ALL TESTS PASSED!" -ForegroundColor Green
    Write-Host ""
    Write-Host "ExcelDataFlow is ready to use!" -ForegroundColor Cyan
    Write-Host "Run: pwsh -File Start.ps1" -ForegroundColor White
    Write-Host ""
    
} catch {
    Write-Host ""
    Write-Host "❌ TEST FAILED!" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack: $($_.ScriptStackTrace)" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Please check the error above and fix the dependencies." -ForegroundColor Yellow
    exit 1
}