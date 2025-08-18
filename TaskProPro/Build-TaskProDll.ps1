#!/usr/bin/env pwsh
# Build-TaskProDll.ps1 - Compile all C# files into TaskPro.dll

param(
    [switch]$Force
)

Write-Host "Building TaskPro.dll..." -ForegroundColor Cyan

# Get all C# source files (exclude deprecated files)
$sourceFiles = Get-ChildItem "$PSScriptRoot/CSharp" -Recurse -Filter "*.cs" | 
               Where-Object { $_.Name -notlike "*_DEPRECATED_*" } | 
               Sort-Object FullName
Write-Host "  Found $($sourceFiles.Count) C# source files" -ForegroundColor Gray

# Check if rebuild is needed
$dllPath = "$PSScriptRoot/TaskPro.dll"
$needsRebuild = $Force.IsPresent

if (-not $needsRebuild -and (Test-Path $dllPath)) {
    $dllTime = (Get-Item $dllPath).LastWriteTime
    $newestSource = ($sourceFiles | Sort-Object LastWriteTime -Descending | Select-Object -First 1).LastWriteTime
    
    if ($newestSource -gt $dllTime) {
        $needsRebuild = $true
        Write-Host "  Source files newer than existing DLL - rebuilding" -ForegroundColor Yellow
    } else {
        Write-Host "  DLL is up to date" -ForegroundColor Green
        exit 0
    }
} else {
    $needsRebuild = $true
}

if ($needsRebuild) {
    Write-Host "  Compiling $($sourceFiles.Count) files into TaskPro.dll..." -ForegroundColor Yellow
    
    # Combine all source files with proper using handling
    $allUsings = @()
    $allNamespaces = @()
    
    foreach ($file in $sourceFiles) {
        $content = Get-Content $file.FullName -Raw
        $lines = $content -split "`n"
        
        # Extract using statements
        $usings = $lines | Where-Object { $_ -match "^using\s+" }
        $allUsings += $usings
        
        # Extract everything after using statements
        $nonUsingLines = @()
        $foundFirstNonUsing = $false
        foreach ($line in $lines) {
            if ($line -match "^using\s+" -and -not $foundFirstNonUsing) {
                continue  # Skip using statements
            }
            if ($line.Trim() -eq "" -and -not $foundFirstNonUsing) {
                continue  # Skip empty lines before namespace
            }
            $foundFirstNonUsing = $true
            $nonUsingLines += $line
        }
        
        $allNamespaces += ($nonUsingLines -join "`n")
    }
    
    # Combine: unique using statements first, then all namespace content
    $uniqueUsings = $allUsings | Sort-Object | Get-Unique
    $combinedSource = ($uniqueUsings -join "`n") + "`n`n" + ($allNamespaces -join "`n`n")
    
    try {
        # Compile to DLL
        Add-Type -TypeDefinition $combinedSource `
                 -OutputAssembly $dllPath `
                 -Language CSharp
        
        Write-Host "  ✓ TaskPro.dll compiled successfully!" -ForegroundColor Green
        Write-Host "    Location: $dllPath" -ForegroundColor Gray
        Write-Host "    Size: $([Math]::Round((Get-Item $dllPath).Length / 1KB, 1)) KB" -ForegroundColor Gray
        
        # Test the DLL by loading it
        Add-Type -Path $dllPath
        $testWidget = [TaskPro.UI.TaskListWidget]::new()
        Write-Host "  ✓ DLL loads and works correctly!" -ForegroundColor Green
        
    } catch {
        Write-Host "  ✗ Compilation failed: $($_.Exception.Message)" -ForegroundColor Red
        if (Test-Path $dllPath) {
            Remove-Item $dllPath -Force
        }
        exit 1
    }
}