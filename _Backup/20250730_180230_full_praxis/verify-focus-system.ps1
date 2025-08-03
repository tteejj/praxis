# Verification script for new focus system - automated test

# Load the framework
. "$PSScriptRoot/Start.ps1" -LoadOnly

Write-Host ""
Write-Host "=== FOCUS SYSTEM VERIFICATION ===" -ForegroundColor Green
Write-Host ""

# Test 1: Check theme colors
Write-Host "1. Theme System:" -ForegroundColor Yellow
$themeManager = $global:ServiceContainer.GetService('ThemeManager')
if ($themeManager) {
    $reverseBg = $themeManager.GetRGB('focus.reverse.background')
    $reverseText = $themeManager.GetRGB('focus.reverse.text')
    
    if ($reverseBg -and $reverseText) {
        Write-Host "   ✓ Reverse focus colors defined: BG=$($reverseBg -join ',') TEXT=$($reverseText -join ',')" -ForegroundColor Green
    } else {
        Write-Host "   ✗ Reverse focus colors missing" -ForegroundColor Red
    }
    
    Write-Host "   ✓ Current theme: $($themeManager.GetCurrentTheme())" -ForegroundColor Green
} else {
    Write-Host "   ✗ ThemeManager not available" -ForegroundColor Red
}

# Test 2: Check component classes
Write-Host ""
Write-Host "2. Component Classes:" -ForegroundColor Yellow

try {
    $textbox = [MinimalTextBox]::new()
    Write-Host "   ✓ MinimalTextBox class loaded" -ForegroundColor Green
} catch {
    Write-Host "   ✗ MinimalTextBox class failed: $_" -ForegroundColor Red
}

try {
    $button = [MinimalButton]::new("Test")
    Write-Host "   ✓ MinimalButton class loaded" -ForegroundColor Green
} catch {
    Write-Host "   ✗ MinimalButton class failed: $_" -ForegroundColor Red
}

try {
    . "$PSScriptRoot/Components/DialogField.ps1"
    $field = [DialogField]::new("Test Key", "placeholder")
    Write-Host "   ✓ DialogField class loaded" -ForegroundColor Green
} catch {
    Write-Host "   ✗ DialogField class failed: $_" -ForegroundColor Red
}

try {
    $dialog = [BaseDialog]::new("Test")
    Write-Host "   ✓ BaseDialog class loaded" -ForegroundColor Green
} catch {
    Write-Host "   ✗ BaseDialog class failed: $_" -ForegroundColor Red
}

# Test 3: Check focus system features
Write-Host ""
Write-Host "3. Focus System Features:" -ForegroundColor Yellow

$textbox = [MinimalTextBox]::new()
$textbox.Initialize($global:ServiceContainer)

# Test theme color caching
$textbox.UpdateColors()
if ($textbox._focusReverseBg -and $textbox._focusReverseText) {
    Write-Host "   ✓ Reverse colors cached in MinimalTextBox" -ForegroundColor Green
} else {
    Write-Host "   ✗ Reverse colors not cached properly" -ForegroundColor Red
}

Write-Host ""
Write-Host "=== VERIFICATION COMPLETE ===" -ForegroundColor Green
Write-Host ""
Write-Host "To see the focus system in action:" -ForegroundColor Cyan
Write-Host "  pwsh -File Start.ps1" -ForegroundColor White
Write-Host "  Then create a new project or task to test the dialog fields" -ForegroundColor Gray
Write-Host ""