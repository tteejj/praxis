# TimeTrackingService - Manages all time entries and calculations

class TimeTrackingService {
    [string]$DataPath
    [System.Collections.ArrayList]$TimeEntries
    [System.Collections.ArrayList]$TimeCodes
    [Logger]$Logger
    [EventBus]$EventBus
    [ProjectService]$ProjectService
    
    TimeTrackingService() {
        $this.TimeEntries = [System.Collections.ArrayList]::new()
        $this.TimeCodes = [System.Collections.ArrayList]::new()
        $this.DataPath = Join-Path $global:PraxisRoot "_ProjectData/timeentries.json"
        $this.LoadData()
        $this.InitializeCommonTimeCodes()
    }
    
    [void] Initialize([ServiceContainer]$container) {
        $this.Logger = $container.GetService("Logger")
        $this.EventBus = $container.GetService("EventBus")
        $this.ProjectService = $container.GetService("ProjectService")
    }
    
    [void] InitializeCommonTimeCodes() {
        # Add common codes if not already present
        $commonCodes = [TimeCode]::GetCommonCodes()
        foreach ($code in $commonCodes) {
            if (-not ($this.TimeCodes | Where-Object { $_.ID2 -eq $code.ID2 })) {
                $this.TimeCodes.Add($code) | Out-Null
            }
        }
    }
    
    [void] LoadData() {
        if (Test-Path $this.DataPath) {
            try {
                $data = Get-Content $this.DataPath -Raw | ConvertFrom-Json
                
                # Load time entries
                if ($data.TimeEntries) {
                    foreach ($entry in $data.TimeEntries) {
                        $timeEntry = [TimeEntry]::new()
                        foreach ($prop in $entry.PSObject.Properties) {
                            if ($timeEntry.PSObject.Properties[$prop.Name]) {
                                $timeEntry.$($prop.Name) = $prop.Value
                            }
                        }
                        $this.TimeEntries.Add($timeEntry) | Out-Null
                    }
                }
                
                # Load time codes
                if ($data.TimeCodes) {
                    foreach ($code in $data.TimeCodes) {
                        $timeCode = [TimeCode]::new()
                        foreach ($prop in $code.PSObject.Properties) {
                            if ($timeCode.PSObject.Properties[$prop.Name]) {
                                $timeCode.$($prop.Name) = $prop.Value
                            }
                        }
                        $this.TimeCodes.Add($timeCode) | Out-Null
                    }
                }
            }
            catch {
                if ($this.Logger) {
                    $this.Logger.Error("Failed to load time tracking data: $_")
                }
            }
        }
    }
    
    [void] SaveData() {
        $data = @{
            TimeEntries = $this.TimeEntries
            TimeCodes = $this.TimeCodes
            LastUpdated = [DateTime]::Now.ToString("yyyy-MM-dd HH:mm:ss")
        }
        
        try {
            $json = $data | ConvertTo-Json -Depth 10
            Set-Content -Path $this.DataPath -Value $json -Encoding UTF8
            
            if ($this.Logger) {
                $this.Logger.Info("Time tracking data saved")
            }
        }
        catch {
            if ($this.Logger) {
                $this.Logger.Error("Failed to save time tracking data: $_")
            }
        }
    }
    
    # Get or create time entry for a specific week and ID2
    [TimeEntry] GetOrCreateTimeEntry([string]$weekEndingFriday, [string]$id2) {
        $existing = $this.TimeEntries | Where-Object { 
            $_.WeekEndingFriday -eq $weekEndingFriday -and $_.ID2 -eq $id2 
        } | Select-Object -First 1
        
        if ($existing) {
            return $existing
        }
        
        # Create new entry
        $entry = [TimeEntry]::new($weekEndingFriday, $id2)
        
        # If it's a project ID2, populate project info
        if ($id2.Length -gt 5) {
            $project = $this.ProjectService.GetAllProjects() | Where-Object { $_.ID2 -eq $id2 } | Select-Object -First 1
            if ($project) {
                $entry.Name = $project.Nickname
                $entry.ID1 = $project.ID1
            }
        }
        
        $this.TimeEntries.Add($entry) | Out-Null
        return $entry
    }
    
    # Get entries for a specific week
    [TimeEntry[]] GetWeekEntries([string]$weekEndingFriday) {
        return $this.TimeEntries | Where-Object { $_.WeekEndingFriday -eq $weekEndingFriday }
    }
    
    # Get entries for current week
    [TimeEntry[]] GetCurrentWeekEntries() {
        $friday = $this.GetCurrentWeekFriday()
        return $this.GetWeekEntries($friday.ToString("yyyyMMdd"))
    }
    
