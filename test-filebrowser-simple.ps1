#!/usr/bin/env pwsh
# Simple file browser test

# Navigate to script directory
Set-Location $PSScriptRoot

# Load all required files
$files = @(
    "Core/VT100.ps1"
    "Core/ServiceContainer.ps1"
    "Services/Logger.ps1"
    "Services/EventBus.ps1"
    "Services/ThemeManager.ps1"
    "Base/UIElement.ps1"
    "Base/Container.ps1"
    "Models/Project.ps1"
    "Services/ConfigurationService.ps1"
    "Components/FastFileTree.ps1"
    "Components/RangerFileTree.ps1"
)

foreach ($file in $files) {
    $fullPath = Join-Path $PSScriptRoot $file
    if (Test-Path $fullPath) {
        . $fullPath
        Write-Host "✓ $file" -ForegroundColor Green
    } else {
        Write-Host "✗ $file not found!" -ForegroundColor Red
    }
}

# Create minimal service container
$global:ServiceContainer = [ServiceContainer]::new()

# Create logger
$logger = [Logger]::new((Join-Path $PSScriptRoot "_Logs" "test.log"))
$global:Logger = $logger
$global:ServiceContainer.Register("Logger", $logger)

# Create theme manager
$themeManager = [ThemeManager]::new()
$global:ServiceContainer.Register("ThemeManager", $themeManager)

# Create config service
$configService = [ConfigurationService]::new()
$global:ServiceContainer.Register("ConfigurationService", $configService)

Write-Host "`nTesting RangerFileTree directly..." -ForegroundColor Cyan

# Create ranger file tree
$ranger = [RangerFileTree]::new($PSScriptRoot)
$ranger.Initialize($global:ServiceContainer)

Write-Host "RangerFileTree created" -ForegroundColor Green
Write-Host "  CurrentPath: $($ranger.CurrentPath)" -ForegroundColor Yellow
Write-Host "  IsFocusable: $($ranger.IsFocusable)" -ForegroundColor Yellow

# Set bounds
$ranger.SetBounds(0, 0, 80, 24)
Write-Host "  Bounds set to: 0,0,80,24" -ForegroundColor Yellow

# Check panes
Write-Host "`nChecking panes:" -ForegroundColor Cyan
if ($ranger.CurrentPane) {
    Write-Host "  CurrentPane exists" -ForegroundColor Green
    Write-Host "    Type: $($ranger.CurrentPane.GetType().Name)" -ForegroundColor Yellow
    Write-Host "    IsFocusable: $($ranger.CurrentPane.IsFocusable)" -ForegroundColor Yellow
    Write-Host "    Bounds: $($ranger.CurrentPane.X),$($ranger.CurrentPane.Y),$($ranger.CurrentPane.Width),$($ranger.CurrentPane.Height)" -ForegroundColor Yellow
    Write-Host "    Items: $($ranger.CurrentPane._flatView.Count)" -ForegroundColor Yellow
} else {
    Write-Host "  ERROR: CurrentPane is null!" -ForegroundColor Red
}

# Try to render
Write-Host "`nTrying to render..." -ForegroundColor Cyan
try {
    $output = $ranger.Render()
    Write-Host "  Render succeeded, output length: $($output.Length)" -ForegroundColor Green
} catch {
    Write-Host "  ERROR: Render failed - $_" -ForegroundColor Red
}

# Test input handling
Write-Host "`nTesting input handling..." -ForegroundColor Cyan
$keyJ = [System.ConsoleKeyInfo]::new('j', [System.ConsoleKey]::J, $false, $false, $false)
$handled = $ranger.HandleInput($keyJ)
Write-Host "  Key 'j' handled: $handled" -ForegroundColor Yellow

Write-Host "`nDone!" -ForegroundColor Green