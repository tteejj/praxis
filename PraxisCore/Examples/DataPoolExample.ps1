#!/usr/bin/env pwsh
# DataPoolExample.ps1 - Example of how apps can use the common data pool

# Load DataPool service
. "$PSScriptRoot/../Services/DataPool.ps1"

# Initialize
[DataPool]::Initialize()

Write-Host "DataPool Example - Cross-App Data Sharing" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor DarkGray
Write-Host ""

# Example 1: TaskPro saves a task
Write-Host "1. TaskPro creates a task:" -ForegroundColor Yellow
$task = @{
    Id = [Guid]::NewGuid().ToString()
    Title = "Review Q4 Reports"
    Priority = "High"
    DueDate = (Get-Date).AddDays(3).ToString("yyyy-MM-dd")
    Tags = @("quarterly", "finance")
}

# Save to data pool
$tasks = @($task)
[DataPool]::Write("TaskPro", "tasks", $tasks)
Write-Host "   ✓ Task saved to data pool" -ForegroundColor Green

# Add to recent items
[DataPool]::AddRecentItem("TaskPro", "task", $task.Title, $task.Id)
Write-Host "   ✓ Added to recent items" -ForegroundColor Green
Write-Host ""

# Example 2: TimeTracker wants to track time for this task
Write-Host "2. TimeTracker reads available tasks:" -ForegroundColor Yellow
$availableTasks = [DataPool]::Read("TaskPro", "tasks")
Write-Host "   Found $($availableTasks.Count) task(s):" -ForegroundColor Gray
foreach ($t in $availableTasks) {
    Write-Host "   - $($t.Title) (Priority: $($t.Priority))" -ForegroundColor Gray
}
Write-Host ""

# Example 3: Exchange data between apps
Write-Host "3. TaskPro sends task to TimeTracker:" -ForegroundColor Yellow
[DataPool]::Exchange("TaskPro", "TimeTracker", "task", @{
    TaskId = $task.Id
    TaskTitle = $task.Title
    Action = "StartTracking"
})
Write-Host "   ✓ Task sent to TimeTracker's exchange queue" -ForegroundColor Green
Write-Host ""

# Example 4: TimeTracker checks for exchanges
Write-Host "4. TimeTracker checks pending exchanges:" -ForegroundColor Yellow
$pending = [DataPool]::GetPendingExchanges("TimeTracker")
Write-Host "   Found $($pending.Count) pending exchange(s):" -ForegroundColor Gray
foreach ($exchange in $pending) {
    Write-Host "   - From: $($exchange.From)" -ForegroundColor Gray
    Write-Host "     Type: $($exchange.Type)" -ForegroundColor Gray
    Write-Host "     Task: $($exchange.Data.TaskTitle)" -ForegroundColor Gray
    Write-Host "     Action: $($exchange.Data.Action)" -ForegroundColor Gray
}
Write-Host ""

# Example 5: CommandLibrary creates a macro from TimeTracker data
Write-Host "5. Creating cross-app automation:" -ForegroundColor Yellow
$command = @{
    Id = [Guid]::NewGuid().ToString()
    Name = "Weekly Time Report"
    Description = "Generate weekly time report and export to Excel"
    Script = @"
# Get time entries from TimeTracker
`$entries = [DataPool]::Read('TimeTracker', 'timeentries')
# Send to ExcelDataFlow for processing
[DataPool]::Exchange('CommandLibrary', 'ExcelDataFlow', 'export-request', @{
    Data = `$entries
    Template = 'WeeklyTimesheet'
    Format = 'xlsx'
})
"@
}

# Save command
$commands = @($command)
[DataPool]::Write("CommandLibrary", "commands", $commands)
Write-Host "   ✓ Automation command saved" -ForegroundColor Green
Write-Host ""

# Example 6: Show recent items across all apps
Write-Host "6. Recent items across all apps:" -ForegroundColor Yellow
$recent = [DataPool]::GetRecentItems(5)
foreach ($item in $recent) {
    Write-Host "   $($item.App): $($item.Name)" -ForegroundColor Gray
}
Write-Host ""

# Show data location
Write-Host "Data Location: $([DataPool]::DataPath)" -ForegroundColor DarkGray
Write-Host ""
Write-Host "This example shows how apps can:" -ForegroundColor Cyan
Write-Host "- Share data through a common pool" -ForegroundColor Gray
Write-Host "- Exchange data asynchronously" -ForegroundColor Gray
Write-Host "- Track recent items across apps" -ForegroundColor Gray
Write-Host "- Build cross-app workflows" -ForegroundColor Gray