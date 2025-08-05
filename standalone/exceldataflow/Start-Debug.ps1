# Start-Debug.ps1 - Debug version to see where it hangs

[Console]::Clear()
[Console]::CursorVisible = $false
$ErrorActionPreference = 'Stop'

try {
    Write-Host "Loading ExcelDataFlow..." -ForegroundColor Cyan
    
    # Core classes first
    . "$PSScriptRoot\Core\VT100.ps1"
    . "$PSScriptRoot\Core\ServiceContainer.ps1"
    . "$PSScriptRoot\Base\UIElement.ps1"
    . "$PSScriptRoot\Base\Container.ps1"
    . "$PSScriptRoot\Base\Screen.ps1"
    . "$PSScriptRoot\Components\MinimalButton.ps1"
    . "$PSScriptRoot\Components\MinimalTextBox.ps1"
    . "$PSScriptRoot\Components\MinimalDataGrid.ps1"
    . "$PSScriptRoot\Base\BaseDialog.ps1"
    . "$PSScriptRoot\Services\ConfigurationService.ps1"
    . "$PSScriptRoot\Services\ExcelService.ps1"
    
    Write-Host "Classes loaded" -ForegroundColor Green
    
    # Load main screens
    . "$PSScriptRoot\Screens\ExcelMappingSetupDialog.ps1"
    
    Write-Host "Screens loaded" -ForegroundColor Green
    
    # Create service container
    $global:ServiceContainer = [ServiceContainer]::new()
    
    # Register services
    $configPath = "$PSScriptRoot\_Config\settings.json"
    $configService = [ConfigurationService]::new($configPath)
    $global:ServiceContainer.RegisterInstance('ConfigurationService', $configService)
    
    $excelService = [ExcelService]::new()
    $global:ServiceContainer.RegisterInstance('ExcelService', $excelService)
    
    Write-Host "Services created" -ForegroundColor Green
    
    # Create and initialize the main screen
    Write-Host "Creating dialog..." -ForegroundColor Yellow
    $setupScreen = [ExcelMappingSetupDialog]::new("Excel Field Mapping Setup", 80, 25)
    
    Write-Host "Initializing dialog..." -ForegroundColor Yellow
    $setupScreen.Initialize($global:ServiceContainer)
    
    Write-Host "Setting bounds..." -ForegroundColor Yellow
    $setupScreen.SetBounds(0, 0, [Console]::WindowWidth, [Console]::WindowHeight)
    
    Write-Host "Activating..." -ForegroundColor Yellow
    $setupScreen.OnActivated()
    
    Write-Host "Dialog ready, attempting first render..." -ForegroundColor Yellow
    
    # Simple application loop
    $running = $true
    
    function Show-Screen {
        Write-Host "Starting render..." -ForegroundColor Magenta
        $output = $setupScreen.Render()
        Write-Host "Render complete, output length: $($output.Length)" -ForegroundColor Magenta
        [Console]::SetCursorPosition(0, 0)
        Write-Host $output -NoNewline
    }
    
    # Initial render
    Show-Screen
    
    Write-Host "First render complete!" -ForegroundColor Cyan
    
    # Exit immediately for testing
    Start-Sleep -Seconds 1
    
} catch {
    Write-Error "Failed: $_"
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
} finally {
    [Console]::CursorVisible = $true
    [Console]::Clear()
    Write-Host "Debug test complete." -ForegroundColor Cyan
}