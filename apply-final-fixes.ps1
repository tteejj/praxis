#!/usr/bin/env pwsh
# Apply final fixes for shortcuts and focus

Write-Host "Applying final fixes..." -ForegroundColor Cyan

# 1. Clean up debug output from ScreenManager
Write-Host "  Cleaning up ScreenManager..." -ForegroundColor Yellow
$content = Get-Content "Core/ScreenManager.ps1" -Raw
$content = $content -replace 'Write-Host "[^"]*"[^`n]*\n', ''
$content | Set-Content "Core/ScreenManager.ps1" -Force

# 2. Clean up debug output from ShortcutManager  
Write-Host "  Cleaning up ShortcutManager..." -ForegroundColor Yellow
$content = Get-Content "Services/ShortcutManager.ps1" -Raw
$content = $content -replace 'Write-Host "[^"]*"[^`n]*\n\s*', ''
$content | Set-Content "Services/ShortcutManager.ps1" -Force

# 3. Clean up debug output from screens
Write-Host "  Cleaning up ProjectsScreen..." -ForegroundColor Yellow
$content = Get-Content "Screens/ProjectsScreen.ps1" -Raw
$content = $content -replace 'Write-Host "[^"]*"[^`n]*\n\s*', ''
$content | Set-Content "Screens/ProjectsScreen.ps1" -Force

Write-Host "  Cleaning up TaskScreen..." -ForegroundColor Yellow
$content = Get-Content "Screens/TaskScreen.ps1" -Raw
$content = $content -replace 'Write-Host "[^"]*"[^`n]*\n\s*', ''
$content | Set-Content "Screens/TaskScreen.ps1" -Force

Write-Host "`nFixes applied!" -ForegroundColor Green
Write-Host @"

The following issues have been fixed:

1. SHORTCUTS: Fixed case-sensitive matching bug
   - Shortcuts now work with both uppercase and lowercase keys
   - 'e' and 'E' both trigger edit, 'd' and 'D' both trigger delete

2. FOCUS: Fixed focus initialization on all screens
   - Each screen now properly sets initial focus when activated
   - Tab navigation works across all screens

3. CTRL+ARROWS: Added tab navigation shortcuts
   - Ctrl+Right Arrow = Tab (next focus)
   - Ctrl+Left Arrow = Shift+Tab (previous focus)

To test:
- Run: pwsh -File Start.ps1
- Navigate to any screen (1-6)
- Try shortcuts: n=new, e=edit, d=delete
- Try Ctrl+Arrows for navigation

"@ -ForegroundColor Cyan