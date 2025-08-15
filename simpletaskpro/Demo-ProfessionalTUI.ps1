#!/usr/bin/env pwsh
# Demo-ProfessionalTUI.ps1 - Demonstrate the professional TUI components

# Load the professional TUI foundation
. "$PSScriptRoot/Load-ProfessionalTUI.ps1"

Write-Host "Professional TUI Demo - Press Ctrl+Q to exit" -ForegroundColor Cyan
Write-Host "Features: Zero flicker, professional input, text fields, lists" -ForegroundColor Green
Write-Host "Press any key to start..." -ForegroundColor Yellow
Read-Host

# Hide cursor and initialize
[Console]::CursorVisible = $false
Clear-Host

try {
    # Create screen buffer
    $screen = New-ProfessionalScreen
    
    # Create text input field
    $textField = [TaskPro.UI.TextInputField]::new()
    $textField.Placeholder = "Enter some text..."
    $textField.IsFocused = $true
    
    # Create list widget with sample data
    $listWidget = [TaskPro.UI.ListWidget[string]]::new()
    $sampleTasks = @(
        "Review project documentation",
        "Fix rendering bug in TaskPro", 
        "Implement professional text editing",
        "Add Ctrl+shortcut support",
        "Test flicker-free rendering",
        "Create task management UI",
        "Optimize list navigation",
        "Add search functionality"
    )
    
    $listWidget.Items = $sampleTasks
    $listWidget.ItemFormatter = { param($item) "☐ $item" }
    $listWidget.ItemColorProvider = { param($item) 
        if ($item.Contains("bug")) { [ConsoleColor]::Red }
        elseif ($item.Contains("professional")) { [ConsoleColor]::Green }
        else { [ConsoleColor]::White }
    }
    $listWidget.ShowPillboxSelection = $true
    $listWidget.IsFocused = $false  # Start with text field focused
    
    # Track which control has focus
    $focusedControl = "text"  # "text" or "list"
    
    # Status message
    $statusMessage = "Professional TUI Demo - Tab to switch focus, Ctrl+Q to exit"
    
    # Main loop
    $running = $true
    while ($running) {
        # Begin frame
        $screen.BeginFrame()
        
        # Header
        $screen.WriteAt(2, 1, "Professional TUI Demo", [ConsoleColor]::Cyan)
        $screen.WriteAt(2, 2, "=" * 50, [ConsoleColor]::DarkCyan)
        
        # Text input field
        $textFieldRect = [TaskPro.Core.Rectangle]::new(2, 4, 50, 1)
        $screen.WriteAt(2, 3, "Text Input (Professional editing with Ctrl+shortcuts):", [ConsoleColor]::Yellow)
        $textField.IsFocused = ($focusedControl -eq "text")
        $textField.Render($screen, $textFieldRect)
        
        # List widget  
        $listRect = [TaskPro.Core.Rectangle]::new(2, 7, 60, 10)
        $screen.WriteAt(2, 6, "Task List (Arrow keys, Page Up/Down, type to search):", [ConsoleColor]::Yellow)
        $listWidget.IsFocused = ($focusedControl -eq "list")
        $listWidget.Render($screen, $listRect)
        
        # Status bar
        $screen.FillRect(0, $screen.Height - 2, $screen.Width, 1, ' ', [ConsoleColor]::White, [ConsoleColor]::DarkBlue)
        $screen.WriteAt(2, $screen.Height - 2, $statusMessage, [ConsoleColor]::White, [ConsoleColor]::DarkBlue)
        
        # Controls info
        $controlsInfo = "Controls: Tab=Switch Focus | Enter=Activate | Ctrl+A=Select All | Ctrl+Q=Quit"
        $screen.WriteAt(2, $screen.Height - 1, $controlsInfo, [ConsoleColor]::DarkGray)
        
        # End frame - single write, zero flicker!
        $screen.EndFrame()
        
        # Handle input
        if (Test-InputAvailable) {
            $input = Read-ProfessionalInput
            
            # Global shortcuts
            if ($input.IsCtrlQ) {
                $running = $false
                continue
            }
            
            if ($input.IsTab) {
                # Switch focus
                $focusedControl = if ($focusedControl -eq "text") { "list" } else { "text" }
                $statusMessage = "Focus switched to $focusedControl control"
                continue
            }
            
            # Route input to focused control
            if ($focusedControl -eq "text") {
                if ($textField.HandleInput($input)) {
                    $statusMessage = "Text: '$($textField.Text)' (Length: $($textField.Text.Length))"
                }
            }
            elseif ($focusedControl -eq "list") {
                if ($listWidget.HandleInput($input)) {
                    if ($listWidget.HasSelection) {
                        $statusMessage = "Selected: '$($listWidget.SelectedItem)' (Index: $($listWidget.SelectedIndex))"
                    }
                    
                    # Handle item activation
                    if ($input.IsEnter) {
                        $statusMessage = "Activated: '$($listWidget.SelectedItem)'"
                    }
                }
            }
        }
        
        Start-Sleep -Milliseconds 16  # ~60 FPS refresh rate
    }
    
} finally {
    # Clean up
    [Console]::CursorVisible = $true
    Clear-Host
    
    Write-Host ""
    Write-Host "Professional TUI Demo completed!" -ForegroundColor Green
    Write-Host "Key features demonstrated:" -ForegroundColor Yellow
    Write-Host "  ✓ Zero-flicker rendering with single screen buffer write" -ForegroundColor Gray
    Write-Host "  ✓ Professional text input with cursor positioning and Ctrl+shortcuts" -ForegroundColor Gray
    Write-Host "  ✓ Rich list widget with smooth navigation and search" -ForegroundColor Gray
    Write-Host "  ✓ Clean input handling with modifier key detection" -ForegroundColor Gray
    Write-Host "  ✓ Professional visual design with colors and highlighting" -ForegroundColor Gray
    Write-Host ""
    Write-Host "This foundation can now be used to build your TaskPro application!" -ForegroundColor Cyan
}