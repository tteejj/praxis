# Load-CyberpunkTaskPro.ps1 - Retro-Futuristic Terminal Task Management
# Classic cyberpunk aesthetic inspired by old-school computer interfaces

Write-Host "████████╗ █████╗ ███████╗██╗  ██╗██████╗ ██████╗  ██████╗ " -ForegroundColor Cyan
Write-Host "╚══██╔══╝██╔══██╗██╔════╝██║ ██╔╝██╔══██╗██╔══██╗██╔═══██╗" -ForegroundColor Cyan  
Write-Host "   ██║   ███████║███████╗█████╔╝ ██████╔╝██████╔╝██║   ██║" -ForegroundColor Cyan
Write-Host "   ██║   ██╔══██║╚════██║██╔═██╗ ██╔═══╝ ██╔══██╗██║   ██║" -ForegroundColor Cyan
Write-Host "   ██║   ██║  ██║███████║██║  ██╗██║     ██║  ██║╚██████╔╝" -ForegroundColor Cyan
Write-Host "   ╚═╝   ╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝╚═╝     ╚═╝  ╚═╝ ╚═════╝ " -ForegroundColor Cyan
Write-Host ""
Write-Host "Loading CYBERPUNK Terminal Interface..." -ForegroundColor Green
Write-Host "Retro-Futuristic Task Management System" -ForegroundColor Yellow

# Build C# source code with cyberpunk UI components
$csharpFiles = @(
    "$PSScriptRoot/CSharp/Core/TaskProException.cs",
    "$PSScriptRoot/CSharp/Core/Rectangle.cs",
    "$PSScriptRoot/CSharp/Core/InputEvent.cs",
    "$PSScriptRoot/CSharp/Core/InputManager.cs",
    "$PSScriptRoot/CSharp/Core/GapBuffer.cs",
    "$PSScriptRoot/CSharp/Core/DoubleBuffer.cs",
    "$PSScriptRoot/CSharp/Core/ScreenBuffer.cs",
    "$PSScriptRoot/CSharp/Data/SimpleTask.cs",
    "$PSScriptRoot/CSharp/Data/FilterCriteria.cs",
    "$PSScriptRoot/CSharp/Data/TaskFilter.cs",
    "$PSScriptRoot/CSharp/Data/TaskPersistence.cs",
    "$PSScriptRoot/CSharp/Data/TaskManager.cs",
    "$PSScriptRoot/CSharp/UI/TaskListItem.cs",
    "$PSScriptRoot/CSharp/UI/TextInputField.cs",
    "$PSScriptRoot/CSharp/UI/ListWidget.cs",
    "$PSScriptRoot/CSharp/UI/StatusBar.cs",
    "$PSScriptRoot/CSharp/UI/InlineEditor.cs",
    "$PSScriptRoot/CSharp/UI/TagEditor.cs",
    "$PSScriptRoot/CSharp/UI/TaskCreationDialog.cs",
    "$PSScriptRoot/CSharp/UI/NotesEditorDialog.cs",
    "$PSScriptRoot/CSharp/UI/ColorTheme.cs",
    "$PSScriptRoot/CSharp/UI/ColorPickerDialog.cs",
    "$PSScriptRoot/CSharp/UI/TaskListWidget.cs"
)

# Check if all files exist
$missingFiles = @()
foreach ($file in $csharpFiles) {
    if (-not (Test-Path $file)) {
        $missingFiles += $file
    }
}

if ($missingFiles.Count -gt 0) {
    Write-Host "❌ Missing required files:" -ForegroundColor Red
    $missingFiles | ForEach-Object { Write-Host "   $_" -ForegroundColor DarkRed }
    return
}

Write-Host "  📁 Compiling modern TaskPro components..." -ForegroundColor DarkCyan

# Combine all C# source files
$combinedSource = ""
foreach ($file in $csharpFiles) {
    $content = Get-Content $file -Raw
    if ($content) {
        $combinedSource += $content + "`n"
    }
}

# Add required assemblies for modern UI
$assemblies = @(
    'System.Core'
)

try {
    # Compile the modern C# code
    Add-Type -TypeDefinition $combinedSource -Language CSharp -ReferencedAssemblies $assemblies
    
    Write-Host "  ✓ CYBERPUNK TaskPro loaded successfully!" -ForegroundColor Green
    Write-Host "    [RETRO] Terminal computer aesthetic" -ForegroundColor DarkGreen
    Write-Host "    [CYBER] Classic sci-fi interface styling" -ForegroundColor DarkGreen
    Write-Host "    [NEON]  Bright cyan borders and amber text" -ForegroundColor DarkGreen
    Write-Host "    [TERM]  Old-school computer terminal UI" -ForegroundColor DarkGreen
    Write-Host "    [RGB]   Custom color support for themes" -ForegroundColor DarkGreen
    Write-Host "    [FAST]  Zero-flicker C# rendering engine" -ForegroundColor DarkGreen
    Write-Host "    [DATA]  Complete task management system" -ForegroundColor DarkGreen
    
    Write-Host ""
    Write-Host "╔══════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║               CYBERPUNK TASKPRO READY FOR INPUT                  ║" -ForegroundColor Cyan
    Write-Host "║                                                                  ║" -ForegroundColor Cyan
    Write-Host "║  CONTROLS:                                                       ║" -ForegroundColor Yellow
    Write-Host "║    ↑↓: NAVIGATE        SPACE: COMPLETE TASK                     ║" -ForegroundColor Green
    Write-Host "║    ENTER: EDIT NOTES   E: INLINE EDIT                           ║" -ForegroundColor Green
    Write-Host "║    T: CYCLE THEMES     SHIFT+T: COLOR PICKER                    ║" -ForegroundColor Green
    Write-Host "║    R: EDIT TAGS        C: COLLAPSE/EXPAND                       ║" -ForegroundColor Green
    Write-Host "║    /: FILTER TASKS     CTRL+↑↓: REORDER                         ║" -ForegroundColor Green
    Write-Host "║    Q: EXIT SYSTEM                                               ║" -ForegroundColor Green
    Write-Host "║                                                                  ║" -ForegroundColor Cyan
    Write-Host "╚══════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    
    # Note: We're using the existing TaskListWidget with enhanced cyberpunk styling
    Write-Host "[SYSTEM] Use the enhanced TaskListWidget with cyberpunk aesthetic" -ForegroundColor Yellow
    Write-Host "[READY]  Create instance and run with: \$widget = New-Object TaskPro.UI.TaskListWidget" -ForegroundColor Green
    
} catch {
    Write-Host "❌ Failed to compile TaskPro Modern components:" -ForegroundColor Red
    Write-Host "   $($_.Exception.Message)" -ForegroundColor DarkRed
    
    if ($_.Exception.InnerException) {
        Write-Host "   Inner: $($_.Exception.InnerException.Message)" -ForegroundColor DarkRed
    }
    
    # Show compilation errors if available
    if ($_ -match "error CS") {
        Write-Host ""
        Write-Host "Compilation errors:" -ForegroundColor Yellow
        $_ | Select-String "error CS\d+:" | ForEach-Object {
            Write-Host "   $($_.Matches[0].Value)" -ForegroundColor Red
        }
    }
}