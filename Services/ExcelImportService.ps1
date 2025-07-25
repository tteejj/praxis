class ExcelImportService {
    $ServiceContainer
    [hashtable] $FieldMappings
    
    ExcelImportService() {
        $this.InitializeFieldMappings()
    }
    
    [void] Initialize($container) {
        $this.ServiceContainer = $container
    }
    
    [void] InitializeFieldMappings() {
        # Based on changes.txt mappings
        $this.FieldMappings = @{
            'RequestDate' = @{ Cell = 'W23'; Type = 'Date' }
            'AuditType' = @{ Cell = 'W78'; Type = 'String' }
            'AuditorName' = @{ Cell = 'W10'; Type = 'String' }
            'AuditorPhone' = @{ Cell = 'W12'; Type = 'String' }
            'AuditorTL' = @{ Cell = 'W15'; Type = 'String' }
            'AuditorTLPhone' = @{ Cell = 'W16'; Type = 'String' }
            'TPName' = @{ Cell = 'W3'; Type = 'String' }
            'TPNum' = @{ Cell = 'W4'; Type = 'String' }
            'Address' = @{ Cell = 'W5'; Type = 'String' }
            'City' = @{ Cell = 'W6'; Type = 'String' }
            'Province' = @{ Cell = 'W7'; Type = 'String' }
            'PostalCode' = @{ Cell = 'W8'; Type = 'String' }
            'Country' = @{ Cell = 'W9'; Type = 'String' }
            'AuditPeriodFrom' = @{ Cell = 'W27'; Type = 'Date' }
            'AuditPeriodTo' = @{ Cell = 'W28'; Type = 'Date' }
            'AuditPeriod1Start' = @{ Cell = 'W29'; Type = 'Date' }
            'AuditPeriod1End' = @{ Cell = 'W30'; Type = 'Date' }
            'AuditPeriod2Start' = @{ Cell = 'W31'; Type = 'Date' }
            'AuditPeriod2End' = @{ Cell = 'W32'; Type = 'Date' }
            'AuditPeriod3Start' = @{ Cell = 'W33'; Type = 'Date' }
            'AuditPeriod3End' = @{ Cell = 'W34'; Type = 'Date' }
            'AuditPeriod4Start' = @{ Cell = 'W35'; Type = 'Date' }
            'AuditPeriod4End' = @{ Cell = 'W36'; Type = 'Date' }
            'AuditPeriod5Start' = @{ Cell = 'W37'; Type = 'Date' }
            'AuditPeriod5End' = @{ Cell = 'W38'; Type = 'Date' }
            'Contact1Name' = @{ Cell = 'W54'; Type = 'String' }
            'Contact1Phone' = @{ Cell = 'W55'; Type = 'String' }
            'Contact1Ext' = @{ Cell = 'W56'; Type = 'String' }
            'Contact1Address' = @{ Cell = 'W57'; Type = 'String' }
            'Contact1Title' = @{ Cell = 'W58'; Type = 'String' }
            'Contact2Name' = @{ Cell = 'W59'; Type = 'String' }
            'Contact2Phone' = @{ Cell = 'W60'; Type = 'String' }
            'Contact2Ext' = @{ Cell = 'W61'; Type = 'String' }
            'Contact2Address' = @{ Cell = 'W62'; Type = 'String' }
            'Contact2Title' = @{ Cell = 'W63'; Type = 'String' }
            'AuditProgram' = @{ Cell = 'W72'; Type = 'String' }
            'AuditCase' = @{ Cell = 'W18'; Type = 'String' }
            'CASCase' = @{ Cell = 'W17'; Type = 'String' }  # Critical ID2 field
            'AuditStartDate' = @{ Cell = 'W24'; Type = 'Date' }
            'AccountingSoftware1' = @{ Cell = 'W98'; Type = 'String' }
            'AccountingSoftware1Other' = @{ Cell = 'W100'; Type = 'String' }
            'AccountingSoftware1Type' = @{ Cell = 'W101'; Type = 'String' }
            'AccountingSoftware2' = @{ Cell = 'W102'; Type = 'String' }
            'AccountingSoftware2Other' = @{ Cell = 'W104'; Type = 'String' }
            'AccountingSoftware2Type' = @{ Cell = 'W105'; Type = 'String' }
            'FXInfo' = @{ Cell = 'W129'; Type = 'String' }
            'ShipToAddress' = @{ Cell = 'W130'; Type = 'String' }
            'Comments' = @{ Cell = 'W108'; Type = 'String' }
        }
    }
    
    [hashtable] ImportFromExcel([string]$FilePath) {
        # Validate file exists
        if (-not (Test-Path $FilePath)) {
            throw "Excel file not found: $FilePath"
        }
        
        # Initialize COM objects
        $excel = $null
        $workbook = $null
        $importedData = @{}
        
        try {
            # Create Excel application
            $excel = New-Object -ComObject Excel.Application
            $excel.Visible = $false
            $excel.DisplayAlerts = $false
            
            # Open workbook
            $workbook = $excel.Workbooks.Open($FilePath, 0, $true) # ReadOnly
            
            # Try to find SVI-CAS worksheet
            $worksheet = $null
            try {
                $worksheet = $workbook.Worksheets.Item('SVI-CAS')
            }
            catch {
                # Use first worksheet if SVI-CAS not found
                $worksheet = $workbook.Worksheets.Item(1)
                Write-Warning "SVI-CAS worksheet not found, using first worksheet: $($worksheet.Name)"
            }
            
            # Extract data based on mappings
            foreach ($field in $this.FieldMappings.Keys) {
                $mapping = $this.FieldMappings[$field]
                try {
                    $cellValue = $worksheet.Range($mapping.Cell).Value2
                    
                    # Convert based on type
                    if ($null -ne $cellValue -and $cellValue -ne '') {
                        switch ($mapping.Type) {
                            'Date' {
                                if ($cellValue -is [double]) {
                                    $importedData[$field] = [DateTime]::FromOADate($cellValue)
                                }
                                else {
                                    $importedData[$field] = [DateTime]::Parse($cellValue.ToString())
                                }
                            }
                            'String' {
                                $importedData[$field] = $cellValue.ToString().Trim()
                            }
                            default {
                                $importedData[$field] = $cellValue
                            }
                        }
                    }
                }
                catch {
                    Write-Warning "Failed to extract $field from cell $($mapping.Cell): $_"
                }
            }
            
            return $importedData
        }
        finally {
            # Clean up COM objects
            if ($workbook) {
                try { $workbook.Close($false) } catch {}
                [System.Runtime.InteropServices.Marshal]::ReleaseComObject($workbook) | Out-Null
            }
            if ($excel) {
                try { $excel.Quit() } catch {}
                [System.Runtime.InteropServices.Marshal]::ReleaseComObject($excel) | Out-Null
            }
            [System.GC]::Collect()
            [System.GC]::WaitForPendingFinalizers()
        }
    }
    
    [object] CreateProjectFromImport([hashtable]$ImportedData) {
        $projectService = $this.ServiceContainer.GetService('ProjectService')
        
        # Create new project with imported data
        $project = [Project]::new()
        
        # Map basic fields
        $project.FullProjectName = $ImportedData.TPName
        $project.Nickname = $ImportedData.TPName  # Can be changed later
        $project.ID2 = $ImportedData.CASCase  # CAS Case# is the ID2
        $project.ClientID = $ImportedData.TPNum
        $project.Status = 'Active'
        
        # Map audit information
        $project.AuditType = $ImportedData.AuditType
        $project.AuditProgram = $ImportedData.AuditProgram
        $project.AuditCase = $ImportedData.AuditCase
        $project.AuditStartDate = $ImportedData.AuditStartDate
        $project.AuditPeriodFrom = $ImportedData.AuditPeriodFrom
        $project.AuditPeriodTo = $ImportedData.AuditPeriodTo
        
        # Map additional audit periods
        $project.AuditPeriod1Start = $ImportedData.AuditPeriod1Start
        $project.AuditPeriod1End = $ImportedData.AuditPeriod1End
        $project.AuditPeriod2Start = $ImportedData.AuditPeriod2Start
        $project.AuditPeriod2End = $ImportedData.AuditPeriod2End
        $project.AuditPeriod3Start = $ImportedData.AuditPeriod3Start
        $project.AuditPeriod3End = $ImportedData.AuditPeriod3End
        $project.AuditPeriod4Start = $ImportedData.AuditPeriod4Start
        $project.AuditPeriod4End = $ImportedData.AuditPeriod4End
        $project.AuditPeriod5Start = $ImportedData.AuditPeriod5Start
        $project.AuditPeriod5End = $ImportedData.AuditPeriod5End
        
        # Map address information
        $project.Address = $ImportedData.Address
        $project.City = $ImportedData.City
        $project.Province = $ImportedData.Province
        $project.PostalCode = $ImportedData.PostalCode
        $project.Country = $ImportedData.Country
        $project.ShipToAddress = $ImportedData.ShipToAddress
        
        # Map auditor information
        $project.AuditorName = $ImportedData.AuditorName
        $project.AuditorPhone = $ImportedData.AuditorPhone
        $project.AuditorTL = $ImportedData.AuditorTL
        $project.AuditorTLPhone = $ImportedData.AuditorTLPhone
        
        # Map contact information directly to project fields
        $project.Contact1Name = $ImportedData.Contact1Name
        $project.Contact1Phone = $ImportedData.Contact1Phone
        $project.Contact1Ext = $ImportedData.Contact1Ext
        $project.Contact1Address = $ImportedData.Contact1Address
        $project.Contact1Title = $ImportedData.Contact1Title
        $project.Contact2Name = $ImportedData.Contact2Name
        $project.Contact2Phone = $ImportedData.Contact2Phone
        $project.Contact2Ext = $ImportedData.Contact2Ext
        $project.Contact2Address = $ImportedData.Contact2Address
        $project.Contact2Title = $ImportedData.Contact2Title
        
        # Map software information
        $project.AccountingSoftware1 = $ImportedData.AccountingSoftware1
        $project.AccountingSoftware1Other = $ImportedData.AccountingSoftware1Other
        $project.AccountingSoftware1Type = $ImportedData.AccountingSoftware1Type
        $project.AccountingSoftware2 = $ImportedData.AccountingSoftware2
        $project.AccountingSoftware2Other = $ImportedData.AccountingSoftware2Other
        $project.AccountingSoftware2Type = $ImportedData.AccountingSoftware2Type
        
        # Map additional fields
        $project.RequestDate = $ImportedData.RequestDate
        $project.FXInfo = $ImportedData.FXInfo
        $project.Comments = $ImportedData.Comments
        
        return $project
    }
}