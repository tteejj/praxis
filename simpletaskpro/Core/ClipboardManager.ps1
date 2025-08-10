# ClipboardManager.ps1 - Advanced clipboard operations for tasks and time entries
# Supports multiple clipboard formats and system clipboard integration

class ClipboardManager {
    [object[]]$ClipboardStack = @()
    [hashtable]$FormatHandlers = @{}
    [object]$Context = $null
    
    ClipboardManager($context) {
        $this.Context = $context
        $this.InitializeFormatHandlers()
    }
    
    [void] InitializeFormatHandlers() {
        # Task format handlers
        $this.FormatHandlers["task"] = @{
            Copy = { param($task) $this.FormatTask($task) }
            Paste = { param($data) $this.ParseTask($data) }
        }
        
        $this.FormatHandlers["title"] = @{
            Copy = { param($task) $task.Title }
            Paste = { param($data) @{ Title = $data } }
        }
        
        $this.FormatHandlers["notes"] = @{
            Copy = { param($task) $task.Notes }
            Paste = { param($data) @{ Notes = $data } }
        }
        
        $this.FormatHandlers["formatted"] = @{
            Copy = { param($task) $this.FormatTaskForExport($task) }
            Paste = { param($data) $this.ParseFormattedTask($data) }
        }
        
        $this.FormatHandlers["timesheet"] = @{
            Copy = { param($timeEntry) $this.FormatTimesheet($timeEntry) }
            Paste = { param($data) $this.ParseTimesheet($data) }
        }
        
        $this.FormatHandlers["project"] = @{
            Copy = { param($task) $this.FormatProject($task) }
            Paste = { param($data) $this.ParseProject($data) }
        }
    }
    
    # Main clipboard operations
    [void] CopyTask([object]$task, [string]$format = "task") {
        if (-not $task) { return }
        
        $handler = $this.FormatHandlers[$format]
        if (-not $handler) { 
            Write-Warning "Unknown format: $format"
            return 
        }
        
        $data = & $handler.Copy $task
        $clipboardItem = @{
            Type = "Task"
            Format = $format
            Data = $data
            Source = $task
            Timestamp = [DateTime]::Now
        }
        
        $this.AddToClipboard($clipboardItem)
        $this.SetSystemClipboard($data)
    }
    
    [void] CopyTimeEntry([object]$timeEntry, [string]$format = "timesheet") {
        if (-not $timeEntry) { return }
        
        $handler = $this.FormatHandlers[$format]
        if (-not $handler) { 
            Write-Warning "Unknown format: $format"
            return 
        }
        
        $data = & $handler.Copy $timeEntry
        $clipboardItem = @{
            Type = "TimeEntry"
            Format = $format
            Data = $data
            Source = $timeEntry
            Timestamp = [DateTime]::Now
        }
        
        $this.AddToClipboard($clipboardItem)
        $this.SetSystemClipboard($data)
    }
    
    [object] PasteTask([string]$format = "task") {
        $item = $this.GetLatestClipboardItem("Task", $format)
        if (-not $item) { 
            # Try to parse from system clipboard
            $systemData = $this.GetSystemClipboard()
            if ($systemData) {
                return $this.ParseTaskFromString($systemData, $format)
            }
            return $null 
        }
        
        $handler = $this.FormatHandlers[$format]
        if (-not $handler.Paste) { return $item.Source }
        
        return & $handler.Paste $item.Data
    }
    
    [object] PasteTimeEntry([string]$format = "timesheet") {
        $item = $this.GetLatestClipboardItem("TimeEntry", $format)
        if (-not $item) { 
            $systemData = $this.GetSystemClipboard()
            if ($systemData) {
                return $this.ParseTimeEntryFromString($systemData, $format)
            }
            return $null 
        }
        
        $handler = $this.FormatHandlers[$format]
        if (-not $handler.Paste) { return $item.Source }
        
        return & $handler.Paste $item.Data
    }
    
