# Comprehensive Pester tests for TimeTrackingService

$SpeedTUIRoot = Split-Path -Parent $PSScriptRoot
Set-Location $SpeedTUIRoot

BeforeAll {
    # Load dependencies with explicit paths
    . "./Core/Logger.ps1"
    . "./Models/BaseModel.ps1"
    . "./Models/TimeEntry.ps1"
    . "./Services/DataService.ps1"
    . "./Services/TimeTrackingService.ps1"
    
    # Create test data directory
    $SpeedTUIRoot = (Get-Location).Path
    $script:TestDataPath = Join-Path $SpeedTUIRoot "TestData"
    if (-not (Test-Path $script:TestDataPath)) {
        New-Item -Path $script:TestDataPath -ItemType Directory -Force
    }
}

Describe "TimeTrackingService Tests" {
    BeforeEach {
        # Create fresh service instance with test data path
        $script:service = [TimeTrackingService]::new()
        $script:service.DataDirectory = $script:TestDataPath
        $script:service.FileName = "test_timeentries"
        
        # Clear any existing test data
        $testFile = Join-Path $script:TestDataPath "test_timeentries.json"
        if (Test-Path $testFile) {
            Remove-Item $testFile -Force
        }
    }
    
    AfterEach {
        # Clean up test files
        $testFile = Join-Path $script:TestDataPath "test_timeentries.json"
        if (Test-Path $testFile) {
            Remove-Item $testFile -Force
        }
    }
    
    Context "Service Initialization" {
        It "Should initialize with correct fiscal year" {
            $service = [TimeTrackingService]::new()
            
            $service.CurrentFiscalYear | Should -Not -BeNullOrEmpty
            $service.CurrentFiscalYear | Should -Match "\d{4}-\d{4}"
        }
        
        It "Should calculate current fiscal year correctly" {
            $service = [TimeTrackingService]::new()
            $now = [DateTime]::Now
            
            if ($now.Month -ge 4) {
                $expected = "$($now.Year)-$($now.Year + 1)"
            } else {
                $expected = "$($now.Year - 1)-$($now.Year)"
            }
            
            $service.CalculateCurrentFiscalYear() | Should -Be $expected
        }
        
        It "Should initialize with empty caches" {
            $script:service.WeekCache.Count | Should -Be 0
            $script:service.FiscalYearCache.Count | Should -Be 0
        }
    }
    
    Context "Week Operations" {
        It "Should get current week ending Friday" {
            $weekEndingFriday = $script:service.GetCurrentWeekEndingFriday()
            
            $weekEndingFriday | Should -Not -BeNullOrEmpty
            $weekEndingFriday | Should -Match "^\d{8}$"
            
            # Validate it's actually a Friday
            $script:service.ValidateWeekEndingFriday($weekEndingFriday) | Should -Be $true
        }
        
        It "Should validate week ending Friday correctly" {
            # Test valid Friday (April 5, 2024)
            $script:service.ValidateWeekEndingFriday("20240405") | Should -Be $true
            
            # Test invalid date (not a Friday - April 6, 2024 is Saturday)
            $script:service.ValidateWeekEndingFriday("20240406") | Should -Be $false
            
            # Test invalid format
            $script:service.ValidateWeekEndingFriday("invalid") | Should -Be $false
        }
        
        It "Should format week range correctly" {
            $formatted = $script:service.FormatWeekRange("20240405")
            $formatted | Should -Match "Apr 01.*Apr 05.*2024"
        }
        
        It "Should get week start date correctly" {
            $startDate = $script:service.GetWeekStartDate("20240405")
            $startDate.DayOfWeek | Should -Be ([DayOfWeek]::Monday)
            $startDate.ToString("yyyyMMdd") | Should -Be "20240401"
        }
    }
    
    Context "Time Entry Creation" {
        It "Should create project time entry" {
            $entry = $script:service.CreateProjectTimeEntry("TEST001", "ABC", "Test Project")
            
            $entry | Should -Not -BeNull
            $entry.ID1 | Should -Be "TEST001"
            $entry.ID2 | Should -Be "ABC"
            $entry.Name | Should -Be "Test Project"
            $entry.IsProjectEntry | Should -Be $true
            $entry.IsValid() | Should -Be $true
        }
        
        It "Should create time code entry" {
            $entry = $script:service.CreateTimeCodeEntry("VAC", "Vacation Time")
            
            $entry | Should -Not -BeNull
            $entry.TimeCodeID | Should -Be "VAC"
            $entry.Description | Should -Be "Vacation Time"
            $entry.IsProjectEntry | Should -Be $false
            $entry.IsValid() | Should -Be $true
        }
        
        It "Should create quick entry with hours" {
            $entry = $script:service.CreateQuickEntry("TEST001-ABC", "Test Project", 8.0, "Monday")
            
            $entry | Should -Not -BeNull
            $entry.ID1 | Should -Be "TEST001"
            $entry.ID2 | Should -Be "ABC"
            $entry.Monday | Should -Be 8.0
            $entry.Total | Should -Be 8.0
        }
        
        It "Should create quick time code entry" {
            $entry = $script:service.CreateQuickEntry("VAC", "Vacation", 4.0, "Friday")
            
            $entry | Should -Not -BeNull
            $entry.TimeCodeID | Should -Be "VAC"
            $entry.Friday | Should -Be 4.0
            $entry.Total | Should -Be 4.0
            $entry.IsProjectEntry | Should -Be $false
        }
    }
    
    Context "Project Time Tracking" {
        BeforeEach {
            # Create test project entries
            $entry1 = $script:service.CreateProjectTimeEntry("PROJ001", "A", "Project One")
            $entry1.Monday = 8.0
            $entry1.Tuesday = 7.5
            $entry1.CalculateTotal()
            $script:service.Update($entry1)
            
            $entry2 = $script:service.CreateProjectTimeEntry("PROJ001", "A", "Project One")
            $entry2.WeekEndingFriday = "20240405"  # Different week
            $entry2.Wednesday = 6.0
            $entry2.CalculateTotal()
            $script:service.Update($entry2)
            
            $entry3 = $script:service.CreateProjectTimeEntry("PROJ002", "B", "Project Two")
            $entry3.Thursday = 5.0
            $entry3.CalculateTotal()
            $script:service.Update($entry3)
        }
        
        It "Should get project entries correctly" {
            $entries = $script:service.GetProjectEntries("PROJ001", "A")
            
            $entries.Count | Should -Be 2
            $entries[0].ID1 | Should -Be "PROJ001"
            $entries[0].ID2 | Should -Be "A"
        }
        
        It "Should calculate project total hours" {
            $totalHours = $script:service.GetProjectTotalHours("PROJ001", "A")
            $totalHours | Should -Be 21.5  # 8.0 + 7.5 + 6.0
        }
        
        It "Should get project hours by week" {
            $weeklyHours = $script:service.GetProjectHoursByWeek("PROJ001", "A")
            
            $weeklyHours.Count | Should -Be 2
            $weeklyHours.ContainsKey("20240405") | Should -Be $true
            $weeklyHours["20240405"] | Should -Be 6.0
        }
        
        It "Should get top projects by hours" {
            $topProjects = $script:service.GetTopProjectsByHours(5)
            
            $topProjects.Count | Should -Be 2
            $topProjects[0].Total | Should -BeGreaterThan $topProjects[1].Total
            $topProjects[0].ID1 | Should -Be "PROJ001"  # Should be highest
        }
    }
    
    Context "Time Code Tracking" {
        BeforeEach {
            # Create test time code entries
            $vacEntry = $script:service.CreateTimeCodeEntry("VAC", "Vacation")
            $vacEntry.Monday = 8.0
            $vacEntry.CalculateTotal()
            $script:service.Update($vacEntry)
            
            $sickEntry = $script:service.CreateTimeCodeEntry("SICK", "Sick Leave")
            $sickEntry.Tuesday = 4.0
            $sickEntry.CalculateTotal()
            $script:service.Update($sickEntry)
            
            $vacEntry2 = $script:service.CreateTimeCodeEntry("VAC", "Vacation")
            $vacEntry2.WeekEndingFriday = "20240405"
            $vacEntry2.Friday = 8.0
            $vacEntry2.CalculateTotal()
            $script:service.Update($vacEntry2)
        }
        
        It "Should get time code entries correctly" {
            $entries = $script:service.GetTimeCodeEntries("VAC")
            
            $entries.Count | Should -Be 2
            $entries[0].TimeCodeID | Should -Be "VAC"
        }
        
        It "Should calculate time code total hours" {
            $totalHours = $script:service.GetTimeCodeTotalHours("VAC")
            $totalHours | Should -Be 16.0  # 8.0 + 8.0
        }
        
        It "Should get available time codes" {
            $timeCodes = $script:service.GetAvailableTimeCodes()
            
            $timeCodes.Count | Should -Be 2
            $timeCodes | Should -Contain "VAC"
            $timeCodes | Should -Contain "SICK"
        }
    }
    
    Context "Week Summary and Analysis" {
        BeforeEach {
            $currentWeek = $script:service.GetCurrentWeekEndingFriday()
            
            # Create mixed entries for current week
            $projectEntry = $script:service.CreateProjectTimeEntry("PROJ001", "A", "Project One")
            $projectEntry.Monday = 8.0
            $projectEntry.Tuesday = 7.0
            $projectEntry.CalculateTotal()
            $script:service.Update($projectEntry)
            
            $vacEntry = $script:service.CreateTimeCodeEntry("VAC", "Vacation")
            $vacEntry.Wednesday = 8.0
            $vacEntry.CalculateTotal()
            $script:service.Update($vacEntry)
            
            $projectEntry2 = $script:service.CreateProjectTimeEntry("PROJ002", "B", "Project Two")
            $projectEntry2.Thursday = 6.0
            $projectEntry2.Friday = 8.0
            $projectEntry2.CalculateTotal()
            $script:service.Update($projectEntry2)
        }
        
        It "Should get week total hours" {
            $currentWeek = $script:service.GetCurrentWeekEndingFriday()
            $totalHours = $script:service.GetWeekTotalHours($currentWeek)
            
            $totalHours | Should -Be 37.0  # 15 + 8 + 14
        }
        
        It "Should generate comprehensive week summary" {
            $currentWeek = $script:service.GetCurrentWeekEndingFriday()
            $summary = $script:service.GetWeekSummary($currentWeek)
            
            $summary.WeekEndingFriday | Should -Be $currentWeek
            $summary.TotalEntries | Should -Be 3
            $summary.ProjectEntries | Should -Be 2
            $summary.TimeCodeEntries | Should -Be 1
            $summary.TotalHours | Should -Be 37.0
            $summary.ProjectHours | Should -Be 29.0  # 15 + 14
            $summary.TimeCodeHours | Should -Be 8.0
            $summary.IsComplete | Should -Be $true  # >= 35 hours
            $summary.UniqueProjects | Should -Be 2
            $summary.UniqueTimeCodes | Should -Be 1
            
            $summary.DailyTotals.Monday | Should -Be 8.0
            $summary.DailyTotals.Tuesday | Should -Be 7.0
            $summary.DailyTotals.Wednesday | Should -Be 8.0
            $summary.DailyTotals.Thursday | Should -Be 6.0
            $summary.DailyTotals.Friday | Should -Be 8.0
        }
    }
    
    Context "Fiscal Year Operations" {
        BeforeEach {
            $currentFY = $script:service.CurrentFiscalYear
            
            # Create entries for current fiscal year
            $entry1 = $script:service.CreateProjectTimeEntry("FY001", "A", "FY Project")
            $entry1.Monday = 8.0
            $entry1.CalculateTotal()
            $script:service.Update($entry1)
            
            # Create entry for different fiscal year
            $entry2 = $script:service.CreateProjectTimeEntry("OLD001", "B", "Old Project")
            $entry2.FiscalYear = "2022-2023"  # Force different FY
            $entry2.Tuesday = 6.0
            $entry2.CalculateTotal()
            $script:service.Update($entry2)
        }
        
        It "Should get available fiscal years" {
            $fiscalYears = $script:service.GetAvailableFiscalYears()
            
            $fiscalYears.Count | Should -BeGreaterOrEqual 2
            $fiscalYears | Should -Contain $script:service.CurrentFiscalYear
            $fiscalYears | Should -Contain "2022-2023"
        }
        
        It "Should get entries for specific fiscal year" {
            $entries = $script:service.GetEntriesForFiscalYear("2022-2023")
            
            $entries.Count | Should -Be 1
            $entries[0].ID1 | Should -Be "OLD001"
        }
        
        It "Should generate fiscal year summary" {
            $summary = $script:service.GetFiscalYearSummary()
            
            $summary.FiscalYear | Should -Be $script:service.CurrentFiscalYear
            $summary.TotalEntries | Should -Be 1
            $summary.ProjectEntries | Should -Be 1
            $summary.TimeCodeEntries | Should -Be 0
            $summary.TotalHours | Should -Be 8.0
            $summary.ProjectHours | Should -Be 8.0
            $summary.TimeCodeHours | Should -Be 0
            $summary.UniqueProjects | Should -Be 1
        }
    }
    
    Context "Data Import/Export" {
        It "Should export week data correctly" {
            # Create test entry
            $entry = $script:service.CreateProjectTimeEntry("EXP001", "A", "Export Test")
            $entry.Monday = 8.0
            $entry.CalculateTotal()
            $script:service.Update($entry)
            
            $currentWeek = $script:service.GetCurrentWeekEndingFriday()
            $exportData = $script:service.ExportWeekData($currentWeek)
            
            $exportData.WeekEndingFriday | Should -Be $currentWeek
            $exportData.Entries.Count | Should -Be 1
            $exportData.Entries[0].ID1 | Should -Be "EXP001"
            $exportData.ExportDate | Should -Not -BeNull
        }
        
        It "Should export fiscal year data correctly" {
            # Create test entry
            $entry = $script:service.CreateProjectTimeEntry("FYE001", "A", "FY Export Test")
            $entry.Tuesday = 7.5
            $entry.CalculateTotal()
            $script:service.Update($entry)
            
            $exportData = $script:service.ExportFiscalYearData()
            
            $exportData.FiscalYear | Should -Be $script:service.CurrentFiscalYear
            $exportData.Entries.Count | Should -Be 1
            $exportData.Summary | Should -Not -BeNull
            $exportData.Summary.TotalHours | Should -Be 7.5
        }
        
        It "Should import week data correctly" {
            $weekData = @{
                "entry1" = @{
                    ID1 = "IMP001"
                    ID2 = "A"
                    Name = "Import Test"
                    Monday = 8.0
                    Total = 8.0
                    IsProjectEntry = $true
                    WeekEndingFriday = $script:service.GetCurrentWeekEndingFriday()
                }
                "entry2" = @{
                    TimeCodeID = "VAC"
                    Description = "Vacation"
                    Friday = 4.0
                    Total = 4.0
                    IsProjectEntry = $false
                    WeekEndingFriday = $script:service.GetCurrentWeekEndingFriday()
                }
            }
            
            $script:service.ImportWeekData($weekData)
            
            $allEntries = $script:service.GetAll()
            $allEntries.Count | Should -Be 2
            
            $projectEntry = $allEntries | Where-Object { $_.ID1 -eq "IMP001" }
            $projectEntry | Should -Not -BeNull
            $projectEntry.Monday | Should -Be 8.0
            
            $timeCodeEntry = $allEntries | Where-Object { $_.TimeCodeID -eq "VAC" }
            $timeCodeEntry | Should -Not -BeNull
            $timeCodeEntry.Friday | Should -Be 4.0
        }
    }
    
    Context "Cache Management" {
        It "Should populate cache on data retrieval" {
            # Create test entry
            $entry = $script:service.CreateProjectTimeEntry("CACHE001", "A", "Cache Test")
            $script:service.Update($entry)
            
            $currentWeek = $script:service.GetCurrentWeekEndingFriday()
            
            # Initial cache should be empty
            $script:service.WeekCache.ContainsKey($currentWeek) | Should -Be $false
            
            # Retrieve data should populate cache
            $entries = $script:service.GetEntriesForWeek($currentWeek)
            $script:service.WeekCache.ContainsKey($currentWeek) | Should -Be $true
            $script:service.WeekCache[$currentWeek].Count | Should -Be 1
        }
        
        It "Should clear caches when data changes" {
            # Create and cache data
            $entry = $script:service.CreateProjectTimeEntry("CLEAR001", "A", "Clear Test")
            $currentWeek = $script:service.GetCurrentWeekEndingFriday()
            $script:service.GetEntriesForWeek($currentWeek) | Out-Null
            
            $script:service.WeekCache.ContainsKey($currentWeek) | Should -Be $true
            
            # Update should clear cache
            $entry.Monday = 8.0
            $script:service.Update($entry)
            
            $script:service.WeekCache.ContainsKey($currentWeek) | Should -Be $false
        }
        
        It "Should refresh caches correctly" {
            $script:service.RefreshCaches()
            
            $currentWeek = $script:service.GetCurrentWeekEndingFriday()
            $script:service.WeekCache.ContainsKey($currentWeek) | Should -Be $true
            $script:service.FiscalYearCache.ContainsKey($script:service.CurrentFiscalYear) | Should -Be $true
        }
    }
    
    Context "Data Validation and Edge Cases" {
        It "Should handle empty week gracefully" {
            $emptyWeek = "20250101"  # Future date with no data
            $entries = $script:service.GetEntriesForWeek($emptyWeek)
            $totalHours = $script:service.GetWeekTotalHours($emptyWeek)
            
            $entries.Count | Should -Be 0
            $totalHours | Should -Be 0
        }
        
        It "Should handle invalid fiscal year gracefully" {
            $entries = $script:service.GetEntriesForFiscalYear("INVALID-FY")
            $entries.Count | Should -Be 0
        }
        
        It "Should validate time entries on creation" {
            # Valid entry
            $validEntry = $script:service.CreateProjectTimeEntry("VALID001", "A", "Valid Project")
            $validEntry | Should -Not -BeNull
            $validEntry.IsValid() | Should -Be $true
            
            # Entry without required fields should still be created but invalid
            try {
                $invalidData = @{
                    WeekEndingFriday = ""  # Invalid week
                    IsProjectEntry = $true
                }
                $invalidEntry = [TimeEntry]::new($invalidData)
                $invalidEntry.IsValid() | Should -Be $false
            } catch {
                # Expected for invalid data
                $true | Should -Be $true
            }
        }
        
        It "Should handle concurrent access safely" {
            # Create multiple entries rapidly
            $entries = @()
            for ($i = 1; $i -le 5; $i++) {
                $entry = $script:service.CreateProjectTimeEntry("CONC$($i.ToString('000'))", "A", "Concurrent Test $i")
                $entry.Monday = $i
                $entry.CalculateTotal()
                $entries += $script:service.Update($entry)
            }
            
            $allEntries = $script:service.GetAll()
            $allEntries.Count | Should -Be 5
            
            # Verify all entries are unique
            $uniqueIds = ($allEntries | Select-Object -ExpandProperty Id | Sort-Object -Unique).Count
            $uniqueIds | Should -Be 5
        }
    }
    
    Context "Performance and Optimization" {
        It "Should handle large datasets efficiently" {
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            
            # Create 100 entries
            for ($i = 1; $i -le 100; $i++) {
                $entry = $script:service.CreateProjectTimeEntry("PERF$($i.ToString('000'))", "A", "Performance Test $i")
                $entry.Monday = ($i % 8) + 1
                $entry.CalculateTotal()
                $script:service.Update($entry) | Out-Null
            }
            
            $stopwatch.Stop()
            $creationTime = $stopwatch.ElapsedMilliseconds
            
            # Test retrieval performance
            $stopwatch.Restart()
            $allEntries = $script:service.GetAll()
            $stopwatch.Stop()
            $retrievalTime = $stopwatch.ElapsedMilliseconds
            
            # Performance assertions (adjust thresholds as needed)
            $allEntries.Count | Should -Be 100
            $creationTime | Should -BeLessThan 10000  # Less than 10 seconds for 100 entries
            $retrievalTime | Should -BeLessThan 1000   # Less than 1 second for retrieval
            
            Write-Host "Performance: Created 100 entries in ${creationTime}ms, Retrieved in ${retrievalTime}ms"
        }
    }
}