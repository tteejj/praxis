#!/usr/bin/env pwsh
# Simple debug to see registered shortcuts

# Load the framework
. ./Start.ps1 -NoRun

# Check ShortcutManager
$sm = $global:ServiceContainer.GetService('ShortcutManager')
if ($sm) {
    Write-Host "ShortcutManager found" -ForegroundColor Green
    Write-Host "Total shortcuts: $($sm.Shortcuts.Count)" -ForegroundColor Yellow
    
    Write-Host "`nRegistered shortcuts:" -ForegroundColor Cyan
    $sm.Shortcuts | ForEach-Object {
        Write-Host "  - $($_.Id): Key=$($_.Key) Char='$($_.KeyChar)' Scope=$($_.Scope) Screen=$($_.ScreenType)"
    }
} else {
    Write-Host "ShortcutManager NOT FOUND!" -ForegroundColor Red
}