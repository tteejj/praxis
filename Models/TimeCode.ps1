# TimeCode Model - Non-project time codes (vacation, admin, etc.)

class TimeCode : BaseModel {
    [string]$ID2               # 3-5 character code (e.g., "VAC", "SICK", "ADMIN")
    [string]$Description       # Optional description for display
    [bool]$IsActive           # Whether this code is currently in use
    [int]$DisplayOrder        # For sorting common codes to top
    
    TimeCode() : base() {
        $this.IsActive = $true
        $this.DisplayOrder = 999  # Default to bottom
    }
    
    TimeCode([string]$id2) : base() {
        $this.ID2 = $id2.ToUpper()
        $this.Description = ""
        $this.IsActive = $true
        $this.DisplayOrder = 999
    }
    
    TimeCode([string]$id2, [string]$description) : base() {
        $this.ID2 = $id2.ToUpper()
        $this.Description = $description
        $this.IsActive = $true
        $this.DisplayOrder = 999
    }
    
    [string] GetDisplayName() {
        if ($this.Description) {
            return "$($this.ID2) - $($this.Description)"
        }
        return $this.ID2
    }
    
    # Static method to get common time codes
    static [TimeCode[]] GetCommonCodes() {
        return @(
            [TimeCode]::new("VAC", "Vacation"),
            [TimeCode]::new("SICK", "Sick Leave"),
            [TimeCode]::new("STAT", "Statutory Holiday"),
            [TimeCode]::new("ADMIN", "Administration"),
            [TimeCode]::new("TRAIN", "Training"),
            [TimeCode]::new("MTG", "Meetings"),
            [TimeCode]::new("PD", "Professional Development")
        )
    }
}