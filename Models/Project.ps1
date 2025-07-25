# Project Model - Enhanced project definition based on PMC pattern

class Project : BaseModel {
    [string]$FullProjectName
    [string]$Nickname
    [string]$ID1
    [string]$ID2
    [DateTime]$DateAssigned
    [DateTime]$BFDate
    [DateTime]$DateDue
    [string]$Note
    [string]$CAAPath
    [string]$RequestPath
    [string]$T2020Path
    [decimal]$CumulativeHrs
    [DateTime]$ClosedDate
    
    # Audit Information
    [string]$AuditType
    [string]$AuditProgram
    [string]$AuditCase
    [DateTime]$AuditStartDate
    [DateTime]$AuditPeriodFrom
    [DateTime]$AuditPeriodTo
    
    # Additional Audit Periods
    [DateTime]$AuditPeriod1Start
    [DateTime]$AuditPeriod1End
    [DateTime]$AuditPeriod2Start
    [DateTime]$AuditPeriod2End
    [DateTime]$AuditPeriod3Start
    [DateTime]$AuditPeriod3End
    [DateTime]$AuditPeriod4Start
    [DateTime]$AuditPeriod4End
    [DateTime]$AuditPeriod5Start
    [DateTime]$AuditPeriod5End
    
    # Client Information
    [string]$ClientID  # TPNum
    [string]$Address
    [string]$City
    [string]$Province
    [string]$PostalCode
    [string]$Country
    [string]$ShipToAddress
    
    # Auditor Information
    [string]$AuditorName
    [string]$AuditorPhone
    [string]$AuditorTL
    [string]$AuditorTLPhone
    
    # Contact Information
    [string]$Contact1Name
    [string]$Contact1Phone
    [string]$Contact1Ext
    [string]$Contact1Address
    [string]$Contact1Title
    [string]$Contact2Name
    [string]$Contact2Phone
    [string]$Contact2Ext
    [string]$Contact2Address
    [string]$Contact2Title
    
    # System Information
    [string]$AccountingSoftware1
    [string]$AccountingSoftware1Other
    [string]$AccountingSoftware1Type
    [string]$AccountingSoftware2
    [string]$AccountingSoftware2Other
    [string]$AccountingSoftware2Type
    
    # Other Information
    [DateTime]$RequestDate
    [string]$FXInfo
    [string]$Comments
    
    # Status tracking (not from Excel)
    [string]$Status = "Active"
    
    # Default constructor
    Project() : base() {
        $this.FullProjectName = ""
        $this.Nickname = ""
        $this.ID1 = ""
        $this.ID2 = ""
        $this.DateAssigned = [DateTime]::Now
        $this.BFDate = [DateTime]::Now
        $this.DateDue = [DateTime]::Now.AddDays(42)  # 6 weeks default
        $this.Note = ""
        $this.CAAPath = ""
        $this.RequestPath = ""
        $this.T2020Path = ""
        $this.CumulativeHrs = 0
        $this.ClosedDate = [DateTime]::MinValue
        
        # Initialize new audit date fields
        $this.AuditStartDate = [DateTime]::MinValue
        $this.AuditPeriodFrom = [DateTime]::MinValue
        $this.AuditPeriodTo = [DateTime]::MinValue
        $this.AuditPeriod1Start = [DateTime]::MinValue
        $this.AuditPeriod1End = [DateTime]::MinValue
        $this.AuditPeriod2Start = [DateTime]::MinValue
        $this.AuditPeriod2End = [DateTime]::MinValue
        $this.AuditPeriod3Start = [DateTime]::MinValue
        $this.AuditPeriod3End = [DateTime]::MinValue
        $this.AuditPeriod4Start = [DateTime]::MinValue
        $this.AuditPeriod4End = [DateTime]::MinValue
        $this.AuditPeriod5Start = [DateTime]::MinValue
        $this.AuditPeriod5End = [DateTime]::MinValue
        $this.RequestDate = [DateTime]::MinValue
        
        # BaseModel handles Id, CreatedAt, UpdatedAt, Deleted initialization
    }
    
    Project([string]$fullName, [string]$nickname) : base() {
        $this.FullProjectName = $fullName
        $this.Nickname = $nickname
        $this.ID1 = ""
        $this.ID2 = ""
        $this.DateAssigned = [DateTime]::Now
        $this.BFDate = [DateTime]::Now
        $this.DateDue = [DateTime]::Now.AddDays(42)  # 6 weeks default
        $this.Note = ""
        $this.CAAPath = ""
        $this.RequestPath = ""
        $this.T2020Path = ""
        $this.CumulativeHrs = 0
        $this.ClosedDate = [DateTime]::MinValue
        
        # Initialize new audit date fields
        $this.AuditStartDate = [DateTime]::MinValue
        $this.AuditPeriodFrom = [DateTime]::MinValue
        $this.AuditPeriodTo = [DateTime]::MinValue
        $this.AuditPeriod1Start = [DateTime]::MinValue
        $this.AuditPeriod1End = [DateTime]::MinValue
        $this.AuditPeriod2Start = [DateTime]::MinValue
        $this.AuditPeriod2End = [DateTime]::MinValue
        $this.AuditPeriod3Start = [DateTime]::MinValue
        $this.AuditPeriod3End = [DateTime]::MinValue
        $this.AuditPeriod4Start = [DateTime]::MinValue
        $this.AuditPeriod4End = [DateTime]::MinValue
        $this.AuditPeriod5Start = [DateTime]::MinValue
        $this.AuditPeriod5End = [DateTime]::MinValue
        $this.RequestDate = [DateTime]::MinValue
        
        # BaseModel handles Id, CreatedAt, UpdatedAt, Deleted initialization
    }
    
    # Legacy constructor for backward compatibility
    Project([string]$name) : base() {
        $this.FullProjectName = $name
        $this.Nickname = $name
        $this.ID1 = ""
        $this.ID2 = ""
        $this.DateAssigned = [DateTime]::Now
        $this.BFDate = [DateTime]::Now
        $this.DateDue = [DateTime]::Now.AddDays(42)
        $this.Note = ""
        $this.CAAPath = ""
        $this.RequestPath = ""
        $this.T2020Path = ""
        $this.CumulativeHrs = 0
        $this.ClosedDate = [DateTime]::MinValue
        
        # Initialize new audit date fields
        $this.AuditStartDate = [DateTime]::MinValue
        $this.AuditPeriodFrom = [DateTime]::MinValue
        $this.AuditPeriodTo = [DateTime]::MinValue
        $this.AuditPeriod1Start = [DateTime]::MinValue
        $this.AuditPeriod1End = [DateTime]::MinValue
        $this.AuditPeriod2Start = [DateTime]::MinValue
        $this.AuditPeriod2End = [DateTime]::MinValue
        $this.AuditPeriod3Start = [DateTime]::MinValue
        $this.AuditPeriod3End = [DateTime]::MinValue
        $this.AuditPeriod4Start = [DateTime]::MinValue
        $this.AuditPeriod4End = [DateTime]::MinValue
        $this.AuditPeriod5Start = [DateTime]::MinValue
        $this.AuditPeriod5End = [DateTime]::MinValue
        $this.RequestDate = [DateTime]::MinValue
        
        # BaseModel handles Id, CreatedAt, UpdatedAt, Deleted initialization
    }
}