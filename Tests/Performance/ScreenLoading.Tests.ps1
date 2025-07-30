# ScreenLoading.Tests.ps1 - Performance tests for screen loading

BeforeAll {
    Import-Module "$PSScriptRoot/../TestHelpers.psm1" -Force
    Initialize-PraxisForTesting
    
    # Create mock services with realistic data
    function New-PerformanceServiceContainer {
        $container = New-MockServiceContainer
        
        # Mock ProjectService with many projects
        $mockProjectService = New-Object PSObject
        $projects = @()
        for ($i = 1; $i -le 100; $i++) {
            $projects += [PSCustomObject]@{
                Id = [Guid]::NewGuid()
                Name = "Project $i"
                FullProjectName = "Test Project Number $i"
                ID1 = "ID1-$i"
                ID2 = "ID2-$i"
                DateAssigned = (Get-Date).AddDays(-$i)
                DateDue = (Get-Date).AddDays($i)
                Deleted = $false
            }
        }
        Add-Member -InputObject $mockProjectService -MemberType ScriptMethod -Name "GetAllProjects" -Value { $projects }.GetNewClosure()
        $container.Register('ProjectService', $mockProjectService)
        
        # Mock TaskService with many tasks
        $mockTaskService = New-Object PSObject
        $tasks = @()
        for ($i = 1; $i -le 200; $i++) {
            $tasks += [PSCustomObject]@{
                Id = [Guid]::NewGuid()
                Title = "Task $i"
                Description = "Description for task $i with some longer text"
                Status = @('Pending', 'InProgress', 'Completed')[$i % 3]
                Priority = @('Low', 'Medium', 'High')[$i % 3]
                DueDate = (Get-Date).AddDays($i % 30)
                Deleted = $false
            }
        }
        Add-Member -InputObject $mockTaskService -MemberType ScriptMethod -Name "GetAllTasks" -Value { $tasks }.GetNewClosure()
        $container.Register('TaskService', $mockTaskService)
        
        # Mock TimeTrackingService
        $mockTimeService = New-Object PSObject
        Add-Member -InputObject $mockTimeService -MemberType ScriptMethod -Name "GetCurrentWeekFriday" -Value { [DateTime]::Now.AddDays(5 - [int][DateTime]::Now.DayOfWeek) }
        $entries = @()
        for ($i = 1; $i -le 50; $i++) {
            $entries += [PSCustomObject]@{
                ID2 = "PROJECT-$($i % 10)"
                Name = "Project $($i % 10)"
                Monday = ($i % 8)
                Tuesday = (($i + 1) % 8)
                Wednesday = (($i + 2) % 8)
                Thursday = (($i + 3) % 8)
                Friday = (($i + 4) % 8)
                Total = ($i % 8) * 5
            }
        }
        Add-Member -InputObject $mockTimeService -MemberType ScriptMethod -Name "GetWeekEntries" -Value { $entries }.GetNewClosure()
        $container.Register('TimeTrackingService', $mockTimeService)
        
        # Add other required services
        $container.Register('ThemeManager', (New-MockThemeManager))
        $container.Register('EventBus', (New-MockEventBus))
        $container.Register('FocusManager', (New-MockFocusManager))
        $container.Register('Logger', (New-MockLogger))
        
        return $container
    }
}

