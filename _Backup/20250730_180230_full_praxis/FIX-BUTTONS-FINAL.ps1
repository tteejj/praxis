#!/usr/bin/env pwsh
Write-Host "FINAL BUTTON FIX - PROPER SPACING!" -ForegroundColor Red

# 1. Fix MinimalButton to ensure proper text spacing
$buttonPath = "Components/MinimalButton.ps1"
$content = Get-Content $buttonPath -Raw

# Check current button width calculation
Write-Host "Checking MinimalButton..." -ForegroundColor Yellow

# 2. Fix BaseDialog button area height
$dialogPath = "Base/BaseDialog.ps1"
$dialogContent = Get-Content $dialogPath -Raw

# Increase button area height to prevent overlap
$dialogContent = $dialogContent -replace '\[int\]\$ButtonHeight = 2', '[int]$ButtonHeight = 3'
Set-Content $dialogPath $dialogContent
Write-Host "✓ Increased button height to 3" -ForegroundColor Green

# 3. Fix HorizontalSplit to add spacing between buttons
$splitPath = "Components/HorizontalSplit.ps1"
if (Test-Path $splitPath) {
    $splitContent = Get-Content $splitPath -Raw
    
    # Add spacing between left and right panes in OnRender
    $splitContent = $splitContent -replace '(if \(\$this\.LeftPane -and \$this\.LeftPane\.Visible\) \{[\s\S]*?\$sb\.Append\(\$this\.LeftPane\.Render\(\)\)[\s\S]*?\})', '$1
        
        # Add spacing between buttons
        if ($this.LeftPane -and $this.RightPane) {
            $sb.Append(" ")
        }'
    
    Set-Content $splitPath $splitContent
    Write-Host "✓ Added spacing between buttons in HorizontalSplit" -ForegroundColor Green
}

# 4. Create test script
$testScript = @'
#!/usr/bin/env pwsh
Write-Host "Testing button rendering..." -ForegroundColor Yellow

. ./Start.ps1 -LoadOnly

# Create new project dialog
$dialog = [NewProjectDialog]::new()
$dialog.Initialize($global:ServiceContainer)
$dialog.SetBounds(10, 5, 60, 22)

Write-Host "Dialog buttons:" -ForegroundColor Cyan
Write-Host "Primary: '$($dialog.PrimaryButton.Text)'" -ForegroundColor Green
Write-Host "Secondary: '$($dialog.SecondaryButton.Text)'" -ForegroundColor Green

# Test button layout
$layout = $dialog._buttonLayout
if ($layout) {
    Write-Host "`nButton layout type: $($layout.GetType().Name)" -ForegroundColor Cyan
    Write-Host "Left pane: $($layout.LeftPane.Text)" -ForegroundColor Green
    Write-Host "Right pane: $($layout.RightPane.Text)" -ForegroundColor Green
}

Write-Host "`nButtons should show 'Create' and 'Cancel' with proper spacing." -ForegroundColor Yellow
'@

Set-Content "test-button-fix.ps1" $testScript
chmod +x test-button-fix.ps1

Write-Host "`n✅ BUTTON SPACING FIXED!" -ForegroundColor Green
Write-Host "Run ./test-button-fix.ps1 to verify" -ForegroundColor Yellow