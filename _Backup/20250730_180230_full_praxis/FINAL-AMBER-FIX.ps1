#!/usr/bin/env pwsh
# FINAL FIX - Make amber the ONLY theme everywhere

Write-Host "FINAL AMBER FIX - NO MORE GREY!" -ForegroundColor Red

# 1. Remove all other themes from ThemeManager
$themeManagerPath = "Services/ThemeManager.ps1"
$content = Get-Content $themeManagerPath -Raw

# Remove matrix theme registration
$content = $content -replace '\$this\.RegisterTheme\("matrix", \$matrixTheme\)', '# Matrix theme removed'
$content = $content -replace '\$this\.RegisterTheme\("matrix-rain", \$matrixRainTheme\)', '# Matrix-rain theme removed'

# Change final SetTheme to amber
$content = $content -replace '\$this\.SetTheme\("amber"\)', '$this.SetTheme("amber")
        $this._currentTheme = "amber"  # FORCE AMBER'

Set-Content $themeManagerPath $content
Write-Host "✓ Removed other themes, forced amber" -ForegroundColor Green

# 2. Force all list/grid background colors in RenderHelper
$renderHelperPath = "Core/RenderHelper.ps1"
if (Test-Path $renderHelperPath) {
    $content = Get-Content $renderHelperPath -Raw
    
    # Replace any background color calls with amber
    $content = $content -replace 'GetBgColor\(''surface\.background''\)', 'GetBgColor(''list.background'')'
    
    Set-Content $renderHelperPath $content
    Write-Host "✓ Fixed RenderHelper backgrounds" -ForegroundColor Green
}

# 3. Simple fix for MinimalDataGrid - remove OnRender theme update
$dataGridPath = "Components/MinimalDataGrid.ps1"
$content = Get-Content $dataGridPath -Raw

# Remove the UpdateThemeCache from OnRender
$content = $content -replace '# FORCE THEME REFRESH\s*\$this\.UpdateThemeCache\(\)', '# Theme already set in OnInitialize'

Set-Content $dataGridPath $content
Write-Host "✓ Fixed MinimalDataGrid rendering" -ForegroundColor Green

# 4. Create final test
$testScript = @'
#!/usr/bin/env pwsh
Write-Host "FINAL AMBER TEST" -ForegroundColor Yellow

. ./Start.ps1 -LoadOnly

$tm = $global:ServiceContainer.GetService("ThemeManager")
Write-Host "Current: $($tm.GetCurrentTheme())" -ForegroundColor Cyan
Write-Host "Available: $($tm.GetThemeNames() -join ', ')" -ForegroundColor Cyan

# Force rebuild cache
$tm.RebuildCache()

# Test a color
$menuBg = $tm.GetRGB("menu.background")
Write-Host "Menu BG: RGB($($menuBg -join ','))" -ForegroundColor $(if ($menuBg[0] -gt 0 -and $menuBg[2] -eq 0) {"Green"} else {"Red"})

Write-Host "`nRun ./Start.ps1" -ForegroundColor Yellow
'@

Set-Content "final-test.ps1" $testScript
chmod +x final-test.ps1

Write-Host "`n✅ FINAL FIX APPLIED!" -ForegroundColor Green
Write-Host "Amber is now the ONLY working theme!" -ForegroundColor Yellow