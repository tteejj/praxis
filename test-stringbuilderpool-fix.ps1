#!/usr/bin/env pwsh
# test-stringbuilderpool-fix.ps1 - Test StringBuilderPool usage in fixed components

. ./Start.ps1 -NoGUI

Write-Host "Testing StringBuilderPool usage in fixed components..." -ForegroundColor Cyan

# Create service container
$container = [ServiceContainer]::new()
$themeManager = [ThemeManager]::new()
$container.RegisterService("ThemeManager", $themeManager)

# Test TreeView
Write-Host "`nTesting TreeView..." -ForegroundColor Yellow
$treeView = [TreeView]::new()
$treeView.X = 1
$treeView.Y = 1
$treeView.Width = 50
$treeView.Height = 10
$treeView.Initialize($container)

$root = $treeView.AddRootNode("Root Node")
$child1 = [TreeNode]::new("Child 1")
$child2 = [TreeNode]::new("Child 2")
$root.AddChild($child1)
$root.AddChild($child2)
$grandchild = [TreeNode]::new("Grandchild")
$child1.AddChild($grandchild)

$render = $treeView.OnRender()
Write-Host "TreeView rendered successfully. Length: $($render.Length)" -ForegroundColor Green

# Test MultiSelectListBox
Write-Host "`nTesting MultiSelectListBox..." -ForegroundColor Yellow
$multiSelect = [MultiSelectListBox]::new()
$multiSelect.X = 1
$multiSelect.Y = 1
$multiSelect.Width = 40
$multiSelect.Height = 10
$multiSelect.Initialize($container)
$multiSelect.SetItems(@("Item 1", "Item 2", "Item 3", "Item 4", "Item 5"))
$multiSelect.SetSelected(1, $true)
$multiSelect.SetSelected(3, $true)

$render = $multiSelect.OnRender()
Write-Host "MultiSelectListBox rendered successfully. Length: $($render.Length)" -ForegroundColor Green

# Test SearchableListBox
Write-Host "`nTesting SearchableListBox..." -ForegroundColor Yellow
$searchable = [SearchableListBox]::new()
$searchable.X = 1
$searchable.Y = 1
$searchable.Width = 40
$searchable.Height = 10
$searchable.Initialize($container)
$searchable.SetItems(@("Apple", "Banana", "Cherry", "Date", "Elderberry"))
$searchable.SetSearchQuery("err")

$render = $searchable.OnRender()
Write-Host "SearchableListBox rendered successfully. Length: $($render.Length)" -ForegroundColor Green
Write-Host "Filtered items count: $($searchable._filteredItems.Count)" -ForegroundColor Green

# Test ProgressBar
Write-Host "`nTesting ProgressBar..." -ForegroundColor Yellow
$progress = [ProgressBar]::new()
$progress.X = 1
$progress.Y = 1
$progress.Width = 40
$progress.Height = 5
$progress.Initialize($container)
$progress.SetProgress(75, "Processing files...")

$render = $progress.OnRender()
Write-Host "ProgressBar rendered successfully. Length: $($render.Length)" -ForegroundColor Green

# Show StringBuilderPool stats
Write-Host "`nStringBuilderPool Statistics:" -ForegroundColor Cyan
$stats = Get-StringBuilderPoolStats
$stats.GetEnumerator() | ForEach-Object {
    Write-Host "$($_.Key): $($_.Value)" -ForegroundColor Gray
}

Write-Host "`nAll components tested successfully!" -ForegroundColor Green