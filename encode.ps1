#!/usr/bin/env pwsh
# encode.ps1 - Convert zip file to base64

param(
    [Parameter(Mandatory=$true)]
    [string]$ZipFile
)

if (-not (Test-Path $ZipFile)) {
    Write-Host "File not found: $ZipFile" -ForegroundColor Red
    exit 1
}

$bytes = [System.IO.File]::ReadAllBytes($ZipFile)
$base64 = [System.Convert]::ToBase64String($bytes)

$outputFile = $ZipFile + ".b64"
[System.IO.File]::WriteAllText($outputFile, $base64)

Write-Host "Encoded: $ZipFile -> $outputFile" -ForegroundColor Green
Write-Host "Size: $($bytes.Length) bytes -> $($base64.Length) chars" -ForegroundColor Cyan