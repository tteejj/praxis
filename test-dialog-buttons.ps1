#!/usr/bin/env pwsh

# Test CommandEditDialog button functionality
Write-Host "Testing CommandEditDialog button functionality..." -ForegroundColor Cyan

# Load framework
. "$PSScriptRoot/Start.ps1" -LoadOnly

try {
    Write-Host "Creating CommandEditDialog..." -ForegroundColor Yellow
    $dialog = [CommandEditDialog]::new()
    $dialog.Initialize($global:ServiceContainer)
    $dialog.SetBounds(0, 0, 120, 40)
    $dialog.SetCommand($null)  # New command
    
    Write-Host "Testing SaveCommand method..." -ForegroundColor Yellow
    
    # Set some sample data
    $dialog.TitleBox.Text = "Test Command"
    $dialog.DescriptionBox.Text = "Test Description"
    $dialog.TagsBox.Text = "test, example"
    $dialog.GroupBox.Text = "Test Group"
    $dialog.CommandBox.Text = "echo 'Hello World'"
    
    try {
        $dialog.SaveCommand()
        Write-Host "  ✓ SaveCommand executed successfully" -ForegroundColor Green
    } catch {
        Write-Host "  ✗ SaveCommand failed: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    Write-Host "Testing Cancel method..." -ForegroundColor Yellow
    try {
        $dialog.Cancel()
        Write-Host "  ✓ Cancel executed successfully" -ForegroundColor Green
    } catch {
        Write-Host "  ✗ Cancel failed: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    # Test button handlers via BaseDialog
    Write-Host "Testing BaseDialog button handlers..." -ForegroundColor Yellow
    try {
        $dialog.HandlePrimaryAction()
        Write-Host "  ✓ Primary button handler executed successfully" -ForegroundColor Green
    } catch {
        Write-Host "  ✗ Primary button handler failed: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    try {
        $dialog.HandleSecondaryAction()
        Write-Host "  ✓ Secondary button handler executed successfully" -ForegroundColor Green
    } catch {
        Write-Host "  ✗ Secondary button handler failed: $($_.Exception.Message)" -ForegroundColor Red
    }
    
} catch {
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack: $($_.ScriptStackTrace)" -ForegroundColor DarkRed
}

Write-Host "`nTest completed!" -ForegroundColor Green