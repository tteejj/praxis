#!/usr/bin/env pwsh
# Dialog bounds diagnostic tool

# Load framework
. "$PSScriptRoot/Start.ps1" -LoadOnly

Write-Host "`n=== DIALOG BOUNDS DIAGNOSTIC ===" -ForegroundColor Yellow

# Get console dimensions
$consoleWidth = [Console]::WindowWidth
$consoleHeight = [Console]::WindowHeight
Write-Host "Console dimensions: ${consoleWidth}x${consoleHeight}" -ForegroundColor Cyan

# Create test dialogs with different sizes
$testCases = @(
    @{ Width = 50; Height = 14; Name = "Standard" },
    @{ Width = 80; Height = 20; Name = "Large" },
    @{ Width = 30; Height = 10; Name = "Small" },
    @{ Width = 120; Height = 30; Name = "Oversized" }
)

foreach ($test in $testCases) {
    Write-Host "`nTesting $($test.Name) dialog (${test.Width}x${test.Height}):" -ForegroundColor Green
    
    # Create a custom dialog to test bounds
    $dialogCode = @"
class TestDialog : BaseDialog {
    TestDialog() : base("Test Dialog", $($test.Width), $($test.Height)) {
    }
}
"@
    
    Invoke-Expression $dialogCode
    
    $dialog = [TestDialog]::new()
    $dialog.Initialize($global:ServiceContainer)
    
    # Trigger bounds calculation
    $dialog.OnBoundsChanged()
    
    # Check bounds
    $bounds = $dialog._dialogBounds
    if ($bounds) {
        Write-Host "  Position: X=$($bounds.X), Y=$($bounds.Y)"
        Write-Host "  Size: Width=$($bounds.Width), Height=$($bounds.Height)"
        
        # Check if dialog fits on screen
        $fitsX = ($bounds.X + $bounds.Width) -le $consoleWidth
        $fitsY = ($bounds.Y + $bounds.Height) -le $consoleHeight
        
        if ($fitsX -and $fitsY) {
            Write-Host "  ✓ Fits on screen" -ForegroundColor Green
        } else {
            Write-Host "  ✗ EXCEEDS SCREEN BOUNDS!" -ForegroundColor Red
            if (-not $fitsX) {
                Write-Host "    X overflow: $(($bounds.X + $bounds.Width) - $consoleWidth) chars" -ForegroundColor Yellow
            }
            if (-not $fitsY) {
                Write-Host "    Y overflow: $(($bounds.Y + $bounds.Height) - $consoleHeight) chars" -ForegroundColor Yellow
            }
        }
        
        # Check centering
        $expectedX = [int](($consoleWidth - $test.Width) / 2)
        $expectedY = [int](($consoleHeight - $test.Height) / 2)
        
        if ($bounds.X -eq $expectedX -and $bounds.Y -eq $expectedY) {
            Write-Host "  ✓ Properly centered" -ForegroundColor Green
        } else {
            Write-Host "  ✗ Not centered correctly" -ForegroundColor Yellow
            Write-Host "    Expected: X=$expectedX, Y=$expectedY" -ForegroundColor Gray
        }
    } else {
        Write-Host "  ✗ No bounds calculated!" -ForegroundColor Red
    }
}

# Test dialog rendering clipping
Write-Host "`n=== RENDER CLIPPING TEST ===" -ForegroundColor Yellow

# Create a dialog that would overflow
$overflowDialog = [ConfirmationDialog]::new("This is a test message that should be properly contained within the dialog bounds")
$overflowDialog.DialogWidth = $consoleWidth + 10  # Intentionally too wide
$overflowDialog.Initialize($global:ServiceContainer)
$overflowDialog.OnBoundsChanged()

$bounds = $overflowDialog._dialogBounds
Write-Host "Overflow dialog bounds:"
Write-Host "  Requested width: $($overflowDialog.DialogWidth)"
Write-Host "  Actual X: $($bounds.X), Width: $($bounds.Width)"
Write-Host "  Right edge: $($bounds.X + $bounds.Width) (console width: $consoleWidth)"

if ($bounds.X + $bounds.Width -le $consoleWidth) {
    Write-Host "  ✓ Dialog properly constrained to screen" -ForegroundColor Green
} else {
    Write-Host "  ✗ Dialog would render outside screen!" -ForegroundColor Red
}

# Check child component bounds
Write-Host "`n=== CHILD COMPONENT BOUNDS ===" -ForegroundColor Yellow

$testDialog = [NewProjectDialog]::new()
$testDialog.Initialize($global:ServiceContainer)
$testDialog.OnBoundsChanged()

Write-Host "Dialog bounds: X=$($testDialog._dialogBounds.X), Y=$($testDialog._dialogBounds.Y), W=$($testDialog._dialogBounds.Width), H=$($testDialog._dialogBounds.Height)"

# Check if main layout is properly positioned
if ($testDialog._mainLayout) {
    Write-Host "Main layout bounds: X=$($testDialog._mainLayout.X), Y=$($testDialog._mainLayout.Y), W=$($testDialog._mainLayout.Width), H=$($testDialog._mainLayout.Height)"
    
    # Check if layout is inside dialog
    $layoutInsideDialog = $testDialog._mainLayout.X -ge $testDialog._dialogBounds.X + 1 -and
                         $testDialog._mainLayout.Y -ge $testDialog._dialogBounds.Y + 2 -and
                         $testDialog._mainLayout.X + $testDialog._mainLayout.Width -le $testDialog._dialogBounds.X + $testDialog._dialogBounds.Width - 1 -and
                         $testDialog._mainLayout.Y + $testDialog._mainLayout.Height -le $testDialog._dialogBounds.Y + $testDialog._dialogBounds.Height - 1
    
    if ($layoutInsideDialog) {
        Write-Host "  ✓ Layout properly contained within dialog" -ForegroundColor Green
    } else {
        Write-Host "  ✗ Layout exceeds dialog bounds!" -ForegroundColor Red
    }
}

Write-Host "`n=== RECOMMENDATIONS ===" -ForegroundColor Yellow
Write-Host "1. BaseDialog.OnBoundsChanged() appears to constrain dialogs to screen"
Write-Host "2. Check if child components respect parent bounds during rendering"
Write-Host "3. Verify RenderDialogChildren() clips content properly"
Write-Host "4. Consider implementing a proper clipping rectangle system"
Write-Host ""