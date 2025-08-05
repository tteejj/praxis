#!/usr/bin/env pwsh

# Debug script to test pillbox alignment
$width = 10

# Test the positioning logic
Write-Host "Testing pillbox with width: $width"
Write-Host "Top border positions:"
Write-Host "  Position 0: ╭"
Write-Host "  Positions 1-$(($width-2)): ─"  
Write-Host "  Position $(($width-1)): ╮"
Write-Host ""
Write-Host "Right border should be at column: $(($width-1))"

# Visual test
$line1 = "╭" + ("─" * ($width - 2)) + "╮"
$line2 = "│" + (" " * ($width - 2)) + "│"
$line3 = "╰" + ("─" * ($width - 2)) + "╯"

Write-Host ""
Write-Host "Visual test:"
Write-Host $line1
Write-Host $line2  
Write-Host $line3

# Test with numbers to show column positions
Write-Host ""
Write-Host "Column positions (0-based):"
$numbers = ""
for ($i = 0; $i -lt $width; $i++) {
    $numbers += ($i % 10)
}
Write-Host $numbers
Write-Host $line1
Write-Host $line2
Write-Host $line3