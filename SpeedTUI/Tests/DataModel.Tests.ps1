# Comprehensive Pester tests for SpeedTUI Data Models

# Set location to the SpeedTUI root directory
$SpeedTUIRoot = Split-Path -Parent $PSScriptRoot
Set-Location $SpeedTUIRoot

BeforeAll {
    # Load the models in BeforeAll block for Pester
    $SpeedTUIRoot = Split-Path -Parent $PSScriptRoot
    . (Join-Path $SpeedTUIRoot "Models" "BaseModel.ps1")
    . (Join-Path $SpeedTUIRoot "Models" "Project.ps1")
    . (Join-Path $SpeedTUIRoot "Models" "Task.ps1")
    . (Join-Path $SpeedTUIRoot "Models" "TimeEntry.ps1")
    . (Join-Path $SpeedTUIRoot "Models" "Command.ps1")
}

Describe "BaseModel Tests" {
    Context "Constructor and Basic Properties" {
        It "Should create BaseModel with default values" {
            $model = [BaseModel]::new()
            
            $model.Id | Should -Not -BeNullOrEmpty
            $model.CreatedAt | Should -BeOfType [DateTime]
            $model.UpdatedAt | Should -BeOfType [DateTime]
            $model.Deleted | Should -Be $false
        }
        
        It "Should create BaseModel from hashtable" {
            $data = @{
                Id = "test-id"
                CreatedAt = [DateTime]::Now.AddDays(-1)
                UpdatedAt = [DateTime]::Now
                Deleted = $true
            }
            
            $model = [BaseModel]::new($data)
            
            $model.Id | Should -Be "test-id"
            $model.Deleted | Should -Be $true
        }
        
        It "Should update timestamp when touched" {
            $model = [BaseModel]::new()
            $originalTime = $model.UpdatedAt
            
            Start-Sleep -Milliseconds 10
            $model.Touch()
            
            $model.UpdatedAt | Should -BeGreaterThan $originalTime
        }
        
        It "Should soft delete correctly" {
            $model = [BaseModel]::new()
            $model.SoftDelete()
            
            $model.Deleted | Should -Be $true
        }
        
        It "Should convert to hashtable" {
            $model = [BaseModel]::new()
            $hash = $model.ToHashtable()
            
            $hash.Id | Should -Be $model.Id
            $hash.CreatedAt | Should -Be $model.CreatedAt
            $hash.UpdatedAt | Should -Be $model.UpdatedAt
            $hash.Deleted | Should -Be $model.Deleted
        }
        
        It "Should validate correctly" {
            $model = [BaseModel]::new()
            $model.IsValid() | Should -Be $true
            
            $model.Id = ""
            $model.IsValid() | Should -Be $false
        }
    }
}

Describe "Project Model Tests" {
    Context "Project Creation and Validation" {
        It "Should create project with defaults" {
            $project = [Project]::new()
            
            $project.Id | Should -Not -BeNullOrEmpty
            $project.Status | Should -Be "Active"
            $project.CumulativeHrs | Should -Be 0
            $project.IsValid() | Should -Be $false  # No name or ID1
        }
        
        It "Should create valid project with name" {
            $data = @{ FullProjectName = "Test Project" }
            $project = [Project]::new($data)
            
            $project.FullProjectName | Should -Be "Test Project"
            $project.IsValid() | Should -Be $true
        }
        
        It "Should create valid project with ID1" {
            $data = @{ ID1 = "TEST001" }
            $project = [Project]::new($data)
            
            $project.ID1 | Should -Be "TEST001"
            $project.IsValid() | Should -Be $true
        }
        
        It "Should get display name correctly" {
            $project1 = [Project]::new(@{ FullProjectName = "Test Project" })
            $project1.GetDisplayName() | Should -Be "Test Project"
            
            $project2 = [Project]::new(@{ ID1 = "TEST001"; ID2 = "ABC" })
            $project2.GetDisplayName() | Should -Be "TEST001 - ABC"
        }
        
        It "Should get project code correctly" {
            $project = [Project]::new(@{ ID1 = "TEST001"; ID2 = "ABC" })
            $project.GetProjectCode() | Should -Be "TEST001-ABC"
        }
        
        It "Should detect overdue projects" {
            $overdueDate = [DateTime]::Now.AddDays(-5)
            $project = [Project]::new(@{ 
                FullProjectName = "Overdue Project"
                DateDue = $overdueDate
                Status = "Active"
            })
            
            $project.IsOverdue() | Should -Be $true
        }
        
        It "Should calculate days until due" {
            $futureDate = [DateTime]::Now.AddDays(10)
            $project = [Project]::new(@{ 
                FullProjectName = "Future Project"
                DateDue = $futureDate
            })
            
            $project.GetDaysUntilDue() | Should -Be 10
        }
        
        It "Should convert to hashtable with all properties" {
            $project = [Project]::new(@{ 
                FullProjectName = "Test Project"
                ID1 = "TEST001"
                AuditorName = "John Doe"
            })
            
            $hash = $project.ToHashtable()
            
            $hash.FullProjectName | Should -Be "Test Project"
            $hash.ID1 | Should -Be "TEST001"
            $hash.AuditorName | Should -Be "John Doe"
            $hash.ContainsKey('CreatedAt') | Should -Be $true
        }
    }
}

