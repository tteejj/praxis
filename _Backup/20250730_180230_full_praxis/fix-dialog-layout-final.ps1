#!/usr/bin/env pwsh
# Fix dialog layout issues - proper button positioning and spacing

Write-Host "Fixing dialog layout issues..." -ForegroundColor Yellow

# 1. Fix NewProjectDialog height and spacing
$newProjectPath = Join-Path $PSScriptRoot "Screens/NewProjectDialog.ps1"
$content = Get-Content $newProjectPath -Raw

# Reduce dialog height to fit content better
$content = $content -replace 'DialogHeight = 30', 'DialogHeight = 20'

Set-Content $newProjectPath $content
Write-Host "✓ Fixed NewProjectDialog height" -ForegroundColor Green

# 2. Fix BaseDialog button positioning
$baseDialogPath = Join-Path $PSScriptRoot "Base/BaseDialog.ps1"
$content = Get-Content $baseDialogPath -Raw

# Fix the button height calculation
$content = $content -replace '# Leave 4 lines for buttons \(3 for button \+ 1 for spacing\)\s*\$buttonHeightLocal = 4', '# Leave 3 lines for buttons (2 for button + 1 for spacing)
        $buttonHeightLocal = 3'

# Fix content height calculation  
$content = $content -replace '\$contentHeightLocal = \$this\.DialogHeight - 4', '$contentHeightLocal = $this.DialogHeight - 3'

Set-Content $baseDialogPath $content
Write-Host "✓ Fixed BaseDialog button calculations" -ForegroundColor Green

# 3. Create enhanced test to see all amber theme colors
Write-Host "`nCreating comprehensive amber theme test..." -ForegroundColor Yellow

$testScript = @'
#!/usr/bin/env pwsh
# Comprehensive test of amber theme and dialog rendering

Write-Host "Starting amber theme test..." -ForegroundColor Yellow

# Load the framework
. ./Start.ps1 -LoadOnly

# Get theme manager
$themeManager = $global:ServiceContainer.GetService("ThemeManager")
if (-not $themeManager) {
    Write-Host "ERROR: ThemeManager not available!" -ForegroundColor Red
    exit 1
}

# Display current theme
$currentTheme = $themeManager.GetCurrentTheme()
Write-Host "`nCurrent theme: $currentTheme" -ForegroundColor Yellow

# Test ALL amber theme colors
Write-Host "`nTesting ALL amber theme colors:" -ForegroundColor Yellow
$allColorKeys = @(
    "text.primary", "text.secondary", "text.disabled", "text.heading", "text.placeholder",
    "surface.background", "surface.elevated", "surface.dialog",
    "color.primary", "color.secondary",
    "status.success", "status.warning", "status.error", "status.info",
    "border.normal", "border.focused", "border.dialog", "border.input", "border.input.focused",
    "state.selected", "state.hover", "state.pressed", "state.focused",
    "focus.reverse.background", "focus.reverse.text",
    "button.background", "button.text",
    "menu.background", "menu.text", "menu.background.selected", "menu.text.selected",
    "list.background", "list.header.background"
)

$nonAmberColors = @()
foreach ($colorKey in $allColorKeys) {
    $rgb = $themeManager.GetRGB($colorKey)
    if ($rgb) {
        $r = $rgb[0]; $g = $rgb[1]; $b = $rgb[2]
        
        # Check if it's amber/brown/yellow (no blue/grey)
        $isAmber = ($r -gt 0 -and $b -eq 0) -or # Pure amber/yellow
                   ($r -gt 150 -and $g -gt 100 -and $b -lt 30) -or # Bright amber
                   ($r -gt 0 -and $g -gt 0 -and $b -eq 0 -and $r -ge $g) -or # Dark amber
                   ($colorKey -match "success" -and $g -gt 200) -or # Green for success
                   ($colorKey -match "error" -and $r -gt 200) -or # Red for error
                   ($colorKey -match "info" -and $b -gt 200) # Blue for info
                   
        if (-not $isAmber) {
            $nonAmberColors += @{Key=$colorKey; RGB="($r,$g,$b)"}
            Write-Host "  ✗ $colorKey : RGB($r, $g, $b) - NOT AMBER!" -ForegroundColor Red
        } else {
            Write-Host "  ✓ $colorKey : RGB($r, $g, $b)" -ForegroundColor Green
        }
    }
}

