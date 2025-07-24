#!/usr/bin/env pwsh
# Add temporary debug output to understand shortcut issues

# Backup original files
Copy-Item "Services/ShortcutManager.ps1" "Services/ShortcutManager.ps1.bak" -Force
Copy-Item "Core/ScreenManager.ps1" "Core/ScreenManager.ps1.bak" -Force

Write-Host "Adding debug output to ShortcutManager and ScreenManager..." -ForegroundColor Yellow

# Add debug output to critical methods
$smContent = Get-Content "Services/ShortcutManager.ps1" -Raw

# Add console output to HandleKeyPress (in addition to logging)
$smContent = $smContent -replace '(\[bool\] HandleKeyPress.*?\{)', @'
$1
        Write-Host "[DEBUG] ShortcutManager.HandleKeyPress: Key=$($keyInfo.Key) Char='$($keyInfo.KeyChar)' Screen=$currentScreen" -ForegroundColor Magenta
'@

# Add console output when shortcuts match
$smContent = $smContent -replace '(if \(\$applicable\.Count -gt 0\) \{)', @'
Write-Host "[DEBUG] Applicable shortcuts: $($applicable.Count)" -ForegroundColor Cyan
        $1
'@

# Save modified ShortcutManager
$smContent | Set-Content "Services/ShortcutManager.ps1" -Force

Write-Host "Debug output added. Run PRAXIS and watch for [DEBUG] messages" -ForegroundColor Green
Write-Host "To restore original files, run: ./restore-shortcuts.ps1" -ForegroundColor Gray

# Create restore script
@'
#!/usr/bin/env pwsh
# Restore original files
Move-Item "Services/ShortcutManager.ps1.bak" "Services/ShortcutManager.ps1" -Force
Move-Item "Core/ScreenManager.ps1.bak" "Core/ScreenManager.ps1" -Force
Write-Host "Original files restored" -ForegroundColor Green
'@ | Set-Content "restore-shortcuts.ps1" -Force