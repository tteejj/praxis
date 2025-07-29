#!/usr/bin/env pwsh
# Test border character rendering

Write-Host "Testing border characters in your terminal:`n"

Write-Host "1. Rounded border (shows horizontal lines):"
Write-Host "   Top: ╭─────────╮"
Write-Host "   Mid: │ Content │"
Write-Host "   Bot: ╰─────────╯"

Write-Host "`n2. RoundedNoLines border (spaces instead):"
Write-Host "   Top: ╭         ╮"
Write-Host "   Mid: │ Content │"
Write-Host "   Bot: ╰         ╯"

Write-Host "`n3. Single border:"
Write-Host "   Top: ┌─────────┐"
Write-Host "   Mid: │ Content │"
Write-Host "   Bot: └─────────┘"

Write-Host "`n4. Testing in grid context (Rounded):"
Write-Host "╭─────────────────────╮"
Write-Host "│ Header              │"
Write-Host "├─────────────────────┤  <- This line causes issues"
Write-Host "│ Row 1               │"
Write-Host "│ Row 2               │"
Write-Host "╰─────────────────────╯"

Write-Host "`n5. Testing in grid context (RoundedNoLines):"
Write-Host "╭                     ╮"
Write-Host "│ Header              │"
Write-Host "│                     │  <- No line, just space"
Write-Host "│ Row 1               │"
Write-Host "│ Row 2               │"
Write-Host "╰                     ╯"

Write-Host "`nWhich looks better in your terminal? The issue is that Rounded uses '─' character."