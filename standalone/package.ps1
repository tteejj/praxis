#!/usr/bin/env pwsh
# package.ps1 - Package individual app folder

param(
    [Parameter(Mandatory=$true)]
    [string]$FolderName,
    [int]$ChunkSize = 50000
)

if (-not (Test-Path $FolderName)) {
    Write-Host "Folder not found: $FolderName" -ForegroundColor Red
    exit 1
}

Write-Host "=== PACKAGING: $FolderName ===" -ForegroundColor Cyan

Write-Host "=== STEP 1: Renaming .ps1 files to ps1.txt ===" -ForegroundColor Yellow
$ps1Files = Get-ChildItem -Path $FolderName -Filter "*.ps1" -Recurse
foreach ($file in $ps1Files) {
    $newName = $file.BaseName + "ps1.txt"
    Rename-Item -Path $file.FullName -NewName $newName
    Write-Host "Renamed: $($file.Name) -> $newName" -ForegroundColor Green
}
Write-Host "Renamed $($ps1Files.Count) files`n" -ForegroundColor Green

Write-Host "=== STEP 2: Creating zip file ===" -ForegroundColor Yellow
$zipFile = "$FolderName.zip"
if (Test-Path $zipFile) { Remove-Item $zipFile }
& zip -r $zipFile $FolderName
if ($LASTEXITCODE -eq 0) {
    Write-Host "Created: $zipFile`n" -ForegroundColor Green
} else {
    Write-Host "Failed to create zip file" -ForegroundColor Red
    exit 1
}

Write-Host "=== STEP 3: Base64 encoding ===" -ForegroundColor Yellow
$bytes = [System.IO.File]::ReadAllBytes($zipFile)
$base64 = [System.Convert]::ToBase64String($bytes)
$base64File = "$zipFile.b64"
[System.IO.File]::WriteAllText($base64File, $base64)
Write-Host "Encoded: $zipFile -> $base64File ($($base64.Length) chars)`n" -ForegroundColor Green

Write-Host "=== STEP 4: Splitting into chunks ===" -ForegroundColor Yellow
$totalLength = $base64.Length
$chunkCount = [Math]::Ceiling($totalLength / $ChunkSize)
Write-Host "Splitting into $chunkCount chunks of ~$ChunkSize chars each" -ForegroundColor Cyan

for ($i = 0; $i -lt $chunkCount; $i++) {
    $start = $i * $ChunkSize
    $length = [Math]::Min($ChunkSize, $totalLength - $start)
    $chunk = $base64.Substring($start, $length)
    
    $chunkFile = "$base64File.part$($i + 1)"
    [System.IO.File]::WriteAllText($chunkFile, $chunk)
    Write-Host "Created: $chunkFile ($length chars)" -ForegroundColor Green
}

Write-Host "`n=== PACKAGING COMPLETE ===" -ForegroundColor Cyan
Write-Host "Email these files:" -ForegroundColor White
Get-ChildItem -Filter "$base64File.part*" | ForEach-Object { Write-Host "  - $($_.Name)" -ForegroundColor Gray }

# Clean up intermediate files
Remove-Item $zipFile
Remove-Item $base64File
Write-Host "`nCleaned up intermediate files" -ForegroundColor Gray