    # Format-specific methods
    [string] FormatTask([object]$task) {
        $sb = [System.Text.StringBuilder]::new()
        [void]$sb.AppendLine("TASK: $($task.Title)")
        if ($task.ID1) { [void]$sb.AppendLine("ID1: $($task.ID1)") }
        if ($task.ID2) { [void]$sb.AppendLine("ID2: $($task.ID2)") }
        if ($task.Priority) { [void]$sb.AppendLine("Priority: $($task.Priority)") }
        if ($task.DueDate) { [void]$sb.AppendLine("Due: $($task.DueDate)") }
        if ($task.Tags) { [void]$sb.AppendLine("Tags: $($task.Tags -join ', ')") }
        if ($task.Notes) { 
            [void]$sb.AppendLine("Notes:")
            [void]$sb.AppendLine($task.Notes)
        }
        if ($task.Subtasks -and $task.Subtasks.Count -gt 0) {
            [void]$sb.AppendLine("Subtasks:")
            foreach ($subtask in $task.Subtasks) {
                [void]$sb.AppendLine("  - $($subtask.Title)")
            }
        }
        return $sb.ToString()
    }
    
    [string] FormatTaskForExport([object]$task) {
        # Format suitable for Excel or external tools
        $fields = @()
        $fields += $task.Title
        $fields += if ($task.ID1) { $task.ID1 } else { "" }
        $fields += if ($task.ID2) { $task.ID2 } else { "" }
        $fields += if ($task.Priority) { $task.Priority } else { "" }
        $fields += if ($task.DueDate) { $task.DueDate.ToString("yyyy-MM-dd") } else { "" }
        $fields += if ($task.Tags) { $task.Tags -join ";" } else { "" }
        $fields += if ($task.Notes) { $task.Notes -replace "`n", " | " } else { "" }
        
        return $fields -join "`t"  # Tab-separated for Excel
    }
    
    [string] FormatTimesheet([object]$timeEntry) {
        $sb = [System.Text.StringBuilder]::new()
        [void]$sb.AppendLine("TIMESHEET ENTRY")
        [void]$sb.AppendLine("Week: $($timeEntry.WeekEndingFriday)")
        [void]$sb.AppendLine("Project: $($timeEntry.ProjectCode)")
        [void]$sb.AppendLine("Description: $($timeEntry.Description)")
        [void]$sb.AppendLine("ID1: $($timeEntry.ID1Display)")
        [void]$sb.AppendLine("")
        [void]$sb.AppendLine("Hours:")
        [void]$sb.AppendLine("  Monday:    $($timeEntry.Monday)")
        [void]$sb.AppendLine("  Tuesday:   $($timeEntry.Tuesday)")
        [void]$sb.AppendLine("  Wednesday: $($timeEntry.Wednesday)")
        [void]$sb.AppendLine("  Thursday:  $($timeEntry.Thursday)")
        [void]$sb.AppendLine("  Friday:    $($timeEntry.Friday)")
        [void]$sb.AppendLine("  Total:     $($timeEntry.Total)")
        return $sb.ToString()
    }
    
    [string] FormatProject([object]$task) {
        # Format for project export with all subtasks
        $sb = [System.Text.StringBuilder]::new()
        [void]$sb.AppendLine("PROJECT: $($task.Title)")
        [void]$sb.AppendLine("Codes: $($task.ID1) / $($task.ID2)")
        [void]$sb.AppendLine("Priority: $($task.Priority)")
        [void]$sb.AppendLine("Due: $($task.DueDate)")
        if ($task.Tags) { [void]$sb.AppendLine("Tags: $($task.Tags -join ', ')") }
        [void]$sb.AppendLine("")
        if ($task.Notes) {
            [void]$sb.AppendLine("Description:")
            [void]$sb.AppendLine($task.Notes)
            [void]$sb.AppendLine("")
        }
        
        if ($task.Subtasks -and $task.Subtasks.Count -gt 0) {
            [void]$sb.AppendLine("Tasks:")
            foreach ($subtask in $task.Subtasks) {
                $status = if ($subtask.IsCompleted) { "[✓]" } else { "[ ]" }
                [void]$sb.AppendLine("$status $($subtask.Title)")
                if ($subtask.Notes) {
                    [void]$sb.AppendLine("    Notes: $($subtask.Notes)")
                }
            }
        }
        return $sb.ToString()
    }
    
