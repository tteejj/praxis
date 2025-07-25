#!/usr/bin/env pwsh

# Verify the RegisterShortcut fix is in place

Write-Host "Checking TimeEntryScreen RegisterShortcut calls..." -ForegroundColor Cyan

$content = Get-Content ./Screens/TimeEntryScreen.ps1 -Raw

# Check if we have the old format
if ($content -match 'RegisterShortcut\([^\@]') {
    Write-Host "ERROR: Found old RegisterShortcut format!" -ForegroundColor Red
    
    # Find the problematic lines
    $lines = $content -split "`n"
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match 'RegisterShortcut\([^\@]') {
            Write-Host "Line $($i+1): $($lines[$i].Trim())" -ForegroundColor Yellow
        }
    }
} else {
    Write-Host "✓ All RegisterShortcut calls use hashtable format" -ForegroundColor Green
    
    # Count them
    $matches = [regex]::Matches($content, 'RegisterShortcut\(@\{')
    Write-Host "  Found $($matches.Count) RegisterShortcut calls" -ForegroundColor White
}

# Also show a sample
Write-Host "`nSample RegisterShortcut call from line 212:" -ForegroundColor Cyan
$lines = $content -split "`n"
for ($i = 211; $i -lt 221 -and $i -lt $lines.Count; $i++) {
    Write-Host "$($i+1): $($lines[$i])" -ForegroundColor Gray
}