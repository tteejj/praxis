#!/usr/bin/env pwsh
# restore-ps1.ps1 - Convert ps1.txt files back to .ps1

param(
    [string]$FolderPath = "."
)

if (-not (Test-Path $FolderPath)) {
    Write-Host "Folder not found: $FolderPath" -ForegroundColor Red
    exit 1
}

Write-Host "=== RESTORING .ps1 FILES ===" -ForegroundColor Cyan
Write-Host "Folder: $FolderPath" -ForegroundColor Gray

# Find all ps1.txt files
$ps1TxtFiles = Get-ChildItem -Path $FolderPath -Filter "*ps1.txt" -Recurse

if ($ps1TxtFiles.Count -eq 0) {
    Write-Host "No ps1.txt files found to restore" -ForegroundColor Yellow
    exit 0
}

Write-Host "`nFound $($ps1TxtFiles.Count) files to restore:" -ForegroundColor Yellow

foreach ($file in $ps1TxtFiles) {
    # Convert filename: remove 'ps1.txt' and add '.ps1'
    $baseName = $file.BaseName -replace 'ps1$', ''
    $newName = $baseName + ".ps1"
    $newPath = Join-Path $file.Directory.FullName $newName
    
    try {
        Rename-Item -Path $file.FullName -NewName $newName
        Write-Host "✅ $($file.Name) -> $newName" -ForegroundColor Green
    } catch {
        Write-Host "❌ Failed to rename $($file.Name): $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host "`n=== RESTORE COMPLETE ===" -ForegroundColor Cyan
Write-Host "All PowerShell files restored to .ps1 extension" -ForegroundColor Green