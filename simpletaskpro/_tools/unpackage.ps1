# unpackage.ps1 - Unpack base64 chunks with proper encoding

param(
    [string]$BaseFileName = "taskpro.zip.b64"
)

Write-Host "=== STEP 1: Joining base64 chunks ===" -ForegroundColor Yellow
$parts = Get-ChildItem -Path . -Filter "$BaseFileName.part*" | Sort-Object { [int] ($_.Name -replace '.*\.part(\d+)$', '$1') }
if ($parts.Count -eq 0) {
    Write-Host "No parts found for $BaseFileName" -ForegroundColor Red
    exit 1
}

Write-Host "Found $($parts.Count) parts" -ForegroundColor Cyan
$combined = ""
foreach ($part in $parts) {
    $contentBytes = [System.IO.File]::ReadAllBytes($part.FullName)
    $content = [System.Text.Encoding]::ASCII.GetString($contentBytes)
    $combined += $content
    Write-Host "Added: $($part.Name) ($($content.Length) chars)" -ForegroundColor Green
}

[System.IO.File]::WriteAllBytes($BaseFileName, [System.Text.Encoding]::ASCII.GetBytes($combined))
Write-Host "Joined: $BaseFileName ($($combined.Length) chars)" -ForegroundColor Green

Write-Host "=== STEP 2: Decoding base64 to zip ===" -ForegroundColor Yellow
try {
    $base64Bytes = [System.IO.File]::ReadAllBytes($BaseFileName)
    $base64 = [System.Text.Encoding]::ASCII.GetString($base64Bytes)
    $bytes = [System.Convert]::FromBase64String($base64)
    $zipFile = $BaseFileName -replace '\.b64$', ''
    [System.IO.File]::WriteAllBytes($zipFile, $bytes)
    Write-Host "Decoded: $BaseFileName -> $zipFile ($($bytes.Length) bytes)" -ForegroundColor Green
} catch {
    Write-Host "Base64 decode failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Check for illegal characters in base64 string" -ForegroundColor Red
    exit 1
}

Write-Host "`n=== SUCCESS ===" -ForegroundColor Cyan
Write-Host "Next: Unzip $zipFile manually, then run restore-ps1.ps1" -ForegroundColor White