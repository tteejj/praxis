#!/usr/bin/env pwsh

# Test CommandEditDialog button handlers specifically
Write-Host "Testing CommandEditDialog button handlers..." -ForegroundColor Cyan

# Load framework
. "$PSScriptRoot/Start.ps1" -LoadOnly

try {
    Write-Host "Creating CommandEditDialog..." -ForegroundColor Yellow
    $dialog = [CommandEditDialog]::new()
    $dialog.Initialize($global:ServiceContainer)
    $dialog.SetBounds(0, 0, 120, 40)
    $dialog.SetCommand($null)  # New command
    
    # Set some test data
    $dialog.CommandBox.Text = "echo 'test command'"
    $dialog.TitleBox.Text = "Test Command"
    
    Write-Host "Testing HandlePrimaryAction (Save button)..." -ForegroundColor Yellow
    try {
        $dialog.HandlePrimaryAction()
        Write-Host "  ✓ HandlePrimaryAction executed successfully" -ForegroundColor Green
    } catch {
        Write-Host "  ✗ HandlePrimaryAction failed: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "    Stack: $($_.ScriptStackTrace)" -ForegroundColor DarkRed
    }
    
    Write-Host "Testing HandleSecondaryAction (Cancel button)..." -ForegroundColor Yellow
    try {
        $dialog.HandleSecondaryAction()
        Write-Host "  ✓ HandleSecondaryAction executed successfully" -ForegroundColor Green
    } catch {
        Write-Host "  ✗ HandleSecondaryAction failed: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "    Stack: $($_.ScriptStackTrace)" -ForegroundColor DarkRed
    }
    
    Write-Host "Testing button OnClick handlers directly..." -ForegroundColor Yellow
    if ($dialog.PrimaryButton -and $dialog.PrimaryButton.OnClick) {
        try {
            & $dialog.PrimaryButton.OnClick
            Write-Host "  ✓ Primary button OnClick executed successfully" -ForegroundColor Green
        } catch {
            Write-Host "  ✗ Primary button OnClick failed: $($_.Exception.Message)" -ForegroundColor Red
        }
    } else {
        Write-Host "  - Primary button or OnClick not found" -ForegroundColor Yellow
    }
    
} catch {
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack: $($_.ScriptStackTrace)" -ForegroundColor DarkRed
}

Write-Host "`nTest completed!" -ForegroundColor Green