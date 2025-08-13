#!/usr/bin/env pwsh
# SimpleTaskPro-Phase5.ps1 - Bulletproof layered startup for Phase 5 architecture
# Implements dependency loading order that prevents "Unable to find type" errors

param([switch]$Debug)

Set-Location $PSScriptRoot
$global:Debug = $Debug

Write-Host "Starting SimpleTaskPro Phase 5 with bulletproof dependency loading..." -ForegroundColor Green

try {
    # ========================================
    # LAYER 0: Core Utilities (No Dependencies)
    # ========================================
    Write-Host "Layer 0: Core utilities..." -ForegroundColor Cyan
    
    . "$PSScriptRoot/Core/StringCache.ps1"  # Performance cache (must be first)
    . "$PSScriptRoot/Core/VT100.ps1"        # Depends on StringCache
    . "$PSScriptRoot/Core/GapBuffer.ps1"
    
    Write-Host "✅ Layer 0 loaded" -ForegroundColor Green
    
    # ========================================
    # LAYER 1: Foundation Services (Minimal Dependencies)
    # ========================================
    Write-Host "Layer 1: Foundation services..." -ForegroundColor Cyan
    
    . "$PSScriptRoot/Core/Logger.ps1"           # Singleton Logger
    . "$PSScriptRoot/Core/EventBus.ps1"         # Singleton EventBus
    . "$PSScriptRoot/Core/SimpleStateManager.ps1" # PowerShell-native state
    . "$PSScriptRoot/Core/ServiceContainer-Phase4.5.ps1" # Service container
    
    Write-Host "✅ Layer 1 loaded" -ForegroundColor Green
    
    # ========================================
    # LAYER 2: Data Models (Foundation Only)
    # ========================================
    Write-Host "Layer 2: Data models..." -ForegroundColor Cyan
    
    . "$PSScriptRoot/Models/SimpleTask.ps1"
    . "$PSScriptRoot/Models/SimpleTimeEntry.ps1"
    . "$PSScriptRoot/Models/Command.ps1"
    
    Write-Host "✅ Layer 2 loaded" -ForegroundColor Green
    
    # ========================================
    # LAYER 3: Rendering Infrastructure
    # ========================================
    Write-Host "Layer 3: Rendering infrastructure..." -ForegroundColor Cyan
    
    . "$PSScriptRoot/Core/AppThemeManager.ps1"
    . "$PSScriptRoot/Core/FastLineBuilder.ps1"
    . "$PSScriptRoot/Core/RenderEngine.ps1"
    . "$PSScriptRoot/Core/UnifiedRenderer.ps1"
    
    Write-Host "✅ Layer 3 loaded" -ForegroundColor Green
    
    # ========================================
    # LAYER 4: Input Processing
    # ========================================
    Write-Host "Layer 4: Input processing..." -ForegroundColor Cyan
    
    . "$PSScriptRoot/Core/InputProcessor.ps1"
    
    Write-Host "✅ Layer 4 loaded" -ForegroundColor Green
    
    # ========================================
    # LAYER 5: Base Classes (Clean Hierarchy)
    # ========================================
    Write-Host "Layer 5: Base classes..." -ForegroundColor Cyan
    
    . "$PSScriptRoot/Base/Screen.ps1"     # Base screen class
    . "$PSScriptRoot/Base/ListScreen.ps1"  # List screen base (inherits from Screen)
    
    Write-Host "✅ Layer 5 loaded" -ForegroundColor Green
    
    # ========================================
    # LAYER 6: Utility Components (Needed by Services)
    # ========================================
    Write-Host "Layer 6: Utility components..." -ForegroundColor Cyan
    
    . "$PSScriptRoot/Core/UniversalBackupManager.ps1" # Needed by services
    . "$PSScriptRoot/Core/FileBrowser.ps1"
    . "$PSScriptRoot/Core/FullNotesEditor.ps1"
    . "$PSScriptRoot/Core/TagEditor.ps1"
    
    Write-Host "✅ Layer 6 loaded" -ForegroundColor Green
    
    # ========================================
    # LAYER 7: Core Services (Phase 5 Quality)
    # ========================================
    Write-Host "Layer 7: Core services..." -ForegroundColor Cyan
    
    . "$PSScriptRoot/Services/SimpleTaskService.ps1"
    . "$PSScriptRoot/Services/TimeTrackingService.ps1"
    . "$PSScriptRoot/Services/CommandService.ps1"
    . "$PSScriptRoot/Services/KeyMappingService.ps1"
    
    Write-Host "✅ Layer 7 loaded" -ForegroundColor Green
    
    # ========================================
    # LAYER 8: Application Screens (Phase 5 - All ListScreen)
    # ========================================
    Write-Host "Layer 8: Application screens..." -ForegroundColor Cyan
    
    . "$PSScriptRoot/Screens/MinimalTaskScreen.ps1"      # Minimal test screen 
    . "$PSScriptRoot/Screens/TaskListScreen-Phase4.ps1"  # Reference implementation
    . "$PSScriptRoot/Screens/TimeEntryScreen.ps1"        # Migrated to ListScreen
    . "$PSScriptRoot/Screens/CommandLibraryScreen.ps1"   # Migrated to ListScreen
    
    # Skip Excel screens - they have complex external dependencies
    # . "$PSScriptRoot/Screens/ExcelMappingScreen.ps1"
    # . "$PSScriptRoot/Screens/ExcelDataScreen.ps1"
    
    Write-Host "✅ Layer 8 loaded" -ForegroundColor Green
    
    # ========================================
    # LAYER 9: Application Framework
    # ========================================
    Write-Host "Layer 9: Application framework..." -ForegroundColor Cyan
    
    . "$PSScriptRoot/Core/SimpleTaskProApp.ps1"  # Updated for Phase 5 architecture
    . "$PSScriptRoot/Core/Bootstrapper.ps1"      # Service container initialization
    
    Write-Host "✅ Layer 9 loaded" -ForegroundColor Green
    
    # ========================================
    # LAYER 10: Application Launch
    # ========================================
    Write-Host "Layer 10: Launching application..." -ForegroundColor Cyan
    
    # Initialize application with bulletproof service injection
    Write-Host "DEBUG: About to call Bootstrapper.Initialize" -ForegroundColor Yellow
    $app = [Bootstrapper]::Initialize($PSScriptRoot)
    Write-Host "DEBUG: Bootstrapper.Initialize completed" -ForegroundColor Yellow
    
    Write-Host "✅ Phase 5 architecture fully initialized!" -ForegroundColor Green
    Write-Host "Starting main application loop..." -ForegroundColor Cyan
    
    # Run the application
    Write-Host "DEBUG: About to call app.Run()" -ForegroundColor Yellow
    $app.Run()
    Write-Host "DEBUG: app.Run() completed" -ForegroundColor Yellow
    
} catch {
    Write-Host ""
    Write-Host "❌ SimpleTaskPro Phase 5 startup failed!" -ForegroundColor Red
    Write-Host "Error: $_" -ForegroundColor Red
    Write-Host ""
    
    if ($global:Debug) {
        Write-Host "Stack trace:" -ForegroundColor Yellow
        Write-Host $_.ScriptStackTrace -ForegroundColor Gray
    }
    
    # Try emergency cleanup
    try {
        if ([Bootstrapper]::IsInitialized) {
            [Bootstrapper]::EmergencyCleanup()
        }
    } catch {
        Write-Host "Emergency cleanup failed: $_" -ForegroundColor Yellow
    }
    
    exit 1
    
} finally {
    Write-Host ""
    Write-Host "SimpleTaskPro Phase 5 session ended." -ForegroundColor Yellow
}