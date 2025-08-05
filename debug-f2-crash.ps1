#!/usr/bin/env pwsh
# debug-f2-crash.ps1 - Debug the actual F2 crash

Write-Host "Starting SimpleTaskPro with debug info..." -ForegroundColor Cyan

try {
    # Launch SimpleTaskPro and capture any errors
    pwsh -Command "
        try {
            . './TaskPro/SimpleTaskPro.ps1'
        } catch {
            Write-Host 'Error in SimpleTaskPro startup:' -ForegroundColor Red
            Write-Host `$_ -ForegroundColor Red
            Write-Host `$_.ScriptStackTrace -ForegroundColor DarkGray
            Write-Host 'Exception details:' -ForegroundColor Yellow
            Write-Host `$_.Exception.GetType().FullName -ForegroundColor Yellow
            Write-Host `$_.Exception.Message -ForegroundColor Yellow
        }
    " 2>&1 | Tee-Object -FilePath "./debug-f2-output.txt"
    
} catch {
    Write-Host "Debug script error: $_" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor DarkGray
}

Write-Host ""
Write-Host "Debug output saved to debug-f2-output.txt" -ForegroundColor Green
Write-Host "Please share the error details so I can fix the F2 crash." -ForegroundColor Yellow