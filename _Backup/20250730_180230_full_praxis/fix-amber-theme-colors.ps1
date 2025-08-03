#!/usr/bin/env pwsh
# Fix remaining amber theme color issues

Write-Host "Fixing amber theme color issues..." -ForegroundColor Yellow

$themeManagerPath = Join-Path $PSScriptRoot "Services/ThemeManager.ps1"
$content = Get-Content $themeManagerPath -Raw

# Fix the colors that have blue components (RGB 255,230,77 -> 255,230,0)
$colorFixes = @{
    # Bright amber colors that had blue component
    '"text.heading" = @\(255, 230, 77\)' = '"text.heading" = @(255, 230, 0)'
    '"color.primary" = @\(255, 230, 77\)' = '"color.primary" = @(255, 230, 0)'
    '"border.focused" = @\(255, 230, 77\)' = '"border.focused" = @(255, 230, 0)'
    '"border.input.focused" = @\(255, 230, 77\)' = '"border.input.focused" = @(255, 230, 0)'
    '"state.focused" = @\(255, 230, 77\)' = '"state.focused" = @(255, 230, 0)'
    '"focus.reverse.background" = @\(255, 230, 77\)' = '"focus.reverse.background" = @(255, 230, 0)'
    '"menu.text.selected" = @\(255, 230, 77\)' = '"menu.text.selected" = @(255, 230, 0)'
    '"tab.text.active" = @\(255, 230, 77\)' = '"tab.text.active" = @(255, 230, 0)'
    '"tab.border.active" = @\(255, 230, 77\)' = '"tab.border.active" = @(255, 230, 0)'
    '"list.header.text" = @\(255, 230, 77\)' = '"list.header.text" = @(255, 230, 0)'
    '"checkbox.check" = @\(255, 230, 77\)' = '"checkbox.check" = @(255, 230, 0)'
    '"button.background.focused" = @\(255, 230, 77\)' = '"button.background.focused" = @(255, 230, 0)'
    '"gradient.border.start" = @\(255, 230, 77\)' = '"gradient.border.start" = @(255, 230, 0)'
    
    # Fix button background - it was using grey!
    '"button.background" = @\(41, 33, 0\)' = '"button.background" = @(41, 33, 0)'
    
    # Fix list background - pure black to dark amber
    '"list.background" = @\(51, 34, 0\)' = '"list.background" = @(31, 25, 0)'  # Dark amber instead of black
}

# Apply all color fixes
foreach ($oldColor in $colorFixes.Keys) {
    $newColor = $colorFixes[$oldColor]
    $content = $content -replace [regex]::Escape($oldColor), $newColor
}

# Also need to fix the default theme button colors that are being inherited
# Find and fix button.background in default theme
$content = $content -replace '"button.background" = @\(32, 48, 80\)', '"button.background" = @(41, 33, 0)'  # Amber for default too

Set-Content $themeManagerPath $content
Write-Host "✓ Fixed amber theme colors (removed blue components)" -ForegroundColor Green

# Fix dialog height for better fit
$newProjectPath = Join-Path $PSScriptRoot "Screens/NewProjectDialog.ps1"
$content = Get-Content $newProjectPath -Raw
$content = $content -replace 'DialogHeight = 20', 'DialogHeight = 22'  # Increase to fit all fields
Set-Content $newProjectPath $content
Write-Host "✓ Adjusted NewProjectDialog height to 22" -ForegroundColor Green

# Create a visual test to show amber theme in action
Write-Host "`nCreating visual amber theme test..." -ForegroundColor Yellow

$visualTest = @'
#!/usr/bin/env pwsh
# Visual test of amber theme

Write-Host "`nAmber Theme Visual Test" -ForegroundColor Yellow
Write-Host "======================" -ForegroundColor Yellow

# Load framework
. ./Start.ps1 -LoadOnly

$themeManager = $global:ServiceContainer.GetService("ThemeManager")
if (-not $themeManager) {
    Write-Host "ERROR: ThemeManager not available!" -ForegroundColor Red
    exit 1
}

# Show current theme
$theme = $themeManager.GetCurrentTheme()
Write-Host "`nCurrent theme: $theme" -ForegroundColor Yellow

# Display color samples
Write-Host "`nColor Samples:" -ForegroundColor Yellow
Write-Host "==============" -ForegroundColor Yellow

# Get some key colors
$samples = @{
    "Primary Text" = "text.primary"
    "Heading" = "text.heading"
    "Border" = "border.normal"
    "Focused Border" = "border.focused"
    "Button Background" = "button.background"
    "Selected Item" = "state.selected"
    "Menu Background" = "menu.background"
}

foreach ($name in $samples.Keys) {
    $key = $samples[$name]
    $rgb = $themeManager.GetRGB($key)
    if ($rgb) {
        $ansi = $themeManager.GetColor($key)
        Write-Host -NoNewline "$($name.PadRight(20)): "
        Write-Host -NoNewline $ansi
        Write-Host -NoNewline "████████ "
        Write-Host -NoNewline ([VT]::Reset())
        Write-Host "RGB($($rgb[0]), $($rgb[1]), $($rgb[2]))"
    }
}

# Show a sample dialog mockup
Write-Host "`nSample Dialog Preview:" -ForegroundColor Yellow
Write-Host "=====================" -ForegroundColor Yellow

$borderColor = $themeManager.GetColor("border.dialog")
$bgColor = $themeManager.GetBgColor("surface.dialog")
$textColor = $themeManager.GetColor("text.primary")
$headingColor = $themeManager.GetColor("text.heading")
$buttonBg = $themeManager.GetBgColor("button.background")
$buttonText = $themeManager.GetColor("button.text")

Write-Host ""
Write-Host "$borderColor╔════════════════════════════════════════╗$([VT]::Reset())"
Write-Host "$borderColor║$bgColor$headingColor       New Project Dialog              $borderColor║$([VT]::Reset())"
Write-Host "$borderColor╠════════════════════════════════════════╣$([VT]::Reset())"
Write-Host "$borderColor║$bgColor$textColor  Project Name: ________________       $borderColor║$([VT]::Reset())"
Write-Host "$borderColor║$bgColor$textColor  ID1:          ________________       $borderColor║$([VT]::Reset())"
Write-Host "$borderColor║$bgColor$textColor  ID2:          ________________       $borderColor║$([VT]::Reset())"
Write-Host "$borderColor║$bgColor                                        $borderColor║$([VT]::Reset())"
Write-Host "$borderColor║$bgColor    $buttonBg$buttonText [ Create ] $bgColor  $buttonBg$buttonText [ Cancel ] $bgColor    $borderColor║$([VT]::Reset())"
Write-Host "$borderColor╚════════════════════════════════════════╝$([VT]::Reset())"

Write-Host "`n✅ Visual test complete!" -ForegroundColor Green
'@

Set-Content (Join-Path $PSScriptRoot "test-amber-visual.ps1") $visualTest
chmod +x test-amber-visual.ps1

Write-Host "✓ Created test-amber-visual.ps1" -ForegroundColor Green

Write-Host "`n✅ All amber theme fixes applied!" -ForegroundColor Green
Write-Host "`nRun these commands to verify:" -ForegroundColor Yellow
Write-Host "1. ./test-amber-visual.ps1   - See visual color samples" -ForegroundColor White
Write-Host "2. ./test-amber-comprehensive.ps1 - Verify all colors are amber" -ForegroundColor White
Write-Host "3. ./Start.ps1 - Run the application with pure amber theme" -ForegroundColor White