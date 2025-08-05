# SimpleTimeEntry.ps1 - Simplified time entry model for standalone tracker

class SimpleTimeEntry {
    [guid]$Id
    [string]$WeekEndingFriday  # Format: yyyyMMdd
    [string]$ProjectCode       # Project code or time code (VAC, SICK, etc.)
    [string]$Description       # Project name or description
    [decimal]$Monday = 0
    [decimal]$Tuesday = 0
    [decimal]$Wednesday = 0
    [decimal]$Thursday = 0
    [decimal]$Friday = 0
    [decimal]$Total = 0
    [string]$FiscalYear
    [bool]$IsProjectEntry = $true  # true for projects, false for time codes
    [datetime]$Created
    [datetime]$Modified
    
    SimpleTimeEntry() {
        $this.Id = [guid]::NewGuid()
        $this.WeekEndingFriday = $this.GetCurrentWeekEndingFriday()
        $this.FiscalYear = $this.CalculateFiscalYear()
        $this.Created = [datetime]::Now
        $this.Modified = [datetime]::Now
    }
    
    SimpleTimeEntry([string]$weekEndingFriday, [string]$projectCode) {
        $this.Id = [guid]::NewGuid()
        $this.WeekEndingFriday = $weekEndingFriday
        $this.ProjectCode = $projectCode
        $this.FiscalYear = $this.CalculateFiscalYear()
        $this.Created = [datetime]::Now
        $this.Modified = [datetime]::Now
    }
    
    [void] CalculateTotal() {
        $this.Total = $this.Monday + $this.Tuesday + $this.Wednesday + $this.Thursday + $this.Friday
        $this.Modified = [datetime]::Now
    }
    
    [string] CalculateFiscalYear() {
        if ([string]::IsNullOrEmpty($this.WeekEndingFriday)) {
            $fridayDate = [datetime]::Now
        } else {
            $fridayDate = [datetime]::ParseExact($this.WeekEndingFriday, "yyyyMMdd", $null)
        }
        
        # Fiscal year runs April 1 - March 31
        if ($fridayDate.Month -ge 4) {
            return "$($fridayDate.Year)-$($fridayDate.Year + 1)"
        } else {
            return "$($fridayDate.Year - 1)-$($fridayDate.Year)"
        }
    }
    
    [string] GetCurrentWeekEndingFriday() {
        $today = [datetime]::Now.Date
        $daysUntilFriday = ([DayOfWeek]::Friday - $today.DayOfWeek + 7) % 7
        if ($daysUntilFriday -eq 0 -and $today.DayOfWeek -ne [DayOfWeek]::Friday) {
            $daysUntilFriday = 7
        }
        
        $fridayDate = $today.AddDays($daysUntilFriday)
        return $fridayDate.ToString("yyyyMMdd")
    }
    
    [datetime] GetWeekStartMonday() {
        $fridayDate = [datetime]::ParseExact($this.WeekEndingFriday, "yyyyMMdd", $null)
        return $fridayDate.AddDays(-4)  # Monday is 4 days before Friday
    }
    
    [string] GetWeekDisplayString() {
        $fridayDate = [datetime]::ParseExact($this.WeekEndingFriday, "yyyyMMdd", $null)
        $mondayDate = $fridayDate.AddDays(-4)
        return "$($mondayDate.ToString('MMM dd')) - $($fridayDate.ToString('MMM dd, yyyy'))"
    }
    
    [bool] IsTimeCode() {
        # Time codes are typically 3-5 characters (VAC, SICK, ADMIN)
        return -not $this.IsProjectEntry -or ($this.ProjectCode.Length -le 5 -and $this.ProjectCode.Length -ge 3)
    }
    
    [string] GetDisplayName() {
        if ($this.IsTimeCode()) {
            if ($this.Description) {
                return "$($this.ProjectCode) - $($this.Description)"
            }
            return $this.ProjectCode
        } else {
            if ($this.Description) {
                return "$($this.ProjectCode) - $($this.Description)"
            }
            return $this.ProjectCode
        }
    }
    
    [void] SetDayHours([string]$dayName, [decimal]$hours) {
        if ($hours -lt 0) { $hours = 0 }
        if ($hours -gt 24) { $hours = 24 }
        
        switch ($dayName.ToLower()) {
            "monday" { $this.Monday = $hours }
            "tuesday" { $this.Tuesday = $hours }
            "wednesday" { $this.Wednesday = $hours }
            "thursday" { $this.Thursday = $hours }
            "friday" { $this.Friday = $hours }
        }
        
        $this.CalculateTotal()
    }
    
    [decimal] GetDayHours([string]$dayName) {
        switch ($dayName.ToLower()) {
            "monday" { return $this.Monday }
            "tuesday" { return $this.Tuesday }
            "wednesday" { return $this.Wednesday }
            "thursday" { return $this.Thursday }
            "friday" { return $this.Friday }
        }
        return 0
    }
    
    [hashtable] ToHashtable() {
        return @{
            Id = $this.Id.ToString()
            WeekEndingFriday = $this.WeekEndingFriday
            ProjectCode = $this.ProjectCode
            Description = $this.Description
            Monday = $this.Monday
            Tuesday = $this.Tuesday
            Wednesday = $this.Wednesday
            Thursday = $this.Thursday
            Friday = $this.Friday
            Total = $this.Total
            FiscalYear = $this.FiscalYear
            IsProjectEntry = $this.IsProjectEntry
            Created = $this.Created.ToString("yyyy-MM-dd HH:mm:ss")
            Modified = $this.Modified.ToString("yyyy-MM-dd HH:mm:ss")
        }
    }
    
    static [SimpleTimeEntry] FromHashtable([hashtable]$data) {
        $entry = [SimpleTimeEntry]::new()
        
        if ($data.Id) { $entry.Id = [guid]$data.Id }
        if ($data.WeekEndingFriday) { $entry.WeekEndingFriday = $data.WeekEndingFriday }
        if ($data.ProjectCode) { $entry.ProjectCode = $data.ProjectCode }
        if ($data.Description) { $entry.Description = $data.Description }
        if ($data.Monday) { $entry.Monday = [decimal]$data.Monday }
        if ($data.Tuesday) { $entry.Tuesday = [decimal]$data.Tuesday }
        if ($data.Wednesday) { $entry.Wednesday = [decimal]$data.Wednesday }
        if ($data.Thursday) { $entry.Thursday = [decimal]$data.Thursday }
        if ($data.Friday) { $entry.Friday = [decimal]$data.Friday }
        if ($data.Total) { $entry.Total = [decimal]$data.Total }
        if ($data.FiscalYear) { $entry.FiscalYear = $data.FiscalYear }
        if ($null -ne $data.IsProjectEntry) { $entry.IsProjectEntry = [bool]$data.IsProjectEntry }
        if ($data.Created) { $entry.Created = [datetime]$data.Created }
        if ($data.Modified) { $entry.Modified = [datetime]$data.Modified }
        
        # Recalculate total if needed
        $entry.CalculateTotal()
        
        return $entry
    }
    
    # Static method to get common time codes
    static [hashtable[]] GetCommonTimeCodes() {
        return @(
            @{ Code = "VAC"; Description = "Vacation" },
            @{ Code = "SICK"; Description = "Sick Leave" },
            @{ Code = "STAT"; Description = "Statutory Holiday" },
            @{ Code = "ADMIN"; Description = "Administration" },
            @{ Code = "TRAIN"; Description = "Training" },
            @{ Code = "MTG"; Description = "Meetings" },
            @{ Code = "PD"; Description = "Professional Development" }
        )
    }
}