Describe "Task Model Tests" {
    Context "Task Creation and Management" {
        It "Should create task with defaults" {
            $task = [Task]::new()
            
            $task.Status | Should -Be ([TaskStatus]::Pending)
            $task.Priority | Should -Be ([TaskPriority]::Medium)
            $task.Progress | Should -Be 0
            $task.IsValid() | Should -Be $false  # No title
        }
        
        It "Should create valid task with title" {
            $data = @{ Title = "Test Task" }
            $task = [Task]::new($data)
            
            $task.Title | Should -Be "Test Task"
            $task.IsValid() | Should -Be $true
        }
        
        It "Should update progress correctly" {
            $task = [Task]::new(@{ Title = "Test Task" })
            $task.UpdateProgress(50)
            
            $task.Progress | Should -Be 50
            $task.Status | Should -Be ([TaskStatus]::InProgress)
        }
        
        It "Should auto-complete at 100% progress" {
            $task = [Task]::new(@{ Title = "Test Task" })
            $task.UpdateProgress(100)
            
            $task.Progress | Should -Be 100
            $task.Status | Should -Be ([TaskStatus]::Completed)
            $task.CompletedDate | Should -Not -Be ([DateTime]::MinValue)
        }
        
        It "Should manage tags correctly" {
            $task = [Task]::new(@{ Title = "Test Task" })
            
            $task.AddTag("urgent")
            $task.HasTag("urgent") | Should -Be $true
            $task.GetTagsDisplay() | Should -Be "urgent"
            
            $task.AddTag("bug")
            $task.GetTagsDisplay() | Should -Be "urgent, bug"
            
            $task.RemoveTag("urgent")
            $task.HasTag("urgent") | Should -Be $false
            $task.GetTagsDisplay() | Should -Be "bug"
        }
        
        It "Should get progress bar display" {
            $task = [Task]::new(@{ Title = "Test Task" })
            $task.Progress = 75
            
            $progressBar = $task.GetProgressBar(10)
            $progressBar | Should -Match "75%"
            $progressBar | Should -Match "█"
        }
        
        It "Should detect overdue tasks" {
            $overdueDate = [DateTime]::Now.AddDays(-3)
            $task = [Task]::new(@{ 
                Title = "Overdue Task"
                DueDate = $overdueDate
                Status = [TaskStatus]::InProgress
            })
            
            $task.IsOverdue() | Should -Be $true
        }
        
        It "Should calculate hours variance" {
            $task = [Task]::new(@{ 
                Title = "Test Task"
                EstimatedHours = 10
                ActualHours = 12
            })
            
            $task.GetHoursVariance() | Should -Be 2
            $task.GetHoursVariancePercent() | Should -Be 20
        }
    }
}

Describe "TimeEntry Model Tests" {
    Context "Time Entry Creation and Calculations" {
        It "Should create time entry with defaults" {
            $timeEntry = [TimeEntry]::new()
            
            $timeEntry.WeekEndingFriday | Should -Not -BeNullOrEmpty
            $timeEntry.FiscalYear | Should -Not -BeNullOrEmpty
            $timeEntry.Total | Should -Be 0
            $timeEntry.IsProjectEntry | Should -Be $true
        }
        
        It "Should calculate total correctly" {
            $timeEntry = [TimeEntry]::new()
            $timeEntry.Monday = 8
            $timeEntry.Tuesday = 7.5
            $timeEntry.Wednesday = 8
            $timeEntry.Thursday = 6
            $timeEntry.Friday = 4
            
            $timeEntry.CalculateTotal()
            $timeEntry.Total | Should -Be 33.5
        }
        
        It "Should set day hours correctly" {
            $timeEntry = [TimeEntry]::new()
            $timeEntry.SetDayHours("Monday", 8.5)
            
            $timeEntry.Monday | Should -Be 8.5
            $timeEntry.Total | Should -Be 8.5
        }
        
        It "Should get day hours correctly" {
            $timeEntry = [TimeEntry]::new()
            $timeEntry.Tuesday = 7.5
            
            $timeEntry.GetDayHours("Tuesday") | Should -Be 7.5
            $timeEntry.GetDayHours("Sunday") | Should -Be 0
        }
        
        It "Should calculate fiscal year correctly" {
            $timeEntry = [TimeEntry]::new()
            
            # Test April date (start of fiscal year)
            $fy = $timeEntry.CalculateFiscalYear("20240405")  # April 5, 2024
            $fy | Should -Be "2024-2025"
            
            # Test March date (end of fiscal year)
            $fy = $timeEntry.CalculateFiscalYear("20240315")  # March 15, 2024
            $fy | Should -Be "2023-2024"
        }
        
        It "Should get week display string" {
            $timeEntry = [TimeEntry]::new()
            $timeEntry.WeekEndingFriday = "20240405"  # April 5, 2024 (Friday)
            
            $display = $timeEntry.GetWeekDisplayString()
            $display | Should -Match "Apr 01.*Apr 05.*2024"
        }
        
        It "Should validate project entries" {
            $projectEntry = [TimeEntry]::new(@{
                ID1 = "PROJECT001"
                IsProjectEntry = $true
            })
            
            $projectEntry.IsValidProjectEntry() | Should -Be $true
            $projectEntry.GetEntryType() | Should -Be "Project"
        }
        
        It "Should validate time code entries" {
            $timeCodeEntry = [TimeEntry]::new(@{
                TimeCodeID = "VAC"
                IsProjectEntry = $false
            })
            
            $timeCodeEntry.IsValidTimeCodeEntry() | Should -Be $true
            $timeCodeEntry.GetEntryType() | Should -Be "Time Code"
        }
        
        It "Should get time distribution" {
            $timeEntry = [TimeEntry]::new()
            $timeEntry.Monday = 8
            $timeEntry.Wednesday = 6
            $timeEntry.Friday = 4
            $timeEntry.CalculateTotal()
            
            $distribution = $timeEntry.GetTimeDistribution()
            $distribution | Should -Match "Mon: 8h"
            $distribution | Should -Match "Wed: 6h"
            $distribution | Should -Match "Fri: 4h"
        }
    }
}

