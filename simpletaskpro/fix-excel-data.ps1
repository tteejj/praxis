# Fix Excel Data - Replace fake data with user's actual field mappings
param()

# Load required classes
. "$PSScriptRoot/Models/ExcelFieldMapping.ps1"

function Create-CorrectMapping {
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

# Create correct mappings from ExcelImportService
$correctMappings = @()

# Project Information
$correctMappings += Create-CorrectMapping "RequestDate" "W23" "A1" "RequestDate" "Project Info" 1 $true
$correctMappings += Create-CorrectMapping "AuditType" "W78" "A2" "AuditType" "Project Info" 2 $true
$correctMappings += Create-CorrectMapping "AuditorName" "W10" "A3" "AuditorName" "Project Info" 3 $true
$correctMappings += Create-CorrectMapping "AuditorPhone" "W12" "A4" "AuditorPhone" "Project Info" 4 $false
$correctMappings += Create-CorrectMapping "AuditorTL" "W15" "A5" "AuditorTL" "Project Info" 5 $false
$correctMappings += Create-CorrectMapping "AuditorTLPhone" "W16" "A6" "AuditorTLPhone" "Project Info" 6 $false
$correctMappings += Create-CorrectMapping "AuditCase" "W18" "A7" "AuditCase" "Project Info" 7 $true
$correctMappings += Create-CorrectMapping "CASCase" "W17" "A8" "CASCase" "Project Info" 8 $true
$correctMappings += Create-CorrectMapping "AuditStartDate" "W24" "A9" "AuditStartDate" "Project Info" 9 $true

# Contact Details
$correctMappings += Create-CorrectMapping "TPName" "W3" "A10" "TPName" "Contact Details" 10 $true
$correctMappings += Create-CorrectMapping "TPNum" "W4" "A11" "TPNum" "Contact Details" 11 $true
$correctMappings += Create-CorrectMapping "Address" "W5" "A12" "Address" "Contact Details" 12 $true
$correctMappings += Create-CorrectMapping "City" "W6" "A13" "City" "Contact Details" 13 $true
$correctMappings += Create-CorrectMapping "Province" "W7" "A14" "Province" "Contact Details" 14 $true
$correctMappings += Create-CorrectMapping "PostalCode" "W8" "A15" "PostalCode" "Contact Details" 15 $false
$correctMappings += Create-CorrectMapping "Country" "W9" "A16" "Country" "Contact Details" 16 $false

# Audit Periods
$correctMappings += Create-CorrectMapping "AuditPeriodFrom" "W27" "A17" "AuditPeriodFrom" "Audit Periods" 17 $true
$correctMappings += Create-CorrectMapping "AuditPeriodTo" "W28" "A18" "AuditPeriodTo" "Audit Periods" 18 $true
$correctMappings += Create-CorrectMapping "AuditPeriod1Start" "W29" "A19" "AuditPeriod1Start" "Audit Periods" 19 $false
$correctMappings += Create-CorrectMapping "AuditPeriod1End" "W30" "A20" "AuditPeriod1End" "Audit Periods" 20 $false

# Contact Information
$correctMappings += Create-CorrectMapping "Contact1Name" "W54" "A21" "Contact1Name" "Contacts" 21 $true
$correctMappings += Create-CorrectMapping "Contact1Phone" "W55" "A22" "Contact1Phone" "Contacts" 22 $false
$correctMappings += Create-CorrectMapping "Contact1Title" "W58" "A23" "Contact1Title" "Contacts" 23 $false
$correctMappings += Create-CorrectMapping "Contact2Name" "W59" "A24" "Contact2Name" "Contacts" 24 $false

# System Information
$correctMappings += Create-CorrectMapping "AuditProgram" "W72" "A25" "AuditProgram" "System Info" 25 $true
$correctMappings += Create-CorrectMapping "AccountingSoftware1" "W98" "A26" "AccountingSoftware1" "System Info" 26 $false
$correctMappings += Create-CorrectMapping "Comments" "W108" "A27" "Comments" "System Info" 27 $false
$correctMappings += Create-CorrectMapping "FXInfo" "W129" "A28" "FXInfo" "System Info" 28 $false
$correctMappings += Create-CorrectMapping "ShipToAddress" "W130" "A29" "ShipToAddress" "System Info" 29 $false

# Convert to JSON
$data = @{
    SourceFolder = ""
    ExcelTargetFile = ""
    T2020TargetFile = ""
    Mappings = @()
}

foreach ($mapping in $correctMappings) {
    $data.Mappings += $mapping.ToHashtable()
}

$json = ConvertTo-Json $data -Depth 10
$outputPath = "$PSScriptRoot/Data/excel-mappings.json"

# Ensure directory exists
$dataDir = Split-Path $outputPath -Parent
if (-not (Test-Path $dataDir)) {
    New-Item -ItemType Directory -Path $dataDir -Force | Out-Null
}

# Write correct data
$json | Out-File -FilePath $outputPath -Encoding UTF8 -Force

Write-Host "Created correct Excel mappings file with YOUR actual field names!" -ForegroundColor Green
Write-Host "File: $outputPath" -ForegroundColor Cyan
Write-Host ""
Write-Host "Your actual field mappings:" -ForegroundColor Yellow
foreach ($mapping in $correctMappings | Sort-Object SortOrder | Select-Object -First 10) {
    Write-Host "  $($mapping.SourceCell): $($mapping.DisplayName)" -ForegroundColor White
}
Write-Host "  ... and $($correctMappings.Count - 10) more" -ForegroundColor Gray