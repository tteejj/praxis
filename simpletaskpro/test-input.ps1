#!/usr/bin/env pwsh
# Simple input test to see what works

Write-Host "Testing input methods..." -ForegroundColor Cyan

# Test 1: Console.ReadKey
Write-Host "`n1. Testing Console.ReadKey..." -ForegroundColor Yellow
try {
    Write-Host "Press any key (Console.ReadKey):" -NoNewline
    $key1 = [Console]::ReadKey($true)
    Write-Host " Success! Key: $($key1.Key) Char: '$($key1.KeyChar)'" -ForegroundColor Green
} catch {
    Write-Host " Failed: $_" -ForegroundColor Red
}

# Test 2: Host.UI.RawUI
Write-Host "`n2. Testing Host.UI.RawUI..." -ForegroundColor Yellow
try {
    Write-Host "Press any key (Host.UI.RawUI):" -NoNewline
    $key2 = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    Write-Host " Success! VirtualKey: $($key2.VirtualKeyCode) Char: '$($key2.Character)'" -ForegroundColor Green
} catch {
    Write-Host " Failed: $_" -ForegroundColor Red
}

# Test 3: Read-Host
Write-Host "`n3. Testing Read-Host..." -ForegroundColor Yellow
try {
    $input = Read-Host "Enter a character"
    Write-Host "Success! Input: '$input'" -ForegroundColor Green
} catch {
    Write-Host "Failed: $_" -ForegroundColor Red
}

Write-Host "`nInput testing complete." -ForegroundColor Cyan