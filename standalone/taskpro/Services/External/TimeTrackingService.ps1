# TimeTrackingService.ps1 - Service for managing time entries with unified data persistence

. (Join-Path $PSScriptRoot ".." "PraxisDataService.ps1")

class TimeTrackingService {
    [string]$DataPath
    [SimpleTimeEntry[]]$TimeEntries
    [datetime]$CurrentWeekFriday
    [hashtable]$CumulativeHours  # Track cumulative hours by id1/id2
    [object[]]$AvailableTasks     # Tasks loaded from tasks.json
    
    TimeTrackingService() {
        # Initialize unified data service
        $praxisRoot = Join-Path $PSScriptRoot "../.." -Resolve
        $this.DataPath = Join-Path $praxisRoot "_ProjectData"
        $this.TimeEntries = @()
        $this.CurrentWeekFriday = $this.GetCurrentWeekFriday()
        $this.CumulativeHours = @{}
        $this.AvailableTasks = @()
        
        # Initialize PraxisDataService if not already done
        if (-not [PraxisDataService]::IsInitialized) {
            [PraxisDataService]::Initialize($this.DataPath)
        }
        
        $this.LoadAllData()
    }
    
    [void] InitializeDataDirectory() {
        if (-not (Test-Path $this.DataPath)) {
            New-Item -ItemType Directory -Path $this.DataPath -Force | Out-Null
        }
        
        # Create backups directory
        $backupPath = Join-Path $this.DataPath "backups"
        if (-not (Test-Path $backupPath)) {
            New-Item -ItemType Directory -Path $backupPath -Force | Out-Null
        }
    }
    
    [void] LoadAllData() {
        # Load time entries
        $this.LoadTimeEntries()
        
        # Load tasks from shared tasks.json
        $this.LoadAvailableTasks()
        
        # Calculate cumulative hours
        $this.CalculateCumulativeHours()
    }
    
    [void] LoadTimeEntries() {
        try {
            # Load time entries from unified data
            $data = [PraxisDataService]::GetTimeEntries()
            
            $this.TimeEntries = @()
            foreach ($item in $data) {
                $hashtable = @{}
                $item.PSObject.Properties | ForEach-Object {
                    $hashtable[$_.Name] = $_.Value
                }
                $this.TimeEntries += [SimpleTimeEntry]::FromHashtable($hashtable)
            }
            
            if ($global:Logger) {
                & $global:Logger.Info "Loaded $($this.TimeEntries.Count) time entries from unified data"
            }
            
            # If no entries, create sample data
            if ($this.TimeEntries.Count -eq 0) {
                $this.CreateSampleData()
            }
            
        } catch {
            if ($global:Logger) {
                & $global:Logger.Error "Error loading time entries from unified data: $_"
            }
            $this.TimeEntries = @()
            $this.CreateSampleData()
        }
    }
    
    [void] LoadAvailableTasks() {
        try {
            # Load tasks from unified data for time entry selection
            $this.AvailableTasks = [PraxisDataService]::GetTasks()
            
            if ($global:Logger) {
                & $global:Logger.Info "Loaded $($this.AvailableTasks.Count) tasks from unified data"
            }
            
        } catch {
            if ($global:Logger) {
                & $global:Logger.Error "Error loading tasks from unified data: $_"
            }
            $this.AvailableTasks = @()
        }
    }
    
    [void] CalculateCumulativeHours() {
        # First load saved cumulative hours
        $cumulativePath = Join-Path $this.DataPath "cumulative-hours.json"
        if (Test-Path $cumulativePath) {
            try {
                $saved = Get-Content $cumulativePath -Raw | ConvertFrom-Json -AsHashtable
                $this.CumulativeHours = $saved
            }
            catch {
                $this.CumulativeHours.Clear()
            }
        }
        
        # Then update with current week's entries (in case file is out of sync)
        foreach ($entry in $this.TimeEntries) {
            # Only calculate cumulative for project entries (those with id1)
            if ($entry.ProjectCode -match '^\d{3}\s*/\s*\d+$') {
                $key = $entry.ProjectCode
                if (-not $this.CumulativeHours.ContainsKey($key)) {
                    $this.CumulativeHours[$key] = 0
                }
                # This will recount current entries - might need better logic
            }
        }
    }
    
