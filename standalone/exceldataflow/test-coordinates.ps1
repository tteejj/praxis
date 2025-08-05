#!/usr/bin/env pwsh

# Test coordinate systems
. "$PSScriptRoot/Core/VT100.ps1"

Clear-Host
Write-Host "Testing coordinate system..."

# Test basic positioning
Write-Host -NoNewline ([VT]::MoveTo(5, 3))
Write-Host -NoNewline "Position (5,3)"

Write-Host -NoNewline ([VT]::MoveTo(10, 5))
Write-Host -NoNewline "Position (10,5)"

Write-Host -NoNewline ([VT]::MoveTo(15, 7))
Write-Host -NoNewline "Position (15,7)"

# Test dialog-like box
Write-Host -NoNewline ([VT]::MoveTo(2, 10))
Write-Host -NoNewline "┌────────────────────────┐"
Write-Host -NoNewline ([VT]::MoveTo(2, 11))
Write-Host -NoNewline "│  Test Dialog Content   │"
Write-Host -NoNewline ([VT]::MoveTo(2, 12))
Write-Host -NoNewline "└────────────────────────┘"

Write-Host -NoNewline ([VT]::MoveTo(0, 15))
Write-Host "Press any key to continue..."
[Console]::ReadKey($true) | Out-Null