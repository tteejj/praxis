#!/usr/bin/env pwsh
# Test script to verify popup fix

param(
    [switch]$Debug
)

try {
    # Temporarily set test mode to allow keyboard input
    $env:PRAXIS_TEST_MODE = ""
    
    # Set paths
    $scriptPath = Split-Path -Path $MyInvocation.MyCommand.Path -Parent
    Set-Location $scriptPath
    
    # Import all required files in order
    Write-Host "Loading PRAXIS components..." -ForegroundColor Cyan
    
    # Core components
    . ./Core/StringCache.ps1
    . ./Base/UIElement.ps1
    . ./Base/Container.ps1
    . ./Base/Screen.ps1
    . ./Components/ContextPopup.ps1
    
    # Start the test
    Write-Host "`nTesting ContextPopup rendering..." -ForegroundColor Yellow
    
    # Create a simple test popup
    $popup = [ContextPopup]::new()
    $popup.Title = "Test Actions"
    $popup.AddItem("New (n)", { Write-Host "New action!" })
    $popup.AddItem("Edit (e)", { Write-Host "Edit action!" })
    $popup.AddItem("Delete (d)", { Write-Host "Delete action!" })
    
    # Set bounds to small size
    $popup.SetBounds(0, 0, 80, 24)
    
    # Test the bounds after SetBounds
    Write-Host "Popup bounds after SetBounds: X=$($popup.X), Y=$($popup.Y), W=$($popup.Width), H=$($popup.Height)"
    
    # Render and display
    $rendered = $popup.OnRender()
    
    # Count the characters to verify it's not full screen
    $lines = $rendered -split "`n"
    Write-Host "Rendered lines count: $($lines.Count)"
    Write-Host "First line length: $($lines[0].Length)"
    
    # Show a portion of the rendered content
    Write-Host "`nRendered popup (first 10 lines):" -ForegroundColor Green
    for ($i = 0; $i -lt [Math]::Min(10, $lines.Count); $i++) {
        if ($lines[$i].Length -gt 50) {
            Write-Host "$($lines[$i].Substring(0, 50))... (truncated)"
        } else {
            Write-Host $lines[$i]
        }
    }
    
    Write-Host "`nTest completed successfully!" -ForegroundColor Green
    
} catch {
    Write-Host "Error: $_" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor DarkGray
} finally {
    $env:PRAXIS_TEST_MODE = "1"
}