#!/usr/bin/env pwsh
# Test Console.Read() as suggested by error message

Write-Host "Testing Console.Read()..." -ForegroundColor Cyan

try {
    Write-Host "Type characters and press Enter:"
    while ($true) {
        $byte = [Console]::Read()
        if ($byte -eq -1) {
            Write-Host "End of input"
            break
        }
        $char = [char]$byte
        Write-Host "Read: '$char' (byte: $byte)"
        
        if ($char -eq 'q') {
            Write-Host "Quit requested"
            break
        }
        
        if ($byte -eq 13) {  # Enter key
            Write-Host "Enter pressed"
        }
    }
} catch {
    Write-Host "Console.Read() failed: $_" -ForegroundColor Red
}