# Test script for retro cyberpunk TaskListWidget
# Load TaskPro.dll and test the new ASCII background highlight system

# Load the compiled DLL
try {
    Add-Type -Path "./TaskPro.dll"
    Write-Host "[SYS] TaskPro.dll loaded successfully" -ForegroundColor Green
} catch {
    Write-Host "[ERROR] Failed to load TaskPro.dll: $_" -ForegroundColor Red
    exit 1
}

# Create test data
Write-Host "[SYS] Initializing retro cyberpunk test environment..." -ForegroundColor Cyan

# Create task manager with test data
$taskManager = New-Object TaskPro.Data.TaskManager
$taskManager.LoadFromJson("./Data/tasks.json")

# Add some test tasks for retro display
$testTasks = @(
    @{ Title = "Fix neural interface"; Priority = "High"; ID1 = "T001"; Tags = @("CRIT") },
    @{ Title = "Debug quantum processor"; Priority = "Medium"; ID1 = "T002"; Tags = @("TECH") },
    @{ Title = "Update security matrix"; Priority = "Low"; ID1 = "T003"; Tags = @("SYS") },
    @{ Title = "Hack the Gibson"; Priority = "Today"; ID1 = "T004"; Tags = @("URGENT") }
)

foreach ($taskData in $testTasks) {
    $task = New-Object TaskPro.Data.SimpleTask
    $task.Title = $taskData.Title
    $task.Priority = [TaskPro.Data.Priority]::($taskData.Priority)
    $task.ID1 = $taskData.ID1
    $task.Tags = $taskData.Tags
    $task.DueDate = (Get-Date).AddDays((Get-Random -Min 1 -Max 7))
    $taskManager.AddTask($task)
}

# Create screen buffer
$screenWidth = [Console]::WindowWidth
$screenHeight = [Console]::WindowHeight
$screenBuffer = New-Object TaskPro.Core.ScreenBuffer($screenWidth, $screenHeight)

# Create retro task list widget
$retroWidget = New-Object TaskPro.UI.TaskListWidgetRetro
$retroWidget.TaskManager = $taskManager

# Create status bar for messages
$statusBar = New-Object TaskPro.UI.StatusBar
$retroWidget.StatusBar = $statusBar

# Create bounds for full screen
$bounds = New-Object TaskPro.Core.Rectangle
$bounds.X = 0
$bounds.Y = 0
$bounds.Width = $screenWidth
$bounds.Height = $screenHeight - 2  # Leave space for instructions

# Refresh task list
$retroWidget.RefreshTaskList()

# Enable Matrix mode by default
$retroWidget.ToggleMatrixMode()

Write-Host "[SYS] Retro cyberpunk environment loaded. Starting interface..." -ForegroundColor Green
Write-Host "[CMD] Controls: Arrow keys=navigate, Ctrl+M=Matrix, Ctrl+B=BladeRunner, Ctrl+G=Glitch, Ctrl+S=Scanlines, Q=Quit" -ForegroundColor Yellow

# Main display loop
$running = $true
while ($running) {
    try {
        # Clear console
        [Console]::Clear()
        
        # Begin frame
        $screenBuffer.BeginFrame()
        
        # Render retro widget
        $retroWidget.Render($screenBuffer, $bounds)
        
        # Add instructions at bottom
        $instructions = "CONTROLS: ↑↓=Navigate │ Ctrl+M=Matrix │ Ctrl+B=BladeRunner │ Ctrl+G=Glitch │ Ctrl+S=Scanlines │ Q=Quit"
        $screenBuffer.WriteAt(0, $bounds.Height, $instructions.PadRight($screenWidth), [ConsoleColor]::Cyan, [ConsoleColor]::Black)
        
        # End frame (render to screen)
        $screenBuffer.EndFrame()
        
        # Get input
        $keyInfo = [Console]::ReadKey($true)
        $inputEvent = [TaskPro.Core.InputEvent]::FromConsoleKeyInfo($keyInfo)
        
        # Handle input
        if ($keyInfo.Key -eq [ConsoleKey]::Q) {
            $running = $false
            break
        }
        
        # Let widget handle input
        $retroWidget.HandleInput($inputEvent)
        
        # Small delay to prevent CPU spinning
        Start-Sleep -Milliseconds 50
        
    } catch {
        Write-Host "[ERROR] Runtime error: $_" -ForegroundColor Red
        Write-Host "[DEBUG] Stack trace: $($_.ScriptStackTrace)" -ForegroundColor Yellow
        $running = $false
    }
}

# Cleanup
[Console]::Clear()
Write-Host "[SYS] Retro cyberpunk test complete. Neural link terminated." -ForegroundColor Green
Write-Host "[SYS] Thanks for testing the ASCII background highlight system!" -ForegroundColor Cyan