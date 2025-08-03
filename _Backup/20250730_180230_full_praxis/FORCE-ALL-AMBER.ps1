#!/usr/bin/env pwsh
Write-Host "FORCING ALL AMBER - NO GREY ANYWHERE!" -ForegroundColor Red

# 1. First check current theme values
Write-Host "`nChecking current theme values..." -ForegroundColor Yellow
. ./Start.ps1 -LoadOnly

$tm = $global:ServiceContainer.GetService("ThemeManager")
$currentTheme = $tm.GetCurrentTheme()
Write-Host "Current theme: $currentTheme" -ForegroundColor Cyan

# Check some colors
$surfaceBg = $tm.GetRGB("surface.background")
$menuBg = $tm.GetRGB("menu.background")
$listBg = $tm.GetRGB("list.background")

Write-Host "surface.background: RGB($($surfaceBg -join ','))" -ForegroundColor $(if ($surfaceBg[0] -eq $surfaceBg[1] -and $surfaceBg[1] -eq $surfaceBg[2]) {"Red"} else {"Green"})
Write-Host "menu.background: RGB($($menuBg -join ','))" -ForegroundColor $(if ($menuBg[0] -eq $menuBg[1] -and $menuBg[1] -eq $menuBg[2]) {"Red"} else {"Green"})
Write-Host "list.background: RGB($($listBg -join ','))" -ForegroundColor $(if ($listBg[0] -eq $listBg[1] -and $listBg[1] -eq $listBg[2]) {"Red"} else {"Green"})

# 2. Fix the default theme to be amber
Write-Host "`nForcing default theme to use amber colors..." -ForegroundColor Yellow
$themeManagerPath = "Services/ThemeManager.ps1"
$content = Get-Content $themeManagerPath -Raw

# Replace default theme surface colors with amber
$content = $content -replace '"surface\.background" = @\(128, 128, 128\)', '"surface.background" = @(51, 34, 0)'
$content = $content -replace '"surface\.elevated" = @\(140, 140, 140\)', '"surface.elevated" = @(61, 49, 0)'
$content = $content -replace '"surface\.dialog" = @\(150, 150, 150\)', '"surface.dialog" = @(71, 57, 0)'

# Replace menu/list backgrounds in default theme
$content = $content -replace '"menu\.background" = @\(40, 40, 40\)', '"menu.background" = @(31, 25, 0)'
$content = $content -replace '"list\.background" = @\(30, 30, 30\)', '"list.background" = @(31, 25, 0)'

# Force theme cache rebuild
$content = $content -replace '(\$this\.SetTheme\("amber"\))', '$1
        $this.RebuildCache()
        $this._colorCache.Clear()
        $this._bgColorCache.Clear()'

Set-Content $themeManagerPath $content
Write-Host "✓ Updated ThemeManager default theme colors" -ForegroundColor Green

# 3. Force theme refresh in all screens
Write-Host "`nForcing theme refresh in base Screen class..." -ForegroundColor Yellow
$screenPath = "Base/Screen.ps1"
$content = Get-Content $screenPath -Raw

# Add theme refresh on activation
$content = $content -replace '(\[void\] OnActivated\(\) \{)', '$1
        # Force theme refresh
        if ($this.Theme) {
            $this.InvalidateAll($this)
        }'

Set-Content $screenPath $content
Write-Host "✓ Updated Screen base class" -ForegroundColor Green

# 4. Create test script
$testScript = @'
#!/usr/bin/env pwsh
Write-Host "Testing forced amber theme..." -ForegroundColor Yellow

. ./Start.ps1 -LoadOnly

$tm = $global:ServiceContainer.GetService("ThemeManager")
$tm.RebuildCache()

Write-Host "`nTheme: $($tm.GetCurrentTheme())" -ForegroundColor Cyan

# Test all surface colors
@("surface.background", "surface.elevated", "surface.dialog", 
  "menu.background", "list.background") | ForEach-Object {
    $rgb = $tm.GetRGB($_)
    $isGrey = ($rgb[0] -eq $rgb[1] -and $rgb[1] -eq $rgb[2] -and $rgb[0] -gt 20)
    Write-Host "$_ : RGB($($rgb -join ','))" -ForegroundColor $(if ($isGrey) {"Red"} else {"Green"})
}

Write-Host "`nRun ./Start.ps1 to test" -ForegroundColor Yellow
'@

Set-Content "test-amber-forced.ps1" $testScript
chmod +x test-amber-forced.ps1

Write-Host "`n✅ AMBER FORCED EVERYWHERE!" -ForegroundColor Green
Write-Host "Run ./test-amber-forced.ps1 to verify" -ForegroundColor Yellow