    # Advanced clipboard operations
    [void] CopyWeekTimesheet([object[]]$timeEntries, [string]$weekEnding) {
        $sb = [System.Text.StringBuilder]::new()
        [void]$sb.AppendLine("WEEKLY TIMESHEET - Week Ending: $weekEnding")
        [void]$sb.AppendLine("=" * 60)
        [void]$sb.AppendLine()
        
        $totalHours = @{
            Monday = 0; Tuesday = 0; Wednesday = 0; Thursday = 0; Friday = 0; Total = 0
        }
        
        foreach ($entry in $timeEntries) {
            [void]$sb.AppendLine("$($entry.ID1Display.PadRight(6)) $($entry.ProjectCode.PadRight(12)) $($entry.Description)")
            [void]$sb.AppendLine("$(' ' * 20)Mon   Tue   Wed   Thu   Fri   Total")
            [void]$sb.AppendLine("$(' ' * 20)$($entry.Monday.ToString().PadLeft(3))   $($entry.Tuesday.ToString().PadLeft(3))   $($entry.Wednesday.ToString().PadLeft(3))   $($entry.Thursday.ToString().PadLeft(3))   $($entry.Friday.ToString().PadLeft(3))   $($entry.Total.ToString().PadLeft(5))")
            [void]$sb.AppendLine()
            
            $totalHours.Monday += $entry.Monday
            $totalHours.Tuesday += $entry.Tuesday  
            $totalHours.Wednesday += $entry.Wednesday
            $totalHours.Thursday += $entry.Thursday
            $totalHours.Friday += $entry.Friday
            $totalHours.Total += $entry.Total
        }
        
        [void]$sb.AppendLine("-" * 60)
        [void]$sb.AppendLine("TOTAL HOURS:        $($totalHours.Monday.ToString().PadLeft(3))   $($totalHours.Tuesday.ToString().PadLeft(3))   $($totalHours.Wednesday.ToString().PadLeft(3))   $($totalHours.Thursday.ToString().PadLeft(3))   $($totalHours.Friday.ToString().PadLeft(3))   $($totalHours.Total.ToString().PadLeft(5))")
        
        $clipboardItem = @{
            Type = "WeeklyTimesheet"
            Format = "formatted"
            Data = $sb.ToString()
            Source = $timeEntries
            Timestamp = [DateTime]::Now
            WeekEnding = $weekEnding
        }
        
        $this.AddToClipboard($clipboardItem)
        $this.SetSystemClipboard($clipboardItem.Data)
    }
    
    [void] CopyTasksAsMarkdown([object[]]$tasks) {
        $sb = [System.Text.StringBuilder]::new()
        [void]$sb.AppendLine("# Task List Export")
        [void]$sb.AppendLine()
        
        foreach ($task in $tasks) {
            $status = if ($task.IsCompleted) { "- [x]" } else { "- [ ]" }
            [void]$sb.AppendLine("$status **$($task.Title)**")
            
            if ($task.Priority) {
                [void]$sb.AppendLine("  - Priority: $($task.Priority)")
            }
            if ($task.DueDate) {
                [void]$sb.AppendLine("  - Due: $($task.DueDate.ToString('yyyy-MM-dd'))")
            }
            if ($task.Tags) {
                $tagString = ($task.Tags | ForEach-Object { "#$_" }) -join " "
                [void]$sb.AppendLine("  - Tags: $tagString")
            }
            if ($task.Notes) {
                [void]$sb.AppendLine("  - Notes: $($task.Notes)")
            }
            
            if ($task.Subtasks -and $task.Subtasks.Count -gt 0) {
                foreach ($subtask in $task.Subtasks) {
                    $subStatus = if ($subtask.IsCompleted) { "  - [x]" } else { "  - [ ]" }
                    [void]$sb.AppendLine("$subStatus $($subtask.Title)")
                }
            }
            [void]$sb.AppendLine()
        }
        
        $clipboardItem = @{
            Type = "TaskList"
            Format = "markdown"
            Data = $sb.ToString()
            Source = $tasks
            Timestamp = [DateTime]::Now
        }
        
        $this.AddToClipboard($clipboardItem)
        $this.SetSystemClipboard($clipboardItem.Data)
    }
    
    # System clipboard integration
    [void] SetSystemClipboard([string]$text) {
        try {
            if ([System.Environment]::OSVersion.Platform -eq "Win32NT") {
                Set-Clipboard -Value $text
            } else {
                # Try xclip for Linux
                if (Get-Command xclip -ErrorAction SilentlyContinue) {
                    $text | xclip -selection clipboard
                } elseif (Get-Command pbcopy -ErrorAction SilentlyContinue) {
                    $text | pbcopy
                }
            }
        } catch {
            Write-Warning "Failed to set system clipboard: $_"
        }
    }
    
