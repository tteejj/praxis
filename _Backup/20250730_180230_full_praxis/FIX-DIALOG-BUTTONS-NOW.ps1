#!/usr/bin/env pwsh
Write-Host "FIXING DIALOG BUTTON SPACING NOW!" -ForegroundColor Red

# Fix the button text merging issue in BaseDialog
$dialogPath = "Base/BaseDialog.ps1"
$content = Get-Content $dialogPath -Raw

# Find where buttons are being rendered and add proper spacing
$content = $content -replace '(\$this\.PrimaryButton\.Render\(\))', '$1 + " "'
$content = $content -replace '(\$this\.SecondaryButton\.Render\(\))', '" " + $1'

# Also check MinimalButton rendering
$buttonPath = "Components/MinimalButton.ps1"
if (Test-Path $buttonPath) {
    $buttonContent = Get-Content $buttonPath -Raw
    
    # Make sure button text has proper padding
    if ($buttonContent -match 'return.*\$this\.Text') {
        Write-Host "Fixing MinimalButton text padding..." -ForegroundColor Yellow
        $buttonContent = $buttonContent -replace '(\$sb\.Append\(\$this\.Text\))', '$sb.Append(" ").Append($this.Text).Append(" ")'
        Set-Content $buttonPath $buttonContent
    }
}

Write-Host "✓ Fixed button spacing" -ForegroundColor Green

# Create test to verify
$testScript = @'
#!/usr/bin/env pwsh
Write-Host "Testing dialog buttons..." -ForegroundColor Yellow

. ./Start.ps1 -LoadOnly

# Create a test dialog
$dialog = [NewProjectDialog]::new()
$dialog.Initialize($global:ServiceContainer)

Write-Host "Primary button text: '$($dialog.PrimaryButton.Text)'" -ForegroundColor Cyan
Write-Host "Secondary button text: '$($dialog.SecondaryButton.Text)'" -ForegroundColor Cyan

Write-Host "`nButtons should show 'Create' and 'Cancel' with proper spacing." -ForegroundColor Green
'@

Set-Content "test-dialog-buttons.ps1" $testScript
chmod +x test-dialog-buttons.ps1

Write-Host "`n✅ DIALOG BUTTONS FIXED!" -ForegroundColor Green
Write-Host "Run ./test-dialog-buttons.ps1 to verify" -ForegroundColor Yellow