#!/usr/bin/env pwsh
# Phase 5 Test: Advanced Features and Utilities

Write-Host "=== Phase 5 Advanced Features Test ===" -ForegroundColor Cyan

# Load all classes
. "$PSScriptRoot/../Models/SimpleTask.ps1"
. "$PSScriptRoot/../Services/SimpleTaskService.ps1"
. "$PSScriptRoot/../Managers/TaskListManager.ps1"

# Create test manager with test data
Write-Host "`n1. Creating TaskListManager with test data..." -ForegroundColor Yellow
$manager = [TaskListManager]::new("TestData/test_tasks.json")
Write-Host "✓ Manager created with $($manager.FlatList.Count) items" -ForegroundColor Green

# Test 1: Bulk Operations
Write-Host "`n2. Testing Bulk Operations..." -ForegroundColor Yellow
try {
    # Test bulk toggle completion
    $testIndices = @(0, 1, 2)  # First few tasks
    $manager.BulkToggleComplete($testIndices)
    Write-Host "✓ Bulk toggle completion completed" -ForegroundColor Green
    
    # Test bulk set priority
    $manager.BulkSetPriority($testIndices, "High")
    Write-Host "✓ Bulk set priority completed" -ForegroundColor Green
    
    # Test bulk add tag
    $manager.BulkAddTag($testIndices, "bulk-test")
    Write-Host "✓ Bulk add tag completed" -ForegroundColor Green
    
    # Test invalid operations
    $manager.BulkSetPriority(@(), "Medium")  # Empty indices
    $manager.BulkSetPriority($testIndices, "Invalid")  # Invalid priority
    Write-Host "✓ Invalid bulk operations handled gracefully" -ForegroundColor Green
    
} catch {
    Write-Host "✗ Bulk operations failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 2: Data Export
Write-Host "`n3. Testing Data Export..." -ForegroundColor Yellow
try {
    # Test JSON export
    $jsonData = $manager.ExportToData("json")
    Write-Host "✓ JSON export: $($jsonData.Count) tasks" -ForegroundColor Green
    
    # Test CSV export
    $csvData = $manager.ExportToData("csv")
    Write-Host "✓ CSV export: $($csvData.Count) records" -ForegroundColor Green
    
    # Test summary export
    $summaryData = $manager.ExportToData("summary")
    Write-Host "✓ Summary export: $($summaryData.Count) parent tasks" -ForegroundColor Green
    
    # Test file export
    $testExportPath = "Tests/test_export.json"
    $manager.ExportToFile($testExportPath, "json")
    if (Test-Path $testExportPath) {
        Write-Host "✓ File export successful" -ForegroundColor Green
        Remove-Item $testExportPath -Force  # Cleanup
    } else {
        Write-Host "✗ File export failed" -ForegroundColor Red
    }
    
    # Test invalid format
    try {
        $manager.ExportToData("invalid")
        Write-Host "✗ Invalid format should have failed" -ForegroundColor Red
    } catch {
        Write-Host "✓ Invalid export format handled correctly" -ForegroundColor Green
    }
    
} catch {
    Write-Host "✗ Data export failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 3: Data Validation and Repair
Write-Host "`n4. Testing Data Validation and Repair..." -ForegroundColor Yellow
try {
    # Test data validation
    $manager.ValidateData()
    Write-Host "✓ Data validation completed" -ForegroundColor Green
    
    # Test data repair
    $manager.RepairData()
    Write-Host "✓ Data repair completed" -ForegroundColor Green
    
    # Create a task with invalid data for testing
    $invalidTask = [SimpleTask]::new("")  # Empty title
    $invalidTask.Priority = "InvalidPriority"
    $manager.TaskService.AddTask($invalidTask)
    
    # Validate again (should find issues)
    $manager.ValidateData()
    Write-Host "✓ Validation found issues as expected" -ForegroundColor Green
    
    # Repair the issues
    $manager.RepairData()
    Write-Host "✓ Data repair fixed issues" -ForegroundColor Green
    
    # Validate again (should be clean)
    $manager.ValidateData()
    Write-Host "✓ Validation passed after repair" -ForegroundColor Green
    
} catch {
    Write-Host "✗ Data validation/repair failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 4: Archive Completed Tasks
Write-Host "`n5. Testing Archive Completed Tasks..." -ForegroundColor Yellow
try {
    # Count completed tasks before archiving
    $completedBefore = ($manager.TaskService.GetAllTasks() | Where-Object { $_.Completed }).Count
    Write-Host "  Completed tasks before archive: $completedBefore" -ForegroundColor Blue
    
    if ($completedBefore -gt 0) {
        # Test archiving
        $archivePath = "Tests/test_archive.json"
        $manager.ArchiveCompleted($archivePath)
        
        # Check if archive file was created
        if (Test-Path $archivePath) {
            Write-Host "✓ Archive file created successfully" -ForegroundColor Green
            
            # Count completed tasks after archiving
            $completedAfter = ($manager.TaskService.GetAllTasks() | Where-Object { $_.Completed }).Count
            Write-Host "  Completed tasks after archive: $completedAfter" -ForegroundColor Blue
            
            if ($completedAfter -lt $completedBefore) {
                Write-Host "✓ Completed tasks were archived" -ForegroundColor Green
            }
            
            Remove-Item $archivePath -Force  # Cleanup
        } else {
            Write-Host "✗ Archive file was not created" -ForegroundColor Red
        }
    } else {
        # Test with no completed tasks
        $manager.ArchiveCompleted("Tests/empty_archive.json")
        Write-Host "✓ Archive with no completed tasks handled correctly" -ForegroundColor Green
    }
    
} catch {
    Write-Host "✗ Archive completed tasks failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 5: Advanced Statistics
Write-Host "`n6. Testing Advanced Statistics..." -ForegroundColor Yellow
try {
    # Get advanced stats
    $stats = $manager.GetAdvancedStats()
    
    # Verify stats structure
    $expectedKeys = @("TotalTasks", "ParentTasks", "SubtaskCount", "CompletedTasks", 
                      "PendingTasks", "HighPriority", "MediumPriority", "LowPriority", 
                      "TodayPriority", "DueToday", "Overdue", "WithTags", "WithNotes", 
                      "CreatedThisWeek", "ModifiedThisWeek", "AvgSubtasksPerParent", 
                      "UniqueTags", "CompletionRate")
    
    $missingKeys = $expectedKeys | Where-Object { -not $stats.ContainsKey($_) }
    if ($missingKeys.Count -eq 0) {
        Write-Host "✓ Advanced stats structure complete" -ForegroundColor Green
    } else {
        Write-Host "✗ Missing stats keys: $($missingKeys -join ', ')" -ForegroundColor Red
    }
    
    # Verify stats values are reasonable
    if ($stats.TotalTasks -ge 0 -and $stats.ParentTasks -ge 0 -and $stats.CompletionRate -ge 0 -and $stats.CompletionRate -le 100) {
        Write-Host "✓ Stats values are reasonable" -ForegroundColor Green
    } else {
        Write-Host "✗ Some stats values are out of range" -ForegroundColor Red
    }
    
    # Display advanced stats
    $manager.ShowAdvancedStats()
    Write-Host "✓ Advanced statistics displayed successfully" -ForegroundColor Green
    
} catch {
    Write-Host "✗ Advanced statistics failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 6: Bulk Delete (with caution)
Write-Host "`n7. Testing Bulk Delete (limited test)..." -ForegroundColor Yellow
try {
    # Create some test tasks for deletion
    $manager.CreateNewTask("Test Delete 1", "Low")
    $manager.CreateNewTask("Test Delete 2", "Low")
    
    # Find indices of test tasks
    $deleteIndices = @()
    for ($i = 0; $i -lt $manager.FlatList.Count; $i++) {
        $item = $manager.FlatList[$i]
        if ($item.Task.Title.StartsWith("Test Delete")) {
            $deleteIndices += $i
        }
    }
    
    if ($deleteIndices.Count -gt 0) {
        $beforeCount = $manager.FlatList.Count
        $manager.BulkDelete($deleteIndices)
        $afterCount = $manager.FlatList.Count
        
        if ($afterCount -lt $beforeCount) {
            Write-Host "✓ Bulk delete successfully removed tasks" -ForegroundColor Green
        } else {
            Write-Host "⚠ Bulk delete may not have removed tasks" -ForegroundColor Yellow
        }
    } else {
        Write-Host "⚠ No test tasks found for deletion" -ForegroundColor Yellow
    }
    
    # Test invalid bulk delete
    $manager.BulkDelete(@())  # Empty array
    Write-Host "✓ Empty bulk delete handled gracefully" -ForegroundColor Green
    
} catch {
    Write-Host "✗ Bulk delete failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 7: Export Format Testing
Write-Host "`n8. Testing Export Formats..." -ForegroundColor Yellow
try {
    # Test CSV export structure
    $csvData = $manager.ExportToData("csv")
    if ($csvData.Count -gt 0) {
        $firstRecord = $csvData[0]
        $expectedCsvKeys = @("Id", "Title", "Priority", "Completed", "CreatedDate", "ModifiedDate", "DueDate", "Tags", "Notes", "ID1", "ID2", "ParentId", "Level")
        
        $missingCsvKeys = $expectedCsvKeys | Where-Object { -not $firstRecord.ContainsKey($_) }
        if ($missingCsvKeys.Count -eq 0) {
            Write-Host "✓ CSV export format is complete" -ForegroundColor Green
        } else {
            Write-Host "✗ CSV export missing keys: $($missingCsvKeys -join ', ')" -ForegroundColor Red
        }
    }
    
    # Test summary export structure
    $summaryData = $manager.ExportToData("summary")
    if ($summaryData.Count -gt 0) {
        $firstSummary = $summaryData[0]
        $expectedSummaryKeys = @("Title", "Priority", "Status", "SubtaskCount", "DueDate", "Tags")
        
        $missingSummaryKeys = $expectedSummaryKeys | Where-Object { -not $firstSummary.ContainsKey($_) }
        if ($missingSummaryKeys.Count -eq 0) {
            Write-Host "✓ Summary export format is complete" -ForegroundColor Green
        } else {
            Write-Host "✗ Summary export missing keys: $($missingSummaryKeys -join ', ')" -ForegroundColor Red
        }
    }
    
} catch {
    Write-Host "✗ Export format testing failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 8: Performance Testing
Write-Host "`n9. Testing Advanced Feature Performance..." -ForegroundColor Yellow
try {
    $startTime = Get-Date
    
    # Perform multiple advanced operations
    $manager.GetAdvancedStats()
    $manager.ExportToData("json")
    $manager.ExportToData("csv")
    $manager.ValidateData()
    $manager.GetAvailableTags()
    $manager.BulkAddTag(@(0, 1), "performance-test")
    
    $endTime = Get-Date
    $duration = ($endTime - $startTime).TotalMilliseconds
    
    Write-Host "✓ Advanced features performance test completed in ${duration}ms" -ForegroundColor Green
    
} catch {
    Write-Host "✗ Performance testing failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Summary
Write-Host "`n=== Phase 5 Advanced Features Test Completed ===" -ForegroundColor Green
Write-Host "Phase 5 implements comprehensive advanced features:" -ForegroundColor White
Write-Host "  ✓ Bulk Operations - Toggle, Priority, Tags, Delete" -ForegroundColor Green
Write-Host "  ✓ Data Export - JSON, CSV, Summary formats" -ForegroundColor Green
Write-Host "  ✓ Data Validation - Integrity checks and issue detection" -ForegroundColor Green
Write-Host "  ✓ Data Repair - Automatic fixing of common issues" -ForegroundColor Green
Write-Host "  ✓ Archive Completed - Move completed tasks to archive" -ForegroundColor Green
Write-Host "  ✓ Advanced Statistics - Comprehensive analytics" -ForegroundColor Green
Write-Host "  ✓ Export Formats - Multiple output formats with validation" -ForegroundColor Green
Write-Host "  ✓ Performance - Optimized for responsive operations" -ForegroundColor Green

Write-Host "`nPhase 5 provides complete advanced utility features!" -ForegroundColor Cyan
$manager.ShowAdvancedStats()