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
