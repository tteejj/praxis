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
        
        # USER'S ACTUAL FIELD MAPPINGS FROM ExcelImportService
        # Project Information
        $this.AddMapping("RequestDate", "W23", "A1", "RequestDate", "Project Info", 1, $true)
        $this.AddMapping("AuditType", "W78", "A2", "AuditType", "Project Info", 2, $true)
        $this.AddMapping("AuditorName", "W10", "A3", "AuditorName", "Project Info", 3, $true)
        $this.AddMapping("AuditorPhone", "W12", "A4", "AuditorPhone", "Project Info", 4, $false)
        $this.AddMapping("AuditorTL", "W15", "A5", "AuditorTL", "Project Info", 5, $false)
        $this.AddMapping("AuditorTLPhone", "W16", "A6", "AuditorTLPhone", "Project Info", 6, $false)
        $this.AddMapping("AuditCase", "W18", "A7", "AuditCase", "Project Info", 7, $true)
        $this.AddMapping("CASCase", "W17", "A8", "CASCase", "Project Info", 8, $true)
        $this.AddMapping("AuditStartDate", "W24", "A9", "AuditStartDate", "Project Info", 9, $true)
        
        # Contact Details
        $this.AddMapping("TPName", "W3", "A10", "TPName", "Contact Details", 10, $true)
        $this.AddMapping("TPNum", "W4", "A11", "TPNum", "Contact Details", 11, $true)
        $this.AddMapping("Address", "W5", "A12", "Address", "Contact Details", 12, $true)
        $this.AddMapping("City", "W6", "A13", "City", "Contact Details", 13, $true)
        $this.AddMapping("Province", "W7", "A14", "Province", "Contact Details", 14, $true)
        $this.AddMapping("PostalCode", "W8", "A15", "PostalCode", "Contact Details", 15, $false)
        $this.AddMapping("Country", "W9", "A16", "Country", "Contact Details", 16, $false)
        
        # Audit Periods
        $this.AddMapping("AuditPeriodFrom", "W27", "A17", "AuditPeriodFrom", "Audit Periods", 17, $true)
        $this.AddMapping("AuditPeriodTo", "W28", "A18", "AuditPeriodTo", "Audit Periods", 18, $true)
        $this.AddMapping("AuditPeriod1Start", "W29", "A19", "AuditPeriod1Start", "Audit Periods", 19, $false)
        $this.AddMapping("AuditPeriod1End", "W30", "A20", "AuditPeriod1End", "Audit Periods", 20, $false)
        $this.AddMapping("AuditPeriod2Start", "W31", "A21", "AuditPeriod2Start", "Audit Periods", 21, $false)
        $this.AddMapping("AuditPeriod2End", "W32", "A22", "AuditPeriod2End", "Audit Periods", 22, $false)
        $this.AddMapping("AuditPeriod3Start", "W33", "A23", "AuditPeriod3Start", "Audit Periods", 23, $false)
        $this.AddMapping("AuditPeriod3End", "W34", "A24", "AuditPeriod3End", "Audit Periods", 24, $false)
        $this.AddMapping("AuditPeriod4Start", "W35", "A25", "AuditPeriod4Start", "Audit Periods", 25, $false)
        $this.AddMapping("AuditPeriod4End", "W36", "A26", "AuditPeriod4End", "Audit Periods", 26, $false)
        $this.AddMapping("AuditPeriod5Start", "W37", "A27", "AuditPeriod5Start", "Audit Periods", 27, $false)
        $this.AddMapping("AuditPeriod5End", "W38", "A28", "AuditPeriod5End", "Audit Periods", 28, $false)
        
        # Contact Information
        $this.AddMapping("Contact1Name", "W54", "A29", "Contact1Name", "Contacts", 29, $true)
        $this.AddMapping("Contact1Phone", "W55", "A30", "Contact1Phone", "Contacts", 30, $false)
        $this.AddMapping("Contact1Ext", "W56", "A31", "Contact1Ext", "Contacts", 31, $false)
        $this.AddMapping("Contact1Address", "W57", "A32", "Contact1Address", "Contacts", 32, $false)
        $this.AddMapping("Contact1Title", "W58", "A33", "Contact1Title", "Contacts", 33, $false)
        $this.AddMapping("Contact2Name", "W59", "A34", "Contact2Name", "Contacts", 34, $false)
        $this.AddMapping("Contact2Phone", "W60", "A35", "Contact2Phone", "Contacts", 35, $false)
        $this.AddMapping("Contact2Ext", "W61", "A36", "Contact2Ext", "Contacts", 36, $false)
        $this.AddMapping("Contact2Address", "W62", "A37", "Contact2Address", "Contacts", 37, $false)
        $this.AddMapping("Contact2Title", "W63", "A38", "Contact2Title", "Contacts", 38, $false)
        
        # System Information
        $this.AddMapping("AuditProgram", "W72", "A39", "AuditProgram", "System Info", 39, $true)
        $this.AddMapping("AccountingSoftware1", "W98", "A40", "AccountingSoftware1", "System Info", 40, $false)
        $this.AddMapping("AccountingSoftware1Other", "W100", "A41", "AccountingSoftware1Other", "System Info", 41, $false)
        $this.AddMapping("AccountingSoftware1Type", "W101", "A42", "AccountingSoftware1Type", "System Info", 42, $false)
        $this.AddMapping("AccountingSoftware2", "W102", "A43", "AccountingSoftware2", "System Info", 43, $false)
        $this.AddMapping("AccountingSoftware2Other", "W104", "A44", "AccountingSoftware2Other", "System Info", 44, $false)
        $this.AddMapping("AccountingSoftware2Type", "W105", "A45", "AccountingSoftware2Type", "System Info", 45, $false)
        $this.AddMapping("Comments", "W108", "A46", "Comments", "System Info", 46, $false)
        $this.AddMapping("FXInfo", "W129", "A47", "FXInfo", "System Info", 47, $false)
        $this.AddMapping("ShipToAddress", "W130", "A48", "ShipToAddress", "System Info", 48, $false)
        
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