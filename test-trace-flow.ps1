#!/usr/bin/env pwsh
# Trace the exact flow of key handling

Write-Host "`nKey Handling Flow Test" -ForegroundColor Cyan
Write-Host "=====================" -ForegroundColor Cyan

# Clear log
if (Test-Path "_Logs/praxis.log") {
    Clear-Content "_Logs/praxis.log" 
}

# Add inline debug to ScreenManager
$smPath = "Core/ScreenManager.ps1"
$smContent = Get-Content $smPath -Raw

# Backup
Copy-Item $smPath "$smPath.bak" -Force

# Add debug output at key points
$smContent = $smContent -replace '(# Log key press for debugging)', @'
$1
                        Write-Host "[TRACE] Key: $($key.Key) Char: '$($key.KeyChar)' (int: $([int]$key.KeyChar))" -ForegroundColor Yellow
'@

$smContent = $smContent -replace '(if \(\$this._shortcutManager\) \{)', @'
Write-Host "[TRACE] Checking ShortcutManager..." -ForegroundColor Cyan
                        $1
'@

$smContent = $smContent -replace '(\$handled = \$this._shortcutManager\.HandleKeyPress)', @'
Write-Host "[TRACE] Calling ShortcutManager.HandleKeyPress with Screen=$currentScreenType" -ForegroundColor Magenta
                            $1
'@

$smContent = $smContent -replace '(if \(\$handled -and \$global:Logger\))', @'
Write-Host "[TRACE] ShortcutManager result: $handled" -ForegroundColor $(if ($handled) { 'Green' } else { 'Red' })
                            $1
'@

# Save modified content
$smContent | Set-Content $smPath -Force

Write-Host "Trace code added. Starting PRAXIS..." -ForegroundColor Green
Write-Host "Press 'e' on Projects screen and watch the output" -ForegroundColor Yellow
Write-Host ""

# Run PRAXIS
try {
    pwsh -File Start.ps1
}
finally {
    # Restore original
    Move-Item "$smPath.bak" $smPath -Force
    Write-Host "`nOriginal files restored" -ForegroundColor Green
}