#!/usr/bin/env pwsh

# Script to remove ALL debug logging from critical render components

Write-Host "Removing all debug logging from critical render components..." -ForegroundColor Cyan

$filesToClean = @(
    "Components/RangerFileTree.ps1",
    "Components/MinimalTextBox.ps1", 
    "Base/BaseDialog.ps1",
    "Screens/FileBrowserScreen.ps1",
    "Screens/TimeEntryScreen.ps1",
    "Screens/TestScreen.ps1"
)

foreach ($file in $filesToClean) {
    $fullPath = "/home/teej/projects/github/praxis/$file"
    if (Test-Path $fullPath) {
        Write-Host "Cleaning $file..." -ForegroundColor Yellow
        
        # Read the file
        $content = Get-Content $fullPath -Raw
        
        # Remove debug logging patterns (but keep error and warning logging)
        $patterns = @(
            '(?m)^\s*if \(\$global:Logger\) \{\s*\n\s*\$global:Logger\.Debug\([^}]+\}\s*\n',
            '(?m)\s*if \(\$global:Logger\) \{\s*\n\s*\$global:Logger\.Debug\([^}]+\}\s*',
            '(?m)\s*\$global:Logger\.Debug\([^)]+\)\s*\n'
        )
        
        $originalLength = $content.Length
        
        foreach ($pattern in $patterns) {
            $content = $content -replace $pattern, ''
        }
        
        # Write back if changed
        if ($content.Length -ne $originalLength) {
            Set-Content $fullPath $content -NoNewline
            Write-Host "  Removed debug logging from $file (saved $($originalLength - $content.Length) characters)" -ForegroundColor Green
        } else {
            Write-Host "  No debug logging found in $file" -ForegroundColor Gray
        }
    } else {
        Write-Host "  File not found: $file" -ForegroundColor Red
    }
}

Write-Host "Debug logging cleanup completed!" -ForegroundColor Green