#!/usr/bin/env pwsh

# Test CommandLibraryScreen rendering
Write-Host "Testing CommandLibraryScreen rendering output..." -ForegroundColor Cyan

# Load framework
. "$PSScriptRoot/Start.ps1" -LoadOnly

try {
    Write-Host "Creating and setting up CommandLibraryScreen..." -ForegroundColor Yellow
    $screen = [CommandLibraryScreen]::new()
    $screen.Initialize($global:ServiceContainer)
    $screen.SetBounds(0, 0, 80, 25)
    
    Write-Host "Commands loaded: $($screen.CommandList.Items.Count)" -ForegroundColor Green
    
    # Test rendering
    Write-Host "`nTesting render output (first 500 chars)..." -ForegroundColor Cyan
    $renderOutput = $screen.OnRender()
    
    if ($renderOutput.Length -gt 0) {
        Write-Host "✓ Render output generated: $($renderOutput.Length) characters" -ForegroundColor Green
        
        # Show a sample of the render output (strip ANSI for readability)
        $sample = $renderOutput.Substring(0, [Math]::Min(500, $renderOutput.Length))
        $cleanSample = $sample -replace '\e\[[0-9;]*m', '' -replace '\e\[[0-9;]*[A-Za-z]', ''
        Write-Host "`nSample output (ANSI stripped):" -ForegroundColor Cyan
        Write-Host $cleanSample -ForegroundColor DarkGray
        
        # Check if it contains command titles
        $containsCommands = $renderOutput -match "@CurrentDate_YYYYMMDD"
        Write-Host "`nContains command titles: $containsCommands" -ForegroundColor $(if ($containsCommands) { "Green" } else { "Red" })
        
    } else {
        Write-Host "✗ No render output generated!" -ForegroundColor Red
    }
    
} catch {
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack: $($_.ScriptStackTrace)" -ForegroundColor DarkRed
}

Write-Host "`nTest completed!" -ForegroundColor Green