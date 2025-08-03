#!/usr/bin/env pwsh
# Direct test of dialog colors

. "$PSScriptRoot/Start.ps1" -LoadOnly

Write-Host "`n=== DIALOG COLOR DEBUG ===" -ForegroundColor Yellow

# Get theme manager
$tm = $global:ServiceContainer.GetService("ThemeManager")

Write-Host "`nCurrent theme: $($tm.GetCurrentTheme())"

# Test surface colors directly
$surfaceBg = $tm.GetRGB('surface.background')
$dialogBg = $tm.GetRGB('surface.dialog')

Write-Host "`nTheme surface colors:"
Write-Host "  surface.background: RGB($($surfaceBg -join ','))"
Write-Host "  surface.dialog: RGB($($dialogBg -join ','))"

# Create test dialog
Write-Host "`nCreating test dialog..."
$dialog = [NewProjectDialog]::new()
$dialog.Initialize($global:ServiceContainer)

# Check if dialog has theme
Write-Host "`nDialog theme check:"
Write-Host "  Has Theme: $(if ($dialog.Theme) { 'YES' } else { 'NO' })"
Write-Host "  Theme name: $($dialog.Theme.GetCurrentTheme())"

# Test rendering a small section
Write-Host "`nTesting dialog background render:"
$sb = [System.Text.StringBuilder]::new()

# Manually get surface background
$bgColor = $dialog.Theme.GetBgColor('surface.background')
Write-Host "  BG color sequence starts with: $($bgColor.Substring(0, [Math]::Min(20, $bgColor.Length)))"

# Check if it contains grey (ESC[48;2;40;40;40m would be grey)
if ($bgColor -match '48;2;(\d+);(\d+);(\d+)') {
    $r = [int]$matches[1]
    $g = [int]$matches[2] 
    $b = [int]$matches[3]
    Write-Host "  Actual RGB: $r, $g, $b"
    
    if ($r -eq $g -and $g -eq $b) {
        Write-Host "  WARNING: This is GREY!" -ForegroundColor Red
    } else {
        Write-Host "  This is colored (not grey)" -ForegroundColor Green
    }
}

# Check dialog surface color
$dialogSurfaceColor = $dialog.Theme.GetBgColor('surface.dialog')
Write-Host "`nDialog surface color:"
if ($dialogSurfaceColor -match '48;2;(\d+);(\d+);(\d+)') {
    $r = [int]$matches[1]
    $g = [int]$matches[2]
    $b = [int]$matches[3]
    Write-Host "  RGB: $r, $g, $b"
}

# Now let's see what's actually being rendered
Write-Host "`nChecking actual render output..."
$renderOutput = $dialog.OnRender()

# Look for grey colors in output
$greyPattern = '48;2;40;40;40|48;5;236|48;5;235|48;5;234'
if ($renderOutput -match $greyPattern) {
    Write-Host "  FOUND GREY IN RENDER OUTPUT!" -ForegroundColor Red
    
    # Find where it comes from
    $lines = $renderOutput -split "`e"
    $greyLines = $lines | Where-Object { $_ -match '48;2;40;40;40' }
    
    if ($greyLines) {
        Write-Host "  Grey appears in these sequences:" -ForegroundColor Yellow
        $greyLines | Select-Object -First 3 | ForEach-Object {
            Write-Host "    $_" -ForegroundColor Gray
        }
    }
} else {
    Write-Host "  No obvious grey found in render" -ForegroundColor Green
}

Write-Host "`n=== CHECKING COMPONENT COLORS ===" -ForegroundColor Yellow

# Check specific components that might have grey
$components = @(
    'Container',
    'BaseDialog', 
    'Screen',
    'MinimalTextBox',
    'DialogField'
)

foreach ($comp in $components) {
    $type = [Type]::GetType($comp)
    if ($type) {
        $instance = $type::new()
        if ($instance.PSObject.Properties['Theme']) {
            Write-Host "`n$comp has Theme property"
            
            # Check if it's using any hardcoded colors
            $methods = $type.GetMethods() | Where-Object { $_.Name -eq 'OnRender' -or $_.Name -eq 'RenderContent' }
            if ($methods) {
                Write-Host "  Has render methods - would need source analysis"
            }
        }
    }
}

Write-Host "`n=== DONE ===" -ForegroundColor Green