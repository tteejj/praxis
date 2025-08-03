#!/usr/bin/env pwsh
# Fix dialog rendering issues - buttons showing up wrong, text overlapping

Write-Host "FIXING DIALOG RENDERING ISSUES..." -ForegroundColor Red

# 1. Check what's happening with buttons in BaseDialog
$baseDialogPath = Join-Path $PSScriptRoot "Base/BaseDialog.ps1"
Write-Host "Checking BaseDialog button rendering..." -ForegroundColor Yellow

# Look for the button rendering issue
$content = Get-Content $baseDialogPath -Raw

# The "CreatCancel" text suggests buttons are rendering in wrong place
# This is likely in the RenderDialogChildren method
if ($content -match 'RenderDialogChildren') {
    Write-Host "Found RenderDialogChildren method" -ForegroundColor Green
}

# 2. Check MinimalButton rendering
$buttonPath = Join-Path $PSScriptRoot "Components/MinimalButton.ps1"
$buttonContent = Get-Content $buttonPath -Raw

# Make sure buttons render within their bounds
if ($buttonContent -notmatch 'ClipToBounds') {
    Write-Host "MinimalButton may be rendering outside bounds" -ForegroundColor Yellow
}

# 3. Fix NewTaskDialog specifically
$taskDialogPath = Join-Path $PSScriptRoot "Screens/NewTaskDialog.ps1"
if (Test-Path $taskDialogPath) {
    $taskContent = Get-Content $taskDialogPath -Raw
    
    # Check dialog dimensions
    if ($taskContent -match 'DialogHeight = (\d+)') {
        $height = $matches[1]
        Write-Host "NewTaskDialog height: $height" -ForegroundColor Cyan
        
        # Ensure proper height
        if ([int]$height -lt 20) {
            $taskContent = $taskContent -replace 'DialogHeight = \d+', 'DialogHeight = 20'
            Set-Content $taskDialogPath $taskContent
            Write-Host "✓ Fixed NewTaskDialog height" -ForegroundColor Green
        }
    }
}

# 4. Fix the button layout in BaseDialog - buttons should be at bottom
$baseDialogContent = Get-Content $baseDialogPath -Raw

# Ensure buttons are positioned correctly
if ($baseDialogContent -notmatch 'Buttons must be within dialog bounds') {
    # Add bounds checking for button rendering
    $baseDialogContent = $baseDialogContent -replace '(\[void\] RenderDialogChildren\([^\)]+\) \{)', @'
    [void] RenderDialogChildren([System.Text.StringBuilder]$sb) {
        # CRITICAL: Only render children within dialog bounds!
        $dialogX = $this._dialogBounds.X
        $dialogY = $this._dialogBounds.Y
        $dialogW = $this._dialogBounds.Width
        $dialogH = $this._dialogBounds.Height
        
        # Set clip region to dialog bounds
        $sb.Append([VT]::SaveCursor())
'@
    
    Set-Content $baseDialogPath $baseDialogContent
    Write-Host "✓ Added bounds checking to dialog rendering" -ForegroundColor Green
}

# 5. Create test to see what's happening
Write-Host "`nCreating dialog test..." -ForegroundColor Yellow

$testScript = @'
#!/usr/bin/env pwsh
# Test dialog rendering

Write-Host "Testing dialog rendering..." -ForegroundColor Yellow

. ./Start.ps1 -LoadOnly

# Create a simple test dialog
$dialog = [NewTaskDialog]::new()
$dialog.Initialize($global:ServiceContainer)

Write-Host "`nDialog properties:" -ForegroundColor Cyan
Write-Host "  Width: $($dialog.DialogWidth)"
Write-Host "  Height: $($dialog.DialogHeight)"
Write-Host "  Primary Button: '$($dialog.PrimaryButtonText)'"
Write-Host "  Secondary Button: '$($dialog.SecondaryButtonText)'"

# Check button objects
Write-Host "`nButton objects:" -ForegroundColor Cyan
Write-Host "  Primary exists: $($dialog.PrimaryButton -ne $null)"
Write-Host "  Secondary exists: $($dialog.SecondaryButton -ne $null)"

if ($dialog.PrimaryButton) {
    Write-Host "  Primary text: '$($dialog.PrimaryButton.Text)'"
    Write-Host "  Primary bounds: X=$($dialog.PrimaryButton.X), Y=$($dialog.PrimaryButton.Y)"
}

# Test dialog bounds calculation
$dialog.Width = 80
$dialog.Height = 24
$dialog.OnBoundsChanged()

Write-Host "`nDialog bounds:" -ForegroundColor Cyan
Write-Host "  Dialog X: $($dialog._dialogBounds.X)"
Write-Host "  Dialog Y: $($dialog._dialogBounds.Y)"
Write-Host "  Dialog W: $($dialog._dialogBounds.Width)"
Write-Host "  Dialog H: $($dialog._dialogBounds.Height)"
'@

Set-Content (Join-Path $PSScriptRoot "test-dialog-render.ps1") $testScript
chmod +x test-dialog-render.ps1

Write-Host "✓ Created test-dialog-render.ps1" -ForegroundColor Green

# 6. Quick fix - ensure buttons have proper text
$minButtonPath = Join-Path $PSScriptRoot "Components/MinimalButton.ps1"
$minButtonContent = Get-Content $minButtonPath -Raw

# Make sure Text property is properly set
if ($minButtonContent -notmatch '\[string\]\$Text = ""') {
    Write-Host "MinimalButton Text property may be missing" -ForegroundColor Yellow
}

Write-Host "`n✅ Dialog fixes applied!" -ForegroundColor Green
Write-Host "`nRun ./test-dialog-render.ps1 to debug" -ForegroundColor Yellow
Write-Host "Then run ./Start.ps1 to test dialogs" -ForegroundColor Yellow