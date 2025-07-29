#!/usr/bin/env pwsh
# Minimal test - standalone, no Start.ps1

# Load only the essential files we need
. ./Core/ServiceContainer.ps1
. ./Services/ThemeManager.ps1
. ./Services/ConfigurationService.ps1
. ./Services/EventBus.ps1
. ./Core/VT100.ps1
. ./Core/StringCache.ps1
. ./Core/StringBuilderPool.ps1
. ./Core/BorderStyle.ps1
. ./Base/UIElement.ps1
. ./Base/Container.ps1
. ./Base/Screen.ps1
. ./Base/FocusableComponent.ps1
. ./Components/TabContainer.ps1
. ./Components/MinimalDataGrid.ps1

# Create minimal service container
$container = [ServiceContainer]::new()
$config = [ConfigurationService]::new()
$config.LoadConfiguration()
$container.RegisterService('ConfigurationService', $config)
$container.RegisterService('EventBus', [EventBus]::new())
$container.RegisterService('ThemeManager', [ThemeManager]::new())

# Initialize theme
$themeManager = $container.GetService('ThemeManager')
$themeManager.Initialize($container)
$themeManager.LoadTheme('matrix')

# Log file for debugging
$logFile = "./test-minimal-debug.log"
"Test started at $(Get-Date)" | Out-File $logFile

try {
    # Test 1: Blank screen
    [Console]::Clear()
    Write-Host "TEST 1: Creating blank screen..." -ForegroundColor Yellow
    "TEST 1: Blank screen" | Out-File $logFile -Append
    
    $screen = [Screen]::new()
    $screen.Initialize($container)
    $screen.SetBounds(0, 0, [Console]::WindowWidth, [Console]::WindowHeight)
    
    $rendered = $screen.Render()
    [Console]::SetCursorPosition(0, 0)
    [Console]::Write($rendered)
    
    [Console]::SetCursorPosition(0, [Console]::WindowHeight - 2)
    Write-Host "Blank screen rendered. Press any key for TabContainer test..." -ForegroundColor Green
    [Console]::ReadKey($true) | Out-Null
    
    # Test 2: Add TabContainer
    [Console]::Clear()
    Write-Host "TEST 2: Adding TabContainer..." -ForegroundColor Yellow
    "TEST 2: TabContainer" | Out-File $logFile -Append
    
    $tabContainer = [TabContainer]::new()
    $tabContainer.Initialize($container)
    $tabContainer.SetBounds(0, 0, [Console]::WindowWidth, [Console]::WindowHeight - 3)
    
    # Create empty screen for tab
    $tabScreen = [Screen]::new()
    $tabScreen.Initialize($container)
    $tabContainer.AddTab("Empty Tab", $tabScreen)
    
    $screen.AddChild($tabContainer)
    $rendered = $screen.Render()
    [Console]::SetCursorPosition(0, 0)
    [Console]::Write($rendered)
    
    [Console]::SetCursorPosition(0, [Console]::WindowHeight - 2)
    Write-Host "TabContainer added. Press any key for Grid test..." -ForegroundColor Green
    [Console]::ReadKey($true) | Out-Null
    
    # Test 3: Add Grid
    [Console]::Clear()
    Write-Host "TEST 3: Adding MinimalDataGrid..." -ForegroundColor Yellow
    "TEST 3: MinimalDataGrid" | Out-File $logFile -Append
    
    $grid = [MinimalDataGrid]::new()
    $grid.Title = "Test Grid"
    $grid.ShowBorder = $true
    $grid.BorderType = [BorderType]::Rounded
    $grid.ShowGridLines = $false
    
    # Setup columns
    $grid.SetColumns(@(
        @{Name="Name"; Header="Name"; Width=20},
        @{Name="Value"; Header="Value"; Width=20}
    ))
    
    # Add test data
    $grid.SetItems(@(
        @{Name="Test Row 1"; Value="Value 1"},
        @{Name="Test Row 2"; Value="Value 2"},
        @{Name="Test Row 3"; Value="Value 3"}
    ))
    
    # Add grid to tab screen
    $tabScreen.AddChild($grid)
    $grid.SetBounds(2, 2, 50, 10)
    
    # Force re-render
    $tabContainer.Invalidate()
    $rendered = $screen.Render()
    [Console]::SetCursorPosition(0, 0)
    [Console]::Write($rendered)
    
    # Check for horizontal line characters in the output
    $lineChars = @('─', '━', '═')
    $foundLines = $false
    foreach ($char in $lineChars) {
        if ($rendered.Contains($char)) {
            $count = ($rendered.ToCharArray() | Where-Object { $_ -eq $char }).Count
            $msg = "Found $count instances of line char '$char'"
            $msg | Out-File $logFile -Append
            $foundLines = $true
        }
    }
    
    if ($foundLines) {
        "HORIZONTAL LINES DETECTED IN OUTPUT" | Out-File $logFile -Append
    } else {
        "No horizontal lines found" | Out-File $logFile -Append
    }
    
    [Console]::SetCursorPosition(0, [Console]::WindowHeight - 2)
    Write-Host "Grid added. Check for horizontal lines. Press any key to exit..." -ForegroundColor Green
    [Console]::ReadKey($true) | Out-Null
    
} catch {
    "ERROR: $_" | Out-File $logFile -Append
    $_.Exception.StackTrace | Out-File $logFile -Append
    Write-Host "Error occurred: $_" -ForegroundColor Red
    Write-Host "Check $logFile for details" -ForegroundColor Yellow
    [Console]::ReadKey($true) | Out-Null
} finally {
    [Console]::Clear()
    Write-Host "Test complete. Log saved to: $logFile" -ForegroundColor Cyan
}