    [void] SaveTimeEntries() {
        try {
            # Convert to hashtables for JSON serialization
            $data = @()
            foreach ($entry in $this.TimeEntries) {
                $data += $entry.ToHashtable()
            }
            
            # Save to unified data service
            [PraxisDataService]::UpdateTimeEntries($data)
            
            # Also save cumulative hours
            $this.SaveCumulativeHours()
            
            if ($global:Logger) {
                & $global:Logger.Info "Saved $($this.TimeEntries.Count) time entries to unified data"
            }
        }
        catch {
            if ($global:Logger) {
                & $global:Logger.Error "Error saving time entries to unified data: $_"
            }
        }
    }
    
    [void] SaveCumulativeHours() {
        try {
            $filePath = Join-Path $this.DataPath "cumulative-hours.json"
            $this.CumulativeHours | ConvertTo-Json -Depth 10 | Set-Content -Path $filePath -Encoding UTF8
        }
        catch {
            if ($global:Logger) {
                & $global:Logger.Error "Error saving cumulative hours: $_"
            }
        }
    }
    
    
    [void] CreateSampleData() {
        # Create some sample time entries for the current week
        $currentWeek = $this.GetCurrentWeekFriday().ToString("yyyyMMdd")
        
        # Sample project entries
        $project1 = [SimpleTimeEntry]::new($currentWeek, "PRJ001")
        $project1.Description = "Web Development Project"
        $project1.Monday = 8.0
        $project1.Tuesday = 7.5
        $project1.Wednesday = 8.0
        $project1.IsProjectEntry = $true
        $project1.CalculateTotal()
        
        $project2 = [SimpleTimeEntry]::new($currentWeek, "PRJ002") 
        $project2.Description = "Database Migration"
        $project2.Thursday = 4.0
        $project2.Friday = 6.0
        $project2.IsProjectEntry = $true
        $project2.CalculateTotal()
        
        # Sample time code entries
        $vacation = [SimpleTimeEntry]::new($currentWeek, "VAC")
        $vacation.Description = "Vacation"
        $vacation.Friday = 2.0
        $vacation.IsProjectEntry = $false
        $vacation.CalculateTotal()
        
        $this.TimeEntries = @($project1, $project2, $vacation)
        $this.SaveTimeEntries()
    }
    
    [SimpleTimeEntry[]] GetCurrentWeekEntries() {
        $currentWeek = $this.CurrentWeekFriday.ToString("yyyyMMdd")
        return $this.TimeEntries | Where-Object { $_.WeekEndingFriday -eq $currentWeek }
    }
    
    [SimpleTimeEntry[]] GetWeekEntries([string]$weekEndingFriday) {
        return $this.TimeEntries | Where-Object { $_.WeekEndingFriday -eq $weekEndingFriday }
    }
    
    [SimpleTimeEntry[]] GetAllEntries() {
        return $this.TimeEntries
    }
    
    [void] AddTimeEntry([SimpleTimeEntry]$entry) {
        $this.TimeEntries += $entry
        
        # Update cumulative hours if it's a project entry
        if ($entry.ProjectCode -match '^\d{3}\s*/\s*\d+$') {
            $key = $entry.ProjectCode
            if (-not $this.CumulativeHours.ContainsKey($key)) {
                $this.CumulativeHours[$key] = 0
            }
            $this.CumulativeHours[$key] += $entry.Total
        }
        
        $this.SaveTimeEntries()
    }
    
    [void] UpdateTimeEntry([SimpleTimeEntry]$entry) {
        $index = -1
        $oldEntry = $null
        for ($i = 0; $i -lt $this.TimeEntries.Count; $i++) {
            if ($this.TimeEntries[$i].Id -eq $entry.Id) {
                $index = $i
                $oldEntry = $this.TimeEntries[$i]
                break
            }
        }
        
        if ($index -ge 0) {
            # Update cumulative hours if project entry
            if ($entry.ProjectCode -match '^\d{3}\s*/\s*\d+$') {
                $key = $entry.ProjectCode
                if (-not $this.CumulativeHours.ContainsKey($key)) {
                    $this.CumulativeHours[$key] = 0
                }
                # Subtract old total, add new total
                if ($oldEntry -and $oldEntry.ProjectCode -eq $entry.ProjectCode) {
                    $this.CumulativeHours[$key] -= $oldEntry.Total
                }
                $this.CumulativeHours[$key] += $entry.Total
            }
            
            $entry.Modified = [datetime]::Now
            $this.TimeEntries[$index] = $entry
            $this.SaveTimeEntries()
        }
    }
    
