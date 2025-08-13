# Test-Phase3.ps1 - Test flat navigation with Phase 1 services and new Screen architecture
# Demonstrates the complete Phase 1 + Phase 3 hybrid approach

param(
    [switch]$Debug
)

# Set debug mode
$global:Debug = $Debug.IsPresent

# Get application root path
$AppRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host "Testing Phase 3 Architecture..." -ForegroundColor Cyan

try {
    # Load Phase 1 core services
    Write-Host "Loading Phase 1 services..." -ForegroundColor Yellow
    . (Join-Path $AppRoot "Core/Logger.ps1")
    . (Join-Path $AppRoot "Core/SettingsService.ps1")
    . (Join-Path $AppRoot "Core/EventBus.ps1")
    . (Join-Path $AppRoot "Core/ServiceContainer.ps1")
    . (Join-Path $AppRoot "Core/StateManager.ps1")
    . (Join-Path $AppRoot "Core/InputProcessor.ps1")
    . (Join-Path $AppRoot "Core/RenderEngine.ps1")
    . (Join-Path $AppRoot "Core/StringCache.ps1")
    . (Join-Path $AppRoot "Core/Bootstrapper.ps1")
    
    # Load Phase 3 Screen architecture
    Write-Host "Loading Phase 3 components..." -ForegroundColor Yellow
    . (Join-Path $AppRoot "Base/Screen.ps1")
    . (Join-Path $AppRoot "Base/ListScreen.ps1")
    . (Join-Path $AppRoot "Core/SimpleTaskProApp-Phase3.ps1")
    
    # Initialize application through bootstrapper
    Write-Host "Initializing application..." -ForegroundColor Green
    $app = [Bootstrapper]::Initialize($AppRoot)
    
    # Create the enhanced app with Phase 1 services
    $serviceContainer = [Bootstrapper]::GetServiceContainer()
    $enhancedApp = [SimpleTaskProApp]::new($serviceContainer)
    
    Write-Host "Phase 3 test application ready!" -ForegroundColor Green
    Write-Host "Controls:" -ForegroundColor Yellow
    Write-Host "  F1 = Tasks screen" -ForegroundColor Gray
    Write-Host "  F3 = Time Entry screen" -ForegroundColor Gray
    Write-Host "  F4 = Commands screen" -ForegroundColor Gray
    Write-Host "  F6 = Excel screen" -ForegroundColor Gray
    Write-Host "  Ctrl+Esc = Exit" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Press any key to start..." -ForegroundColor Yellow
    $null = [Console]::ReadKey($true)
    
    # Run the application
    $enhancedApp.Run()
    
} catch {
    Write-Host "Test failed: $_" -ForegroundColor Red
    [Logger]::Error("Phase 3 test error", $_)
    
    # Emergency cleanup
    try {
        [Bootstrapper]::EmergencyCleanup()
    } catch {
        Write-Host "Emergency cleanup failed: $_" -ForegroundColor Red
    }
    
    exit 1
    
} finally {
    # Clean shutdown
    Write-Host "Test cleanup..." -ForegroundColor Yellow
    [Bootstrapper]::Cleanup()
    Write-Host "Phase 3 test complete." -ForegroundColor Green
}