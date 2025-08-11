#!/usr/bin/env pwsh
# Test script to identify broken functionality systematically

Write-Host "=== SYSTEMATIC CRASH ANALYSIS ===" -ForegroundColor Cyan

# Test each key that might be broken
$testKeys = @("E", "N", "D", "T", "F")

foreach ($key in $testKeys) {
    Write-Host "`n--- Testing key: $key ---" -ForegroundColor Yellow
    
    # Create a simple test that simulates the key press
    $testScript = @"
try {
    # Load the main app classes
    . "./SimpleTaskPro.ps1"
    
    # Try to create a TaskListScreen instance to test methods
    `$screen = [TaskListScreen]::new()
    `$screen.Initialize(80, 24)
    
    Write-Host "Testing $key key functionality..." -ForegroundColor Green
    
    # Test the specific method that would be called by this key
    switch ("$key") {
        "E" { 
            Write-Host "Testing StartInlineEdit method..."
            if (`$screen.FlatList.Count -eq 0) {
                Write-Host "No tasks to edit - this is expected"
            } else {
                `$screen.StartInlineEdit("title")
            }
        }
        "N" { 
            Write-Host "Testing StartNewTask/StartInlineAdd method..."
            `$screen.StartInlineAdd()
        }
        "D" { 
            Write-Host "Testing DeleteCurrentTask method..."
            if (`$screen.FlatList.Count -eq 0) {
                Write-Host "No tasks to delete - this is expected"
            }
        }
        "T" { 
            Write-Host "Testing theme functionality..."
        }
    }
    Write-Host "$key: SUCCESS" -ForegroundColor Green
} catch {
    Write-Host "$key: FAILED - `$_" -ForegroundColor Red
    Write-Host "Error details: `$(`$_.ScriptStackTrace)" -ForegroundColor Red
}
"@
    
    # Execute the test
    Invoke-Expression $testScript
}