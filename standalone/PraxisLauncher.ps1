#!/usr/bin/env pwsh
# PraxisLauncher.ps1 - Simple pillbox launcher for Praxis apps

# Hide cursor
[Console]::CursorVisible = $false

# App definitions
$apps = @(
    @{
        Name = "TaskPro"
        Path = "./taskpro/SimpleTaskPro.ps1"
        Icon = "📋"
        Description = "Task Management & Notes"
    },
    @{
        Name = "TimeTracker"
        Path = "./timetracker/TimeTracker.ps1"
        Icon = "⏱️"
        Description = "Time Entry Management"
    },
    @{
        Name = "CommandLibrary"
        Path = "./commandlibrary/CommandLibrary.ps1"
        Icon = "📚"
        Description = "Command Repository"
    },
    @{
        Name = "ExcelDataFlow"
        Path = "./exceldataflow/Start.ps1"
        Icon = "📊"
        Description = "Excel Data Management"
    }
)

$selectedIndex = 0

function Draw-Launcher {
    Clear-Host
    
    # Header
    Write-Host "╭─────────────────────────────────────────────────────────────╮" -ForegroundColor Blue
    Write-Host "│ PRAXIS LAUNCHER                                             │" -ForegroundColor Blue
    Write-Host "╰─────────────────────────────────────────────────────────────╯" -ForegroundColor Blue
    Write-Host ""
    
    # Apps
    for ($i = 0; $i -lt $apps.Count; $i++) {
        $app = $apps[$i]
        
        if ($i -eq $selectedIndex) {
            # Selected - pillbox style
            Write-Host "  ╭─────────────────────────────────────────────────────────╮" -ForegroundColor Cyan
            Write-Host "  │ $($app.Icon) $($app.Name) - $($app.Description)".PadRight(60) "│" -ForegroundColor White
            Write-Host "  ╰─────────────────────────────────────────────────────────╯" -ForegroundColor Cyan
        } else {
            # Not selected
            Write-Host "    $($app.Icon) $($app.Name) - $($app.Description)" -ForegroundColor Gray
        }
        Write-Host ""
    }
    
    # Controls
    Write-Host "  [↑↓] Navigate  [Enter] Launch  [Q] Quit" -ForegroundColor DarkGray
}

# Main loop
while ($true) {
    Draw-Launcher
    
    $key = [Console]::ReadKey($true)
    
    switch ($key.Key) {
        'UpArrow' {
            if ($selectedIndex -gt 0) {
                $selectedIndex--
            }
        }
        'DownArrow' {
            if ($selectedIndex -lt ($apps.Count - 1)) {
                $selectedIndex++
            }
        }
        'Enter' {
            $app = $apps[$selectedIndex]
            Clear-Host
            Write-Host "Launching $($app.Name)..." -ForegroundColor Green
            
            # Launch the app
            & $app.Path
            
            # Return to launcher after app exits
            Write-Host "`nPress any key to return to launcher..." -ForegroundColor Gray
            [Console]::ReadKey($true) | Out-Null
        }
        'Q' {
            [Console]::CursorVisible = $true
            Clear-Host
            exit
        }
    }
}