#!/usr/bin/env pwsh
# test-format-function.ps1 - Test if Format-CommandDisplay is available

Write-Host "Testing Format-CommandDisplay function availability..." -ForegroundColor Cyan

try {
    # Load dependencies in same order as AppManager
    . "./TaskPro/Core/StringCache.ps1"
    . "./TaskPro/Components/Shared/VT100.ps1"
    . "./TaskPro/Services/UnifiedThemeService.ps1"
    . "./TaskPro/Components/Shared/ColorThemeService.ps1"
    
    Write-Host "Dependencies loaded successfully" -ForegroundColor Green
    
    # Test if Format-CommandDisplay function exists
    $formatFunc = Get-Command -Name "Format-CommandDisplay" -ErrorAction SilentlyContinue
    if ($formatFunc) {
        Write-Host "✓ Format-CommandDisplay function is available!" -ForegroundColor Green
        Write-Host "Function type: $($formatFunc.GetType().Name)" -ForegroundColor DarkGray
    } else {
        Write-Host "✗ Format-CommandDisplay function is NOT available" -ForegroundColor Red
    }
    
    # Test if we can call it
    Write-Host "Testing function call..." -ForegroundColor Yellow
    
    # Create a simple command object for testing
    $testCommand = [PSCustomObject]@{
        Title = "Test Command"
        Description = "Test Description"
        Tags = @("test")
        UseCount = 5
    }
    
    # Add GetDisplayText method
    $testCommand | Add-Member -MemberType ScriptMethod -Name "GetDisplayText" -Value {
        return "$($this.Title) - $($this.Description)"
    }
    
    $result = Format-CommandDisplay -Command $testCommand -Selected $false -Width 80 -SearchTerm ""
    Write-Host "✓ Format-CommandDisplay function call successful!" -ForegroundColor Green
    Write-Host "Result length: $($result.Length) characters" -ForegroundColor DarkGray
    
} catch {
    Write-Host "Error: $_" -ForegroundColor Red
    Write-Host "Exception type: $($_.Exception.GetType().FullName)" -ForegroundColor DarkGray
    Write-Host "Stack trace:" -ForegroundColor DarkGray
    Write-Host $_.ScriptStackTrace -ForegroundColor DarkGray
}