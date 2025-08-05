#!/usr/bin/env pwsh
# Test AppManager service loading and management

Write-Host "Testing AppManager..." -ForegroundColor Cyan
Write-Host ""

# Load dependencies
try {
    . "$PSScriptRoot/TaskPro/Core/StringCache.ps1"
    . "$PSScriptRoot/TaskPro/Components/Shared/VT100.ps1"
    . "$PSScriptRoot/TaskPro/Services/AppManager.ps1"
    Write-Host "✓ Dependencies loaded" -ForegroundColor Green
} catch {
    Write-Host "✗ Failed to load dependencies: $_" -ForegroundColor Red
    exit 1
}

# Initialize AppManager
try {
    $basePath = "$PSScriptRoot/TaskPro"
    Write-Host "Base path: $basePath" -ForegroundColor DarkGray
    [AppManager]::Initialize($basePath)
    Write-Host "✓ AppManager initialized" -ForegroundColor Green
} catch {
    Write-Host "✗ Failed to initialize AppManager: $_" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Checking app availability..." -ForegroundColor Yellow

# Check which apps are available
$apps = @("CommandLibrary", "TimeTracker")
foreach ($app in $apps) {
    $available = [AppManager]::IsAppAvailable($app)
    if ($available) {
        Write-Host "  ✓ $app is available" -ForegroundColor Green
    } else {
        Write-Host "  ✗ $app is not available" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "Testing service loading..." -ForegroundColor Yellow

# Test loading CommandLibrary service
try {
    $cmdService = [AppManager]::GetService("CommandLibrary")
    if ($cmdService -ne $null) {
        Write-Host "  ✓ CommandLibrary service loaded" -ForegroundColor Green
        Write-Host "    Service type: $($cmdService.GetType().Name)" -ForegroundColor DarkGray
    } else {
        Write-Host "  ✗ CommandLibrary service is null" -ForegroundColor Red
    }
} catch {
    Write-Host "  ✗ Failed to load CommandLibrary service: $_" -ForegroundColor Red
}

# Test loading TimeTracker service
try {
    $timeService = [AppManager]::GetService("TimeTracker")
    if ($timeService -ne $null) {
        Write-Host "  ✓ TimeTracker service loaded" -ForegroundColor Green
        Write-Host "    Service type: $($timeService.GetType().Name)" -ForegroundColor DarkGray
    } else {
        Write-Host "  ✗ TimeTracker service is null" -ForegroundColor Red
    }
} catch {
    Write-Host "  ✗ Failed to load TimeTracker service: $_" -ForegroundColor Red
}

Write-Host ""
Write-Host "Testing screen creation..." -ForegroundColor Yellow

# Test creating CommandLibrary screen
try {
    $cmdScreen = [AppManager]::GetScreen("CommandLibrary")
    if ($cmdScreen -ne $null) {
        Write-Host "  ✓ CommandLibrary screen created" -ForegroundColor Green
        Write-Host "    Screen type: $($cmdScreen.GetType().Name)" -ForegroundColor DarkGray
    } else {
        Write-Host "  ✗ CommandLibrary screen is null" -ForegroundColor Red
    }
} catch {
    Write-Host "  ✗ Failed to create CommandLibrary screen: $_" -ForegroundColor Red
}

# Test creating TimeTracker screen
try {
    $timeScreen = [AppManager]::GetScreen("TimeTracker")
    if ($timeScreen -ne $null) {
        Write-Host "  ✓ TimeTracker screen created" -ForegroundColor Green
        Write-Host "    Screen type: $($timeScreen.GetType().Name)" -ForegroundColor DarkGray
    } else {
        Write-Host "  ✗ TimeTracker screen is null" -ForegroundColor Red
    }
} catch {
    Write-Host "  ✗ Failed to create TimeTracker screen: $_" -ForegroundColor Red
}

Write-Host ""
Write-Host "App Status Report:" -ForegroundColor Yellow
$allStatus = [AppManager]::GetAllAppStatus()
foreach ($status in $allStatus) {
    Write-Host "  $($status.Name):" -ForegroundColor White
    Write-Host "    Available: $($status.Available)" -ForegroundColor $(if ($status.Available) { "Green" } else { "Red" })
    Write-Host "    Service Loaded: $($status.ServiceLoaded)" -ForegroundColor $(if ($status.ServiceLoaded) { "Green" } else { "Yellow" })
    Write-Host "    Screen Created: $($status.ScreenCreated)" -ForegroundColor $(if ($status.ScreenCreated) { "Green" } else { "Yellow" })
}

$availableApps = [AppManager]::GetAvailableApps()
$loadedApps = [AppManager]::GetLoadedApps()

Write-Host ""
Write-Host "Summary:" -ForegroundColor Cyan
Write-Host "  Available apps: $($availableApps -join ', ')" -ForegroundColor Green
Write-Host "  Loaded apps: $($loadedApps -join ', ')" -ForegroundColor Green
Write-Host ""

if ($availableApps.Count -gt 0 -and $loadedApps.Count -gt 0) {
    Write-Host "✓ AppManager working correctly!" -ForegroundColor Green
    exit 0
} else {
    Write-Host "✗ AppManager has issues" -ForegroundColor Red
    exit 1
}