#!/usr/bin/env pwsh
# Test file browser debugging

# Navigate to script directory
Set-Location $PSScriptRoot

# Set debug flag
$global:Debug = $true

# Clear log
$logFile = Join-Path $PSScriptRoot "_Logs" "praxis.log"
if (Test-Path $logFile) {
    Clear-Content $logFile
}

Write-Host "Testing File Browser..." -ForegroundColor Cyan

# Load framework
. ./Start.ps1 -Debug

# Navigate to file browser tab (tab 3)
Start-Sleep -Milliseconds 500
[System.Console]::KeyAvailable = $true
[System.Console]::ReadKey($true) # Clear any pending keys

# Press 3 to go to file browser
$key3 = [System.ConsoleKeyInfo]::new('3', [System.ConsoleKey]::D3, $false, $false, $false)
$global:ScreenManager.HandleInput($key3)

Write-Host "`nNavigated to File Browser tab" -ForegroundColor Yellow

# Check if FileBrowserScreen is active
$activeTab = $global:ScreenManager.CurrentScreen.TabContainer.GetActiveTab()
if ($activeTab) {
    Write-Host "Active tab: $($activeTab.Title)" -ForegroundColor Green
    Write-Host "Tab content type: $($activeTab.Content.GetType().Name)" -ForegroundColor Green
    
    if ($activeTab.Content -is [FileBrowserScreen]) {
        $fileScreen = $activeTab.Content
        Write-Host "FileBrowserScreen found!" -ForegroundColor Green
        
        if ($fileScreen.FileTree) {
            Write-Host "FileTree type: $($fileScreen.FileTree.GetType().Name)" -ForegroundColor Cyan
            Write-Host "FileTree IsFocusable: $($fileScreen.FileTree.IsFocusable)" -ForegroundColor Cyan
            Write-Host "FileTree IsFocused: $($fileScreen.FileTree.IsFocused)" -ForegroundColor Cyan
            
            if ($fileScreen.FileTree -is [RangerFileTree]) {
                $ranger = $fileScreen.FileTree
                Write-Host "RangerFileTree CurrentPath: $($ranger.CurrentPath)" -ForegroundColor Cyan
                
                if ($ranger.CurrentPane) {
                    Write-Host "CurrentPane type: $($ranger.CurrentPane.GetType().Name)" -ForegroundColor Yellow
                    Write-Host "CurrentPane IsFocusable: $($ranger.CurrentPane.IsFocusable)" -ForegroundColor Yellow
                    Write-Host "CurrentPane IsFocused: $($ranger.CurrentPane.IsFocused)" -ForegroundColor Yellow
                    Write-Host "CurrentPane Items: $($ranger.CurrentPane._flatView.Count)" -ForegroundColor Yellow
                }
            }
        } else {
            Write-Host "ERROR: FileTree is null!" -ForegroundColor Red
        }
    }
}

# Try to send a 'j' key
Write-Host "`nTrying to send 'j' key..." -ForegroundColor Cyan
$keyJ = [System.ConsoleKeyInfo]::new('j', [System.ConsoleKey]::J, $false, $false, $false)
$handled = $global:ScreenManager.HandleInput($keyJ)
Write-Host "Key 'j' handled: $handled" -ForegroundColor Yellow

# Exit
Write-Host "`nPress any key to exit..." -ForegroundColor Gray
[System.Console]::ReadKey($true) | Out-Null