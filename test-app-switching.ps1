#!/usr/bin/env pwsh
# Test app switching functionality

Write-Host "Testing TaskPro app switching functionality..." -ForegroundColor Cyan
Write-Host ""

# Load core dependencies first
try {
    . "$PSScriptRoot/TaskPro/Core/StringCache.ps1"
    . "$PSScriptRoot/TaskPro/Components/Shared/VT100.ps1"
    . "$PSScriptRoot/TaskPro/Services/AppManager.ps1"
    Write-Host "✓ Core dependencies loaded" -ForegroundColor Green
} catch {
    Write-Host "✗ Failed to load core dependencies: $_" -ForegroundColor Red
    exit 1
}

# Load TaskPro dependencies (needed for TaskProApp)
try {
    . "$PSScriptRoot/TaskPro/Services/UnifiedThemeService.ps1"
    . "$PSScriptRoot/TaskPro/Screens/ColorPickerDialog.ps1"
    . "$PSScriptRoot/TaskPro/Screens/HybridColorPickerDialog.ps1"
    . "$PSScriptRoot/TaskPro/Screens/EnhancedThemeSettingsScreen.ps1"
    . "$PSScriptRoot/TaskPro/Core/TextEditor.ps1"
    . "$PSScriptRoot/TaskPro/Models/Project.ps1"
    . "$PSScriptRoot/TaskPro/Models/Task.ps1"
    . "$PSScriptRoot/TaskPro/Services/TaskService.ps1"
    . "$PSScriptRoot/TaskPro/Screens/TaskScreen.ps1"
    Write-Host "✓ TaskPro components loaded" -ForegroundColor Green
} catch {
    Write-Host "✗ Failed to load TaskPro components: $_" -ForegroundColor Red
    exit 1
}

# Load TaskProApp last
try {
    . "$PSScriptRoot/TaskPro/Core/TaskProApp.ps1"
    Write-Host "✓ TaskProApp loaded" -ForegroundColor Green
} catch {
    Write-Host "✗ Failed to load TaskProApp: $_" -ForegroundColor Red
    exit 1
}

# Initialize theme system
try {
    $userDataPath = Join-Path $PSScriptRoot "TaskPro/Data"
    if (-not (Test-Path $userDataPath)) {
        New-Item -ItemType Directory -Path $userDataPath -Force | Out-Null
    }
    [UnifiedThemeService]::Initialize($userDataPath)
    Write-Host "✓ Theme system initialized" -ForegroundColor Green
} catch {
    Write-Host "✗ Failed to initialize themes: $_" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Testing TaskProApp instantiation..." -ForegroundColor Yellow

# Test creating TaskProApp
try {
    $app = [TaskProApp]::new()
    Write-Host "✓ TaskProApp created successfully" -ForegroundColor Green
    Write-Host "  Current app: $($app.CurrentApp)" -ForegroundColor DarkGray
    Write-Host "  Available screens: $($app.AppScreens.Keys -join ', ')" -ForegroundColor DarkGray
} catch {
    Write-Host "✗ Failed to create TaskProApp: $_" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor DarkGray
    exit 1
}

Write-Host ""
Write-Host "Testing app switching methods..." -ForegroundColor Yellow

# Test switching to TimeTracker
try {
    $switched = $app.SwitchToApp("TimeTracker")
    if ($switched) {
        Write-Host "✓ Successfully switched to TimeTracker" -ForegroundColor Green
        Write-Host "  Current app: $($app.CurrentApp)" -ForegroundColor DarkGray
        Write-Host "  Current screen type: $($app.CurrentScreen.GetType().Name)" -ForegroundColor DarkGray
    } else {
        Write-Host "✗ Failed to switch to TimeTracker" -ForegroundColor Red
    }
} catch {
    Write-Host "✗ Error switching to TimeTracker: $_" -ForegroundColor Red
}

# Test switching to CommandLibrary
try {
    $switched = $app.SwitchToApp("CommandLibrary")
    if ($switched) {
        Write-Host "✓ Successfully switched to CommandLibrary" -ForegroundColor Green
        Write-Host "  Current app: $($app.CurrentApp)" -ForegroundColor DarkGray
        Write-Host "  Current screen type: $($app.CurrentScreen.GetType().Name)" -ForegroundColor DarkGray
    } else {
        Write-Host "✗ Failed to switch to CommandLibrary" -ForegroundColor Red
    }
} catch {
    Write-Host "✗ Error switching to CommandLibrary: $_" -ForegroundColor Red
}

# Test switching back to TaskPro
try {
    $switched = $app.SwitchToApp("TaskPro")
    if ($switched) {
        Write-Host "✓ Successfully switched back to TaskPro" -ForegroundColor Green
        Write-Host "  Current app: $($app.CurrentApp)" -ForegroundColor DarkGray
        Write-Host "  Current screen type: $($app.CurrentScreen.GetType().Name)" -ForegroundColor DarkGray
    } else {
        Write-Host "✗ Failed to switch back to TaskPro" -ForegroundColor Red
    }
} catch {
    Write-Host "✗ Error switching back to TaskPro: $_" -ForegroundColor Red
}

Write-Host ""
Write-Host "Cached screens summary:" -ForegroundColor Yellow
foreach ($appName in $app.AppScreens.Keys) {
    $screenType = $app.AppScreens[$appName].GetType().Name
    Write-Host "  $appName -> $screenType" -ForegroundColor DarkGray
}

Write-Host ""
if ($app.AppScreens.Count -eq 3) {
    Write-Host "✓ App switching integration working correctly!" -ForegroundColor Green
    exit 0
} else {
    Write-Host "✗ App switching has issues" -ForegroundColor Red
    exit 1
}