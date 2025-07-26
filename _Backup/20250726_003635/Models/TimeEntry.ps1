# TimeEntry Model - Universal time tracking for projects and non-project codes

class TimeEntry : BaseModel {
    [string]$WeekEndingFriday  # Friday date in yyyyMMdd format
    [string]$Name              # Project name or empty for non-project
    [string]$ID1               # Project ID1 or empty for non-project
    [string]$ID2               # Project ID2 or non-project code (3-5 chars)
    [decimal]$Monday
    [decimal]$Tuesday
    [decimal]$Wednesday
    [decimal]$Thursday
    [decimal]$Friday
    [decimal]$Total            # Calculated total for the week
    [string]$FiscalYear       # Format: "2024-2025" (Apr 1 2024 - Mar 31 2025)
    
    TimeEntry() : base() {
        $this.Monday = 0
        $this.Tuesday = 0
        $this.Wednesday = 0
        $this.Thursday = 0
        $this.Friday = 0
        $this.Total = 0
        $this.CalculateFiscalYear()
    }
    
    TimeEntry([string]$weekEndingFriday, [string]$id2) : base() {
        $this.WeekEndingFriday = $weekEndingFriday
        $this.ID2 = $id2
        $this.Name = ""
        $this.ID1 = ""
        $this.Monday = 0
        $this.Tuesday = 0
        $this.Wednesday = 0
        $this.Thursday = 0
        $this.Friday = 0
        $this.Total = 0
        $this.CalculateFiscalYear()
    }
    
    [void] CalculateTotal() {
        $this.Total = $this.Monday + $this.Tuesday + $this.Wednesday + $this.Thursday + $this.Friday
    }
    
    [void] CalculateFiscalYear() {
        if (-not $this.WeekEndingFriday) {
            $fridayDate = [DateTime]::Now
            while ($fridayDate.DayOfWeek -ne [DayOfWeek]::Friday) {
                $fridayDate = $fridayDate.AddDays(1)
            }
            $this.WeekEndingFriday = $fridayDate.ToString("yyyyMMdd")
        }
        
        $date = [DateTime]::ParseExact($this.WeekEndingFriday, "yyyyMMdd", $null)
        
        # Fiscal year runs April 1 - March 31
        if ($date.Month -ge 4) {
            # April through December - fiscal year starts this calendar year
            $fiscalStart = $date.Year
        } else {
            # January through March - fiscal year started last calendar year
            $fiscalStart = $date.Year - 1
        }
        
        $this.FiscalYear = "$fiscalStart-$($fiscalStart + 1)"
    }
    
    [bool] IsProjectEntry() {
        # Non-project entries have 3-5 character ID2 codes
        return $this.ID2.Length -gt 5
    }
    
    [DateTime] GetWeekStartMonday() {
        $fridayDate = [DateTime]::ParseExact($this.WeekEndingFriday, "yyyyMMdd", $null)
        return $fridayDate.AddDays(-4)  # Monday is 4 days before Friday
    }
    
    [string] GetWeekDisplayString() {
        $fridayDate = [DateTime]::ParseExact($this.WeekEndingFriday, "yyyyMMdd", $null)
        return "Week ending " + $fridayDate.ToString("MM/dd/yyyy")
    }
}