#!/usr/bin/env pwsh
# Display "SYNTH" in braille font

Write-Host "`nSYNTH in 3x5 Braille Font:" -ForegroundColor Magenta
Write-Host "==========================" -ForegroundColor Cyan

# Define 3x5 font using 2x2 braille characters
# Each letter is 3 dots wide, 5 dots tall
# Using 2x2 braille chars (each braille char is 2x4 dots)

$font = @{
    'S' = @(
        "⡏⡉",  # Top row
        "⠸⠄",  # Middle row  
        "⠉⡇"   # Bottom row
    )
    'Y' = @(
        "⡇⡇",
        "⠈⠁",
        "⠀⡇"
    )
    'N' = @(
        "⡇⡇",
        "⡏⡇",
        "⡇⡇"
    )
    'T' = @(
        "⡏⡏",
        "⠀⡇",
        "⠀⡇"
    )
    'H' = @(
        "⡇⡇",
        "⡏⡇",
        "⡇⡇"
    )
}

# Display each row
for ($row = 0; $row -lt 3; $row++) {
    Write-Host -NoNewline "  "
    foreach ($letter in 'S','Y','N','T','H') {
        Write-Host -NoNewline $font[$letter][$row]
        Write-Host -NoNewline " "  # Space between letters
    }
    Write-Host ""
}

Write-Host "`nCompact version (single row):" -ForegroundColor Yellow
Write-Host -NoNewline "  "
foreach ($letter in 'S','Y','N','T','H') {
    # Just show middle row for ultra-compact
    Write-Host -NoNewline $font[$letter][1]
}
Write-Host ""

Write-Host "`nMicro version (2x3 per letter):" -ForegroundColor Green
# Even smaller - single braille char per letter
$micro = @{
    'S' = "⠾"
    'Y' = "⠽"
    'N' = "⠝"
    'T' = "⠞"
    'H' = "⠓"
}
Write-Host -NoNewline "  "
foreach ($letter in 'S','Y','N','T','H') {
    Write-Host -NoNewline $micro[$letter]
}
Write-Host "  (actual braille letters)"

Write-Host "`nFor comparison, regular text: SYNTH" -ForegroundColor White