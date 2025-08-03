# Simple test for new focus system - no custom classes needed

# Load the framework
. "$PSScriptRoot/Start.ps1" -LoadOnly

# Load the new DialogField component
. "$PSScriptRoot/Components/DialogField.ps1"

try {
    Write-Host "Starting Simple Focus System Test..." -ForegroundColor Yellow
    Write-Host "- This will show a NewProjectDialog to test the new focus system" -ForegroundColor Gray
    Write-Host "- Use Tab to navigate, Enter on OK, Escape to cancel" -ForegroundColor Gray
    Write-Host ""
    
    # Use existing NewProjectDialog to test the system
    $dialog = [NewProjectDialog]::new()
    $global:ScreenManager.Push($dialog)
    
    # Run the main loop
    $global:ScreenManager.Run()
    
} catch {
    Write-Error "Test failed: $_"
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
} finally {
    Write-Host "`nTest completed." -ForegroundColor Yellow
}