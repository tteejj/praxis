#!/usr/bin/env pwsh

# Test script to debug tab positioning issues

Write-Host "Testing Tab Container Positioning" -ForegroundColor Yellow
Write-Host "===============================" -ForegroundColor Yellow

# Simulate tab container dimensions
$containerX = 0
$containerY = 0
$containerWidth = 120
$containerHeight = 40
$tabBarHeight = 1

Write-Host "`nContainer Bounds:"
Write-Host "  X: $containerX, Y: $containerY"
Write-Host "  Width: $containerWidth, Height: $containerHeight"
Write-Host "  Tab Bar Height: $tabBarHeight"

# Calculate content position (from PositionContent method)
$gap = 2  # Standard visual separation per Island Components spec
$topGap = 2  # Gap between tabs and content
$availableWidth = $containerWidth - ($gap * 2)
$availableHeight = $containerHeight - $tabBarHeight - $topGap - $gap
$contentY = $containerY + $tabBarHeight + $topGap
$contentX = $containerX + $gap

Write-Host "`nContent Bounds Calculation:"
Write-Host "  Gap: $gap, Top Gap: $topGap"
Write-Host "  Content X: $contentX"
Write-Host "  Content Y: $contentY"
Write-Host "  Available Width: $availableWidth"
Write-Host "  Available Height: $availableHeight"

# Show visual representation
Write-Host "`nVisual Representation:" -ForegroundColor Cyan
Write-Host "┌" + ("─" * ($containerWidth - 2)) + "┐"

# Tab bar
Write-Host "│ [1:Projects] 2:Tasks 3:Time 4:Files" + (" " * ($containerWidth - 38)) + "│"

# Gap lines
for ($i = 0; $i -lt $topGap; $i++) {
    Write-Host "│" + (" " * ($containerWidth - 2)) + "│"
}

# Content area start
Write-Host "│" + (" " * $gap) + "┌" + ("─" * ($availableWidth - 2)) + "┐" + (" " * $gap) + "│"

# Some content lines
for ($i = 0; $i -lt 5; $i++) {
    Write-Host "│" + (" " * $gap) + "│" + (" Content line $i" + (" " * ($availableWidth - 17))) + "│" + (" " * $gap) + "│"
}

Write-Host "│" + (" " * $gap) + "└" + ("─" * ($availableWidth - 2)) + "┘" + (" " * $gap) + "│"

# Bottom gap
for ($i = 0; $i -lt $gap; $i++) {
    Write-Host "│" + (" " * ($containerWidth - 2)) + "│"
}

Write-Host "└" + ("─" * ($containerWidth - 2)) + "┘"

# Test actual tab titles
Write-Host "`nActual Tab Titles:" -ForegroundColor Yellow
$tabs = @(
    @{Title="Projects"; ShortcutKey=1},
    @{Title="Tasks"; ShortcutKey=2},
    @{Title="Time"; ShortcutKey=3},
    @{Title="Files"; ShortcutKey=4},
    @{Title="Editor"; ShortcutKey=5},
    @{Title="Commands"; ShortcutKey=6},
    @{Title="Macro Factory"; ShortcutKey=7},
    @{Title="Settings"; ShortcutKey=8}
)

$x = 2
foreach ($tab in $tabs) {
    $title = "$($tab.ShortcutKey):$($tab.Title)"
    $tabWidth = $title.Length + 4
    Write-Host "Tab: $title, Width: $tabWidth, X Position: $x"
    $x += $tabWidth + 1
}

Write-Host "`nPotential Issues:" -ForegroundColor Red
if ($contentY -lt ($containerY + $tabBarHeight)) {
    Write-Host "- Content Y position overlaps with tab bar!"
}
if ($availableHeight -lt 10) {
    Write-Host "- Available height is very small: $availableHeight"
}
if ($x -gt $containerWidth) {
    Write-Host "- Tabs overflow container width! Total tab width: $x, Container width: $containerWidth"
}