if ($nonAmberColors.Count -gt 0) {
    Write-Host "`n⚠️  Found $($nonAmberColors.Count) non-amber colors!" -ForegroundColor Red
    Write-Host "These need to be fixed in the amber theme definition." -ForegroundColor Yellow
} else {
    Write-Host "`n✅ All colors are properly amber-themed!" -ForegroundColor Green
}

# Test dialog rendering
Write-Host "`nTesting dialog layout..." -ForegroundColor Yellow
try {
    $dialog = [NewProjectDialog]::new()
    $dialog.Initialize($global:ServiceContainer)
    
    Write-Host "  Dialog dimensions:" -ForegroundColor Cyan
    Write-Host "    Width: $($dialog.DialogWidth)" -ForegroundColor White
    Write-Host "    Height: $($dialog.DialogHeight)" -ForegroundColor White
    Write-Host "    Padding: $($dialog.DialogPadding)" -ForegroundColor White
    Write-Host "    Button Height: $($dialog.ButtonHeight)" -ForegroundColor White
    Write-Host "    Button Spacing: $($dialog.ButtonSpacing)" -ForegroundColor White
    
    # Check field count
    $fieldCount = 8 # Name, ID1, ID2, Notes, CAA, Request, T2020, DueDate
    $requiredHeight = 2 + # Title + top border
                      $fieldCount + # Fields
                      ($fieldCount - 1) + # Spacing between fields
                      1 + # Space before buttons
                      3 + # Button area
                      1   # Bottom border
    
    Write-Host "`n  Content analysis:" -ForegroundColor Cyan
    Write-Host "    Fields: $fieldCount" -ForegroundColor White
    Write-Host "    Required height: $requiredHeight" -ForegroundColor White
    Write-Host "    Actual height: $($dialog.DialogHeight)" -ForegroundColor White
    
    if ($dialog.DialogHeight -lt $requiredHeight) {
        Write-Host "    ⚠️  Dialog may be too short!" -ForegroundColor Yellow
    } else {
        Write-Host "    ✓ Dialog height is adequate" -ForegroundColor Green
    }
    
} catch {
    Write-Host "  ✗ Error creating dialog: $_" -ForegroundColor Red
}

Write-Host "`n✅ Test complete!" -ForegroundColor Green
Write-Host "Run ./Start.ps1 to see the amber theme in action" -ForegroundColor Yellow
'@

Set-Content (Join-Path $PSScriptRoot "test-amber-comprehensive.ps1") $testScript
chmod +x test-amber-comprehensive.ps1

Write-Host "✓ Created test-amber-comprehensive.ps1" -ForegroundColor Green

# 4. Fix any remaining hardcoded colors in components
Write-Host "`nChecking for hardcoded colors in components..." -ForegroundColor Yellow

# Components that might have hardcoded colors
$componentsToCheck = @(
    "Components/MinimalListBox.ps1",
    "Components/MinimalDataGrid.ps1",
    "Components/MinimalButton.ps1",
    "Screens/ProjectsScreen.ps1"
)

foreach ($component in $componentsToCheck) {
    $path = Join-Path $PSScriptRoot $component
    if (Test-Path $path) {
        $content = Get-Content $path -Raw
        
        # Check for hardcoded RGB values (looking for patterns like @(128, 128, 128))
        if ($content -match '@\(\d+,\s*\d+,\s*\d+\)') {
            Write-Host "  ⚠️  Found hardcoded colors in $component" -ForegroundColor Yellow
        } else {
            Write-Host "  ✓ $component uses theme colors" -ForegroundColor Green
        }
    }
}

Write-Host "`n✅ All fixes applied!" -ForegroundColor Green
Write-Host "`nNext steps:" -ForegroundColor Yellow
Write-Host "1. Run ./test-amber-comprehensive.ps1 to verify amber theme" -ForegroundColor White
Write-Host "2. Run ./Start.ps1 to see the application with amber theme" -ForegroundColor White
Write-Host "3. Check the Projects screen and dialogs for proper amber colors" -ForegroundColor White