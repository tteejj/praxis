#!/usr/bin/env pwsh
# Test script to verify Excel import functionality

Write-Host "Testing Excel Import Service..." -ForegroundColor Cyan

# Create a test Excel file with sample data
$excel = New-Object -ComObject Excel.Application
$excel.Visible = $false
$excel.DisplayAlerts = $false

try {
    $workbook = $excel.Workbooks.Add()
    $worksheet = $workbook.Worksheets.Item(1)
    $worksheet.Name = "SVI-CAS"
    
    # Add test data based on changes.txt mappings
    $worksheet.Range("W17").Value2 = "CAS-2024-001"  # CAS Case# (ID2)
    $worksheet.Range("W3").Value2 = "Test Company Inc"  # TP Name
    $worksheet.Range("W4").Value2 = "TC-12345"  # TP Number
    $worksheet.Range("W5").Value2 = "123 Main Street"  # Address
    $worksheet.Range("W6").Value2 = "Toronto"  # City
    $worksheet.Range("W7").Value2 = "ON"  # Province
    $worksheet.Range("W8").Value2 = "M5V 3A8"  # Postal Code
    $worksheet.Range("W9").Value2 = "Canada"  # Country
    $worksheet.Range("W10").Value2 = "John Auditor"  # Auditor Name
    $worksheet.Range("W12").Value2 = "416-555-1234"  # Auditor Phone
    $worksheet.Range("W78").Value2 = "Annual Audit"  # Audit Type
    
    # Save the file
    $testFile = Join-Path $PSScriptRoot "test_import.xlsx"
    $workbook.SaveAs($testFile)
    Write-Host "Created test Excel file: $testFile" -ForegroundColor Green
    
    $workbook.Close($false)
}
finally {
    $excel.Quit()
    [System.Runtime.InteropServices.Marshal]::ReleaseComObject($excel) | Out-Null
    [System.GC]::Collect()
    [System.GC]::WaitForPendingFinalizers()
}

Write-Host "`nTo test the import:" -ForegroundColor Yellow
Write-Host "1. Run Start.ps1"
Write-Host "2. Press Ctrl+I to open Excel Import"
Write-Host "3. Select test_import.xlsx"
Write-Host "4. Click Import"