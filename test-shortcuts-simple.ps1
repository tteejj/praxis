#!/usr/bin/env pwsh
# Simple test to verify keyboard input

Write-Host "Testing keyboard input..." -ForegroundColor Cyan
Write-Host "Press keys to see what's captured (Ctrl+C to exit):" -ForegroundColor Yellow

while ($true) {
    if ([Console]::KeyAvailable) {
        $key = [Console]::ReadKey($true)
        
        Write-Host ""
        Write-Host "Key Pressed:" -ForegroundColor Green
        Write-Host "  Key: $($key.Key)" -ForegroundColor Gray
        Write-Host "  KeyChar: '$($key.KeyChar)'" -ForegroundColor Gray
        Write-Host "  KeyChar (int): $([int]$key.KeyChar)" -ForegroundColor Gray
        Write-Host "  Modifiers: $($key.Modifiers)" -ForegroundColor Gray
        
        if ($key.KeyChar) {
            Write-Host "  IsLetter: $([char]::IsLetter($key.KeyChar))" -ForegroundColor Gray
            Write-Host "  ToLower: '$([char]::ToLower($key.KeyChar))'" -ForegroundColor Gray
        }
        
        if (($key.Modifiers -band [System.ConsoleModifiers]::Control) -and 
            $key.Key -eq [System.ConsoleKey]::C) {
            break
        }
    }
    Start-Sleep -Milliseconds 50
}