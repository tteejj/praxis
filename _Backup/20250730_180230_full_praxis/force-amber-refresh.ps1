#!/usr/bin/env pwsh
# Force complete amber theme refresh - fix rendering issues

Write-Host "FORCING COMPLETE AMBER THEME REFRESH!" -ForegroundColor Yellow

# 1. Clear all theme caches
Write-Host "`nClearing theme caches..." -ForegroundColor Yellow
Remove-Item -Path "$PSScriptRoot/_Cache/*" -Force -ErrorAction SilentlyContinue
Remove-Item -Path "$PSScriptRoot/_State/*" -Force -ErrorAction SilentlyContinue

# 2. Fix MinimalDataGrid to use theme colors properly
Write-Host "Fixing MinimalDataGrid rendering..." -ForegroundColor Yellow
$dataGridPath = Join-Path $PSScriptRoot "Components/MinimalDataGrid.ps1"
$content = Get-Content $dataGridPath -Raw

# Ensure it's not caching grey colors
$content = $content -replace 'hidden \[string\]\$_headerBg = ""', 'hidden [string]$_headerBg = ""  # NO CACHE'
$content = $content -replace 'hidden \[string\]\$_headerText = ""', 'hidden [string]$_headerText = ""  # NO CACHE'

# Force theme color refresh in OnInitialize
if ($content -notmatch 'UpdateThemeCache.*NO CACHE') {
    $content = $content -replace '(\[void\] UpdateThemeCache\(\) \{)', @'
    [void] UpdateThemeCache() {
        # FORCE AMBER THEME - NO GREY!
        if ($this.Theme) {
            # Invalidate any cached values
            $this._headerBg = ""
            $this._headerText = ""
            $this._rowBg = ""
            $this._rowAltBg = ""
            $this._selectedBg = ""
            $this._selectedText = ""
            $this._borderColor = ""
            $this._textColor = ""
            
            # Get fresh theme colors
'@
}

Set-Content $dataGridPath $content

# 3. Fix ProjectsScreen data grid
Write-Host "Fixing ProjectsScreen..." -ForegroundColor Yellow
$projectsPath = Join-Path $PSScriptRoot "Screens/ProjectsScreen.ps1"
$content = Get-Content $projectsPath -Raw

# Force theme refresh on screen activation
if ($content -notmatch 'OnActivated.*Invalidate') {
    $content = $content -replace '(\[void\] OnActivated\(\) \{)', @'
    [void] OnActivated() {
        # Force complete theme refresh
        if ($this.ProjectGrid) {
            $this.ProjectGrid.UpdateThemeCache()
            $this.ProjectGrid.Invalidate()
        }
'@
}

Set-Content $projectsPath $content

# 4. Fix Screen base class to force theme refresh
Write-Host "Fixing Screen base class..." -ForegroundColor Yellow
$screenPath = Join-Path $PSScriptRoot "Base/Screen.ps1"
$content = Get-Content $screenPath -Raw

# Add force refresh on theme change
if ($content -notmatch 'ForceThemeRefresh') {
    $content = $content -replace '(\[void\] OnInitialize\(\) \{)', @'
    [void] OnInitialize() {
        # Force theme refresh for all child components
        $this.Theme = $this.ServiceContainer.GetService("ThemeManager")
        if ($this.Theme) {
            $this.Theme.Subscribe({
                $this.ForceThemeRefresh()
            })
        }
'@
    
    # Add ForceThemeRefresh method
    $content = $content -replace '(}\s*$)', @'
    
    [void] ForceThemeRefresh() {
        # Recursively refresh all components
        $this.InvalidateRecursive($this)
    }
    
    hidden [void] InvalidateRecursive([UIElement]$element) {
        $element.Invalidate()
        if ($element.PSObject.Properties['UpdateThemeCache']) {
            $element.UpdateThemeCache()
        }
        if ($element -is [Container]) {
            foreach ($child in $element.GetChildren()) {
                $this.InvalidateRecursive($child)
            }
        }
    }
}
'@
}

Set-Content $screenPath $content

# 5. Create immediate test script
Write-Host "`nCreating immediate test..." -ForegroundColor Yellow
$testScript = @'
#!/usr/bin/env pwsh
# Test amber theme is working

Write-Host "Testing amber theme application..." -ForegroundColor Yellow

# Clear PowerShell type cache
[System.Management.Automation.PSInvalidCastException]
Remove-TypeData * -ErrorAction SilentlyContinue

# Load framework
. ./Start.ps1 -LoadOnly

# Force theme manager to amber
$tm = $global:ServiceContainer.GetService("ThemeManager")
$tm.SetTheme("amber")
$tm.RebuildCache()

# Test colors
Write-Host "`nTheme colors:" -ForegroundColor Yellow
$testKeys = @("menu.background", "list.background", "button.background", "surface.background")
foreach ($key in $testKeys) {
    $rgb = $tm.GetRGB($key)
    Write-Host "$key = RGB($($rgb -join ', '))"
}

Write-Host "`nIf any color shows grey (equal RGB values), the theme is NOT applied correctly!" -ForegroundColor Red
'@

Set-Content (Join-Path $PSScriptRoot "test-immediate.ps1") $testScript
chmod +x test-immediate.ps1

Write-Host "`n✅ FIXES APPLIED!" -ForegroundColor Green
Write-Host "`nNOW RUN:" -ForegroundColor Yellow
Write-Host "1. ./test-immediate.ps1 - Verify colors" -ForegroundColor White  
Write-Host "2. ./Start.ps1 - See amber theme (NO GREY!)" -ForegroundColor White