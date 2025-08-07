#!/usr/bin/env pwsh
# package.ps1 - Package app folder (non-destructive)
# Creates temporary copy, renames files, packages, then cleans up temp

param(
    [string]$FolderName = ".",
    [int]$ChunkSize = 50000
)

# Determine source path and folder name
if ($FolderName -eq ".") {
    # Package current directory contents
    $FolderName = Split-Path -Leaf (Get-Location)
    $SourcePath = Get-Location
    $PackageCurrentDir = $true
} else {
    # Package specific folder
    if (-not (Test-Path $FolderName)) {
        Write-Host "Folder not found: $FolderName" -ForegroundColor Red
        exit 1
    }
    $SourcePath = Resolve-Path $FolderName
    $PackageCurrentDir = $false
}

Write-Host "=== PACKAGING: $FolderName ===" -ForegroundColor Cyan
Write-Host "Source: $SourcePath" -ForegroundColor Gray

# Preview what will be packaged
Write-Host "`n=== PREVIEW: Files to be packaged ===" -ForegroundColor Yellow
if ($PackageCurrentDir) {
    $previewItems = Get-ChildItem -Path $SourcePath -Force | Where-Object {
        $_.Name -notlike ".*" -and
        $_.Name -notlike "temp_package_*" -and
        ($_.PSIsContainer -or $_.Extension -in @('.ps1', '.md', '.json', '.txt'))
    }
} else {
    $previewItems = Get-ChildItem -Path $SourcePath -Recurse
}

$previewItems | ForEach-Object { 
    $type = if ($_.PSIsContainer) { "[DIR]" } else { "[FILE]" }
    Write-Host "  $type $($_.Name)" -ForegroundColor Gray 
}
Write-Host "Total items: $($previewItems.Count)" -ForegroundColor Cyan

$continue = Read-Host "`nContinue with packaging? (y/N)"
if ($continue -notmatch '^y|yes$') {
    Write-Host "Packaging cancelled by user" -ForegroundColor Yellow
    exit 0
}

# Create temporary working directory
$TempDir = "temp_package_$([System.Guid]::NewGuid().ToString().Substring(0,8))"
Write-Host "`n=== STEP 1: Creating temporary copy ===" -ForegroundColor Yellow

try {
    if ($PackageCurrentDir) {
        # Copy only essential files from current directory, not subdirectories we don't want
        $itemsToCopy = Get-ChildItem -Path $SourcePath -Force | Where-Object {
            $_.Name -notlike ".*" -and  # Skip hidden files/folders
            $_.Name -ne "temp_package_*" -and  # Skip any old temp dirs
            ($_.PSIsContainer -or $_.Extension -in @('.ps1', '.md', '.json', '.txt'))  # Essential folders or specific files
        }
        
        # Create target directory
        $TempTargetPath = Join-Path $TempDir $FolderName
        New-Item -Path $TempTargetPath -ItemType Directory -Force | Out-Null
        
        # Copy each selected item
        foreach ($item in $itemsToCopy) {
            $destPath = Join-Path $TempTargetPath $item.Name
            if ($item.PSIsContainer) {
                Copy-Item -Path $item.FullName -Destination $destPath -Recurse -Force
                Write-Host "Copied folder: $($item.Name)" -ForegroundColor Gray
            } else {
                Copy-Item -Path $item.FullName -Destination $destPath -Force
                Write-Host "Copied file: $($item.Name)" -ForegroundColor Gray
            }
        }
        
        $TempSourcePath = $TempTargetPath
    } else {
        # Copy specific folder
        Copy-Item -Path $SourcePath -Destination $TempDir -Recurse -Force
        $TempSourcePath = Join-Path $TempDir (Split-Path -Leaf $SourcePath)
    }
    
    Write-Host "Created temporary copy: $TempDir" -ForegroundColor Green
    
    Write-Host "=== STEP 2: Renaming .ps1 files in temp copy ===" -ForegroundColor Yellow
    $ps1Files = Get-ChildItem -Path $TempSourcePath -Filter "*.ps1" -Recurse
    foreach ($file in $ps1Files) {
        $newName = $file.BaseName + "ps1.txt"
        Rename-Item -Path $file.FullName -NewName $newName
        Write-Host "Renamed: $($file.Name) -> $newName" -ForegroundColor Green
    }
    Write-Host "Renamed $($ps1Files.Count) files in temp copy`n" -ForegroundColor Green

    Write-Host "=== STEP 3: Creating zip file ===" -ForegroundColor Yellow
    $zipFile = "$FolderName.zip"
    if (Test-Path $zipFile) { Remove-Item $zipFile }
    
    # Zip the temp directory content (always zip the created folder structure)
    Push-Location $TempDir
    & zip -r "../$zipFile" $FolderName
    Pop-Location
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Created: $zipFile`n" -ForegroundColor Green
    } else {
        Write-Host "Failed to create zip file" -ForegroundColor Red
        throw "Zip creation failed"
    }

    Write-Host "=== STEP 4: Base64 encoding ===" -ForegroundColor Yellow
    $bytes = [System.IO.File]::ReadAllBytes($zipFile)
    $base64 = [System.Convert]::ToBase64String($bytes)
    $base64File = "$zipFile.b64"
    [System.IO.File]::WriteAllBytes($base64File, [System.Text.Encoding]::ASCII.GetBytes($base64))
    Write-Host "Encoded: $zipFile -> $base64File ($($base64.Length) chars)`n" -ForegroundColor Green

    Write-Host "=== STEP 5: Splitting into chunks ===" -ForegroundColor Yellow
    $totalLength = $base64.Length
    $chunkCount = [Math]::Ceiling($totalLength / $ChunkSize)
    Write-Host "Splitting into $chunkCount chunks of ~$ChunkSize chars each" -ForegroundColor Cyan

    for ($i = 0; $i -lt $chunkCount; $i++) {
        $start = $i * $ChunkSize
        $length = [Math]::Min($ChunkSize, $totalLength - $start)
        $chunk = $base64.Substring($start, $length)
        
        $chunkFile = "$base64File.part$($i + 1)"
        [System.IO.File]::WriteAllBytes($chunkFile, [System.Text.Encoding]::ASCII.GetBytes($chunk))
        Write-Host "Created: $chunkFile ($length chars)" -ForegroundColor Green
    }

    Write-Host "`n=== PACKAGING COMPLETE ===" -ForegroundColor Cyan
    Write-Host "Email these files:" -ForegroundColor White
    Get-ChildItem -Filter "$base64File.part*" | ForEach-Object { Write-Host "  - $($_.Name)" -ForegroundColor Gray }
    
} catch {
    Write-Host "Error during packaging: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} finally {
    # Clean up
    Write-Host "`n=== STEP 6: Cleaning up ===" -ForegroundColor Yellow
    
    if (Test-Path $TempDir) {
        Remove-Item -Path $TempDir -Recurse -Force
        Write-Host "Removed temporary directory: $TempDir" -ForegroundColor Gray
    }
    
    if (Test-Path $zipFile) {
        Remove-Item $zipFile
        Write-Host "Removed intermediate zip file" -ForegroundColor Gray
    }
    
    if (Test-Path $base64File) {
        Remove-Item $base64File  
        Write-Host "Removed intermediate base64 file" -ForegroundColor Gray
    }
}

Write-Host "`n✅ Original files unchanged - packaging complete!" -ForegroundColor Green