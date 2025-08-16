#!/usr/bin/env pwsh
# Quick launcher for enhanced cyberpunk TaskProPro

Clear-Host
Write-Host "╔══════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║                 TASKPRO CYBERPUNK ENHANCED                      ║" -ForegroundColor Cyan  
Write-Host "║                                                                  ║" -ForegroundColor Cyan
Write-Host "║  🚀 FEATURES:                                                    ║" -ForegroundColor Yellow
Write-Host "║    • ID1/ID2 Project Codes in task display                      ║" -ForegroundColor Green
Write-Host "║    • Cyberpunk [brackets] styling everywhere                    ║" -ForegroundColor Green
Write-Host "║    • Enhanced inline editing with 7 fields                      ║" -ForegroundColor Green
Write-Host "║    • [TODAY], [TOM], [H], [M], [L] indicators                   ║" -ForegroundColor Green
Write-Host "║    • Professional text input with blinking cursors              ║" -ForegroundColor Green
Write-Host "║                                                                  ║" -ForegroundColor Cyan
Write-Host "║  🎮 CONTROLS:                                                    ║" -ForegroundColor Yellow
Write-Host "║    E = Enhanced Inline Edit (ID1/ID2/Priority/Date/Tags/Notes)  ║" -ForegroundColor White
Write-Host "║    N = New Task (with all 7 fields)                             ║" -ForegroundColor White
Write-Host "║    Space = Complete Task                                         ║" -ForegroundColor White
Write-Host "║    Enter = Edit Notes                                            ║" -ForegroundColor White
Write-Host "║    Q = Quit                                                      ║" -ForegroundColor White
Write-Host "║                                                                  ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""
Write-Host "Starting enhanced TaskProPro..." -ForegroundColor Green
Start-Sleep 2

# Launch TaskProPro
& "$PSScriptRoot/TaskProPro.ps1"