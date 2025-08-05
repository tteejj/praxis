#!/usr/bin/env pwsh
# Test clipboard functionality

Write-Host "Testing clipboard functionality..." -ForegroundColor Cyan
Write-Host ""

$testText = "Test clipboard text $(Get-Date)"

Write-Host "Attempting to copy text: '$testText'" -ForegroundColor Yellow
Write-Host ""

try {
    if ($IsWindows -or $PSVersionTable.Platform -eq 'Win32NT') {
        Write-Host "Detected Windows - using Set-Clipboard" -ForegroundColor Green
        $testText | Set-Clipboard
        Write-Host "✓ Success!" -ForegroundColor Green
    } elseif ($IsMacOS) {
        Write-Host "Detected macOS - using pbcopy" -ForegroundColor Green
        $testText | & pbcopy
        Write-Host "✓ Success!" -ForegroundColor Green
    } elseif ($IsLinux) {
        Write-Host "Detected Linux - checking for clipboard utilities..." -ForegroundColor Green
        
        if (Get-Command xclip -ErrorAction SilentlyContinue) {
            Write-Host "Found xclip - using it" -ForegroundColor Green
            $testText | & xclip -selection clipboard
            Write-Host "✓ Success!" -ForegroundColor Green
        } elseif (Get-Command xsel -ErrorAction SilentlyContinue) {
            Write-Host "Found xsel - using it" -ForegroundColor Green
            $testText | & xsel --clipboard --input
            Write-Host "✓ Success!" -ForegroundColor Green
        } else {
            Write-Host "✗ No clipboard utility found!" -ForegroundColor Red
            Write-Host ""
            Write-Host "Please install xclip or xsel:" -ForegroundColor Yellow
            Write-Host "  Ubuntu/Debian: sudo apt-get install xclip" -ForegroundColor Cyan
            Write-Host "  Fedora: sudo dnf install xclip" -ForegroundColor Cyan
            Write-Host "  Arch: sudo pacman -S xclip" -ForegroundColor Cyan
        }
    } else {
        Write-Host "Unknown OS - trying Set-Clipboard" -ForegroundColor Yellow
        $testText | Set-Clipboard
        Write-Host "✓ Success!" -ForegroundColor Green
    }
} catch {
    Write-Host "✗ Clipboard operation failed: $_" -ForegroundColor Red
}

Write-Host ""
Write-Host "Try pasting (Ctrl+V) to see if it worked!" -ForegroundColor Cyan