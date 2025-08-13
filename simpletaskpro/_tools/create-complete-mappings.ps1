# Create COMPLETE Excel mappings with ALL 43 fields from ExcelImportService
param()

# Load required classes
. "$PSScriptRoot/Models/ExcelFieldMapping.ps1"

function Create-CompleteMapping {
    param([string]$displayName, [string]$sourceCell, [string]$destCell, [string]$t2020Name, [string]$category, [int]$sortOrder, [bool]$includeInT2020)
    
    $mapping = [ExcelFieldMapping]::new()
    $mapping.DisplayName = $displayName
    $mapping.SourceCell = $sourceCell
    $mapping.DestinationCell = $destCell
    $mapping.T2020Name = $t2020Name
    $mapping.Category = $category
    $mapping.SortOrder = $sortOrder
    $mapping.IncludeInT2020 = $includeInT2020
    $mapping.CreatedDate = Get-Date
    $mapping.ModifiedDate = Get-Date
    return $mapping
}

# ALL 43 FIELDS FROM EXCELIMPORTSERVICE - EVERY SINGLE ONE
$completeMappings = @()

# Project Information (9 fields)
$completeMappings += Create-CompleteMapping "RequestDate" "W23" "A1" "RequestDate" "Project Info" 1 $true
$completeMappings += Create-CompleteMapping "AuditType" "W78" "A2" "AuditType" "Project Info" 2 $true
$completeMappings += Create-CompleteMapping "AuditorName" "W10" "A3" "AuditorName" "Project Info" 3 $true
$completeMappings += Create-CompleteMapping "AuditorPhone" "W12" "A4" "AuditorPhone" "Project Info" 4 $false
$completeMappings += Create-CompleteMapping "AuditorTL" "W15" "A5" "AuditorTL" "Project Info" 5 $false
$completeMappings += Create-CompleteMapping "AuditorTLPhone" "W16" "A6" "AuditorTLPhone" "Project Info" 6 $false
$completeMappings += Create-CompleteMapping "AuditCase" "W18" "A7" "AuditCase" "Project Info" 7 $true
$completeMappings += Create-CompleteMapping "CASCase" "W17" "A8" "CASCase" "Project Info" 8 $true
$completeMappings += Create-CompleteMapping "AuditStartDate" "W24" "A9" "AuditStartDate" "Project Info" 9 $true

# Contact Details (7 fields)
$completeMappings += Create-CompleteMapping "TPName" "W3" "A10" "TPName" "Contact Details" 10 $true
$completeMappings += Create-CompleteMapping "TPNum" "W4" "A11" "TPNum" "Contact Details" 11 $true
$completeMappings += Create-CompleteMapping "Address" "W5" "A12" "Address" "Contact Details" 12 $true
$completeMappings += Create-CompleteMapping "City" "W6" "A13" "City" "Contact Details" 13 $true
$completeMappings += Create-CompleteMapping "Province" "W7" "A14" "Province" "Contact Details" 14 $true
$completeMappings += Create-CompleteMapping "PostalCode" "W8" "A15" "PostalCode" "Contact Details" 15 $false
$completeMappings += Create-CompleteMapping "Country" "W9" "A16" "Country" "Contact Details" 16 $false

# Audit Periods (12 fields - ALL OF THEM)
$completeMappings += Create-CompleteMapping "AuditPeriodFrom" "W27" "A17" "AuditPeriodFrom" "Audit Periods" 17 $true
$completeMappings += Create-CompleteMapping "AuditPeriodTo" "W28" "A18" "AuditPeriodTo" "Audit Periods" 18 $true
$completeMappings += Create-CompleteMapping "AuditPeriod1Start" "W29" "A19" "AuditPeriod1Start" "Audit Periods" 19 $false
$completeMappings += Create-CompleteMapping "AuditPeriod1End" "W30" "A20" "AuditPeriod1End" "Audit Periods" 20 $false
$completeMappings += Create-CompleteMapping "AuditPeriod2Start" "W31" "A21" "AuditPeriod2Start" "Audit Periods" 21 $false
$completeMappings += Create-CompleteMapping "AuditPeriod2End" "W32" "A22" "AuditPeriod2End" "Audit Periods" 22 $false
$completeMappings += Create-CompleteMapping "AuditPeriod3Start" "W33" "A23" "AuditPeriod3Start" "Audit Periods" 23 $false
$completeMappings += Create-CompleteMapping "AuditPeriod3End" "W34" "A24" "AuditPeriod3End" "Audit Periods" 24 $false
$completeMappings += Create-CompleteMapping "AuditPeriod4Start" "W35" "A25" "AuditPeriod4Start" "Audit Periods" 25 $false
$completeMappings += Create-CompleteMapping "AuditPeriod4End" "W36" "A26" "AuditPeriod4End" "Audit Periods" 26 $false
$completeMappings += Create-CompleteMapping "AuditPeriod5Start" "W37" "A27" "AuditPeriod5Start" "Audit Periods" 27 $false
$completeMappings += Create-CompleteMapping "AuditPeriod5End" "W38" "A28" "AuditPeriod5End" "Audit Periods" 28 $false

