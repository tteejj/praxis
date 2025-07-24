#!/usr/bin/env pwsh
# Debug input flow

# Add extensive logging to key components
$debugCode = @'
# Add to Container.HandleInput
Write-Host "Container.HandleInput: Type=$($this.GetType().Name) Key=$($key.Key)" -ForegroundColor Yellow

# Add to Screen.HandleInput  
Write-Host "Screen.HandleInput: Type=$($this.GetType().Name) Key=$($key.Key)" -ForegroundColor Cyan

# Add to ProjectsScreen.HandleScreenInput
Write-Host "ProjectsScreen.HandleScreenInput: Key=$($key.Key) Char='$($key.KeyChar)'" -ForegroundColor Green

# Add to TabContainer.HandleInput
Write-Host "TabContainer.HandleInput: Key=$($key.Key) Routing to: $($activeTab.Content.GetType().Name)" -ForegroundColor Magenta
'@

Write-Host "Debug code to add for testing input flow:" -ForegroundColor Yellow
Write-Host $debugCode

Write-Host ""
Write-Host "Run PRAXIS and watch the console output to see input flow" -ForegroundColor Cyan