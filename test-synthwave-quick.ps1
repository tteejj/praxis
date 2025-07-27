#!/usr/bin/env pwsh
# Quick test of synthwave colors

# Test ANSI RGB colors directly
Write-Host "`nDirect ANSI Color Test:" -ForegroundColor Magenta

# Synthwave background (15, 0, 25) - deep purple-black
$bgColor = "`e[48;2;15;0;25m"
Write-Host "${bgColor}This should have deep purple-black background (15,0,25)`e[0m"

# Dialog background (25, 10, 40) - slightly lighter purple
$dialogBg = "`e[48;2;25;10;40m"
Write-Host "${dialogBg}This should have dialog purple background (25,10,40)`e[0m"

# Hot pink foreground
$pink = "`e[38;2;255;0;144m"
Write-Host "${pink}This should be hot pink text`e[0m"

# Cyan foreground
$cyan = "`e[38;2;0;255;255m"
Write-Host "${cyan}This should be electric cyan text`e[0m"

# Combined
Write-Host "${bgColor}${pink}Hot pink on deep purple background`e[0m"
Write-Host "${dialogBg}${cyan}Cyan on dialog background`e[0m"

Write-Host "`nIf you see grey backgrounds, your terminal may not support true color."