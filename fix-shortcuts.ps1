#!/usr/bin/env pwsh
# Fix shortcut issues

Write-Host "Applying shortcut fixes..." -ForegroundColor Yellow

# 1. Fix ShortcutManager debug logging to be more visible
$smPath = "Services/ShortcutManager.ps1"
$content = Get-Content $smPath -Raw

# Make the Matches method log at INFO level for debugging
$content = $content -replace 'if \(\$global:Logger\) \{\s*\$global:Logger\.Debug\("Shortcut\.Matches:', @'
if ($global:Logger) {
                $global:Logger.Info("Shortcut.Matches:'
@

# Make HandleKeyPress log at INFO level
$content = $content -replace '\$this\.Logger\.Debug\("ShortcutManager\.HandleKeyPress:', '$this.Logger.Info("ShortcutManager.HandleKeyPress:'

$content | Set-Content $smPath -Force
Write-Host "  Updated ShortcutManager logging" -ForegroundColor Green

# 2. Ensure ScreenManager properly gets the current screen type
$smPath = "Core/ScreenManager.ps1"
$content = Get-Content $smPath -Raw

# Add validation that screen type is correct
$newCheck = @'
$currentScreenType = if ($this._activeScreen) { $this._activeScreen.GetType().Name } else { "" }
                            $currentContext = ""
                            
                            # Check if CommandPalette exists and is visible
                            if ($this._activeScreen) {
                                $cmdPalette = $this._activeScreen.PSObject.Properties['CommandPalette']
                                if ($cmdPalette -and $cmdPalette.Value -and $cmdPalette.Value.IsVisible) {
                                    $currentContext = "CommandPalette"
                                }
                            }
                            
                            if ($global:Logger) {
                                $global:Logger.Info("ScreenManager: Active screen type = '$currentScreenType'")
                                $global:Logger.Info("Calling ShortcutManager.HandleKeyPress: Screen=$currentScreenType Context=$currentContext")
                            }
'@

$content = $content -replace '(\$currentScreenType = if.*?Calling ShortcutManager\.HandleKeyPress[^\}]+\})', $newCheck

$content | Set-Content $smPath -Force
Write-Host "  Updated ScreenManager validation" -ForegroundColor Green

# 3. Add temporary console output to see what's happening
$projectsPath = "Screens/ProjectsScreen.ps1"
$content = Get-Content $projectsPath -Raw

# Add console output when shortcuts are registered
$content = $content -replace '(\[void\] RegisterShortcuts\(\) \{[^}]+?)(\$shortcutManager = )', @'
$1
        Write-Host "[ProjectsScreen] Registering shortcuts..." -ForegroundColor Cyan
        $2
'@

$content = $content -replace '(if \(\$global:Logger\) \{\s*\$global:Logger\.Debug\("ProjectsScreen\.RegisterShortcuts: Registered 5 shortcuts"\))', @'
Write-Host "[ProjectsScreen] Registered 5 shortcuts successfully" -ForegroundColor Green
        $1
'@

$content | Set-Content $projectsPath -Force
Write-Host "  Updated ProjectsScreen debug output" -ForegroundColor Green

Write-Host "`nFixes applied. Run Start.ps1 to test" -ForegroundColor Green
Write-Host "Look for [ProjectsScreen] messages when navigating to screen 1" -ForegroundColor Yellow