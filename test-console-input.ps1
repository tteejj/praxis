#!/usr/bin/env pwsh
# Test if console input gets broken after tab switching

Write-Host "=== Console Input Debug Test ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "This will add extra console debugging to understand the input freeze."
Write-Host ""

# Patch ScreenManager to add console state debugging
$patchFile = @'
# Temporary patch for ScreenManager to debug console input
$screenManagerPath = "./Core/ScreenManager.ps1"
$content = Get-Content $screenManagerPath -Raw

# Add console state check after KeyAvailable check
$patch = @"
                    if ([Console]::KeyAvailable) {
                        `$key = [Console]::ReadKey(`$true)
"@

$replacement = @"
                    # Debug console state
                    if (`$this._frameCount % 50 -eq 0) {
                        if (`$global:Logger) {
                            try {
                                `$keyAvail = [Console]::KeyAvailable
                                `$global:Logger.Debug("Console state check: KeyAvailable=`$keyAvail")
                            } catch {
                                `$global:Logger.Debug("Console state check failed: `$_")
                            }
                        }
                    }
                    
                    if ([Console]::KeyAvailable) {
                        `$key = [Console]::ReadKey(`$true)
"@

$content = $content -replace [regex]::Escape($patch), $replacement
$content | Set-Content $screenManagerPath -NoNewline
'@

# Create a temporary file with the patch
$patchFile | Out-File -FilePath "apply-debug-patch.ps1" -Encoding UTF8

Write-Host "Applying debug patch..." -ForegroundColor Yellow
. ./apply-debug-patch.ps1

Write-Host "Starting PRAXIS with console debugging..." -ForegroundColor Green
Write-Host ""
Write-Host "Test these steps:" -ForegroundColor Yellow
Write-Host "1. Press 2 to go to Tasks tab"
Write-Host "2. Press 1 to go back to Projects tab"
Write-Host "3. Try pressing any other key - does it respond?"
Write-Host ""

# Clear log
Clear-Content _Logs/praxis.log -ErrorAction SilentlyContinue

# Run PRAXIS
pwsh -File Start.ps1 -Debug

Write-Host ""
Write-Host "=== Checking for console state logs ===" -ForegroundColor Cyan
grep "Console state" _Logs/praxis.log | tail -20

# Clean up
Write-Host ""
Write-Host "Reverting patch..." -ForegroundColor Yellow
git checkout -- Core/ScreenManager.ps1
Remove-Item apply-debug-patch.ps1 -ErrorAction SilentlyContinue