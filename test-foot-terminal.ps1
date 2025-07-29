#!/usr/bin/env pwsh

Write-Host "Testing Foot Terminal Compatibility" -ForegroundColor Yellow
Write-Host "===================================" -ForegroundColor Yellow

# Test basic ANSI sequences
Write-Host "`nTesting ANSI escape sequences:"
Write-Host "This should be red: $([char]27)[31mRed Text$([char]27)[0m"
Write-Host "This should be green: $([char]27)[32mGreen Text$([char]27)[0m"
Write-Host "This should be blue: $([char]27)[34mBlue Text$([char]27)[0m"

# Test cursor positioning
Write-Host "`nTesting cursor positioning:"
Write-Host "$([char]27)[10;20HText at position 10,20"
Start-Sleep -Milliseconds 500
Write-Host "$([char]27)[12;1H"

# Test true color support
Write-Host "`nTesting true color (24-bit):"
Write-Host "$([char]27)[48;2;51;34;0mBackground RGB(51,34,0)$([char]27)[0m"
Write-Host "$([char]27)[38;2;255;230;77mForeground RGB(255,230,77)$([char]27)[0m"

# Check terminal info
Write-Host "`nTerminal Information:"
Write-Host "TERM: $env:TERM"
Write-Host "COLORTERM: $env:COLORTERM"
Write-Host "Terminal size: $($Host.UI.RawUI.WindowSize.Width) x $($Host.UI.RawUI.WindowSize.Height)"

# Test the specific sequences used in TabContainer
Write-Host "`nTesting TabContainer sequences:"
$esc = [char]27
Write-Host "${esc}[1;1H${esc}[48;2;61;49;0m${esc}[38;2;204;163;0m 1:Projects ${esc}[48;2;51;34;0m"
Write-Host "If you see proper colors above, the sequences are working."

Write-Host "`nPossible fixes for foot:" -ForegroundColor Green
Write-Host "1. Try running with explicit locale:"
Write-Host "   LC_ALL=C.UTF-8 foot -e pwsh -file Start.ps1"
Write-Host ""
Write-Host "2. Check foot config (~/.config/foot/foot.ini):"
Write-Host "   Ensure you have:"
Write-Host "   [main]"
Write-Host "   term=xterm-256color"
Write-Host ""
Write-Host "3. Try with different TERM:"
Write-Host "   TERM=xterm-256color foot -e pwsh -file Start.ps1"