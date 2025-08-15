#!/usr/bin/env pwsh
# test-architecture.ps1 - Simple test of the Smart Component architecture

Set-Location $PSScriptRoot

# Load minimal dependencies to test the architecture
. "$PSScriptRoot/Core/ServiceContainer-Phase4.5.ps1"
. "$PSScriptRoot/Core/Logger.ps1"
. "$PSScriptRoot/Core/EventBus.ps1"
. "$PSScriptRoot/Core/Bootstrapper.ps1"

Write-Host "Testing Bootstrapper class definition..." -ForegroundColor Yellow
try {
    Write-Host "Creating ServiceContainer..." -ForegroundColor Green
    $container = [ServiceContainer]::new()
    Write-Host "ServiceContainer created successfully!" -ForegroundColor Green
    
    Write-Host "Testing Logger..." -ForegroundColor Green
    $logger = [Logger]::new()
    Write-Host "Logger created successfully!" -ForegroundColor Green
    
    Write-Host "Testing Bootstrapper..." -ForegroundColor Green
    Write-Host "Bootstrapper class is available: $([Bootstrapper] -ne $null)" -ForegroundColor Green
    
} catch {
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack: $($_.ScriptStackTrace)" -ForegroundColor DarkRed
}

Write-Host "Architecture test complete." -ForegroundColor Yellow