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
        
        # Map critical fields
        $project.ID2 = $ImportedData.CASCase  # CAS Case# is the ID2
        $project.Name = $ImportedData.TPName
        $project.ClientID = $ImportedData.TPNum
        $project.Status = 'Active'
        $project.CreatedDate = [DateTime]::Now
        
        # Map audit information
        $project.AuditType = $ImportedData.AuditType
        $project.AuditStartDate = $ImportedData.AuditStartDate
        $project.AuditPeriodFrom = $ImportedData.AuditPeriodFrom
        $project.AuditPeriodTo = $ImportedData.AuditPeriodTo
        
        # Map address information
        $project.Address = $ImportedData.Address
        $project.City = $ImportedData.City
        $project.Province = $ImportedData.Province
        $project.PostalCode = $ImportedData.PostalCode
        $project.Country = $ImportedData.Country
        
        # Map auditor information
        $project.AuditorName = $ImportedData.AuditorName
        $project.AuditorPhone = $ImportedData.AuditorPhone
        $project.AuditorTL = $ImportedData.AuditorTL
        $project.AuditorTLPhone = $ImportedData.AuditorTLPhone
        
        # Map contacts
        $project.Contacts = @()
        if ($ImportedData.Contact1Name) {
            $project.Contacts += @{
                Name = $ImportedData.Contact1Name
                Phone = $ImportedData.Contact1Phone
                Extension = $ImportedData.Contact1Ext
                Address = $ImportedData.Contact1Address
                Title = $ImportedData.Contact1Title
            }
        }
        if ($ImportedData.Contact2Name) {
            $project.Contacts += @{
                Name = $ImportedData.Contact2Name
                Phone = $ImportedData.Contact2Phone
                Extension = $ImportedData.Contact2Ext
                Address = $ImportedData.Contact2Address
                Title = $ImportedData.Contact2Title
            }
        }
        
        # Map software information
        $project.AccountingSoftware = @()
        if ($ImportedData.AccountingSoftware1) {
            $project.AccountingSoftware += @{
                Name = $ImportedData.AccountingSoftware1
                Other = $ImportedData.AccountingSoftware1Other
                Type = $ImportedData.AccountingSoftware1Type
            }
        }
        if ($ImportedData.AccountingSoftware2) {
            $project.AccountingSoftware += @{
                Name = $ImportedData.AccountingSoftware2
                Other = $ImportedData.AccountingSoftware2Other
                Type = $ImportedData.AccountingSoftware2Type
            }
        }
        
        # Map additional fields
        $project.Comments = $ImportedData.Comments
        $project.FXInfo = $ImportedData.FXInfo
        $project.ShipToAddress = $ImportedData.ShipToAddress
        
        # Map audit periods
        $project.AuditPeriods = @()
        for ($i = 1; $i -le 5; $i++) {
            $startKey = "AuditPeriod${i}Start"
            $endKey = "AuditPeriod${i}End"
            if ($ImportedData[$startKey] -or $ImportedData[$endKey]) {
                $project.AuditPeriods += @{
                    Start = $ImportedData[$startKey]
                    End = $ImportedData[$endKey]
                }
            }
        }
        
        return $project
    }
}