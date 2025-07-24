#!/usr/bin/env pwsh
# Test script for time tracking functionality

Write-Host "Testing Time Tracking System..." -ForegroundColor Cyan

# Load the models
. "$PSScriptRoot/Models/TimeEntry.ps1"
. "$PSScriptRoot/Models/TimeCode.ps1"

# Test TimeEntry model
Write-Host "`nTesting TimeEntry model:" -ForegroundColor Yellow

$entry = [TimeEntry]::new()
Write-Host "  Created empty TimeEntry"
Write-Host "  Week Ending Friday: $($entry.WeekEndingFriday)"
Write-Host "  Fiscal Year: $($entry.FiscalYear)"

# Test with specific date
$entry2 = [TimeEntry]::new("20240126", "CAS-2024-001")
$entry2.Monday = 8
$entry2.Tuesday = 7.5
$entry2.Wednesday = 8
$entry2.Thursday = 6
$entry2.Friday = 4.5
$entry2.CalculateTotal()

Write-Host "`n  Created TimeEntry for week ending 01/26/2024:"
Write-Host "  ID2: $($entry2.ID2)"
Write-Host "  Total Hours: $($entry2.Total)"
Write-Host "  Is Project Entry: $($entry2.IsProjectEntry())"
Write-Host "  Week Display: $($entry2.GetWeekDisplayString())"

# Test non-project entry
$entry3 = [TimeEntry]::new("20240126", "VAC")
$entry3.Monday = 8
$entry3.Tuesday = 8
$entry3.CalculateTotal()

Write-Host "`n  Created non-project TimeEntry:"
Write-Host "  ID2: $($entry3.ID2)"
Write-Host "  Total Hours: $($entry3.Total)"
Write-Host "  Is Project Entry: $($entry3.IsProjectEntry())"

# Test TimeCode model
Write-Host "`nTesting TimeCode model:" -ForegroundColor Yellow

$code = [TimeCode]::new("ADMIN", "Administration")
Write-Host "  Created TimeCode: $($code.GetDisplayName())"

$commonCodes = [TimeCode]::GetCommonCodes()
Write-Host "  Common codes count: $($commonCodes.Count)"
foreach ($c in $commonCodes[0..2]) {
    Write-Host "    - $($c.GetDisplayName())"
}

Write-Host "`nTime tracking models test completed!" -ForegroundColor Green