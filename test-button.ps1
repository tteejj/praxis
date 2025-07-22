#!/usr/bin/env pwsh
# Test button rendering directly

# Load framework
. ./Core/VT100.ps1
. ./Core/ServiceContainer.ps1
. ./Services/Logger.ps1
. ./Services/ThemeManager.ps1
. ./Base/UIElement.ps1
. ./Components/Button.ps1

# Initialize services
$global:ServiceContainer = [ServiceContainer]::new()
$logger = [Logger]::new()
$global:Logger = $logger
$global:ServiceContainer.Register("Logger", $logger)

$themeManager = [ThemeManager]::new()
$global:ServiceContainer.Register("ThemeManager", $themeManager)

# Create a button
$button = [Button]::new("Test Button")
$button.Initialize($global:ServiceContainer)
$button.SetBounds(5, 5, 20, 3)

# Clear screen
Write-Host ([VT]::Clear())

# Render the button
$output = $button.Render()
Write-Host $output -NoNewline

# Position cursor below button
Write-Host ([VT]::MoveTo(0, 10))

# Show what the button thinks it has
Write-Host "Button Text: '$($button.Text)'"
Write-Host "Button Bounds: X=$($button.X) Y=$($button.Y) W=$($button.Width) H=$($button.Height)"
Write-Host "Cache empty: $([string]::IsNullOrEmpty($button._cachedRender))"

# Wait for key
Write-Host "`nPress any key to exit..."
[Console]::ReadKey($true) | Out-Null