    [string] GetSystemClipboard() {
        try {
            if ([System.Environment]::OSVersion.Platform -eq "Win32NT") {
                return Get-Clipboard -Raw
            } else {
                # Try xclip for Linux
                if (Get-Command xclip -ErrorAction SilentlyContinue) {
                    return xclip -selection clipboard -o
                } elseif (Get-Command pbpaste -ErrorAction SilentlyContinue) {
                    return pbpaste
                }
            }
        } catch {
            Write-Warning "Failed to get system clipboard: $_"
        }
        return ""
    }
    
    # Internal clipboard management
    [void] AddToClipboard([hashtable]$item) {
        $this.ClipboardStack = @($item) + $this.ClipboardStack
        
        # Keep only last 20 items
        if ($this.ClipboardStack.Count -gt 20) {
            $this.ClipboardStack = $this.ClipboardStack[0..19]
        }
    }
    
    [hashtable] GetLatestClipboardItem([string]$type, [string]$format = $null) {
        foreach ($item in $this.ClipboardStack) {
            if ($item.Type -eq $type) {
                if ($format -and $item.Format -ne $format) { continue }
                return $item
            }
        }
        return $null
    }
    
    [hashtable[]] GetClipboardHistory([string]$type = $null) {
        if ($type) {
            return $this.ClipboardStack | Where-Object { $_.Type -eq $type }
        }
        return $this.ClipboardStack
    }
    
    [void] ClearClipboard() {
        $this.ClipboardStack = @()
    }
    
    # Parsing methods for paste operations
    [object] ParseTask([string]$data) {
        # Simple task parser - can be enhanced
        $lines = $data -split "`n"
        $task = @{
            Title = ""
            ID1 = ""
            ID2 = ""
            Priority = ""
            DueDate = $null
            Tags = @()
            Notes = ""
            Subtasks = @()
        }
        
        foreach ($line in $lines) {
            $line = $line.Trim()
            if ($line.StartsWith("TASK: ")) {
                $task.Title = $line.Substring(6)
            } elseif ($line.StartsWith("ID1: ")) {
                $task.ID1 = $line.Substring(5)
            } elseif ($line.StartsWith("ID2: ")) {
                $task.ID2 = $line.Substring(5)
            } elseif ($line.StartsWith("Priority: ")) {
                $task.Priority = $line.Substring(10)
            } elseif ($line.StartsWith("Tags: ")) {
                $task.Tags = $line.Substring(6) -split ', '
            }
        }
        
        return $task
    }
    
    [object] ParseTaskFromString([string]$data, [string]$format) {
        # Try to intelligently parse task data from various formats
        if ($format -eq "formatted" -or $data.Contains("`t")) {
            # Tab-separated format
            $fields = $data -split "`t"
            return @{
                Title = if ($fields.Count -gt 0) { $fields[0] } else { "" }
                ID1 = if ($fields.Count -gt 1) { $fields[1] } else { "" }
                ID2 = if ($fields.Count -gt 2) { $fields[2] } else { "" }
                Priority = if ($fields.Count -gt 3) { $fields[3] } else { "" }
                DueDate = if ($fields.Count -gt 4 -and $fields[4]) { [DateTime]::Parse($fields[4]) } else { $null }
                Tags = if ($fields.Count -gt 5 -and $fields[5]) { $fields[5] -split ';' } else { @() }
                Notes = if ($fields.Count -gt 6) { $fields[6] -replace ' \| ', "`n" } else { "" }
            }
        } else {
            # Plain text - use as title
            return @{
                Title = $data.Trim()
                ID1 = ""
                ID2 = ""
                Priority = ""
                DueDate = $null
                Tags = @()
                Notes = ""
            }
        }
    }
    
    [object] ParseTimeEntryFromString([string]$data, [string]$format) {
        # Basic time entry parsing
        return @{
            ProjectCode = ""
            Description = $data.Trim()
            ID1Display = ""
            Monday = 0
            Tuesday = 0
            Wednesday = 0
            Thursday = 0
            Friday = 0
            Total = 0
        }
    }
}