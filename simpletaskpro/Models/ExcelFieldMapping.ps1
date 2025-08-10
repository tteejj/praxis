# ExcelFieldMapping.ps1 - Data model for Excel field mappings

class ExcelFieldMapping {
    [string]$Id
    [string]$DisplayName      # User-friendly name shown in screen
    [string]$SourceCell       # Excel cell reference (W23, B15, etc.)
    [string]$DestinationCell  # Target Excel cell (A1, A2, etc.)
    [string]$T2020Name        # Field name for T2020 text export
    [bool]$IncludeInT2020     # X mark - include in T2020 export
    [string]$Category         # Project Info, Contact, Site Info, etc.
    [int]$SortOrder           # Order for display and export
    [datetime]$CreatedDate
    [datetime]$ModifiedDate
    
    # Default constructor
    ExcelFieldMapping() {
        $this.Id = [System.Guid]::NewGuid().ToString()
        $this.DisplayName = ""
        $this.SourceCell = ""
        $this.DestinationCell = ""
        $this.T2020Name = ""
        $this.IncludeInT2020 = $false
        $this.Category = "General"
        $this.SortOrder = 0
        $this.CreatedDate = Get-Date
        $this.ModifiedDate = Get-Date
    }
    
    # Constructor with display name
    ExcelFieldMapping([string]$displayName) {
        $this.Id = [System.Guid]::NewGuid().ToString()
        $this.DisplayName = $displayName
        $this.SourceCell = ""
        $this.DestinationCell = ""
        $this.T2020Name = $displayName.Replace(" ", "")  # Default T2020 name
        $this.IncludeInT2020 = $false
        $this.Category = "General"
        $this.SortOrder = 0
        $this.CreatedDate = Get-Date
        $this.ModifiedDate = Get-Date
    }
    
    # Full constructor
    ExcelFieldMapping([string]$displayName, [string]$sourceCell, [string]$destinationCell, [string]$t2020Name, [string]$category) {
        $this.Id = [System.Guid]::NewGuid().ToString()
        $this.DisplayName = $displayName
        $this.SourceCell = $sourceCell
        $this.DestinationCell = $destinationCell
        $this.T2020Name = $t2020Name
        $this.IncludeInT2020 = $false
        $this.Category = $category
        $this.SortOrder = 0
        $this.CreatedDate = Get-Date
        $this.ModifiedDate = Get-Date
    }
    
    [void] UpdateModifiedDate() {
        $this.ModifiedDate = Get-Date
    }
    
    [bool] IsValid() {
        return $this.DisplayName -and $this.SourceCell -and $this.DestinationCell
    }
    
    [bool] IsReadyForExcelCopy() {
        return $this.IsValid()
    }
    
    [bool] IsReadyForT2020Export() {
        return $this.IsValid() -and $this.T2020Name -and $this.IncludeInT2020
    }
    
    # Create from hashtable (for JSON loading)
    static [ExcelFieldMapping] FromHashtable([hashtable]$data) {
        $mapping = [ExcelFieldMapping]::new()
        
        if ($data.ContainsKey('Id')) { $mapping.Id = $data.Id }
        if ($data.ContainsKey('DisplayName')) { $mapping.DisplayName = $data.DisplayName }
        if ($data.ContainsKey('SourceCell')) { $mapping.SourceCell = $data.SourceCell }
        if ($data.ContainsKey('DestinationCell')) { $mapping.DestinationCell = $data.DestinationCell }
        if ($data.ContainsKey('T2020Name')) { $mapping.T2020Name = $data.T2020Name }
        if ($data.ContainsKey('IncludeInT2020')) { $mapping.IncludeInT2020 = $data.IncludeInT2020 }
        if ($data.ContainsKey('Category')) { $mapping.Category = $data.Category }
        if ($data.ContainsKey('SortOrder')) { $mapping.SortOrder = $data.SortOrder }
        
        if ($data.ContainsKey('CreatedDate')) {
            $mapping.CreatedDate = [datetime]::Parse($data.CreatedDate)
        }
        if ($data.ContainsKey('ModifiedDate')) {
            $mapping.ModifiedDate = [datetime]::Parse($data.ModifiedDate)
        }
        
        return $mapping
    }
    
    # Convert to hashtable (for JSON saving)
    [hashtable] ToHashtable() {
        return @{
            Id = $this.Id
            DisplayName = $this.DisplayName
            SourceCell = $this.SourceCell
            DestinationCell = $this.DestinationCell
            T2020Name = $this.T2020Name
            IncludeInT2020 = $this.IncludeInT2020
            Category = $this.Category
            SortOrder = $this.SortOrder
            CreatedDate = $this.CreatedDate.ToString("o")
            ModifiedDate = $this.ModifiedDate.ToString("o")
        }
    }
    
    # Display string for debugging
    [string] ToString() {
        $t2020Mark = if ($this.IncludeInT2020) { "X" } else { " " }
        return "[$t2020Mark] $($this.DisplayName) ($($this.SourceCell) → $($this.DestinationCell))"
    }
}