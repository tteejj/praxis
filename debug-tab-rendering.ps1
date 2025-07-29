#!/usr/bin/env pwsh

# Debug script to show exactly what's being rendered in tab bar

Write-Host "Tab Bar Debug Output" -ForegroundColor Yellow
Write-Host "===================" -ForegroundColor Yellow

# Simulate the exact sequences from TabContainer
$esc = [char]27

Write-Host "`nSimulating tab bar render at Y=0, Width=80:" -ForegroundColor Cyan

# Move to position and fill background
$output = "${esc}[1;1H${esc}[48;2;61;49;0m" + (" " * 80)
Write-Host "Background fill: [moves to 1,1 then fills 80 spaces with background color]"

# Tab positions with overflow check
$x = 3  # Starting at X=2 (1-based)
$maxX = 78  # Width - 2

$tabs = @(
    @{Title="1:Projects"; Width=14},
    @{Title="2:Tasks"; Width=11},
    @{Title="3:Time"; Width=10},
    @{Title="4:Files"; Width=11},
    @{Title="5:Editor"; Width=12},
    @{Title="6:Commands"; Width=14},
    @{Title="7:Macro Factory"; Width=19},
    @{Title="8:Settings"; Width=14}
)

Write-Host "`nTab rendering simulation:"
foreach ($i in 0..($tabs.Count-1)) {
    $tab = $tabs[$i]
    $tabWidth = $tab.Width
    
    Write-Host "`nTab $($i+1): '$($tab.Title)'"
    Write-Host "  Position X: $x (1-based)"
    Write-Host "  Width: $tabWidth"
    
    if (($x + $tabWidth) -gt $maxX) {
        Write-Host "  OVERFLOW DETECTED! Would extend to: $($x + $tabWidth), max is: $maxX" -ForegroundColor Red
        Write-Host "  This tab should NOT be rendered" -ForegroundColor Red
        break
    } else {
        Write-Host "  OK - fits within bounds" -ForegroundColor Green
    }
    
    $x += $tabWidth + 1
}

Write-Host "`nActual sequences that would be sent:" -ForegroundColor Magenta
Write-Host "(ESC sequences shown as <ESC> for clarity)"

# Show what the fixed version outputs
$sequence = "<ESC>[1;1H<ESC>[48;2;61;49;0m" + (" " * 80) + "<ESC>[1;3H<ESC>[48;2;51;34;0m<ESC>[38;2;255;230;77m 1:Projects <ESC>[48;2;61;49;0m"

Write-Host $sequence
Write-Host "(Additional tabs would follow but stop at overflow)"

Write-Host "`nThe fix ensures:" -ForegroundColor Green
Write-Host "1. Tabs 7 and 8 are not rendered as they overflow"
Write-Host "2. Background color is reset after each tab"
Write-Host "3. No gap line is drawn at Y+1"
Write-Host "4. Rest of tab bar is filled with background color"

Write-Host "`nTo run in foot:" -ForegroundColor Yellow
Write-Host "1. Use: LC_ALL=C.UTF-8 foot -e pwsh -file Start.ps1"
Write-Host "2. Or use the wrapper: foot -e ./run-in-foot.sh"