Describe "Screen Loading Performance" {
    BeforeEach {
        $container = New-PerformanceServiceContainer
    }
    
    Context "Individual Screen Loading" {
        It "Should load ProjectsScreen in under 100ms" {
            $perf = Measure-Performance -Name "ProjectsScreen Loading" -ScriptBlock {
                $screen = [ProjectsScreen]::new()
                $screen.Initialize($container)
                $screen.SetBounds(0, 0, 80, 24)
            }
            
            Write-Host "ProjectsScreen loaded in $($perf.ElapsedMilliseconds)ms"
            $perf.ElapsedMilliseconds | Should -BeLessThan 100
        }
        
        It "Should load TaskScreen in under 150ms" {
            $perf = Measure-Performance -Name "TaskScreen Loading" -ScriptBlock {
                $screen = [TaskScreen]::new()
                $screen.Initialize($container)
                $screen.SetBounds(0, 0, 80, 24)
            }
            
            Write-Host "TaskScreen loaded in $($perf.ElapsedMilliseconds)ms"
            $perf.ElapsedMilliseconds | Should -BeLessThan 150
        }
        
        It "Should load TimeEntryScreen in under 100ms" {
            $perf = Measure-Performance -Name "TimeEntryScreen Loading" -ScriptBlock {
                $screen = [TimeEntryScreen]::new()
                $screen.Initialize($container)
                $screen.SetBounds(0, 0, 80, 24)
            }
            
            Write-Host "TimeEntryScreen loaded in $($perf.ElapsedMilliseconds)ms"
            $perf.ElapsedMilliseconds | Should -BeLessThan 100
        }
        
        It "Should load CommandLibraryScreen in under 100ms" {
            # Add CommandService
            $mockCommandService = New-Object PSObject
            Add-Member -InputObject $mockCommandService -MemberType ScriptMethod -Name "GetAllCommands" -Value { @() }
            $container.Register('CommandService', $mockCommandService)
            
            $perf = Measure-Performance -Name "CommandLibraryScreen Loading" -ScriptBlock {
                $screen = [CommandLibraryScreen]::new()
                $screen.Initialize($container)
                $screen.SetBounds(0, 0, 80, 24)
            }
            
            Write-Host "CommandLibraryScreen loaded in $($perf.ElapsedMilliseconds)ms"
            $perf.ElapsedMilliseconds | Should -BeLessThan 100
        }
    }
    
    Context "Screen Switching Performance" {
        It "Should switch between screens quickly" {
            $mainScreen = [MainScreen]::new()
            $mainScreen.Initialize($container)
            $mainScreen.SetBounds(0, 0, 80, 24)
            
            # Warm up
            $mainScreen.SwitchToScreen("Projects")
            
            $perf = Measure-Performance -Name "10 Screen Switches" -ScriptBlock {
                for ($i = 0; $i -lt 10; $i++) {
                    $mainScreen.SwitchToScreen("Tasks")
                    $mainScreen.SwitchToScreen("Projects")
                }
            }
            
            Write-Host "20 screen switches completed in $($perf.ElapsedMilliseconds)ms"
            # Should average less than 50ms per switch
            $perf.ElapsedMilliseconds | Should -BeLessThan 1000
        }
    }
    
    Context "Data Grid Performance" {
        It "Should render large data grid efficiently" {
            $grid = [MinimalDataGrid]::new()
            $grid.Initialize($container)
            $grid.SetBounds(0, 0, 80, 24)
            
            # Set columns
            $columns = @(
                @{Name="Col1"; Header="Column 1"; Width=20}
                @{Name="Col2"; Header="Column 2"; Width=20}
                @{Name="Col3"; Header="Column 3"; Width=20}
                @{Name="Col4"; Header="Column 4"; Width=20}
            )
            $grid.SetColumns($columns)
            
            # Add many items
            $items = @()
            for ($i = 1; $i -le 1000; $i++) {
                $items += [PSCustomObject]@{
                    Col1 = "Value $i-1"
                    Col2 = "Value $i-2"
                    Col3 = "Value $i-3"
                    Col4 = "Value $i-4"
                }
            }
            
            $perf = Measure-Performance -Name "SetItems with 1000 items" -ScriptBlock {
                $grid.SetItems($items)
            }
            
            Write-Host "SetItems with 1000 items completed in $($perf.ElapsedMilliseconds)ms"
            $perf.ElapsedMilliseconds | Should -BeLessThan 100
            
            # Measure rendering
            $perf = Measure-Performance -Name "Render 1000-item grid" -ScriptBlock {
                $grid.Render() | Out-Null
            }
            
            Write-Host "Rendering 1000-item grid completed in $($perf.ElapsedMilliseconds)ms"
            $perf.ElapsedMilliseconds | Should -BeLessThan 50
        }
    }
    
    Context "Input Processing Performance" {
        It "Should process rapid keyboard input efficiently" {
            $screen = [ProjectsScreen]::new()
            $screen.Initialize($container)
            $screen.SetBounds(0, 0, 80, 24)
            
            $keys = @(
                (New-ConsoleKeyInfo -Key ([System.ConsoleKey]::DownArrow)),
                (New-ConsoleKeyInfo -Key ([System.ConsoleKey]::UpArrow)),
                (New-ConsoleKeyInfo -KeyChar 'n'),
                (New-ConsoleKeyInfo -KeyChar 'e'),
                (New-ConsoleKeyInfo -Key ([System.ConsoleKey]::Enter))
            )
            
            $perf = Measure-Performance -Name "Process 1000 key inputs" -ScriptBlock {
                for ($i = 0; $i -lt 1000; $i++) {
                    $key = $keys[$i % $keys.Count]
                    $screen.HandleInput($key) | Out-Null
                }
            }
            
            Write-Host "1000 key inputs processed in $($perf.ElapsedMilliseconds)ms"
            $perf.ElapsedMilliseconds | Should -BeLessThan 500
        }
    }
    
    Context "Memory Usage" -Skip {
        It "Should not leak memory during screen switches" {
            $mainScreen = [MainScreen]::new()
            $mainScreen.Initialize($container)
            $mainScreen.SetBounds(0, 0, 80, 24)
            
            # Get baseline memory
            [GC]::Collect()
            [GC]::WaitForPendingFinalizers()
            [GC]::Collect()
            $baselineMemory = [GC]::GetTotalMemory($false)
            
            # Perform many screen switches
            for ($i = 0; $i -lt 100; $i++) {
                $mainScreen.SwitchToScreen("Projects")
                $mainScreen.SwitchToScreen("Tasks")
                $mainScreen.SwitchToScreen("Time Entry")
            }
            
            # Force garbage collection
            [GC]::Collect()
            [GC]::WaitForPendingFinalizers()
            [GC]::Collect()
            $finalMemory = [GC]::GetTotalMemory($false)
            
            $memoryIncrease = $finalMemory - $baselineMemory
            Write-Host "Memory increased by $([math]::Round($memoryIncrease / 1MB, 2)) MB"
            
            # Should not increase by more than 10MB
            $memoryIncrease | Should -BeLessThan (10 * 1MB)
        }
    }
}