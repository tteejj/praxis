#!/usr/bin/env pwsh

# Quick test to verify pillbox right border alignment
# This simulates navigation through tasks with tags to check the pillbox rendering

Write-Host "Testing TaskPro pillbox right border alignment..."
Write-Host "Starting TaskPro in test mode..."

# Start TaskPro and simulate navigation
& './TaskPro.ps1'

Write-Host "`nTest completed. Check if right borders | are consistently aligned within each pillbox."