    [void] DeleteTimeEntry([guid]$id) {
        # Find entry to delete
        $entryToDelete = $this.TimeEntries | Where-Object { $_.Id -eq $id } | Select-Object -First 1
        
        if ($entryToDelete) {
            # Update cumulative hours if it's a project entry
            if ($entryToDelete.ProjectCode -match '^\d{3}\s*/\s*\d+$') {
                $key = $entryToDelete.ProjectCode
                if ($this.CumulativeHours.ContainsKey($key)) {
                    $this.CumulativeHours[$key] -= $entryToDelete.Total
                    if ($this.CumulativeHours[$key] -le 0) {
                        $this.CumulativeHours.Remove($key)
                    }
                }
            }
        }
        
        $this.TimeEntries = $this.TimeEntries | Where-Object { $_.Id -ne $id }
        $this.SaveTimeEntries()
    }
    
    [SimpleTimeEntry] GetTimeEntry([guid]$id) {
        return $this.TimeEntries | Where-Object { $_.Id -eq $id } | Select-Object -First 1
    }
    
    [datetime] GetCurrentWeekFriday() {
        $today = [datetime]::Now.Date
        $daysUntilFriday = ([DayOfWeek]::Friday - $today.DayOfWeek + 7) % 7
        if ($daysUntilFriday -eq 0 -and $today.DayOfWeek -ne [DayOfWeek]::Friday) {
            $daysUntilFriday = 7
        }
        
        return $today.AddDays($daysUntilFriday)
    }
    
    [void] NavigateToWeek([datetime]$weekEndingFriday) {
        $this.CurrentWeekFriday = $weekEndingFriday
    }
    
    [void] NavigateToCurrentWeek() {
        $this.CurrentWeekFriday = $this.GetCurrentWeekFriday()
    }
    
    [void] NavigateToPreviousWeek() {
        $this.CurrentWeekFriday = $this.CurrentWeekFriday.AddDays(-7)
    }
    
    [void] NavigateToNextWeek() {
        $this.CurrentWeekFriday = $this.CurrentWeekFriday.AddDays(7)
    }
    
    [string] GetWeekDisplayString() {
        $mondayDate = $this.CurrentWeekFriday.AddDays(-4)
        return "$($mondayDate.ToString('MMM dd')) - $($this.CurrentWeekFriday.ToString('MMM dd, yyyy'))"
    }
    
    [bool] IsCurrentWeek() {
        $actualCurrentFriday = $this.GetCurrentWeekFriday()
        return $this.CurrentWeekFriday.Date -eq $actualCurrentFriday.Date
    }
    
    [decimal] GetWeekTotal([string]$weekEndingFriday) {
        $weekEntries = $this.GetWeekEntries($weekEndingFriday)
        $total = 0
        foreach ($entry in $weekEntries) {
            $total += $entry.Total
        }
        return $total
    }
    
    [decimal] GetCumulativeHours([string]$projectCode) {
        if ($this.CumulativeHours.ContainsKey($projectCode)) {
            return $this.CumulativeHours[$projectCode]
        }
        return 0
    }
    
    [hashtable] GetAllCumulativeHours() {
        return $this.CumulativeHours.Clone()
    }
    
    [hashtable[]] GetWeekSummary([string]$weekEndingFriday) {
        $weekEntries = $this.GetWeekEntries($weekEndingFriday)
        $summary = @()
        
        foreach ($entry in $weekEntries) {
            $summary += @{
                ProjectCode = $entry.ProjectCode
                Description = $entry.Description
                Total = $entry.Total
                IsProjectEntry = $entry.IsProjectEntry
            }
        }
        
        return $summary
    }
    
}