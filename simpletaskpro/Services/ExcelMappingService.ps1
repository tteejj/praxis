# ExcelMappingService.ps1 - Service for managing Excel field mappings
# Following SimpleTaskPro patterns with UniversalBackupManager integration

class ExcelMappingService {
    [string]$DataFile
    [System.Collections.Generic.List[ExcelFieldMapping]]$Mappings
    [string]$SourceFolder = ""
    [string]$ExcelTargetFile = ""
    [string]$T2020TargetFile = ""
    
    ExcelMappingService() {
        $this.DataFile = Join-Path $PSScriptRoot "../Data/excel-mappings.json"
        $this.Mappings = [System.Collections.Generic.List[ExcelFieldMapping]]::new()
        $this.EnsureDataDirectory()
        
        # Initialize universal backup system (following SimpleTaskService pattern)
        [UniversalBackupManager]::Initialize((Join-Path $PSScriptRoot ".."))
        
        # Register auto-save for critical data protection
        $serviceInstance = $this
        [UniversalBackupManager]::RegisterAutoSave(
            "excel-mappings", 
            $this.DataFile, 
            { $serviceInstance.Save() }.GetNewClosure(),
            "excel-mappings"
        )
        
        $this.Load()
    }
    
    [void] EnsureDataDirectory() {
        $dataDir = Split-Path $this.DataFile -Parent
        if (-not (Test-Path $dataDir)) {
            New-Item -ItemType Directory -Path $dataDir -Force | Out-Null
        }
    }
    
    [void] Load() {
        if (Test-Path $this.DataFile) {
            try {
                $json = Get-Content $this.DataFile -Raw
                $data = ConvertFrom-Json $json -AsHashtable
                
                $this.Mappings.Clear()
                
                # Load settings
                if ($data.ContainsKey('SourceFolder')) { $this.SourceFolder = $data.SourceFolder }
                if ($data.ContainsKey('ExcelTargetFile')) { $this.ExcelTargetFile = $data.ExcelTargetFile }
                if ($data.ContainsKey('T2020TargetFile')) { $this.T2020TargetFile = $data.T2020TargetFile }
                
                # Load mappings
                if ($data.ContainsKey('Mappings') -and $data.Mappings) {
                    foreach ($mappingData in $data.Mappings) {
                        $mapping = [ExcelFieldMapping]::FromHashtable($mappingData)
                        $this.Mappings.Add($mapping)
                    }
                }
                
            } catch {
                Write-Warning "Failed to load Excel mappings: $_"
                $this.CreateSampleMappings()
            }
        } else {
            $this.CreateSampleMappings()
        }
    }
    
