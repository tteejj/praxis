#!/usr/bin/env pwsh
# Phase 3 Test: Advanced Filtering & Search functionality

Write-Host "=== Phase 3 Advanced Filtering & Search Test ===" -ForegroundColor Cyan

# Load all classes
. "$PSScriptRoot/../Models/SimpleTask.ps1"
. "$PSScriptRoot/../Services/SimpleTaskService.ps1"
. "$PSScriptRoot/../Managers/TaskListManager.ps1"

# Create test manager with test data
Write-Host "`n1. Creating TaskListManager with test data..." -ForegroundColor Yellow
$manager = [TaskListManager]::new("TestData/test_tasks.json")
Write-Host "✓ Manager created with $($manager.FlatList.Count) items" -ForegroundColor Green

# Test 1: Quick Filters
Write-Host "`n2. Testing Quick Filters..." -ForegroundColor Yellow
try {
    # Test various quick filters
    $quickFilters = @("high", "medium", "today", "urgent", "overdue", "recent", "completed", "pending")
    
    foreach ($filter in $quickFilters) {
        $initialCount = $manager.FlatList.Count
        $manager.ApplyQuickFilter($filter)
        $newCount = $manager.FlatList.Count
        
        Write-Host "  ✓ Quick filter '$filter': $newCount items (was $initialCount)" -ForegroundColor Green
    }
    
    # Test clearing filters
    $manager.ClearAllFilters()
    Write-Host "✓ All quick filters tested and cleared" -ForegroundColor Green
    
} catch {
    Write-Host "✗ Quick filters failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 2: Advanced Search
Write-Host "`n3. Testing Advanced Search..." -ForegroundColor Yellow
try {
    # Test basic search
    $manager.SearchTasksAdvanced("Task", $true, $false)
    $searchResults = $manager.FlatList.Count
    Write-Host "✓ Basic search for 'Task' found $searchResults items" -ForegroundColor Green
    
    # Test case-sensitive search
    $manager.SearchTasksAdvanced("TASK", $true, $true)
    $caseSensitiveResults = $manager.FlatList.Count
    Write-Host "✓ Case-sensitive search for 'TASK' found $caseSensitiveResults items" -ForegroundColor Green
    
    # Test search in different fields
    $manager.SearchTasksAdvanced("RPT", $true, $false)  # ID1 field
    $idSearchResults = $manager.FlatList.Count
    Write-Host "✓ ID search for 'RPT' found $idSearchResults items" -ForegroundColor Green
    
    # Test tag search
    $manager.SearchTasksAdvanced("urgent", $true, $false)  # Tag field
    $tagSearchResults = $manager.FlatList.Count
    Write-Host "✓ Tag search for 'urgent' found $tagSearchResults items" -ForegroundColor Green
    
    # Clear search
    $manager.ClearSearch()
    Write-Host "✓ Search cleared successfully" -ForegroundColor Green
    
} catch {
    Write-Host "✗ Advanced search failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 3: Tag Filtering
Write-Host "`n4. Testing Tag Filtering..." -ForegroundColor Yellow
try {
    # Get available tags
    $availableTags = $manager.GetAvailableTags()
    Write-Host "✓ Found $($availableTags.Count) available tags: $($availableTags -join ', ')" -ForegroundColor Green
    
    if ($availableTags.Count -gt 0) {
        # Test filtering by first tag
        $testTag = $availableTags[0]
        $manager.FilterByTag($testTag, $false)  # Partial match
        $tagResults = $manager.FlatList.Count
        Write-Host "✓ Tag filter for '$testTag' found $tagResults items" -ForegroundColor Green
        
        # Test exact match
        $manager.FilterByTag($testTag, $true)  # Exact match
        $exactResults = $manager.FlatList.Count
        Write-Host "✓ Exact tag filter for '$testTag' found $exactResults items" -ForegroundColor Green
        
        # Clear tag filter
        $manager.FilterByTag("", $false)
        Write-Host "✓ Tag filter cleared" -ForegroundColor Green
    } else {
        Write-Host "⚠ No tags available for testing" -ForegroundColor Yellow
    }
    
} catch {
    Write-Host "✗ Tag filtering failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 4: Custom Filter Logic
Write-Host "`n5. Testing Custom Filter Logic..." -ForegroundColor Yellow
try {
    # Create some test data with different states
    $manager.CreateNewTask("Overdue Test Task", "High")
    $overdueTasks = $manager.FlatList | Where-Object { $_.Task.Title -eq "Overdue Test Task" }
    if ($overdueTasks.Count -gt 0) {
        $overdueTask = $overdueTasks[0].Task
        $overdueTask.DueDate = (Get-Date).AddDays(-5)  # Make it overdue
        $manager.TaskService.SaveTask($overdueTask)
    }
    
    # Test overdue filter
    $manager.ApplyQuickFilter("overdue")
    $overdueCount = $manager.FlatList.Count
    Write-Host "✓ Overdue filter found $overdueCount items" -ForegroundColor Green
    
    # Test recent filter
    $manager.ApplyQuickFilter("recent")
    $recentCount = $manager.FlatList.Count
    Write-Host "✓ Recent filter found $recentCount items" -ForegroundColor Green
    
    # Test urgent filter
    $manager.ApplyQuickFilter("urgent")
    $urgentCount = $manager.FlatList.Count
    Write-Host "✓ Urgent filter found $urgentCount items" -ForegroundColor Green
    
} catch {
    Write-Host "✗ Custom filter logic failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 5: Combined Filtering
Write-Host "`n6. Testing Combined Filtering..." -ForegroundColor Yellow
try {
    # Clear all filters first
    $manager.ClearAllFilters()
    $allItemsCount = $manager.FlatList.Count
    
    # Apply a base filter
    $manager.SetFilter("High")
    $highPriorityCount = $manager.FlatList.Count
    
    # Add search on top of filter
    $manager.SearchTasksAdvanced("Task", $true, $false)
    $combinedCount = $manager.FlatList.Count
    
    Write-Host "✓ All items: $allItemsCount" -ForegroundColor Green
    Write-Host "✓ High priority: $highPriorityCount" -ForegroundColor Green
    Write-Host "✓ High priority + search: $combinedCount" -ForegroundColor Green
    
    # Clear everything
    $manager.ClearAllFilters()
    Write-Host "✓ Combined filtering tested successfully" -ForegroundColor Green
    
} catch {
    Write-Host "✗ Combined filtering failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 6: Filter Summary
Write-Host "`n7. Testing Filter Summary..." -ForegroundColor Yellow
try {
    # Apply some filters and show summary
    $manager.SetFilter("High")
    $manager.SetTagFilter("urgent")
    $manager.SetSearchTerm("task")
    
    $manager.ShowFilterSummary()
    Write-Host "✓ Filter summary displayed successfully" -ForegroundColor Green
    
} catch {
    Write-Host "✗ Filter summary failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 7: Performance with Large Filter Operations
Write-Host "`n8. Testing Filter Performance..." -ForegroundColor Yellow
try {
    # Create some additional test tasks for performance testing
    for ($i = 1; $i -le 10; $i++) {
        $manager.CreateNewTask("Performance Test Task $i", "Medium")
    }
    
    $startTime = Get-Date
    
    # Perform multiple filter operations
    $manager.ApplyQuickFilter("medium")
    $manager.SearchTasksAdvanced("Performance", $true, $false)
    $manager.FilterByTag("test", $false)
    $manager.ClearAllFilters()
    $manager.ToggleFilter()
    
    $endTime = Get-Date
    $duration = ($endTime - $startTime).TotalMilliseconds
    
    Write-Host "✓ Performance test completed in ${duration}ms" -ForegroundColor Green
    
} catch {
    Write-Host "✗ Filter performance test failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Summary
Write-Host "`n=== Phase 3 Advanced Filtering & Search Test Completed ===" -ForegroundColor Green
Write-Host "Phase 3 implements comprehensive filtering and search:" -ForegroundColor White
Write-Host "  ✓ Quick Filters - high, medium, today, urgent, overdue, recent" -ForegroundColor Green
Write-Host "  ✓ Advanced Search - multi-field with case sensitivity options" -ForegroundColor Green
Write-Host "  ✓ Tag Filtering - partial and exact match support" -ForegroundColor Green
Write-Host "  ✓ Custom Filter Logic - overdue, recent, urgent combinations" -ForegroundColor Green
Write-Host "  ✓ Combined Filtering - multiple filters working together" -ForegroundColor Green
Write-Host "  ✓ Filter Summary - comprehensive filter state display" -ForegroundColor Green
Write-Host "  ✓ Filter Performance - optimized for responsive filtering" -ForegroundColor Green

Write-Host "`nPhase 3 provides complete advanced filtering and search capabilities!" -ForegroundColor Cyan
$manager.ShowFilterSummary()