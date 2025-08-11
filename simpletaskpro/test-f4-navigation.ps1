#!/usr/bin/env pwsh
# Test F4 navigation to TimeEntryScreen

# Load SimpleTaskPro components
. "./SimpleTaskPro.ps1"

Write-Host "=== Testing F4 Navigation to TimeEntryScreen ===" -ForegroundColor Cyan

try {
    # Create app instance
    $app = [SimpleTaskProApp]::new()
    Write-Host "✓ App created successfully" -ForegroundColor Green
    
    # Check if TimeScreen exists
    if ($app.TimeScreen) {
        Write-Host "✓ TimeScreen exists: $($app.TimeScreen.GetType().Name)" -ForegroundColor Green
    } else {
        Write-Host "✗ TimeScreen is null!" -ForegroundColor Red
        exit 1
    }
    
    # Test EventBus manually
    Write-Host "`nTesting EventBus navigation..." -ForegroundColor Yellow
    
    # Simulate F4 key press by publishing event directly
    Write-Host "Publishing NavigateTo 'timeentry' event..."
    [EventBus]::Publish("NavigateTo", "timeentry")
    
    # Check current screen after navigation
    Write-Host "Current screen type: $($app.CurrentScreen.GetType().Name)" -ForegroundColor Cyan
    Write-Host "Current mode: $($app.CurrentMode)" -ForegroundColor Cyan
    Write-Host "Screen stack depth: $($app.ScreenStack.Count)" -ForegroundColor Cyan
    
    if ($app.CurrentScreen -is [TimeEntryScreen]) {
        Write-Host "✓ Successfully navigated to TimeEntryScreen!" -ForegroundColor Green
        
        # Test navigation back
        Write-Host "`nTesting navigation back..."
        [EventBus]::Publish("NavigateBack")
        
        Write-Host "After NavigateBack:" -ForegroundColor Cyan
        Write-Host "Current screen type: $($app.CurrentScreen.GetType().Name)" -ForegroundColor Cyan
        Write-Host "Current mode: $($app.CurrentMode)" -ForegroundColor Cyan
        Write-Host "Screen stack depth: $($app.ScreenStack.Count)" -ForegroundColor Cyan
        
        if ($app.CurrentScreen -is [TaskListScreen]) {
            Write-Host "✓ Successfully navigated back to TaskListScreen!" -ForegroundColor Green
        } else {
            Write-Host "✗ Failed to navigate back to TaskListScreen" -ForegroundColor Red
        }
        
    } else {
        Write-Host "✗ Failed to navigate to TimeEntryScreen" -ForegroundColor Red
        Write-Host "Expected: TimeEntryScreen, Got: $($app.CurrentScreen.GetType().Name)" -ForegroundColor Red
    }
    
} catch {
    Write-Host "✗ Error during test: $_" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor DarkRed
}

Write-Host "`n=== Test Complete ===" -ForegroundColor Cyan