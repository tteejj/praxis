# Start-Simple.ps1 - Simplified version to test basic functionality

# Clear screen and hide cursor for better UI
[Console]::Clear()
[Console]::CursorVisible = $false

# Set up error handling
$ErrorActionPreference = 'Stop'

try {
    Write-Host "Loading ExcelDataFlow (simplified)..." -ForegroundColor Cyan
    
    # Core classes first
    . "$PSScriptRoot\Core\VT100.ps1"
    . "$PSScriptRoot\Core\ServiceContainer.ps1"
    
    # Base classes
    . "$PSScriptRoot\Base\UIElement.ps1"
    . "$PSScriptRoot\Base\Container.ps1"
    . "$PSScriptRoot\Base\Screen.ps1"
    
    # Components (needed by BaseDialog)
    . "$PSScriptRoot\Components\MinimalButton.ps1"
    . "$PSScriptRoot\Components\MinimalTextBox.ps1"
    
    # BaseDialog last (depends on components)
    . "$PSScriptRoot\Base\BaseDialog.ps1"
    
    # Services
    . "$PSScriptRoot\Services\ConfigurationService.ps1"
    
    Write-Host "Classes loaded successfully" -ForegroundColor Green
    
    # Create service container
    $global:ServiceContainer = [ServiceContainer]::new()
    
    # Register services
    $configPath = "$PSScriptRoot\_Config\settings.json"
    $configService = [ConfigurationService]::new($configPath)
    $global:ServiceContainer.RegisterInstance('ConfigurationService', $configService)
    
    Write-Host "Services initialized successfully" -ForegroundColor Green
    
    # Create a simple test dialog
    $testDialog = [BaseDialog]::new("Test Dialog", 60, 20)
    $testDialog.Initialize($global:ServiceContainer)
    $testDialog.SetBounds(0, 0, [Console]::WindowWidth, [Console]::WindowHeight)
    $testDialog.OnActivated()
    
    Write-Host "Dialog created successfully" -ForegroundColor Green
    
    # Simple application loop
    $running = $true
    
    function Show-Screen {
        $output = $testDialog.Render()
        [Console]::SetCursorPosition(0, 0)
        Write-Host $output -NoNewline
    }
    
    # Initial render
    Show-Screen
    
    Write-Host ""
    Write-Host "Simple Test Ready - F10 to exit, Enter for OK, Escape for Cancel" -ForegroundColor Green
    
    # Main application loop
    while ($running) {
        if ([Console]::KeyAvailable) {
            $key = [Console]::ReadKey($true)
            
            # Global exit key
            if ($key.Key -eq [System.ConsoleKey]::F10) {
                $running = $false
                break
            }
            
            # Route input to dialog
            $handled = $testDialog.HandleInput($key)
            if ($handled) {
                Show-Screen
            }
        }
        
        Start-Sleep -Milliseconds 50
    }
    
} catch {
    Write-Error "Failed to start simplified test: $_"
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
} finally {
    # Restore cursor and clear screen
    [Console]::CursorVisible = $true
    [Console]::Clear()
    Write-Host "Test exited." -ForegroundColor Cyan
}