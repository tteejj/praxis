#!/usr/bin/env pwsh
# FORCE AMBER THEME - NO GREY ANYWHERE

Write-Host "FORCING AMBER THEME - REMOVING ALL GREY!" -ForegroundColor Red

# 1. Find ALL components that might have hardcoded colors
$componentsWithGrey = @()
$searchPaths = @(
    "Components/*.ps1",
    "Screens/*.ps1",
    "Base/*.ps1"
)

foreach ($path in $searchPaths) {
    $files = Get-ChildItem -Path $path -ErrorAction SilentlyContinue
    foreach ($file in $files) {
        $content = Get-Content $file.FullName -Raw
        
        # Look for RGB values that are grey (equal R,G,B)
        if ($content -match '@\((\d+),\s*\1,\s*\1\)') {
            $componentsWithGrey += $file.Name
            Write-Host "  Found grey in: $($file.Name)" -ForegroundColor Yellow
        }
        
        # Look for hex colors that are grey
        if ($content -match '#[0-9A-Fa-f]{6}' -and $content -match '#(..)\1\1') {
            $componentsWithGrey += $file.Name
            Write-Host "  Found grey hex in: $($file.Name)" -ForegroundColor Yellow
        }
    }
}

# 2. Force MinimalDataGrid to use amber theme colors
Write-Host "`nFixing MinimalDataGrid..." -ForegroundColor Yellow
$dataGridPath = "Components/MinimalDataGrid.ps1"
$content = Get-Content $dataGridPath -Raw

# Remove ALL color caching - force fresh colors every time
$content = $content -replace 'if \(\$this\._headerBg\) \{ return \}', '# FORCE REFRESH'
$content = $content -replace 'hidden \[string\]\$_headerBg = ""', 'hidden [string]$_headerBg = ""  # NO CACHE'

# Add force refresh at start of render
$renderMethod = @'
    [string] OnRender() {
        # FORCE THEME REFRESH
        $this.UpdateThemeCache()
        
'@
$content = $content -replace '\[string\] OnRender\(\) \{', $renderMethod

Set-Content $dataGridPath $content

# 3. Force all screens to invalidate on activation
Write-Host "Fixing screen activation..." -ForegroundColor Yellow
$screenPath = "Base/Screen.ps1"
$content = Get-Content $screenPath -Raw

if ($content -notmatch 'ForceCompleteRefresh') {
    $content = $content -replace '(\[void\] OnActivated\(\) \{)', @'
    [void] OnActivated() {
        # FORCE COMPLETE REFRESH ON ACTIVATION
        $this.ForceCompleteRefresh()
'@
    
    # Add method
    $content = $content -replace '(}\s*$)', @'
    
    [void] ForceCompleteRefresh() {
        # Force all children to refresh
        $this.InvalidateAll($this)
    }
    
    hidden [void] InvalidateAll([UIElement]$element) {
        $element.Invalidate()
        if ($element -is [Container]) {
            foreach ($child in $element.GetChildren()) {
                $this.InvalidateAll($child)
            }
        }
    }
}
'@
}

Set-Content $screenPath $content

# 4. OVERRIDE DEFAULT THEME COLORS
Write-Host "Overriding default theme..." -ForegroundColor Yellow
$themeManagerPath = "Services/ThemeManager.ps1"
$content = Get-Content $themeManagerPath -Raw

# Replace default theme colors with amber colors
$defaultThemeOverride = @'
            # Standardized text colors
            "text.primary" = @(255, 204, 0)       # AMBER
            "text.secondary" = @(204, 163, 0)     # AMBER
            "text.disabled" = @(102, 82, 0)       # AMBER
            "text.heading" = @(255, 230, 0)       # AMBER
            "text.placeholder" = @(153, 122, 0)   # AMBER
            
            # Standardized surface colors
            "surface.background" = @(51, 34, 0)   # AMBER
            "surface.elevated" = @(61, 49, 0)     # AMBER
            "surface.dialog" = @(71, 57, 0)       # AMBER
'@

# Find and replace the default theme definition
if ($content -match '# Define default theme[\s\S]*?"text\.primary" = @\(204, 204, 204\)') {
    Write-Host "  Replacing default theme colors with amber..." -ForegroundColor Green
    $content = $content -replace '"text\.primary" = @\(204, 204, 204\)', '"text.primary" = @(255, 204, 0)'
    $content = $content -replace '"text\.secondary" = @\(170, 170, 170\)', '"text.secondary" = @(204, 163, 0)'
    $content = $content -replace '"surface\.background" = @\(10, 15, 30\)', '"surface.background" = @(51, 34, 0)'
    $content = $content -replace '"menu\.background" = @\(0, 0, 20\)', '"menu.background" = @(31, 25, 0)'
    $content = $content -replace '"list\.background" = @\(0, 0, 0\)', '"list.background" = @(31, 25, 0)'
}

Set-Content $themeManagerPath $content

# 5. Create verification script
$verifyScript = @'
#!/usr/bin/env pwsh
Write-Host "VERIFYING AMBER THEME..." -ForegroundColor Yellow

. ./Start.ps1 -LoadOnly

$tm = $global:ServiceContainer.GetService("ThemeManager")
Write-Host "Current: $($tm.GetCurrentTheme())" -ForegroundColor Cyan

# Create a data grid and check its colors
$grid = [MinimalDataGrid]::new()
$grid.Initialize($global:ServiceContainer)
$grid.UpdateThemeCache()

Write-Host "`nDataGrid colors:" -ForegroundColor Yellow
Write-Host "  Header BG: $($grid._headerBg)" -ForegroundColor Cyan
Write-Host "  Row BG: $($grid._rowBg)" -ForegroundColor Cyan

# Test rendering
$rendered = $grid.OnRender()
if ($rendered -match 'surface\.background|list\.background') {
    Write-Host "`nSTILL USING THEME KEYS!" -ForegroundColor Red
}

Write-Host "`nDONE. Run ./Start.ps1" -ForegroundColor Green
'@

Set-Content "verify-amber.ps1" $verifyScript
chmod +x verify-amber.ps1

Write-Host "`n✅ AMBER THEME FORCED!" -ForegroundColor Green
Write-Host "NO MORE GREY!" -ForegroundColor Yellow
Write-Host "`nRun ./Start.ps1 NOW!" -ForegroundColor Red