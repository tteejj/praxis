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
