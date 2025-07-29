#!/usr/bin/env pwsh

Write-Host "Testing PRAXIS Shortcut System" -ForegroundColor Cyan
Write-Host "==============================" -ForegroundColor Cyan

# Start application in background
$process = Start-Process pwsh -ArgumentList "-File", "Start.ps1" -PassThru

Write-Host "`nApplication started. Please test the following shortcuts:" -ForegroundColor Yellow
Write-Host ""
Write-Host "Main Screen Shortcuts:" -ForegroundColor Green
Write-Host "  1-9     : Switch to tab 1-9"
Write-Host "  Ctrl+Tab: Next tab"
Write-Host "  Alt+→   : Next tab"
Write-Host "  Alt+←   : Previous tab"
Write-Host "  F1      : Show help"
Write-Host ""
Write-Host "Projects Screen (Tab 1):" -ForegroundColor Green
Write-Host "  Enter   : View project details"
Write-Host "  n       : New project"
Write-Host "  e       : Edit project"
Write-Host "  d       : Delete project"
Write-Host "  v       : View details"
Write-Host "  F5/r    : Refresh"
Write-Host ""
Write-Host "Tasks Screen (Tab 2):" -ForegroundColor Green
Write-Host "  Enter   : Edit task"
Write-Host "  n       : New task"
Write-Host "  e       : Edit task"
Write-Host "  d       : Delete task"
Write-Host "  s       : Cycle status"
Write-Host "  p       : Cycle priority"
Write-Host "  t       : Toggle subtasks"
Write-Host "  a       : Add subtask"
Write-Host "  F5/r    : Refresh"
Write-Host ""
Write-Host "Project Details Screen:" -ForegroundColor Green
Write-Host "  ESC     : Go back"
Write-Host "  F5      : Refresh"
Write-Host ""
Write-Host "Global Shortcuts:" -ForegroundColor Green
Write-Host "  Ctrl+Q  : Quit application"
Write-Host "  /       : Command palette"
Write-Host ""

Write-Host "Press any key to stop the test..." -ForegroundColor Yellow
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

# Stop the application
if (-not $process.HasExited) {
    $process.Kill()
    Write-Host "`nApplication stopped." -ForegroundColor Cyan
}