    # Update time entry
    [void] UpdateTimeEntry([TimeEntry]$entry) {
        $entry.CalculateTotal()
        $entry.CalculateFiscalYear()
        $entry.UpdatedAt = [DateTime]::Now
        
        $this.SaveData()
        
        if ($this.EventBus) {
            $this.EventBus.Publish([EventNames]::TimeEntryUpdated, $this, @{ TimeEntry = $entry })
        }
    }
    
    # Add hours for today
    [void] AddHoursForToday([string]$id2, [decimal]$hours, [string]$description = "") {
        $today = [DateTime]::Now
        $friday = $this.GetWeekFridayForDate($today)
        
        $entry = $this.GetOrCreateTimeEntry($friday.ToString("yyyyMMdd"), $id2)
        
        # Add hours to appropriate day
        switch ($today.DayOfWeek) {
            Monday { $entry.Monday += $hours }
            Tuesday { $entry.Tuesday += $hours }
            Wednesday { $entry.Wednesday += $hours }
            Thursday { $entry.Thursday += $hours }
            Friday { $entry.Friday += $hours }
            default {
                if ($this.Logger) {
                    $this.Logger.Warning("Cannot add time for weekend day")
                }
                return
            }
        }
        
        $this.UpdateTimeEntry($entry)
    }
    
    # Get Friday date for current week
    [DateTime] GetCurrentWeekFriday() {
        $today = [DateTime]::Now
        return $this.GetWeekFridayForDate($today)
    }
    
    # Get Friday date for any date's week
    [DateTime] GetWeekFridayForDate([DateTime]$date) {
        $friday = $date
        while ($friday.DayOfWeek -ne [DayOfWeek]::Friday) {
            if ($friday.DayOfWeek -eq [DayOfWeek]::Saturday) {
                $friday = $friday.AddDays(-1)
            } else {
                $friday = $friday.AddDays(1)
            }
        }
        return $friday
    }
    
    # Calculate total hours for a project
    [decimal] GetProjectTotalHours([string]$id2) {
        $total = 0
        $entries = $this.TimeEntries | Where-Object { $_.ID2 -eq $id2 }
        foreach ($entry in $entries) {
            $total += $entry.Total
        }
        return $total
    }
    
    # Calculate fiscal year total for non-project code
    [decimal] GetFiscalYearTotal([string]$id2, [string]$fiscalYear) {
        $total = 0
        $entries = $this.TimeEntries | Where-Object { 
            $_.ID2 -eq $id2 -and $_.FiscalYear -eq $fiscalYear 
        }
        foreach ($entry in $entries) {
            $total += $entry.Total
        }
        return $total
    }
    
    # Get current fiscal year string
    [string] GetCurrentFiscalYear() {
        $today = [DateTime]::Now
        if ($today.Month -ge 4) {
            return "$($today.Year)-$($today.Year + 1)"
        } else {
            return "$($today.Year - 1)-$($today.Year)"
        }
    }
    
    # Get all unique ID2s (both project and non-project)
    [string[]] GetAllID2s() {
        $id2s = @()
        
        # Add project ID2s
        $projects = $this.ProjectService.GetAllProjects() | Where-Object { -not $_.Deleted -and $_.ID2 }
        foreach ($project in $projects) {
            $id2s += $project.ID2
        }
        
        # Add time code ID2s
        foreach ($code in $this.TimeCodes) {
            if ($code.IsActive) {
                $id2s += $code.ID2
            }
        }
        
        return $id2s | Select-Object -Unique | Sort-Object
    }
    
    # Get display info for an ID2
    [hashtable] GetID2DisplayInfo([string]$id2) {
        # Check if it's a project
        $project = $this.ProjectService.GetAllProjects() | Where-Object { $_.ID2 -eq $id2 } | Select-Object -First 1
        if ($project) {
            return @{
                Name = $project.Nickname
                ID1 = $project.ID1
                ID2 = $id2
                IsProject = $true
            }
        }
        
        # It's a non-project code
        $timeCode = $this.TimeCodes | Where-Object { $_.ID2 -eq $id2 } | Select-Object -First 1
        return @{
            Name = ""
            ID1 = ""
            ID2 = $id2
            IsProject = $false
            Description = if ($timeCode) { $timeCode.Description } else { "" }
        }
    }
    
    # Add or update time code
    [void] AddTimeCode([string]$id2, [string]$description = "") {
        $existing = $this.TimeCodes | Where-Object { $_.ID2 -eq $id2 } | Select-Object -First 1
        if ($existing) {
            $existing.Description = $description
            $existing.UpdatedAt = [DateTime]::Now
        } else {
            $code = [TimeCode]::new($id2, $description)
            $this.TimeCodes.Add($code) | Out-Null
        }
        $this.SaveData()
    }
}