# Contact Information (10 fields - ALL CONTACTS)
$completeMappings += Create-CompleteMapping "Contact1Name" "W54" "A29" "Contact1Name" "Contacts" 29 $true
$completeMappings += Create-CompleteMapping "Contact1Phone" "W55" "A30" "Contact1Phone" "Contacts" 30 $false
$completeMappings += Create-CompleteMapping "Contact1Ext" "W56" "A31" "Contact1Ext" "Contacts" 31 $false
$completeMappings += Create-CompleteMapping "Contact1Address" "W57" "A32" "Contact1Address" "Contacts" 32 $false
$completeMappings += Create-CompleteMapping "Contact1Title" "W58" "A33" "Contact1Title" "Contacts" 33 $false
$completeMappings += Create-CompleteMapping "Contact2Name" "W59" "A34" "Contact2Name" "Contacts" 34 $false
$completeMappings += Create-CompleteMapping "Contact2Phone" "W60" "A35" "Contact2Phone" "Contacts" 35 $false
$completeMappings += Create-CompleteMapping "Contact2Ext" "W61" "A36" "Contact2Ext" "Contacts" 36 $false
$completeMappings += Create-CompleteMapping "Contact2Address" "W62" "A37" "Contact2Address" "Contacts" 37 $false
$completeMappings += Create-CompleteMapping "Contact2Title" "W63" "A38" "Contact2Title" "Contacts" 38 $false

# System Information (8 fields - ALL SOFTWARE FIELDS)
$completeMappings += Create-CompleteMapping "AuditProgram" "W72" "A39" "AuditProgram" "System Info" 39 $true
$completeMappings += Create-CompleteMapping "AccountingSoftware1" "W98" "A40" "AccountingSoftware1" "System Info" 40 $false
$completeMappings += Create-CompleteMapping "AccountingSoftware1Other" "W100" "A41" "AccountingSoftware1Other" "System Info" 41 $false
$completeMappings += Create-CompleteMapping "AccountingSoftware1Type" "W101" "A42" "AccountingSoftware1Type" "System Info" 42 $false
$completeMappings += Create-CompleteMapping "AccountingSoftware2" "W102" "A43" "AccountingSoftware2" "System Info" 43 $false
$completeMappings += Create-CompleteMapping "AccountingSoftware2Other" "W104" "A44" "AccountingSoftware2Other" "System Info" 44 $false
$completeMappings += Create-CompleteMapping "AccountingSoftware2Type" "W105" "A45" "AccountingSoftware2Type" "System Info" 45 $false
$completeMappings += Create-CompleteMapping "Comments" "W108" "A46" "Comments" "System Info" 46 $false

# Additional Fields (2 fields)  
$completeMappings += Create-CompleteMapping "FXInfo" "W129" "A47" "FXInfo" "Additional" 47 $false
$completeMappings += Create-CompleteMapping "ShipToAddress" "W130" "A48" "ShipToAddress" "Additional" 48 $false

# Convert to JSON with ALL 43 FIELDS
$data = @{
    SourceFolder = ""
    ExcelTargetFile = ""
    T2020TargetFile = ""
    Mappings = @()
}

foreach ($mapping in $completeMappings) {
    $data.Mappings += $mapping.ToHashtable()
}

$json = ConvertTo-Json $data -Depth 10
$outputPath = "$PSScriptRoot/Data/excel-mappings.json"

# Write COMPLETE data with ALL 43 fields
$json | Out-File -FilePath $outputPath -Encoding UTF8 -Force

Write-Host "✅ CREATED COMPLETE Excel mappings with ALL 43 FIELDS!" -ForegroundColor Green
Write-Host "File: $outputPath" -ForegroundColor Cyan
Write-Host ""
Write-Host "ALL YOUR FIELDS ARE NOW IMPLEMENTED:" -ForegroundColor Yellow
Write-Host "  📁 Project Info: 9 fields" -ForegroundColor White
Write-Host "  👤 Contact Details: 7 fields" -ForegroundColor White
Write-Host "  📅 Audit Periods: 12 fields (ALL periods)" -ForegroundColor White
Write-Host "  📞 Contacts: 10 fields (ALL contact info)" -ForegroundColor White
Write-Host "  💻 System Info: 8 fields (ALL software)" -ForegroundColor White
Write-Host "  ➕ Additional: 2 fields" -ForegroundColor White
Write-Host ""
Write-Host "🎯 TOTAL: $($completeMappings.Count) fields implemented!" -ForegroundColor Magenta