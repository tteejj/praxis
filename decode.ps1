#!/usr/bin/env pwsh
# decode.ps1 - Convert base64 back to zip file

param(
    [Parameter(Mandatory=$true)]
    [string]$Base64File
)

if (-not (Test-Path $Base64File)) {
    Write-Host "File not found: $Base64File" -ForegroundColor Red
    exit 1
}

$base64 = [System.IO.File]::ReadAllText($Base64File)
$bytes = [System.Convert]::FromBase64String($base64)

$outputFile = $Base64File -replace '\.b64$', ''
[System.IO.File]::WriteAllBytes($outputFile, $bytes)

Write-Host "Decoded: $Base64File -> $outputFile" -ForegroundColor Green
Write-Host "Size: $($base64.Length) chars -> $($bytes.Length) bytes" -ForegroundColor Cyan