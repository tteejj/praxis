# TimeTrackingService.ps1 - Service for managing time entries with JSON persistence

class TimeTrackingService {
    [string]$DataPath
    [SimpleTimeEntry[]]$TimeEntries
    [datetime]$CurrentWeekFriday
    
    TimeTrackingService() {
        $this.DataPath = "$PSScriptRoot/../Data"
        $this.TimeEntries = @()
        $this.CurrentWeekFriday = $this.GetCurrentWeekFriday()
        $this.InitializeDataDirectory()
        $this.LoadTimeEntries()
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
    
    [void] LoadTimeEntries() {
        $filePath = Join-Path $this.DataPath "timeentries.json"
        
        if (Test-Path $filePath) {
            try {
                $jsonContent = Get-Content $filePath -Raw
                $data = $jsonContent | ConvertFrom-Json
                
                $this.TimeEntries = @()
                foreach ($item in $data) {
                    $hashtable = @{}
                    $item.PSObject.Properties | ForEach-Object {
                        $hashtable[$_.Name] = $_.Value
                    }
                    $this.TimeEntries += [SimpleTimeEntry]::FromHashtable($hashtable)
                }
                
                if ($global:Logger) {
                    & $global:Logger.Info "Loaded $($this.TimeEntries.Count) time entries"
                }
            }
            catch {
                if ($global:Logger) {
                    & $global:Logger.Error "Error loading time entries: $_"
                }
                $this.TimeEntries = @()
            }
        } else {
            # Create sample data for testing
            $this.CreateSampleData()
        }
    }
    
    [void] SaveTimeEntries() {
        try {
            # Create backup first
            $this.CreateBackup()
            
            # Convert to hashtables for JSON serialization
            $data = @()
            foreach ($entry in $this.TimeEntries) {
                $data += $entry.ToHashtable()
            }
            
            # Save to JSON
            $filePath = Join-Path $this.DataPath "timeentries.json"
            $jsonContent = $data | ConvertTo-Json -Depth 10
            Set-Content -Path $filePath -Value $jsonContent -Encoding UTF8
            
            if ($global:Logger) {
                & $global:Logger.Info "Saved $($this.TimeEntries.Count) time entries"
            }
        }
        catch {
            if ($global:Logger) {
                & $global:Logger.Error "Error saving time entries: $_"
            }
        }
    }
    
    [void] CreateBackup() {
        $filePath = Join-Path $this.DataPath "timeentries.json"
        if (Test-Path $filePath) {
            $timestamp = [datetime]::Now.ToString("yyyyMMdd_HHmmss")
            $backupPath = Join-Path $this.DataPath "backups" "timeentries_backup_$timestamp.json"
            Copy-Item $filePath $backupPath
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
        $this.SaveTimeEntries()
    }
    
    [void] UpdateTimeEntry([SimpleTimeEntry]$entry) {
        $index = -1
        for ($i = 0; $i -lt $this.TimeEntries.Count; $i++) {
            if ($this.TimeEntries[$i].Id -eq $entry.Id) {
                $index = $i
                break
            }
        }
        
        if ($index -ge 0) {
            $entry.Modified = [datetime]::Now
            $this.TimeEntries[$index] = $entry
            $this.SaveTimeEntries()
        }
    }
    
    [void] DeleteTimeEntry([guid]$id) {
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