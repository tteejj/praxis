#!/usr/bin/env pwsh

# Remove all debug logging from Services that could cause performance issues

Write-Host "Removing debug logging from Services..." -ForegroundColor Cyan

Get-ChildItem "/home/teej/projects/github/praxis/Services" -Name "*.ps1" | ForEach-Object {
    $file = "Services/$_"
    $fullPath = "/home/teej/projects/github/praxis/$file"
    
    Write-Host "Cleaning $file..." -ForegroundColor Yellow
    
    # Read content
    $content = Get-Content $fullPath -Raw
    $originalLength = $content.Length
    
    # Remove debug logging patterns - keep error and warning
    $patterns = @(
        '(?m)^\s*if \(\$global:Logger\) \{\s*\n\s*\$global:Logger\.Debug\([^}]+\}\s*\n',
        '(?m)\s*if \(\$global:Logger\) \{\s*\n\s*\$global:Logger\.Debug\([^}]+\}\s*',
        '(?m)\s*\$global:Logger\.Debug\([^)]+\)\s*\n'
    )
    
    foreach ($pattern in $patterns) {
        $content = $content -replace $pattern, ''
    }
    
    # Write back if changed
    if ($content.Length -ne $originalLength) {
        Set-Content $fullPath $content -NoNewline
        Write-Host "  Removed debug logging (saved $($originalLength - $content.Length) characters)" -ForegroundColor Green
    } else {
        Write-Host "  No debug logging found" -ForegroundColor Gray
    }
}

Write-Host "Services debug logging cleanup completed!" -ForegroundColor Green