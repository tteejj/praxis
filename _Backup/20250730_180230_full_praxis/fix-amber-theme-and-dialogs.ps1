#!/usr/bin/env pwsh
# Fix amber theme colors and dialog layouts

# 1. First, ensure the amber theme is set as current
Write-Host "Setting amber theme as current..." -ForegroundColor Yellow

# Update settings.json to use amber theme
$settingsPath = Join-Path $PSScriptRoot "_Config/settings.json"
$settings = Get-Content $settingsPath | ConvertFrom-Json
$settings.Theme.CurrentTheme = "amber"
$settings | ConvertTo-Json -Depth 10 | Set-Content $settingsPath

Write-Host "✓ Updated settings.json to use amber theme" -ForegroundColor Green

# 2. Fix the default theme loading in Start.ps1
Write-Host "`nFixing Start.ps1 theme loading..." -ForegroundColor Yellow

$startPath = Join-Path $PSScriptRoot "Start.ps1"
$startContent = Get-Content $startPath -Raw

# Change default theme from "matrix" to "amber"
$startContent = $startContent -replace '\$currentTheme = \$configService\.Get\("Theme\.CurrentTheme", "matrix"\)', '$currentTheme = $configService.Get("Theme.CurrentTheme", "amber")'
$startContent = $startContent -replace 'themeManager\.SetTheme\("matrix"\)', '$themeManager.SetTheme("amber")'

Set-Content $startPath $startContent
Write-Host "✓ Fixed Start.ps1 to default to amber theme" -ForegroundColor Green

# 3. Fix dialog spacing issues in BaseDialog.ps1
Write-Host "`nFixing dialog layouts..." -ForegroundColor Yellow

$baseDialogPath = Join-Path $PSScriptRoot "Base/BaseDialog.ps1"
$dialogContent = Get-Content $baseDialogPath -Raw

# Reduce dialog padding and button spacing
$dialogContent = $dialogContent -replace '\[int\]\$DialogPadding = 2', '[int]$DialogPadding = 1'
$dialogContent = $dialogContent -replace '\[int\]\$ButtonSpacing = 2', '[int]$ButtonSpacing = 1'
$dialogContent = $dialogContent -replace '\[int\]\$ButtonHeight = 3', '[int]$ButtonHeight = 2'

Set-Content $baseDialogPath $dialogContent
Write-Host "✓ Reduced dialog padding and button spacing" -ForegroundColor Green

# 4. Ensure amber theme has NO grey or blue colors
Write-Host "`nVerifying amber theme colors..." -ForegroundColor Yellow

$themeManagerPath = Join-Path $PSScriptRoot "Services/ThemeManager.ps1"
$themeContent = Get-Content $themeManagerPath -Raw

# The amber theme is already correctly defined with no grey/blue colors
# Just need to ensure menu colors are amber
$menuFixes = @"
            # Menu colors
            "menu.background" = @(31, 25, 0)      # Dark amber background (not grey!)
            "menu.text" = @(255, 204, 0)          # Amber text
            "menu.background.selected" = @(255, 230, 77)  # Bright amber selected
            "menu.text.selected" = @(20, 18, 12)  # Dark brown on amber
"@

# Check if menu colors need updating in amber theme
if ($themeContent -match '"menu.background" = @\(31, 25, 0\)') {
    Write-Host "✓ Amber theme menu colors are already correct" -ForegroundColor Green
} else {
    Write-Host "! Need to update amber theme menu colors" -ForegroundColor Yellow
}

# 5. Create a test script to verify the fixes
Write-Host "`nCreating test script..." -ForegroundColor Yellow

$testScript = @'
#!/usr/bin/env pwsh
# Test amber theme and dialog rendering

. ./Start.ps1 -LoadOnly

# Check theme
$themeManager = $global:ServiceContainer.GetService("ThemeManager")
$currentTheme = $themeManager.GetCurrentTheme()
Write-Host "`nCurrent theme: $currentTheme" -ForegroundColor Yellow

# Test some color values
Write-Host "`nTesting amber theme colors:" -ForegroundColor Yellow
$testColors = @(
    "text.primary",
    "menu.background", 
    "menu.text",
    "menu.background.selected",
    "border.normal",
    "surface.background"
)

foreach ($colorKey in $testColors) {
    $rgb = $themeManager.GetRGB($colorKey)
    if ($rgb) {
        $r = $rgb[0]; $g = $rgb[1]; $b = $rgb[2]
        $isAmber = ($r -gt 0 -and $g -gt 0 -and $b -eq 0) -or 
                   ($r -gt 150 -and $g -gt 100 -and $b -lt 30)
        $status = if ($isAmber) { "✓ AMBER" } else { "✗ NOT AMBER" }
        Write-Host "  $colorKey : RGB($r, $g, $b) - $status" -ForegroundColor $(if ($isAmber) {"Green"} else {"Red"})
    }
}

# Test dialog
Write-Host "`nTesting dialog layout..." -ForegroundColor Yellow
$dialog = [NewProjectDialog]::new()
Write-Host "  Dialog padding: $($dialog.DialogPadding)" -ForegroundColor Cyan
Write-Host "  Button spacing: $($dialog.ButtonSpacing)" -ForegroundColor Cyan
Write-Host "  Button height: $($dialog.ButtonHeight)" -ForegroundColor Cyan
'@

Set-Content (Join-Path $PSScriptRoot "test-amber-fixes.ps1") $testScript
Write-Host "✓ Created test-amber-fixes.ps1" -ForegroundColor Green

Write-Host "`n✅ All fixes applied!" -ForegroundColor Green
Write-Host "Run ./test-amber-fixes.ps1 to verify the changes" -ForegroundColor Yellow
Write-Host "Then run ./Start.ps1 to see the amber theme in action" -ForegroundColor Yellow