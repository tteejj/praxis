# DataPoolAdapter.ps1 - Adapter to make TimeTracker use the common data pool

class DataPoolAdapter {
    [string]$AppName = "TimeTracker"
    [bool]$UseDataPool = $false
    
    DataPoolAdapter() {
        # Check if DataPool is available
        $dataPoolPath = Join-Path $PSScriptRoot "../../PraxisCore/Services/DataPool.ps1"
        if (Test-Path $dataPoolPath) {
            . $dataPoolPath
            [DataPool]::Initialize()
            $this.UseDataPool = $true
        }
    }
    
    # Load time entries from either local file or data pool
    [object[]] LoadTimeEntries() {
        if ($this.UseDataPool) {
            # Try data pool first
            $entries = [DataPool]::Read($this.AppName, "timeentries")
            if ($entries) {
                return $entries
            }
        }
        
        # Fall back to local file
        $localFile = Join-Path $PSScriptRoot "../Data/timeentries.json"
        if (Test-Path $localFile) {
            return Get-Content $localFile -Raw | ConvertFrom-Json
        }
        
        return @()
    }
    
    # Save time entries to both local and data pool
    [void] SaveTimeEntries([object[]]$entries) {
        # Save to local file (for standalone operation)
        $localFile = Join-Path $PSScriptRoot "../Data/timeentries.json"
        $localDir = Split-Path $localFile -Parent
        if (-not (Test-Path $localDir)) {
            New-Item -ItemType Directory -Path $localDir -Force | Out-Null
        }
        $entries | ConvertTo-Json -Depth 10 | Set-Content $localFile -Encoding UTF8
        
        # Also save to data pool if available
        if ($this.UseDataPool) {
            [DataPool]::Write($this.AppName, "timeentries", $entries)
        }
    }
    
    # Check for incoming data from other apps
    [object[]] CheckExchanges() {
        if ($this.UseDataPool) {
            return [DataPool]::GetPendingExchanges($this.AppName)
        }
        return @()
    }
    
    # Process task from TaskPro
    [hashtable] ProcessTaskExchange([object]$exchange) {
        if ($exchange.Type -eq "task" -and $exchange.Data.Action -eq "CreateTimeEntry") {
            return @{
                ProjectCode = "TASK-" + $exchange.Data.TaskId.Substring(0, 8).ToUpper()
                Description = $exchange.Data.TaskTitle
                IsProjectEntry = $true
            }
        } elseif ($exchange.Type -eq "task" -and $exchange.Data.Action -eq "StartTracking") {
            return @{
                ProjectCode = "TASK-" + $exchange.Data.TaskId.Substring(0, 8).ToUpper()
                Description = $exchange.Data.TaskTitle
                IsProjectEntry = $true
                StartTracking = $true
            }
        }
        return $null
    }
    
    # Send time entries to ExcelDataFlow
    [void] ExportToExcel([object[]]$entries, [string]$weekEnding) {
        if ($this.UseDataPool) {
            [DataPool]::Exchange($this.AppName, "ExcelDataFlow", "export-request", @{
                Data = $entries
                Template = "WeeklyTimesheet"
                Format = "xlsx"
                WeekEnding = $weekEnding
            })
        }
    }
    
    # Add time entry to recent items
    [void] AddToRecent([object]$entry) {
        if ($this.UseDataPool) {
            $displayName = "$($entry.ProjectCode) - $($entry.Description)"
            [DataPool]::AddRecentItem($this.AppName, "timeentry", $displayName, $entry.Id)
        }
    }
    
    # Send time data to CommandLibrary for automation
    [void] SendToCommandLibrary([object[]]$entries) {
        if ($this.UseDataPool) {
            [DataPool]::Exchange($this.AppName, "CommandLibrary", "time-data", @{
                Entries = $entries
                Action = "CreateReportMacro"
            })
        }
    }
}