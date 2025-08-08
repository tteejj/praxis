# TimeTrackingService.ps1 - Service for managing time entries with JSON persistence
# Adapted for SimpleTaskPro integration with UniversalBackupManager

class TimeTrackingService {
    [string]$DataPath
    [string]$DataFile
    [SimpleTimeEntry[]]$TimeEntries
    [datetime]$CurrentWeekFriday
    
    TimeTrackingService() {
        $this.DataPath = Join-Path $PSScriptRoot "../Data"
        $this.DataFile = Join-Path $this.DataPath "timeentries.json"
        $this.TimeEntries = @()
        $this.CurrentWeekFriday = $this.GetCurrentWeekFriday()
        $this.EnsureDataDirectory()
        
        # Initialize universal backup system (same as SimpleTaskService)
        [UniversalBackupManager]::Initialize((Join-Path $PSScriptRoot ".."))
        
        # Register auto-save for critical data protection
        $serviceInstance = $this
        [UniversalBackupManager]::RegisterAutoSave(
            "timeentries", 
            $this.DataFile, 
            { $serviceInstance.Save() }.GetNewClosure(),
            "timeentries"
        )
        
        $this.LoadTimeEntries()
    }
    
    [void] EnsureDataDirectory() {
        # Match SimpleTaskService pattern
        if (-not (Test-Path $this.DataPath)) {
            New-Item -ItemType Directory -Path $this.DataPath -Force | Out-Null
        }
        
        $backupDir = Join-Path $this.DataPath "backups"
        if (-not (Test-Path $backupDir)) {
            New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
        }
    }
    
    [void] LoadTimeEntries() {
        if (Test-Path $this.DataFile) {
            try {
                $jsonContent = Get-Content $this.DataFile -Raw
                $data = $jsonContent | ConvertFrom-Json
                
                $this.TimeEntries = @()
                foreach ($item in $data) {
                    $hashtable = @{}
                    $item.PSObject.Properties | ForEach-Object {
                        $hashtable[$_.Name] = $_.Value
                    }
                    $this.TimeEntries += [SimpleTimeEntry]::FromHashtable($hashtable)
                }
            }
            catch {
                Write-Warning "Error loading time entries: $_"
                $this.TimeEntries = @()
            }
        } else {
            # Create sample data for testing
            $this.CreateSampleData()
        }
    }
    
    [void] Save() {
        # BULLETPROOF SAVE: Use universal backup system for maximum data safety (same as SimpleTaskService)
        $json = ""
        
        try {
            # Convert to hashtables for JSON serialization
            $data = @()
            foreach ($entry in $this.TimeEntries) {
                $data += $entry.ToHashtable()
            }
            
            $json = ConvertTo-Json $data -Depth 10
            
            # Use UniversalBackupManager for bulletproof atomic save
            $success = [UniversalBackupManager]::AtomicSave($this.DataFile, $json, "timeentries", "")
            
            if (-not $success) {
                throw "UniversalBackupManager failed to save time entries"
            }
            
        } catch {
            Write-Warning "Failed to save time entries: $_"
            
            # CRITICAL: Even if primary save fails, try emergency backup
            if ($json -and $json.Length -gt 0) {
                try {
                    $emergencyFile = "$($this.DataFile).emergency"
                    [System.IO.File]::WriteAllText($emergencyFile, $json)
                    Write-Warning "Emergency backup created at: $emergencyFile"
                } catch {
                    Write-Warning "Emergency backup also failed: $_"
                }
            }
        }
    }
    
    [void] SaveTimeEntries() {
        # Wrapper for backward compatibility with existing TimeTracker code
        $this.Save()
    }
    
    [void] CreateSampleData() {
        # Create some sample time entries for the current week
        $currentWeek = $this.GetCurrentWeekFriday().ToString("yyyyMMdd")
        
        # Sample project entries
        $project1 = [SimpleTimeEntry]::new($currentWeek, "v00123456789S")
        $project1.Description = "Web Development Project"
        $project1.Monday = 8.0
        $project1.Tuesday = 7.5
        $project1.Wednesday = 8.0
        $project1.IsProjectEntry = $true
        $project1.ID1Display = "WEB"
        $project1.CalculateTotal()
        
        $project2 = [SimpleTimeEntry]::new($currentWeek, "PRJ002") 
        $project2.Description = "Database Migration"
        $project2.Thursday = 4.0
        $project2.Friday = 6.0
        $project2.IsProjectEntry = $true
        $project2.ID1Display = "DB"
        $project2.CalculateTotal()
        
        # Sample time code entries
        $vacation = [SimpleTimeEntry]::new($currentWeek, "")
        $vacation.Description = "Vacation"
        $vacation.Friday = 2.0
        $vacation.IsProjectEntry = $false
        $vacation.ID1Display = "VAC"
        $vacation.CalculateTotal()
        
        $this.TimeEntries = @($project1, $project2, $vacation)
        $this.Save()
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
        $this.Save()
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
            $this.Save()
        }
    }
    
    [void] DeleteTimeEntry([guid]$id) {
        $this.TimeEntries = $this.TimeEntries | Where-Object { $_.Id -ne $id }
        $this.Save()
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