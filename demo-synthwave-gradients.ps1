#!/usr/bin/env pwsh
# Demo script showing how to use synthwave gradients in components

# Load the framework
. ./Start.ps1 -LoadOnly

Write-Host "`nSynthwave Gradient Demo" -ForegroundColor Magenta
Write-Host "======================" -ForegroundColor Cyan

# Get the theme manager and set synthwave theme
$themeManager = $global:ServiceContainer.GetService('ThemeManager')
$themeManager.SetTheme('synthwave-84')

Write-Host "`nGradient Examples:" -ForegroundColor Yellow

# Example 1: Border gradient
Write-Host "`n1. Neon Border Gradient (Pink to Cyan):" -ForegroundColor Green
$borderGradient = $themeManager.GetGradient('gradient.border.start', 'gradient.border.end', 10)
Write-Host "   " -NoNewline
foreach ($color in $borderGradient) {
    Write-Host "$color█" -NoNewline
}
Write-Host "[0m"

# Example 2: Background gradient
Write-Host "`n2. Background Gradient (Purple fade):" -ForegroundColor Green
$bgGradient = $themeManager.GetGradient('gradient.bg.start', 'gradient.bg.end', 10)
Write-Host "   " -NoNewline
foreach ($color in $bgGradient) {
    Write-Host "$color█" -NoNewline
}
Write-Host "[0m"

# Example 3: Custom gradient using theme colors
Write-Host "`n3. Custom Accent Gradient:" -ForegroundColor Green
$startRGB = $themeManager.GetRGB('primary')      # Hot pink
$endRGB = $themeManager.GetRGB('secondary')      # Electric cyan
$customGradient = [VT]::VerticalGradient($startRGB, $endRGB, 10)
Write-Host "   " -NoNewline
foreach ($color in $customGradient) {
    Write-Host "$color█" -NoNewline
}
Write-Host "[0m"

# Example 4: Using gradients in a mock component
Write-Host "`n4. Synthwave Component Example:" -ForegroundColor Green
Write-Host ""

# Draw a box with gradient border
$width = 40
$height = 8

# Top border with gradient
$topGradient = $themeManager.GetGradient('gradient.border.start', 'gradient.border.end', $width)
Write-Host -NoNewline "   "
for ($i = 0; $i -lt $width; $i++) {
    Write-Host "$($topGradient[$i % $topGradient.Count])═" -NoNewline
}
Write-Host "[0m"

# Side borders with content
$sideGradient = $themeManager.GetGradient('gradient.accent.start', 'gradient.accent.end', $height - 2)
for ($y = 0; $y -lt $height - 2; $y++) {
    $color = $sideGradient[$y % $sideGradient.Count]
    Write-Host -NoNewline "   $color║[0m"
    
    # Content area with purple background
    $bgColor = $themeManager.GetColor('surface')
    $fgColor = $themeManager.GetColor('on-surface')
    
    if ($y -eq 2) {
        Write-Host -NoNewline "$bgColor$fgColor"
        Write-Host -NoNewline "      SYNTHWAVE-84 THEME      ".PadRight($width - 2)
        Write-Host -NoNewline "[0m"
    } elseif ($y -eq 3) {
        Write-Host -NoNewline "$bgColor$fgColor"
        Write-Host -NoNewline "    Neon Dreams Come True     ".PadRight($width - 2)
        Write-Host -NoNewline "[0m"
    } else {
        Write-Host -NoNewline "$bgColor"
        Write-Host -NoNewline (" " * ($width - 2))
        Write-Host -NoNewline "[0m"
    }
    
    Write-Host "$color║[0m"
}

# Bottom border
Write-Host -NoNewline "   "
for ($i = 0; $i -lt $width; $i++) {
    $idx = $width - 1 - $i  # Reverse for bottom
    Write-Host "$($topGradient[$idx % $topGradient.Count])═" -NoNewline
}
Write-Host "[0m"

Write-Host "`n5. Theme Colors:" -ForegroundColor Green
@("primary", "secondary", "background", "surface", "focus", "error", "warning", "success") | ForEach-Object {
    $color = $themeManager.GetColor($_)
    Write-Host "   $_ : $color████[0m"
}

Write-Host "`nUse these gradients in your custom components for that" -ForegroundColor Cyan
Write-Host "authentic 80s synthwave aesthetic!" -ForegroundColor Magenta
Write-Host ""