#!/usr/bin/env pwsh

# Debug the closure creation issue
Write-Host "Testing closure creation..." -ForegroundColor Cyan

# Load framework
. "$PSScriptRoot/Start.ps1" -LoadOnly

try {
    Write-Host "Creating CommandEditDialog..." -ForegroundColor Yellow
    $dialog = [CommandEditDialog]::new()
    
    Write-Host "Checking if dialog exists..." -ForegroundColor Yellow
    if ($dialog) {
        Write-Host "  ✓ Dialog created" -ForegroundColor Green
    } else {
        Write-Host "  ✗ Dialog is null" -ForegroundColor Red
        return
    }
    
    Write-Host "Checking if SaveCommand method exists..." -ForegroundColor Yellow
    try {
        $method = $dialog | Get-Member -Name "SaveCommand" -MemberType Method
        if ($method) {
            Write-Host "  ✓ SaveCommand method found" -ForegroundColor Green
        } else {
            Write-Host "  ✗ SaveCommand method not found" -ForegroundColor Red
        }
    } catch {
        Write-Host "  ✗ Error checking SaveCommand: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    Write-Host "Testing simple closure creation..." -ForegroundColor Yellow
    try {
        $testClosure = { Write-Host "Test closure" }.GetNewClosure()
        if ($testClosure) {
            Write-Host "  ✓ Simple closure created successfully" -ForegroundColor Green
        }
    } catch {
        Write-Host "  ✗ Simple closure failed: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    Write-Host "Testing closure with method call..." -ForegroundColor Yellow
    try {
        $methodClosure = { $dialog.GetType().Name }.GetNewClosure()
        if ($methodClosure) {
            Write-Host "  ✓ Method closure created successfully" -ForegroundColor Green
            $result = & $methodClosure
            Write-Host "  ✓ Closure result: $result" -ForegroundColor Green
        }
    } catch {
        Write-Host "  ✗ Method closure failed: $($_.Exception.Message)" -ForegroundColor Red
    }
    
} catch {
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack: $($_.ScriptStackTrace)" -ForegroundColor DarkRed
}

Write-Host "`nTest completed!" -ForegroundColor Green