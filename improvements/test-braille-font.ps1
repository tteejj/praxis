#!/usr/bin/env pwsh
# Test braille font rendering

Write-Host "`nBraille Unicode Font Test" -ForegroundColor Cyan
Write-Host "========================" -ForegroundColor Cyan

# Braille patterns for a 3x5 font
$brailleFont = @{
    'A' = @("⠏⠹⠇", "⠇⠇⠇")  # Two rows of braille chars
    'B' = @("⠏⠏⠹", "⠇⠇⠏")
    '0' = @("⠏⠇⠹", "⠇⠇⠇")
    '1' = @("⠀⠇⠀", "⠀⠇⠀")
}

# Single character micro font (2x3)
$microFont = @{
    '0' = "⠔"  # dots 1,4,5
    '1' = "⠃"  # dots 1,2
    '2' = "⠗"  # dots 1,2,4,5
    '3' = "⠛"  # dots 1,2,4,5,6
    'A' = "⠁"  # dot 1
}

Write-Host "`n3x5 Braille Font (using 3x2 braille characters):" -ForegroundColor Yellow
foreach ($char in 'A', 'B', '0', '1') {
    if ($brailleFont.ContainsKey($char)) {
        Write-Host "`n$char :"
        Write-Host "  $($brailleFont[$char][0])"
        Write-Host "  $($brailleFont[$char][1])"
    }
}

Write-Host "`n2x3 Micro Font (single braille character):" -ForegroundColor Yellow
Write-Host "0123: " -NoNewline
foreach ($char in '0', '1', '2', '3') {
    if ($microFont.ContainsKey($char)) {
        Write-Host $microFont[$char] -NoNewline
    }
}
Write-Host ""

Write-Host "`nBraille Pattern Reference:" -ForegroundColor Yellow
Write-Host "Each braille character has 8 dots in a 2x4 grid:"
Write-Host "  1 4"
Write-Host "  2 5"
Write-Host "  3 6"
Write-Host "  7 8"

Write-Host "`nExample patterns:" -ForegroundColor Green
Write-Host "⠀ (blank) ⠁ (dot 1) ⠃ (dots 1,2) ⠇ (dots 1,2,3) ⠏ (dots 1,2,3,4)"
Write-Host "⠗ (dots 1,2,4,5) ⠛ (dots 1,2,4,5,6) ⠟ (all except 7,8)"

Write-Host "`nPossible uses:" -ForegroundColor Magenta
Write-Host "- Tiny status indicators"
Write-Host "- Compact data visualization"
Write-Host "- Mini graphs in tight spaces"
Write-Host "- Custom icons/symbols"