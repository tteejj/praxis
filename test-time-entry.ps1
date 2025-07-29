#!/usr/bin/env pwsh

Write-Host "Testing Time Entry CRUD functionality..." -ForegroundColor Cyan

# Start the app with a test script
$testScript = @'
# Wait for app to load
Start-Sleep -Milliseconds 500

# Navigate to Time Entry tab
[System.Console]::Write("3")
Start-Sleep -Milliseconds 500

# Test new entry (n key)
Write-Host "`nTesting 'n' key for new entry..." -ForegroundColor Yellow
[System.Console]::Write("n")
Start-Sleep -Milliseconds 1000

# Press ESC to close if dialog opened
[System.Console]::Write([char]27)
Start-Sleep -Milliseconds 500

# Test quick entry (q key)  
Write-Host "`nTesting 'q' key for quick entry..." -ForegroundColor Yellow
[System.Console]::Write("q")
Start-Sleep -Milliseconds 1000

# Press ESC to close if dialog opened
[System.Console]::Write([char]27)
Start-Sleep -Milliseconds 500

# Test edit (e key)
Write-Host "`nTesting 'e' key for edit..." -ForegroundColor Yellow
[System.Console]::Write("e")
Start-Sleep -Milliseconds 1000

# Press ESC to close if dialog opened
[System.Console]::Write([char]27)
Start-Sleep -Milliseconds 500

# Exit app
[System.Console]::Write("Q")
'@

# Run the test
$testScript | pwsh -File Start.ps1 2>&1 | Out-Host

Write-Host "`nChecking log for errors..." -ForegroundColor Cyan
Get-Content _Logs/praxis.log -Tail 50 | Select-String -Pattern "(Error|Exception|time\.(new|edit|quick))" | ForEach-Object {
    Write-Host $_ -ForegroundColor Red
}