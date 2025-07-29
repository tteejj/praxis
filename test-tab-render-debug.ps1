#!/usr/bin/env pwsh

# Load all dependencies properly
. ./Start.ps1 -NoRun

Write-Host "Creating test tab container..." -ForegroundColor Yellow

# Create a minimal test
$container = [TabContainer]::new()
$container.Initialize($global:ServiceContainer)
$container.SetBounds(0, 0, 80, 30)

# Add test tabs
$container.AddTab("Projects", [Screen]::new())
$container.AddTab("Tasks", [Screen]::new())
$container.AddTab("Time", [Screen]::new())

Write-Host "`nTab container setup complete" -ForegroundColor Green
Write-Host "Container bounds: X=$($container.X), Y=$($container.Y), W=$($container.Width), H=$($container.Height)"
Write-Host "Tab count: $($container.Tabs.Count)"
Write-Host "Active tab index: $($container.ActiveTabIndex)"

# Check each tab's content bounds
Write-Host "`nChecking tab content bounds:" -ForegroundColor Cyan
for ($i = 0; $i -lt $container.Tabs.Count; $i++) {
    $tab = $container.Tabs[$i]
    Write-Host "`nTab $i ($($tab.Title)):"
    if ($tab.Content) {
        Write-Host "  Content bounds: X=$($tab.Content.X), Y=$($tab.Content.Y), W=$($tab.Content.Width), H=$($tab.Content.Height)"
        Write-Host "  IsInitialized: $($tab.IsInitialized)"
    } else {
        Write-Host "  No content"
    }
}

# Test the RebuildTabBar method
Write-Host "`nTesting tab bar rendering..." -ForegroundColor Yellow
$container._tabBarInvalid = $true
$container.RebuildTabBar()

# Show the cached tab bar (with escape sequences visible)
Write-Host "`nCached tab bar output (escape sequences shown):" -ForegroundColor Magenta
$tabBarEscaped = $container._cachedTabBar -replace "`e", "<ESC>"
Write-Host $tabBarEscaped

# Test switching to tab 2
Write-Host "`nSwitching to tab 2 (Tasks)..." -ForegroundColor Yellow
$container.ActivateTab(1)

Write-Host "`nAfter switching to tab 2:" -ForegroundColor Green
Write-Host "Active tab index: $($container.ActiveTabIndex)"
$activeTab = $container.GetActiveTab()
if ($activeTab -and $activeTab.Content) {
    Write-Host "Active content bounds: X=$($activeTab.Content.X), Y=$($activeTab.Content.Y), W=$($activeTab.Content.Width), H=$($activeTab.Content.Height)"
}

# Check positioning calculation
Write-Host "`nPositioning calculation:" -ForegroundColor Cyan
$gap = 2
$topGap = 2
$contentY = $container.Y + $container.TabBarHeight + $topGap
Write-Host "Container Y: $($container.Y)"
Write-Host "TabBarHeight: $($container.TabBarHeight)"
Write-Host "TopGap: $topGap"
Write-Host "Expected content Y: $contentY"

# Check for overlaps
if ($activeTab -and $activeTab.Content) {
    if ($activeTab.Content.Y -lt ($container.Y + $container.TabBarHeight)) {
        Write-Host "`nWARNING: Content overlaps with tab bar!" -ForegroundColor Red
    }
}

Write-Host "`nDone." -ForegroundColor Green