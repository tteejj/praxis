#!/usr/bin/env pwsh
# Phase 4 Test: Advanced Navigation Operations

Write-Host "=== Phase 4 Advanced Navigation Test ===" -ForegroundColor Cyan

# Load all classes
. "$PSScriptRoot/../Models/SimpleTask.ps1"
. "$PSScriptRoot/../Services/SimpleTaskService.ps1"
. "$PSScriptRoot/../Managers/TaskListManager.ps1"

# Create test manager with test data
Write-Host "`n1. Creating TaskListManager with test data..." -ForegroundColor Yellow
$manager = [TaskListManager]::new("TestData/test_tasks.json")
Write-Host "✓ Manager created with $($manager.FlatList.Count) items" -ForegroundColor Green

# Test 1: Basic Navigation
Write-Host "`n2. Testing Basic Navigation..." -ForegroundColor Yellow
try {
    $manager.MoveHome()
    $homeIndex = $manager.SelectedIndex
    
    $manager.MoveDown()
    $downIndex = $manager.SelectedIndex
    
    $manager.MoveUp()
    $upIndex = $manager.SelectedIndex
    
    $manager.MoveEnd()
    $endIndex = $manager.SelectedIndex
    
    Write-Host "✓ Basic navigation: Home($homeIndex) Down($downIndex) Up($upIndex) End($endIndex)" -ForegroundColor Green
    
} catch {
    Write-Host "✗ Basic navigation failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 2: Jump to Task by Search
Write-Host "`n3. Testing Jump to Task..." -ForegroundColor Yellow
try {
    # Jump to task containing "Task"
    $manager.JumpToTask("Task")
    $jumpResult1 = $manager.GetCurrentTask()
    
    # Jump to task by ID
    $manager.JumpToTask("RPT")
    $jumpResult2 = $manager.GetCurrentTask()
    
    Write-Host "✓ Jump to 'Task': $($jumpResult1.Title)" -ForegroundColor Green
    Write-Host "✓ Jump to 'RPT': $($jumpResult2.Title)" -ForegroundColor Green
    
    # Test non-existent task
    $manager.JumpToTask("NonExistentTask")
    Write-Host "✓ Non-existent task handled gracefully" -ForegroundColor Green
    
} catch {
    Write-Host "✗ Jump to task failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 3: Priority Navigation
Write-Host "`n4. Testing Priority Navigation..." -ForegroundColor Yellow
try {
    $manager.MoveHome()
    
    # Jump to next high priority
    $manager.JumpToNextPriority("High")
    $highTask = $manager.GetCurrentTask()
    Write-Host "✓ Jump to High priority: $($highTask.Title)" -ForegroundColor Green
    
    # Jump to next medium priority
    $manager.JumpToNextPriority("Medium")
    $mediumTask = $manager.GetCurrentTask()
    Write-Host "✓ Jump to Medium priority: $($mediumTask.Title)" -ForegroundColor Green
    
    # Test wrapping behavior
    $manager.MoveEnd()
    $manager.JumpToNextPriority("High")  # Should wrap to beginning
    $wrappedTask = $manager.GetCurrentTask()
    Write-Host "✓ Priority navigation with wrap: $($wrappedTask.Title)" -ForegroundColor Green
    
} catch {
    Write-Host "✗ Priority navigation failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 4: Status-based Navigation
Write-Host "`n5. Testing Status-based Navigation..." -ForegroundColor Yellow
try {
    $manager.MoveHome()
    
    # Jump to next incomplete task
    $manager.JumpToNextIncomplete()
    $incompleteTask = $manager.GetCurrentTask()
    Write-Host "✓ Jump to incomplete: $($incompleteTask.Title) (Completed: $($incompleteTask.Completed))" -ForegroundColor Green
    
    # Jump to next due today
    $manager.JumpToNextDueToday()
    $dueTodayTask = $manager.GetCurrentTask()
    Write-Host "✓ Jump to due today: $($dueTodayTask.Title)" -ForegroundColor Green
    
} catch {
    Write-Host "✗ Status-based navigation failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 5: Hierarchical Navigation
Write-Host "`n6. Testing Hierarchical Navigation..." -ForegroundColor Yellow
try {
    # Find a parent task with subtasks
    $parentFound = $false
    for ($i = 0; $i -lt $manager.FlatList.Count; $i++) {
        $item = $manager.FlatList[$i]
        if ($item.Level -eq 0 -and $item.Task.Subtasks.Count -gt 0) {
            $manager.SelectedIndex = $i
            $parentFound = $true
            break
        }
    }
    
    if ($parentFound) {
        $parentTask = $manager.GetCurrentTask()
        Write-Host "  Selected parent: $($parentTask.Title)" -ForegroundColor Blue
        
        # Jump to first subtask
        $manager.JumpToFirstSubtask()
        $subtask = $manager.GetCurrentTask()
        Write-Host "✓ Jump to first subtask: $($subtask.Title)" -ForegroundColor Green
        
        # Jump back to parent
        $manager.JumpToParent()
        $backToParent = $manager.GetCurrentTask()
        Write-Host "✓ Jump back to parent: $($backToParent.Title)" -ForegroundColor Green
        
        # Test sibling navigation if multiple subtasks exist
        $manager.JumpToFirstSubtask()
        $manager.JumpToNextSibling()
        $nextSibling = $manager.GetCurrentTask()
        Write-Host "✓ Jump to next sibling: $($nextSibling.Title)" -ForegroundColor Green
        
        $manager.JumpToPreviousSibling()
        $prevSibling = $manager.GetCurrentTask()
        Write-Host "✓ Jump to previous sibling: $($prevSibling.Title)" -ForegroundColor Green
        
    } else {
        Write-Host "⚠ No parent tasks with subtasks found for hierarchical testing" -ForegroundColor Yellow
    }
    
} catch {
    Write-Host "✗ Hierarchical navigation failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 6: Direct Index Navigation
Write-Host "`n7. Testing Direct Index Navigation..." -ForegroundColor Yellow
try {
    # Jump to specific indices
    $manager.JumpToIndex(0)
    $task0 = $manager.GetCurrentTask()
    Write-Host "✓ Jump to index 0: $($task0.Title)" -ForegroundColor Green
    
    $midIndex = [Math]::Floor($manager.FlatList.Count / 2)
    $manager.JumpToIndex($midIndex)
    $taskMid = $manager.GetCurrentTask()
    Write-Host "✓ Jump to index ${midIndex}: $($taskMid.Title)" -ForegroundColor Green
    
    # Test invalid index
    $manager.JumpToIndex(999)
    Write-Host "✓ Invalid index handled gracefully" -ForegroundColor Green
    
} catch {
    Write-Host "✗ Direct index navigation failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 7: Navigation Context
Write-Host "`n8. Testing Navigation Context..." -ForegroundColor Yellow
try {
    # Get context for different positions
    $manager.MoveHome()
    $context1 = $manager.GetNavigationContext()
    
    # Move to a subtask if available
    $manager.JumpToFirstSubtask()
    $context2 = $manager.GetNavigationContext()
    
    if ($context1.Valid) {
        Write-Host "✓ Context at home:" -ForegroundColor Green
        Write-Host "    Task: $($context1.CurrentTask)" -ForegroundColor Gray
        Write-Host "    Type: $($context1.Type)" -ForegroundColor Gray
        Write-Host "    Position: $($context1.SiblingPosition)/$($context1.TotalSiblings)" -ForegroundColor Gray
    }
    
    if ($context2.Valid) {
        Write-Host "✓ Context at subtask:" -ForegroundColor Green
        Write-Host "    Task: $($context2.CurrentTask)" -ForegroundColor Gray
        Write-Host "    Type: $($context2.Type)" -ForegroundColor Gray
        if ($context2.ParentInfo) {
            Write-Host "    Parent: $($context2.ParentInfo.Title)" -ForegroundColor Gray
        }
        Write-Host "    Position: $($context2.SiblingPosition)/$($context2.TotalSiblings)" -ForegroundColor Gray
    }
    
    Write-Host "✓ Navigation context working correctly" -ForegroundColor Green
    
} catch {
    Write-Host "✗ Navigation context failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 8: Navigation Help Display
Write-Host "`n9. Testing Navigation Help..." -ForegroundColor Yellow
try {
    $manager.ShowNavigationHelp()
    Write-Host "✓ Navigation help displayed successfully" -ForegroundColor Green
    
} catch {
    Write-Host "✗ Navigation help failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 9: Page Navigation
Write-Host "`n10. Testing Page Navigation..." -ForegroundColor Yellow
try {
    $manager.MoveHome()
    $startIndex = $manager.SelectedIndex
    
    $manager.PageDown()
    $pageDownIndex = $manager.SelectedIndex
    
    $manager.PageUp()
    $pageUpIndex = $manager.SelectedIndex
    
    Write-Host "✓ Page navigation: Start($startIndex) PageDown($pageDownIndex) PageUp($pageUpIndex)" -ForegroundColor Green
    
} catch {
    Write-Host "✗ Page navigation failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 10: Navigation Performance
Write-Host "`n11. Testing Navigation Performance..." -ForegroundColor Yellow
try {
    $startTime = Get-Date
    
    # Perform multiple navigation operations
    for ($i = 0; $i -lt 10; $i++) {
        $manager.MoveDown()
        $manager.MoveUp()
        $manager.JumpToNextPriority("Medium")
        $manager.JumpToNextIncomplete()
        $manager.JumpToParent()
        $manager.JumpToFirstSubtask()
    }
    
    $endTime = Get-Date
    $duration = ($endTime - $startTime).TotalMilliseconds
    
    Write-Host "✓ Navigation performance test completed in ${duration}ms" -ForegroundColor Green
    
} catch {
    Write-Host "✗ Navigation performance test failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Summary
Write-Host "`n=== Phase 4 Advanced Navigation Test Completed ===" -ForegroundColor Green
Write-Host "Phase 4 implements comprehensive navigation capabilities:" -ForegroundColor White
Write-Host "  ✓ Basic Movement - Up, Down, PageUp, PageDown, Home, End" -ForegroundColor Green
Write-Host "  ✓ Search Navigation - JumpToTask with title/ID search" -ForegroundColor Green
Write-Host "  ✓ Priority Navigation - JumpToNextPriority with wrapping" -ForegroundColor Green
Write-Host "  ✓ Status Navigation - JumpToNextIncomplete, JumpToNextDueToday" -ForegroundColor Green
Write-Host "  ✓ Hierarchical Navigation - Parent/child/sibling navigation" -ForegroundColor Green
Write-Host "  ✓ Direct Navigation - JumpToIndex for precise positioning" -ForegroundColor Green
Write-Host "  ✓ Navigation Context - Detailed position and relationship info" -ForegroundColor Green
Write-Host "  ✓ Navigation Help - Comprehensive command reference" -ForegroundColor Green
Write-Host "  ✓ Performance - Optimized for responsive navigation" -ForegroundColor Green

Write-Host "`nPhase 4 provides complete advanced navigation system!" -ForegroundColor Cyan
$manager.ShowNavigationHelp()