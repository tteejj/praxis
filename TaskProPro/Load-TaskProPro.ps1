# Load-TaskProPro.ps1 - Professional Task Management with C# TUI Foundation
# The "Pro" version - zero flicker, professional input, real text controls

Write-Host "Loading TaskProPro - Professional Task Management..." -ForegroundColor Cyan

# Build C# source code
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
    "$PSScriptRoot/CSharp/UI/TaskListWidget.cs"
)

# Check if all files exist
foreach ($file in $csharpFiles) {
    if (-not (Test-Path $file)) {
        throw "Missing C# file: $file"
    }
}

# Combine all C# source with proper using statement handling
$allUsings = @()
$allNamespaces = @()

foreach ($file in $csharpFiles) {
    $content = Get-Content $file -Raw
    $lines = $content -split "`n"
    
    # Extract using statements
    $usings = $lines | Where-Object { $_ -match "^using\s+" }
    $allUsings += $usings
    
    # Extract everything after using statements
    $nonUsingLines = @()
    $foundFirstNonUsing = $false
    foreach ($line in $lines) {
        if ($line -match "^using\s+" -and -not $foundFirstNonUsing) {
            continue  # Skip using statements
        }
        if ($line.Trim() -eq "" -and -not $foundFirstNonUsing) {
            continue  # Skip empty lines before namespace
        }
        $foundFirstNonUsing = $true
        $nonUsingLines += $line
    }
    
    $allNamespaces += ($nonUsingLines -join "`n")
}

# Combine: unique using statements first, then all namespace content
$uniqueUsings = $allUsings | Sort-Object | Get-Unique
$combinedSource = ($uniqueUsings -join "`n") + "`n`n" + ($allNamespaces -join "`n`n")

# Compile C# code
try {
    Write-Host "  Compiling TaskProPro C# components..." -ForegroundColor Yellow
    Add-Type -TypeDefinition $combinedSource -Language CSharp
    
    Write-Host "  ✓ TaskProPro Foundation loaded successfully!" -ForegroundColor Green
    Write-Host "    - Professional TUI with zero flicker" -ForegroundColor Gray
    Write-Host "    - Real text editing with Ctrl+shortcuts" -ForegroundColor Gray  
    Write-Host "    - Smooth list navigation" -ForegroundColor Gray
    Write-Host "    - Professional visual design" -ForegroundColor Gray
    Write-Host "    - Complete task management with data persistence" -ForegroundColor Gray
    
} catch {
    Write-Host "  ✗ Failed to compile TaskProPro components:" -ForegroundColor Red
    Write-Host "    $($_.Exception.Message)" -ForegroundColor Red
    throw
}

Write-Host "TaskProPro ready - The professional task manager!" -ForegroundColor Green