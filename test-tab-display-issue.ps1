#!/usr/bin/env pwsh

# Simple test to reproduce tab display issue
Write-Host "Testing Tab Display Issue" -ForegroundColor Yellow
Write-Host "========================" -ForegroundColor Yellow

# Looking at the TabContainer code, I see potential issues:
# 1. In RebuildTabBar() method, line 283-285 fills a gap line
# 2. The gap between tabs and content might be overlapping with content
# 3. Content positioning uses topGap = 2 which might push content down too far

Write-Host "`nPotential Issues Found:" -ForegroundColor Cyan

Write-Host "`n1. Gap Calculation (from PositionContent method):"
Write-Host "   - TabBarHeight = 1"
Write-Host "   - TopGap = 2"
Write-Host "   - ContentY = Y + TabBarHeight + TopGap = 0 + 1 + 2 = 3"
Write-Host "   - But tab bar fills lines Y=0 AND Y=1 (gap line)"

Write-Host "`n2. Tab Title Overflow:"
Write-Host "   Looking at tab titles and their positions:"
$tabs = @(
    @{Title="Projects"; Key=1; FullTitle="1:Projects"},
    @{Title="Tasks"; Key=2; FullTitle="2:Tasks"},
    @{Title="Time"; Key=3; FullTitle="3:Time"},
    @{Title="Files"; Key=4; FullTitle="4:Files"},
    @{Title="Editor"; Key=5; FullTitle="5:Editor"},
    @{Title="Commands"; Key=6; FullTitle="6:Commands"},
    @{Title="Macro Factory"; Key=7; FullTitle="7:Macro Factory"},
    @{Title="Settings"; Key=8; FullTitle="8:Settings"}
)

$x = 2  # Starting X position
$containerWidth = 80  # Typical terminal width
Write-Host "`n   Container width: $containerWidth"

foreach ($tab in $tabs) {
    $tabWidth = $tab.FullTitle.Length + 4  # Padding
    Write-Host "   Tab $($tab.Key): '$($tab.FullTitle)' at X=$x, width=$tabWidth"
    
    if (($x + $tabWidth) -gt $containerWidth) {
        Write-Host "     -> OVERFLOW! Would extend to X=$($x + $tabWidth)" -ForegroundColor Red
    }
    
    $x += $tabWidth + 1
}

Write-Host "`n3. Content Area Calculation:"
Write-Host "   When tab 3 (Time) is active:"
Write-Host "   - Content should start at Y=3"
Write-Host "   - But if tab text overflows or renders incorrectly,"
Write-Host "   - it might appear in the content area"

Write-Host "`n4. The 'week' text you see might be:"
Write-Host "   - Part of a truncated tab title (e.g., '7:Macro Factory' truncated)"
Write-Host "   - Content from TimeEntryScreen bleeding through"
Write-Host "   - Or tab bar rendering at wrong Y position"

Write-Host "`nRecommended Fix:" -ForegroundColor Green
Write-Host "1. Check if tabs fit in available width before rendering"
Write-Host "2. Ensure gap line doesn't interfere with content"
Write-Host "3. Add proper bounds checking for tab rendering"
Write-Host "4. Clear the entire tab bar area before rendering tabs"