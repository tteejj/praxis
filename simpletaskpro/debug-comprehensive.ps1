#!/usr/bin/env pwsh
# debug-comprehensive.ps1 - COMPREHENSIVE debugging with detailed logging

Set-Location $PSScriptRoot

# Create debug log file
$debugLog = "./DEBUG-RENDER.log"
"=== COMPREHENSIVE RENDERING DEBUG $(Get-Date) ===" | Out-File $debugLog -Encoding UTF8

# Load ALL components exactly as SimpleTaskPro does
. "$PSScriptRoot/Core/ServiceContainer-Phase4.5.ps1"
. "$PSScriptRoot/Core/StringCache.ps1"
. "$PSScriptRoot/Core/VT100.ps1"
. "$PSScriptRoot/Core/UniversalBackupManager.ps1"
. "$PSScriptRoot/Core/GapBuffer.ps1"
. "$PSScriptRoot/Models/SimpleTask.ps1"
. "$PSScriptRoot/Models/SimpleTimeEntry.ps1"
. "$PSScriptRoot/Models/Command.ps1"
. "$PSScriptRoot/Models/ExcelFieldMapping.ps1"
. "$PSScriptRoot/Core/Logger.ps1"
. "$PSScriptRoot/Core/EventBus.ps1"
. "$PSScriptRoot/Core/SimpleStateManager.ps1"
. "$PSScriptRoot/Core/InputProcessor.ps1"
. "$PSScriptRoot/Core/AppThemeManager.ps1"
. "$PSScriptRoot/Core/RenderEngine.ps1"
. "$PSScriptRoot/Core/FastLineBuilder.ps1"
. "$PSScriptRoot/Services/SimpleTaskService.ps1"
. "$PSScriptRoot/Services/TimeTrackingService.ps1"
. "$PSScriptRoot/Services/CommandService.ps1"
. "$PSScriptRoot/Services/ExcelMappingService.ps1"
. "$PSScriptRoot/Services/KeyMappingService.ps1"
. "$PSScriptRoot/Base/Screen.ps1"
. "$PSScriptRoot/Base/ListScreen.ps1"
. "$PSScriptRoot/Screens/TaskListScreen.ps1"
. "$PSScriptRoot/Core/SimpleTaskProApp.ps1"
. "$PSScriptRoot/Core/Bootstrapper.ps1"

try {
    "1. Testing Bootstrapper initialization..." | Tee-Object $debugLog -Append
    $app = [Bootstrapper]::Initialize($PSScriptRoot)
    "   SUCCESS: Bootstrapper created app: $($app.GetType().Name)" | Tee-Object $debugLog -Append
    
    "2. Testing screen creation..." | Tee-Object $debugLog -Append
    $taskScreen = $app._screens["Tasks"]
    "   Screen type: $($taskScreen.GetType().Name)" | Tee-Object $debugLog -Append
    "   Screen title: '$($taskScreen.Title)'" | Tee-Object $debugLog -Append
    "   Screen width: $($taskScreen.Width)" | Tee-Object $debugLog -Append
    "   Screen height: $($taskScreen.Height)" | Tee-Object $debugLog -Append
    
    "3. Testing TaskService injection..." | Tee-Object $debugLog -Append
    "   TaskService is null: $($taskScreen.TaskService -eq $null)" | Tee-Object $debugLog -Append
    if ($taskScreen.TaskService) {
        "   TaskService type: $($taskScreen.TaskService.GetType().Name)" | Tee-Object $debugLog -Append
    }
    
    "4. Testing theme colors..." | Tee-Object $debugLog -Append
    $headerBg = [AppThemeManager]::GetBackgroundColor("Header")
    $headerFg = [AppThemeManager]::GetColor("Header")
    "   HeaderBg: '$headerBg' (length: $($headerBg.Length))" | Tee-Object $debugLog -Append
    "   HeaderFg: '$headerFg' (length: $($headerFg.Length))" | Tee-Object $debugLog -Append
    
    "5. Testing manual render..." | Tee-Object $debugLog -Append
    $sb = [System.Text.StringBuilder]::new()
    $taskScreen.RenderHeader($sb)
    $headerOutput = $sb.ToString()
    "   Header output length: $($headerOutput.Length)" | Tee-Object $debugLog -Append
    "   Header output (hex): $([System.Text.Encoding]::UTF8.GetBytes($headerOutput) | ForEach-Object { $_.ToString('X2') } | Join-String ' ')" | Tee-Object $debugLog -Append
    "   Header output (escaped): $($headerOutput -replace '`e', '\e' -replace '\n', '\n' -replace '\r', '\r')" | Tee-Object $debugLog -Append
    
    "6. Testing full render..." | Tee-Object $debugLog -Append
    $fullOutput = $taskScreen.Render()
    "   Full render length: $($fullOutput.Length)" | Tee-Object $debugLog -Append
    "   First 200 chars: $($fullOutput.Substring(0, [Math]::Min(200, $fullOutput.Length)) -replace '`e', '\e')" | Tee-Object $debugLog -Append
    
} catch {
    "ERROR: $($_.Exception.Message)" | Tee-Object $debugLog -Append
    "Stack: $($_.ScriptStackTrace)" | Tee-Object $debugLog -Append
}

"=== DEBUG COMPLETE ===" | Tee-Object $debugLog -Append
Write-Host "Debug log written to: $debugLog" -ForegroundColor Yellow