Describe "Command Model Tests" {
    Context "Command Creation and Management" {
        It "Should create command with defaults" {
            $command = [Command]::new()
            
            $command.UseCount | Should -Be 0
            $command.Language | Should -Be "PowerShell"
            $command.IsTemplate | Should -Be $false
            $command.LastUsed | Should -Be ([DateTime]::MinValue)
        }
        
        It "Should validate command correctly" {
            $validCommand = [Command]::new(@{
                Title = "Test Command"
                CommandText = "Get-Process"
            })
            
            $validCommand.IsValid() | Should -Be $true
            
            $invalidCommand = [Command]::new(@{
                Title = "Invalid Command"
                # Missing CommandText
            })
            
            $invalidCommand.IsValid() | Should -Be $false
        }
        
        It "Should record usage correctly" {
            $command = [Command]::new(@{
                Title = "Test Command"
                CommandText = "Get-Process"
            })
            
            $originalCount = $command.UseCount
            $command.RecordUsage()
            
            $command.UseCount | Should -Be ($originalCount + 1)
            $command.LastUsed | Should -Not -Be ([DateTime]::MinValue)
        }
        
        It "Should manage tags correctly" {
            $command = [Command]::new(@{
                Title = "Test Command"
                CommandText = "Get-Process"
            })
            
            $command.AddTag("utility")
            $command.HasTag("utility") | Should -Be $true
            
            $command.AddTag("system")
            $command.GetTagsDisplay() | Should -Be "utility, system"
            
            $command.RemoveTag("utility")
            $command.HasTag("utility") | Should -Be $false
        }
        
        It "Should get display text correctly" {
            $commandWithTitle = [Command]::new(@{
                Title = "Process List"
                CommandText = "Get-Process | Select-Object Name, CPU"
            })
            
            $commandWithTitle.GetDisplayText() | Should -Be "Process List"
            
            $commandNoTitle = [Command]::new(@{
                CommandText = "Get-Process | Select-Object Name, CPU, WorkingSet"
            })
            
            $display = $commandNoTitle.GetDisplayText()
            $display.Length | Should -BeLessOrEqual 50
            $display | Should -Match "Get-Process"
        }
        
        It "Should search commands correctly" {
            $command = [Command]::new(@{
                Title = "Process Management"
                Description = "Lists system processes"
                CommandText = "Get-Process"
                Tags = @("system", "process")
                Group = "System Administration"
            })
            
            $command.MatchesSearch("process") | Should -Be $true
            $command.MatchesSearch("system admin") | Should -Be $true
            $command.MatchesSearch("network") | Should -Be $false
        }
        
        It "Should filter commands correctly" {
            $command = [Command]::new(@{
                Title = "Process Command"
                CommandText = "Get-Process"
                Group = "System"
                Category = "Administration"
                Language = "PowerShell"
                Tags = @("system")
                UseCount = 5
            })
            
            $command.MatchesFilter("group", "System") | Should -Be $true
            $command.MatchesFilter("language", "PowerShell") | Should -Be $true
            $command.MatchesFilter("tag", "system") | Should -Be $true
            $command.MatchesFilter("used", "few") | Should -Be $true
            $command.MatchesFilter("used", "never") | Should -Be $false
        }
        
        It "Should clone command correctly" {
            $original = [Command]::new(@{
                Title = "Original Command"
                CommandText = "Get-Process"
                UseCount = 10
            })
            
            $clone = $original.Clone()
            
            $clone.Title | Should -Be "Original Command"
            $clone.CommandText | Should -Be "Get-Process"
            $clone.UseCount | Should -Be 0
            $clone.Id | Should -Not -Be $original.Id
        }
    }
}