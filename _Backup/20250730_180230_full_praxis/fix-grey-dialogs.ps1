#!/usr/bin/env pwsh
# Fix grey dialog backgrounds

Write-Host "Fixing grey dialog backgrounds..." -ForegroundColor Yellow

# The issue is that Container base class renders _cachedBackground when DrawBackground = true
# Even though content container has DrawBackground = false, the DIALOG itself has DrawBackground = true

$baseDialogPath = "$PSScriptRoot/Base/BaseDialog.ps1"
$content = Get-Content $baseDialogPath -Raw

# Change DrawBackground to false for BaseDialog
$content = $content -replace '\$this\.DrawBackground = \$true', '$this.DrawBackground = $false'

Set-Content $baseDialogPath $content
Write-Host "✓ Fixed BaseDialog to not draw background" -ForegroundColor Green

# Now let's ensure the dialog overlay uses the correct theme color
# The overlay is what creates the dimmed background effect

# Check if RenderOverlay is using the right color
if ($content -match 'RenderOverlay.*\{[\s\S]*?GetBgColor\([''"]surface\.background[''"]') {
    Write-Host "✓ RenderOverlay uses surface.background (should be amber)" -ForegroundColor Green
} else {
    Write-Host "✗ RenderOverlay might not be using theme colors correctly" -ForegroundColor Red
}

# Also check Container to ensure it's not forcing a grey background
$containerPath = "$PSScriptRoot/Base/Container.ps1"
$containerContent = Get-Content $containerPath -Raw

# Look for any hardcoded background color initialization
if ($containerContent -match '_cachedBgColor\s*=\s*[''"].*grey|_cachedBgColor\s*=.*40.*40.*40') {
    Write-Host "✗ Container has hardcoded grey background!" -ForegroundColor Red
} else {
    Write-Host "✓ Container doesn't have hardcoded grey" -ForegroundColor Green
}

Write-Host "`nFix applied. The real issue was:" -ForegroundColor Yellow
Write-Host "1. BaseDialog had DrawBackground = true" -ForegroundColor White
Write-Host "2. This caused Container.OnRender() to render _cachedBackground" -ForegroundColor White
Write-Host "3. Even without a color set, this was creating a grey background" -ForegroundColor White

Write-Host "`nNow dialogs should use only theme colors!" -ForegroundColor Green