#!/usr/bin/env pwsh
# Test script to verify ListBox OnSelectionChanged functionality

Write-Host "ListBox OnSelectionChanged Test" -ForegroundColor Cyan
Write-Host "===============================" -ForegroundColor Cyan
Write-Host ""

# Check ListBox implementation
Write-Host "Checking ListBox.ps1..." -ForegroundColor Yellow
$content = Get-Content "Components/ListBox.ps1" -Raw

$checks = 0
$passed = 0

# Check 1: OnSelectionChanged property exists
$checks++
if ($content -match '\[scriptblock\]\$OnSelectionChanged = \{\}') {
    Write-Host "  ✓ OnSelectionChanged property defined" -ForegroundColor Green
    $passed++
} else {
    Write-Host "  ✗ OnSelectionChanged property NOT found" -ForegroundColor Red
}

# Check 2: SelectIndex calls OnSelectionChanged
$checks++
if ($content -match 'SelectIndex[\s\S]*OnSelectionChanged[\s\S]*& \$this\.OnSelectionChanged') {
    Write-Host "  ✓ SelectIndex triggers OnSelectionChanged" -ForegroundColor Green
    $passed++
} else {
    Write-Host "  ✗ SelectIndex does NOT trigger OnSelectionChanged" -ForegroundColor Red
}

# Check 3: SetItems calls OnSelectionChanged
$checks++
if ($content -match 'SetItems[\s\S]*OnSelectionChanged[\s\S]*& \$this\.OnSelectionChanged') {
    Write-Host "  ✓ SetItems triggers OnSelectionChanged" -ForegroundColor Green
    $passed++
} else {
    Write-Host "  ✗ SetItems does NOT trigger OnSelectionChanged" -ForegroundColor Red
}

# Check SettingsScreen implementation
Write-Host "`nChecking SettingsScreen.ps1..." -ForegroundColor Yellow
$content = Get-Content "Screens/SettingsScreen.ps1" -Raw

# Check 4: SettingsScreen uses OnSelectionChanged
$checks++
if ($content -match 'CategoryList\.OnSelectionChanged = \{') {
    Write-Host "  ✓ SettingsScreen sets OnSelectionChanged callback" -ForegroundColor Green
    $passed++
} else {
    Write-Host "  ✗ SettingsScreen does NOT set OnSelectionChanged" -ForegroundColor Red
}

# Check 5: HandleInput is simplified
$checks++
if ($content -match 'HandleInput[\s\S]*return \(\[Screen\]\$this\)\.HandleInput\(\$key\)' -and 
    $content -notmatch 'previousSelection') {
    Write-Host "  ✓ HandleInput is simplified (no manual tracking)" -ForegroundColor Green
    $passed++
} else {
    Write-Host "  ✗ HandleInput still has manual selection tracking" -ForegroundColor Red
}

Write-Host ""
Write-Host "Results: $passed/$checks checks passed" -ForegroundColor $(if ($passed -eq $checks) { "Green" } else { "Yellow" })

if ($passed -eq $checks) {
    Write-Host "`nOnSelectionChanged implementation successful!" -ForegroundColor Green
    Write-Host ""
    Write-Host "To test manually:" -ForegroundColor Cyan
    Write-Host "1. Run: pwsh -File Start.ps1"
    Write-Host "2. Press '4' to go to Settings tab"
    Write-Host "3. Use arrow keys to navigate categories"
    Write-Host "4. Settings should update automatically when selection changes"
} else {
    Write-Host "`nSome checks failed. Please review the implementation." -ForegroundColor Yellow
}