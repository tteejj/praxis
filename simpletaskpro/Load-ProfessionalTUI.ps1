# Load-ProfessionalTUI.ps1 - Load C# TUI components for professional interface
# This provides flicker-free rendering, professional input handling, and real text controls

Write-Host "Loading Professional TUI Foundation..." -ForegroundColor Cyan

# Build C# source code
$csharpFiles = @(
    "$PSScriptRoot/CSharp/Core/InputEvent.cs",
    "$PSScriptRoot/CSharp/Core/InputManager.cs", 
    "$PSScriptRoot/CSharp/Core/ScreenBuffer.cs",
    "$PSScriptRoot/CSharp/UI/TextInputField.cs",
    "$PSScriptRoot/CSharp/UI/ListWidget.cs"
)

# Check if all files exist
foreach ($file in $csharpFiles) {
    if (-not (Test-Path $file)) {
        throw "Missing C# file: $file"
    }
}

# Combine all C# source
$combinedSource = ""
foreach ($file in $csharpFiles) {
    $content = Get-Content $file -Raw
    $combinedSource += $content + "`n"
}

# Compile C# code
try {
    Write-Host "  Compiling C# TUI components..." -ForegroundColor Yellow
    Add-Type -TypeDefinition $combinedSource -Language CSharp
    
    Write-Host "  ✓ Professional TUI Foundation loaded successfully!" -ForegroundColor Green
    Write-Host "    - Zero-flicker screen rendering" -ForegroundColor Gray
    Write-Host "    - Professional input handling with Ctrl+shortcuts" -ForegroundColor Gray  
    Write-Host "    - Real text input fields with cursor positioning" -ForegroundColor Gray
    Write-Host "    - Rich list widgets with smooth navigation" -ForegroundColor Gray
    
} catch {
    Write-Host "  ✗ Failed to compile C# TUI components:" -ForegroundColor Red
    Write-Host "    $($_.Exception.Message)" -ForegroundColor Red
    throw
}

# Helper function to create a new professional screen
function New-ProfessionalScreen {
    param(
        [int]$Width = [Console]::WindowWidth,
        [int]$Height = [Console]::WindowHeight
    )
    
    return [TaskPro.Core.ScreenBuffer]::new($Width, $Height)
}

# Helper function for input handling
function Read-ProfessionalInput {
    return [TaskPro.Core.InputManager]::ReadInput()
}

# Helper function to check for available input
function Test-InputAvailable {
    return [TaskPro.Core.InputManager]::IsInputAvailable()
}

# Export functions for PowerShell integration
Export-ModuleMember -Function @(
    'New-ProfessionalScreen',
    'Read-ProfessionalInput', 
    'Test-InputAvailable'
)

Write-Host "Professional TUI Foundation ready for use!" -ForegroundColor Green
Write-Host ""
Write-Host "Usage Examples:" -ForegroundColor Yellow
Write-Host "  `$screen = New-ProfessionalScreen" -ForegroundColor Gray
Write-Host "  `$screen.BeginFrame()" -ForegroundColor Gray
Write-Host "  `$screen.WriteAt(10, 5, 'Hello World', [ConsoleColor]::Yellow)" -ForegroundColor Gray
Write-Host "  `$screen.EndFrame()  # Single write - zero flicker!" -ForegroundColor Gray
Write-Host ""
Write-Host "  `$input = Read-ProfessionalInput" -ForegroundColor Gray
Write-Host "  if (`$input.IsCtrlS) { Write-Host 'Save shortcut!' }" -ForegroundColor Gray
Write-Host ""