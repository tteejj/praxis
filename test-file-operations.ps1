#!/usr/bin/env pwsh
# Test script for file operations in the RangerFileTree

# Load the framework in test mode
. ./Start.ps1 -LoadOnly

Write-Host "`nTesting File Operations" -ForegroundColor Cyan
Write-Host "======================" -ForegroundColor Cyan

# Create test environment
$testDir = Join-Path $env:TEMP "praxis_file_ops_test_$(Get-Random)"
New-Item -ItemType Directory -Path $testDir -Force | Out-Null

Write-Host "`nCreating test files..." -ForegroundColor Yellow

# Create test files and directories
@(
    "file1.txt",
    "file2.ps1",
    "document.md",
    "script.sh"
) | ForEach-Object {
    $filePath = Join-Path $testDir $_
    "Test content for $_" | Out-File -FilePath $filePath -Encoding UTF8
    Write-Host "  Created: $_" -ForegroundColor DarkGray
}

# Create subdirectories
@(
    "src",
    "docs",
    "tests"
) | ForEach-Object {
    $dirPath = Join-Path $testDir $_
    New-Item -ItemType Directory -Path $dirPath -Force | Out-Null
    
    # Add a file in each directory
    $subFile = Join-Path $dirPath "example.txt"
    "Content in $_" | Out-File -FilePath $subFile -Encoding UTF8
    Write-Host "  Created: $_/ with example.txt" -ForegroundColor DarkGray
}

Write-Host "`nTest directory created at: $testDir" -ForegroundColor Green

# Create FileBrowserScreen with the test directory
Write-Host "`nInitializing File Browser..." -ForegroundColor Yellow

$fileBrowser = [FileBrowserScreen]::new()
$fileBrowser.ServiceContainer = $global:ServiceContainer
$fileBrowser.OnInitialize()

# Set the test directory
$fileBrowser.FileTree.CurrentPath = $testDir
$fileBrowser.FileTree.NavigateToDirectory($testDir)

Write-Host "File Browser initialized with test directory" -ForegroundColor Green

# Test file operations service
Write-Host "`nTesting FileOperationService..." -ForegroundColor Yellow

$fileOps = $global:ServiceContainer.GetService('FileOperationService')
if ($fileOps) {
    Write-Host "  FileOperationService found" -ForegroundColor Green
    
    # Test yank operation
    $testFile = Join-Path $testDir "file1.txt"
    $fileOps.YankItems(@($testFile), $false)
    $yankInfo = $fileOps.GetYankBufferInfo()
    Write-Host "  Yank buffer contains: $($yankInfo.Count) items" -ForegroundColor DarkGray
    
    # Test paste operation
    $destDir = Join-Path $testDir "src"
    $result = $fileOps.PasteItems($destDir)
    if ($result.Success) {
        Write-Host "  Paste operation: $($result.Message)" -ForegroundColor Green
    } else {
        Write-Host "  Paste operation failed: $($result.Message)" -ForegroundColor Red
    }
    
    # Test rename operation
    $renameFile = Join-Path $testDir "file2.ps1"
    $renameResult = $fileOps.RenameItem($renameFile, "renamed_file.ps1")
    if ($renameResult.Success) {
        Write-Host "  Rename operation: $($renameResult.Message)" -ForegroundColor Green
    } else {
        Write-Host "  Rename operation failed: $($renameResult.Message)" -ForegroundColor Red
    }
    
} else {
    Write-Host "  FileOperationService not found!" -ForegroundColor Red
}

Write-Host "`nFile Operations Test Summary:" -ForegroundColor Cyan
Write-Host "- Test directory: $testDir" -ForegroundColor DarkGray
Write-Host "- FileOperationService: $(if ($fileOps) { 'OK' } else { 'FAILED' })" -ForegroundColor $(if ($fileOps) { 'Green' } else { 'Red' })
Write-Host "- Keyboard shortcuts:" -ForegroundColor DarkGray
Write-Host "  - y: Yank (copy) files" -ForegroundColor DarkGray
Write-Host "  - d: Cut files" -ForegroundColor DarkGray
Write-Host "  - p: Paste files" -ForegroundColor DarkGray
Write-Host "  - r: Rename file" -ForegroundColor DarkGray
Write-Host "  - D: Delete files" -ForegroundColor DarkGray
Write-Host "  - Space: Mark/unmark files" -ForegroundColor DarkGray

Write-Host "`nPress Enter to run the File Browser with test directory..."
Read-Host

# Run the file browser
$screenManager = $global:ServiceContainer.GetService('ScreenManager')
$screenManager.Push($fileBrowser)
$screenManager.Run()

# Cleanup
Write-Host "`nCleaning up test directory..." -ForegroundColor Yellow
Remove-Item -Path $testDir -Recurse -Force -ErrorAction SilentlyContinue
Write-Host "Test completed!" -ForegroundColor Green