    [void] Save() {
        # BULLETPROOF SAVE: Use universal backup system (following SimpleTaskService pattern)
        $json = ""
        
        try {
            # Convert mappings to hashtables
            $mappingData = @()
            foreach ($mapping in $this.Mappings) {
                $mappingData += $mapping.ToHashtable()
            }
            
            $data = @{
                SourceFolder = $this.SourceFolder
                ExcelTargetFile = $this.ExcelTargetFile
                T2020TargetFile = $this.T2020TargetFile
                Mappings = $mappingData
            }
            
            $json = ConvertTo-Json $data -Depth 10
            
            # Use UniversalBackupManager for bulletproof atomic save
            $success = [UniversalBackupManager]::AtomicSave($this.DataFile, $json, "excel-mappings", "")
            
            if (-not $success) {
                throw "UniversalBackupManager failed to save Excel mappings"
            }
            
        } catch {
            Write-Warning "Failed to save Excel mappings: $_"
            
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
    
    [void] CreateSampleMappings() {
        $this.Mappings.Clear()
        
        # COMPLETE ExcelDataFlow mappings - all 40+ fields from the original system
        # Project Information category
        $this.AddMapping("Request Date", "W23", "A1", "RequestDate", "Project Info", 1, $true)
        $this.AddMapping("Audit Type", "W78", "A2", "AuditType", "Project Info", 2, $true)
        $this.AddMapping("Auditor Name", "W10", "A3", "AuditorName", "Project Info", 3, $true)
        
        # Contact Details - TP (Technical Person)
        $this.AddMapping("TP Name", "W3", "A4", "TPName", "Contact Details", 4, $true)
        $this.AddMapping("TP Email Address", "X3", "A5", "TPEmailAddress", "Contact Details", 5, $true)
        $this.AddMapping("TP Phone Number", "Y3", "A6", "TPPhoneNumber", "Contact Details", 6, $false)
        
        # Contact Details - Corporate
        $this.AddMapping("Corporate Contact", "W5", "A7", "CorporateContact", "Contact Details", 7, $true)
        $this.AddMapping("Corporate Contact Email", "X5", "A8", "CorporateContactEmail", "Contact Details", 8, $true)
        $this.AddMapping("Corporate Contact Phone", "Y5", "A9", "CorporateContactPhone", "Contact Details", 9, $false)
        
        # Site Information
        $this.AddMapping("Site Name", "W7", "A10", "SiteName", "Site Info", 10, $true)
        $this.AddMapping("Site Address", "W8", "A11", "SiteAddress", "Site Info", 11, $true)
        $this.AddMapping("Site City", "W9", "A12", "SiteCity", "Site Info", 12, $true)
        $this.AddMapping("Site State", "X9", "A13", "SiteState", "Site Info", 13, $true)
        $this.AddMapping("Site Zip", "Y9", "A14", "SiteZip", "Site Info", 14, $false)
        $this.AddMapping("Site Country", "Z9", "A15", "SiteCountry", "Site Info", 15, $false)
        
        # Contact Details - Attention Contact
        $this.AddMapping("Attention Contact", "W11", "A16", "AttentionContact", "Contact Details", 16, $false)
        $this.AddMapping("Attention Contact Email", "X11", "A17", "AttentionContactEmail", "Contact Details", 17, $false)
        $this.AddMapping("Attention Contact Phone", "Y11", "A18", "AttentionContactPhone", "Contact Details", 18, $false)
        
        # Business Information
        $this.AddMapping("Tax ID", "W13", "A19", "TaxID", "Business Info", 19, $false)
        $this.AddMapping("DUNS Number", "X13", "A20", "DUNS", "Business Info", 20, $false)
        
        # Asset Details - Primary Tank Data
        $this.AddMapping("CAS Number", "G17", "A21", "CASNumber", "Asset Details", 21, $true)
        $this.AddMapping("Asset Name", "H17", "A22", "AssetName", "Asset Details", 22, $true)
        $this.AddMapping("Serial Number", "I17", "A23", "SerialNumber", "Asset Details", 23, $true)
        $this.AddMapping("Model Number", "J17", "A24", "ModelNumber", "Asset Details", 24, $false)
        $this.AddMapping("Manufacturer Name", "K17", "A25", "ManufacturerName", "Asset Details", 25, $false)
        $this.AddMapping("Install Date", "L17", "A26", "InstallDate", "Asset Details", 26, $false)
        
        # Technical Specifications
        $this.AddMapping("Capacity", "M17", "A27", "Capacity", "Technical Data", 27, $true)
        $this.AddMapping("Capacity Unit", "N17", "A28", "CapacityUnit", "Technical Data", 28, $true)
        $this.AddMapping("Tank Type", "O17", "A29", "TankType", "Technical Data", 29, $true)
        $this.AddMapping("Product", "P17", "A30", "Product", "Technical Data", 30, $true)
        $this.AddMapping("Leak Detection", "Q17", "A31", "LeakDetection", "Technical Data", 31, $true)
        $this.AddMapping("Piping", "R17", "A32", "Piping", "Technical Data", 32, $false)
        $this.AddMapping("Monitoring", "S17", "A33", "Monitoring", "Technical Data", 33, $false)
        $this.AddMapping("Status", "T17", "A34", "Status", "Technical Data", 34, $false)
        $this.AddMapping("Comments", "U17", "A35", "Comments", "Technical Data", 35, $false)
        
        # Compliance Information
        $this.AddMapping("Compliance Date", "W25", "A36", "ComplianceDate", "Compliance", 36, $true)
        $this.AddMapping("Next Inspection Date", "W27", "A37", "NextInspectionDate", "Compliance", 37, $true)
        $this.AddMapping("Certification Number", "W29", "A38", "CertificationNumber", "Compliance", 38, $true)
        $this.AddMapping("Inspector Name", "W31", "A39", "InspectorName", "Compliance", 39, $true)
        $this.AddMapping("Inspector License", "W33", "A40", "InspectorLicense", "Compliance", 40, $false)
        
        $this.Save()
    }
    
    [void] AddMapping([string]$displayName, [string]$sourceCell, [string]$destCell, [string]$t2020Name, [string]$category, [int]$sortOrder, [bool]$includeInT2020) {
        $mapping = [ExcelFieldMapping]::new($displayName, $sourceCell, $destCell, $t2020Name, $category)
        $mapping.SortOrder = $sortOrder
        $mapping.IncludeInT2020 = $includeInT2020
        $this.Mappings.Add($mapping)
    }
    
    [ExcelFieldMapping[]] GetMappings() {
        # Return mappings sorted by SortOrder, then by Category
        return $this.Mappings | Sort-Object SortOrder, Category, DisplayName
    }
    
    [ExcelFieldMapping[]] GetMappingsForT2020Export() {
        return $this.Mappings | Where-Object { $_.IsReadyForT2020Export() } | Sort-Object SortOrder
    }
    
    [ExcelFieldMapping[]] GetMappingsForExcelCopy() {
        return $this.Mappings | Where-Object { $_.IsReadyForExcelCopy() } | Sort-Object SortOrder
    }
    
    [ExcelFieldMapping] GetMapping([string]$id) {
        return $this.Mappings | Where-Object { $_.Id -eq $id } | Select-Object -First 1
    }
    
    [void] AddMapping([ExcelFieldMapping]$mapping) {
        $mapping.UpdateModifiedDate()
        $this.Mappings.Add($mapping)
        $this.Save()
    }
    
    [void] UpdateMapping([ExcelFieldMapping]$mapping) {
        $mapping.UpdateModifiedDate()
        $this.Save()
    }
    
    [void] DeleteMapping([string]$id) {
        $mapping = $this.GetMapping($id)
        if ($mapping) {
            $this.Mappings.Remove($mapping)
            $this.Save()
        }
    }
    
    [void] MoveUp([string]$id) {
        $mapping = $this.GetMapping($id)
        if (-not $mapping) { return }
        
        $sortedMappings = $this.GetMappings()
        $currentIndex = [Array]::IndexOf($sortedMappings, $mapping)
        
        if ($currentIndex -gt 0) {
            $previousMapping = $sortedMappings[$currentIndex - 1]
            $tempOrder = $mapping.SortOrder
            $mapping.SortOrder = $previousMapping.SortOrder
            $previousMapping.SortOrder = $tempOrder
            
            $mapping.UpdateModifiedDate()
            $previousMapping.UpdateModifiedDate()
            $this.Save()
        }
    }
    
    [void] MoveDown([string]$id) {
        $mapping = $this.GetMapping($id)
        if (-not $mapping) { return }
        
        $sortedMappings = $this.GetMappings()
        $currentIndex = [Array]::IndexOf($sortedMappings, $mapping)
        
        if ($currentIndex -ge 0 -and $currentIndex -lt ($sortedMappings.Count - 1)) {
            $nextMapping = $sortedMappings[$currentIndex + 1]
            $tempOrder = $mapping.SortOrder
            $mapping.SortOrder = $nextMapping.SortOrder
            $nextMapping.SortOrder = $tempOrder
            
            $mapping.UpdateModifiedDate()
            $nextMapping.UpdateModifiedDate()
            $this.Save()
        }
    }
    
    [void] ToggleT2020Include([string]$id) {
        $mapping = $this.GetMapping($id)
        if ($mapping) {
            $mapping.IncludeInT2020 = -not $mapping.IncludeInT2020
            $mapping.UpdateModifiedDate()
            $this.Save()
        }
    }
    
    # File path management
    [void] SetSourceFolder([string]$path) {
        $this.SourceFolder = $path
        $this.Save()
    }
    
    [void] SetExcelTargetFile([string]$path) {
        $this.ExcelTargetFile = $path
        $this.Save()
    }
    
    [void] SetT2020TargetFile([string]$path) {
        $this.T2020TargetFile = $path
        $this.Save()
    }
}