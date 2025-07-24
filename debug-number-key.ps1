#!/usr/bin/env pwsh
# Debug where number key input is getting consumed

Write-Host "=== Debug Number Key Input Flow ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "This will start PRAXIS and capture debug logs to trace number key input."
Write-Host "The goal is to understand where the '2' key gets consumed when you try"
Write-Host "to switch from Projects to Tasks tab."
Write-Host ""
Write-Host "Instructions:" -ForegroundColor Yellow
Write-Host "1. App will start on Projects tab"
Write-Host "2. Press '2' once to try switching to Tasks tab"
Write-Host "3. Press 'q' to quit immediately after"
Write-Host ""
Write-Host "Then we'll examine the logs to see the exact input flow."
Write-Host ""

# Clear the log
> _Logs/praxis.log

# Start PRAXIS 
pwsh -File Start.ps1 -Debug

# After it exits, show the relevant log entries
Write-Host ""
Write-Host "=== Input Flow Analysis ===" -ForegroundColor Cyan
Write-Host ""

# Show the key press and routing
Write-Host "Looking for '2' key press in logs:" -ForegroundColor Yellow
grep -A 20 -B 5 "Key pressed: D2\|KeyChar.*2" _Logs/praxis.log || Write-Host "No '2' key press found"

Write-Host ""
Write-Host "Looking for TabContainer input routing:" -ForegroundColor Yellow  
grep -A 10 -B 2 "TabContainer.*HandleInput\|TabContainer.*Routing" _Logs/praxis.log || Write-Host "No TabContainer routing found"

Write-Host ""
Write-Host "Looking for tab switching attempts:" -ForegroundColor Yellow
grep -A 5 -B 2 "Switching to tab\|ActivateTab" _Logs/praxis.log || Write-Host "No tab switching found"