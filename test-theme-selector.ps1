#!/usr/bin/env pwsh

# Test theme selection dialog
Set-Location $PSScriptRoot

# Load all required files
. ./Core/VT100.ps1
. ./Core/StringCache.ps1
. ./Core/StringBuilderPool.ps1
. ./Core/BorderStyle.ps1
. ./Core/ServiceContainer.ps1
. ./Core/ScreenManager.ps1
. ./Services/Logger.ps1
. ./Services/EventBus.ps1
. ./Services/ThemeManager.ps1
. ./Base/UIElement.ps1
. ./Base/Container.ps1
. ./Base/Screen.ps1
. ./Base/BaseDialog.ps1
. ./Components/MinimalListBox.ps1
. ./Screens/ThemeSelectionDialog.ps1

# Initialize services
$global:ServiceContainer = [ServiceContainer]::new()
$global:Logger = [Logger]::new()
$global:ServiceContainer.RegisterService('Logger', $global:Logger)

$eventBus = [EventBus]::new()
$global:ServiceContainer.RegisterService('EventBus', $eventBus)

$themeManager = [ThemeManager]::new()
$global:ServiceContainer.RegisterService('ThemeManager', $themeManager)

$screenManager = [ScreenManager]::new()
$global:ServiceContainer.RegisterService('ScreenManager', $screenManager)
$global:ScreenManager = $screenManager

# Clear screen
[Console]::Clear()

try {
    # Create and show theme selection dialog
    $dialog = [ThemeSelectionDialog]::new()
    $dialog.Initialize($global:ServiceContainer)
    
    Write-Host "Showing theme selection dialog..." -ForegroundColor Green
    Write-Host "Use arrow keys to navigate, Enter to select, Escape to cancel" -ForegroundColor Yellow
    Start-Sleep -Seconds 1
    
    # Show dialog
    $screenManager.PushScreen($dialog)
    $screenManager.Run()
    
    # Check result
    if ($dialog.DialogResult -and $dialog.SelectedTheme) {
        Write-Host "`nTheme selected: $($dialog.SelectedTheme)" -ForegroundColor Green
        Write-Host "Current theme is now: $($themeManager.GetCurrentTheme())" -ForegroundColor Cyan
    } else {
        Write-Host "`nNo theme selected" -ForegroundColor Yellow
    }
} catch {
    Write-Host "Error: $_" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor DarkGray
} finally {
    # Reset console
    [Console]::CursorVisible = $true
    Write-Host "`nPress any key to exit..."
    [Console]::ReadKey($true) | Out-Null
}