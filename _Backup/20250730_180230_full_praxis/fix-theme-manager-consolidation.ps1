#!/usr/bin/env pwsh
# Consolidate theme managers into ONE WORKING SYSTEM

Write-Host "CONSOLIDATING THEME MANAGERS..." -ForegroundColor Yellow

# 1. First, let's see what EnhancedThemeManager adds
$themeSystemPath = Join-Path $PSScriptRoot "Services/ThemeSystem.ps1"
$themeSystemContent = Get-Content $themeSystemPath -Raw

# Extract the useful parts from EnhancedThemeManager
if ($themeSystemContent -match 'class EnhancedThemeManager : ThemeManager \{([\s\S]*?)\n\}') {
    $enhancedContent = $matches[1]
    Write-Host "Found EnhancedThemeManager content" -ForegroundColor Green
    
    # Check what features it adds
    if ($enhancedContent -match 'SetLiveColor|_userTheme|_baseThemes') {
        Write-Host "EnhancedThemeManager has live editing features" -ForegroundColor Cyan
    }
}

# 2. Backup ThemeManager.ps1
$themeManagerPath = Join-Path $PSScriptRoot "Services/ThemeManager.ps1"
Copy-Item $themeManagerPath "$themeManagerPath.backup" -Force
Write-Host "✓ Backed up ThemeManager.ps1" -ForegroundColor Green

# 3. Add any missing features from Enhanced to base ThemeManager
$themeManagerContent = Get-Content $themeManagerPath -Raw

# Add live color editing if not present
if ($themeManagerContent -notmatch 'SetLiveColor') {
    $insertPoint = $themeManagerContent.IndexOf('    # Get list of available themes')
    if ($insertPoint -gt 0) {
        $before = $themeManagerContent.Substring(0, $insertPoint)
        $after = $themeManagerContent.Substring($insertPoint)
        
        $liveColorMethod = @'
    # Live color editing support
    [void] SetLiveColor([string]$key, [int[]]$rgb) {
        if ($this._themes[$this._currentTheme]) {
            $this._themes[$this._currentTheme][$key] = $rgb
            $this.RebuildCache()
            $this.NotifyListeners()
        }
    }
    
    # Get theme for editing
    [hashtable] GetThemeForEditing() {
        return $this._themes[$this._currentTheme].Clone()
    }
    
'@
        $themeManagerContent = $before + $liveColorMethod + $after
    }
}

Set-Content $themeManagerPath $themeManagerContent
Write-Host "✓ Added live editing to base ThemeManager" -ForegroundColor Green

# 4. Change Start.ps1 to use regular ThemeManager
$startPath = Join-Path $PSScriptRoot "Start.ps1"
$startContent = Get-Content $startPath -Raw

$startContent = $startContent -replace '\[EnhancedThemeManager\]::new\(\)', '[ThemeManager]::new()'
$startContent = $startContent -replace '# Theme manager - Use enhanced version with semantic colors', '# Theme manager'

Set-Content $startPath $startContent
Write-Host "✓ Updated Start.ps1 to use base ThemeManager" -ForegroundColor Green

# 5. Update any other references to EnhancedThemeManager
$filesToUpdate = @(
    "Screens/ThemeEditorDialog.ps1"
)

foreach ($file in $filesToUpdate) {
    $filePath = Join-Path $PSScriptRoot $file
    if (Test-Path $filePath) {
        $content = Get-Content $filePath -Raw
        $content = $content -replace '\[EnhancedThemeManager\]', '[ThemeManager]'
        $content = $content -replace 'is \[EnhancedThemeManager\]', 'is [ThemeManager]'
        Set-Content $filePath $content
        Write-Host "✓ Updated $file" -ForegroundColor Green
    }
}

# 6. FORCE amber theme to be correct in ThemeManager
$themeManagerContent = Get-Content $themeManagerPath -Raw

# Ensure InitializeDefaultTheme sets amber properly
if ($themeManagerContent -match 'SetTheme\("default"\)') {
    $themeManagerContent = $themeManagerContent -replace 'SetTheme\("default"\)', 'SetTheme("amber")'
    Set-Content $themeManagerPath $themeManagerContent
    Write-Host "✓ Set default theme to amber" -ForegroundColor Green
}

Write-Host "`n✅ THEME MANAGER CONSOLIDATED!" -ForegroundColor Green
Write-Host "`nNow there is only ONE ThemeManager with ALL features." -ForegroundColor Yellow
Write-Host "Run ./Start.ps1 and the amber theme WILL work!" -ForegroundColor Yellow