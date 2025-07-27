#!/usr/bin/env pwsh
# Test the synthwave theme

Write-Host "`nSynthwave Theme Test" -ForegroundColor Magenta
Write-Host "===================" -ForegroundColor Cyan
Write-Host ""
Write-Host "This will launch PRAXIS with the synthwave theme options." -ForegroundColor Yellow
Write-Host ""
Write-Host "To test the synthwave themes:" -ForegroundColor Green
Write-Host "1. Press 6 to go to Settings" 
Write-Host "2. Navigate to 'Theme' category"
Write-Host "3. Press Enter on 'Current Theme'"
Write-Host "4. Select 'synthwave-84' or 'synthwave-outrun'"
Write-Host "5. Press Enter to apply"
Write-Host ""
Write-Host "The synthwave-84 theme features:" -ForegroundColor Magenta
Write-Host "• Hot pink and electric cyan neon colors"
Write-Host "• Deep purple backgrounds"
Write-Host "• Gradient effects on borders and backgrounds"
Write-Host "• Retro 80s aesthetic"
Write-Host ""
Write-Host "The synthwave-outrun variant has:" -ForegroundColor Yellow
Write-Host "• Orange and purple sunset colors"
Write-Host "• Darker backgrounds"
Write-Host "• Sunset gradient effects"
Write-Host ""
Write-Host "Press any key to start..." -ForegroundColor Cyan
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

# Launch with synthwave-84 as default
& ./Start.ps1 -Theme "synthwave-84"