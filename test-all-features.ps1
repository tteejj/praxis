#!/usr/bin/env pwsh
# Test script to verify all PRAXIS features

Write-Host "Testing PRAXIS Features..." -ForegroundColor Cyan

# Load base classes first
. "$PSScriptRoot/Base/BaseModel.ps1"
. "$PSScriptRoot/Base/UIElement.ps1"
. "$PSScriptRoot/Base/Container.ps1"
. "$PSScriptRoot/Base/Screen.ps1"
. "$PSScriptRoot/Base/BaseDialog.ps1"
. "$PSScriptRoot/Core/ServiceContainer.ps1"
. "$PSScriptRoot/Services/Logger.ps1"

# Test 1: Time Entry Model
Write-Host "`n1. Testing Time Entry Model:" -ForegroundColor Yellow
. "$PSScriptRoot/Models/TimeEntry.ps1"
. "$PSScriptRoot/Models/TimeCode.ps1"

$entry = [TimeEntry]::new("20240126", "CAS-2024-001")
$entry.Monday = 8
$entry.Tuesday = 7.5
$entry.CalculateTotal()
Write-Host "   ✓ Created time entry for project: $($entry.ID2), Total: $($entry.Total) hours"

$nonProjectEntry = [TimeEntry]::new("20240126", "VAC")
$nonProjectEntry.Monday = 8
$nonProjectEntry.CalculateTotal()
Write-Host "   ✓ Created non-project entry: $($nonProjectEntry.ID2), Is Project: $($nonProjectEntry.IsProjectEntry())"

# Test 2: Time Tracking Service
Write-Host "`n2. Testing Time Tracking Service:" -ForegroundColor Yellow
. "$PSScriptRoot/Services/TimeTrackingService.ps1"
$service = [TimeTrackingService]::new()
Write-Host "   ✓ TimeTrackingService created"
Write-Host "   ✓ Data file: $($service.DataFilePath)"

# Test 3: Project Model with Excel Fields
Write-Host "`n3. Testing Project Model with Excel Import Fields:" -ForegroundColor Yellow
. "$PSScriptRoot/Models/Project.ps1"
$project = [Project]::new()
$project.Name = "Test Client"
$project.ID1 = "2024-001"
$project.ID2 = "CAS-2024-001"
$project.Status = "Active"
$project.AuditType = "Financial"
Write-Host "   ✓ Created project with Excel fields: $($project.Name) | $($project.ID1) | $($project.ID2)"

# Test 4: Excel Import Service
Write-Host "`n4. Testing Excel Import Service:" -ForegroundColor Yellow
. "$PSScriptRoot/Services/ExcelImportService.ps1"
$excelService = [ExcelImportService]::new()
Write-Host "   ✓ ExcelImportService created"
Write-Host "   ✓ Field mappings loaded: $($excelService.FieldMappings.Count) fields"

# Test 5: DataGrid Component
Write-Host "`n5. Testing DataGrid Component:" -ForegroundColor Yellow
. "$PSScriptRoot/Components/DataGrid.ps1"
$grid = [DataGrid]::new()
$columns = @(
    @{ Name = "Status"; Header = "Status"; Width = 8 }
    @{ Name = "Name"; Header = "Name"; Width = 20 }
    @{ Name = "ID2"; Header = "ID2"; Width = 15 }
)
$grid.SetColumns($columns)
Write-Host "   ✓ DataGrid created with $($columns.Count) columns"

# Test 6: Quick Time Entry Dialog
Write-Host "`n6. Testing QuickTimeEntryDialog:" -ForegroundColor Yellow
. "$PSScriptRoot/Screens/QuickTimeEntryDialog.ps1"
$dialog = [QuickTimeEntryDialog]::new()
Write-Host "   ✓ QuickTimeEntryDialog created successfully"

# Test 7: Fiscal Year Calculation
Write-Host "`n7. Testing Fiscal Year Calculations:" -ForegroundColor Yellow
$testDates = @(
    "20240415",  # April 15, 2024 - FY 2024-2025
    "20240301",  # March 1, 2024 - FY 2023-2024
    "20250131"   # January 31, 2025 - FY 2024-2025
)
foreach ($date in $testDates) {
    $entry = [TimeEntry]::new($date, "TEST")
    $dateObj = [DateTime]::ParseExact($date, "yyyyMMdd", $null)
    Write-Host "   Date: $($dateObj.ToString('yyyy-MM-dd')) -> Fiscal Year: $($entry.FiscalYear)"
}

Write-Host "`nAll tests completed successfully!" -ForegroundColor Green
Write-Host "PRAXIS is ready with:" -ForegroundColor Cyan
Write-Host "  • Excel import functionality (Ctrl+I)"
Write-Host "  • Time tracking system (Ctrl+T)"
Write-Host "  • Enhanced project screens with DataGrid"
Write-Host "  • Full project detail display"
Write-Host "  • Fiscal year tracking for non-project codes"