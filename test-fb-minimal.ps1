#!/usr/bin/env pwsh
# Minimal test for file browser

# Clear the log first
Clear-Content "_Logs/praxis.log" -Force

Write-Host @"
File Browser Test Instructions:
1. Press '3' to go to file browser
2. Use vim keys to navigate:
   - j: down
   - k: up  
   - h: parent directory
   - l: enter directory
3. Check if highlight shows on selected item
4. Press Ctrl+C to exit

Starting PRAXIS...
"@ -ForegroundColor Cyan

# Run the app
& ./Start.ps1