#!/usr/bin/env pwsh

# Quick bounds test
Write-Host "Testing TaskProPro bounds safety..." -ForegroundColor Cyan

# Test minimum bounds
$width = 50
$height = 15

Write-Host "Terminal size: ${width}x${height}" -ForegroundColor Yellow

# Test the same calculation as TaskProPro
$listStartY = 4
$listHeight = [Math]::Max(1, $height - 8)
$statusY = [Math]::Max($listStartY + $listHeight + 1, $height - 3)
$statusHeight = [Math]::Max(1, $height - $statusY)

Write-Host "List area: Y=$listStartY Height=$listHeight" -ForegroundColor Green
Write-Host "Status area: Y=$statusY Height=$statusHeight" -ForegroundColor Green

if ($statusY + $statusHeight -le $height) {
    Write-Host "✓ Bounds calculation is safe!" -ForegroundColor Green
} else {
    Write-Host "✗ Bounds calculation would overflow!" -ForegroundColor Red
}

Write-Host ""
Write-Host "Try running TaskProPro now with: pwsh TaskProPro.ps1" -ForegroundColor Cyan