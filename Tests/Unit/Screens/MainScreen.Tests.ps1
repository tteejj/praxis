# MainScreen.Tests.ps1 - Tests for MainScreen

BeforeAll {
    Import-Module "$PSScriptRoot/../../TestHelpers.psm1" -Force
    Initialize-PraxisForTesting
    
    # Mock global variables
    $global:Logger = New-MockLogger
    $global:ScreenManager = $null
}

Describe "MainScreen" {
    BeforeEach {
        $container = New-MockServiceContainer
        $container.Register('ThemeManager', (New-MockThemeManager))
        $container.Register('EventBus', (New-MockEventBus))
        $container.Register('FocusManager', (New-MockFocusManager))
        $container.Register('Logger', $global:Logger)
        
        # Mock services needed by screens
        $mockProjectService = New-Object PSObject
        Add-Member -InputObject $mockProjectService -MemberType ScriptMethod -Name "GetAllProjects" -Value { @() }
        $container.Register('ProjectService', $mockProjectService)
        
        $mockTaskService = New-Object PSObject
        Add-Member -InputObject $mockTaskService -MemberType ScriptMethod -Name "GetAllTasks" -Value { @() }
        $container.Register('TaskService', $mockTaskService)
        
        $mockTimeService = New-Object PSObject
        Add-Member -InputObject $mockTimeService -MemberType ScriptMethod -Name "GetCurrentWeekFriday" -Value { [DateTime]::Now }
        Add-Member -InputObject $mockTimeService -MemberType ScriptMethod -Name "GetWeekEntries" -Value { @() }
        $container.Register('TimeTrackingService', $mockTimeService)
        
        $mainScreen = [MainScreen]::new()
        $mainScreen.Initialize($container)
        $mainScreen.SetBounds(0, 0, 80, 24)
    }
    
    Context "Initialization" {
        It "Should initialize with correct menu items" {
            $mainScreen.MenuItems.Count | Should -Be 7
            $mainScreen.MenuItems.ContainsKey("Projects") | Should -Be $true
            $mainScreen.MenuItems.ContainsKey("Tasks") | Should -Be $true
            $mainScreen.MenuItems.ContainsKey("Time Entry") | Should -Be $true
            $mainScreen.MenuItems.ContainsKey("Files") | Should -Be $true
            $mainScreen.MenuItems.ContainsKey("Commands") | Should -Be $true
            $mainScreen.MenuItems.ContainsKey("Macro Factory") | Should -Be $true
            $mainScreen.MenuItems.ContainsKey("Settings") | Should -Be $true
        }
        
        It "Should create menu list and status bar" {
            $mainScreen.MenuList | Should -Not -BeNull
            $mainScreen.StatusBar | Should -Not -BeNull
        }
        
        It "Should set menu focused initially" {
            $mainScreen.MenuFocused | Should -Be $false  # Not focused until OnActivated
        }
    }
    
    Context "Screen Switching" {
        It "Should switch to Projects screen" {
            $mainScreen.SwitchToScreen("Projects")
            
            $mainScreen.CurrentScreen | Should -Not -BeNull
            $mainScreen.CurrentScreen.GetType().Name | Should -Be "ProjectsScreen"
            $mainScreen.CurrentScreenName | Should -Be "Projects"
        }
        
        It "Should switch to different screens" {
            $screens = @("Tasks", "Time Entry", "Commands", "Settings")
            
            foreach ($screen in $screens) {
                $mainScreen.SwitchToScreen($screen)
                $mainScreen.CurrentScreenName | Should -Be $screen
            }
        }
        
        It "Should handle invalid screen names gracefully" {
            { $mainScreen.SwitchToScreen("NonExistent") } | Should -Not -Throw
            # Current screen should remain unchanged
        }
    }
    
    Context "Focus Management" {
        It "Should switch focus between menu and content" {
            $mainScreen.SwitchToScreen("Projects")
            
            # Switch to content
            $mainScreen.SwitchFocusToContent()
            $mainScreen.MenuFocused | Should -Be $false
            
            # Switch to menu
            $mainScreen.SwitchFocusToMenu()
            $mainScreen.MenuFocused | Should -Be $true
        }
        
        It "Should update status bar when focus changes" {
            $mainScreen.SwitchFocusToMenu()
            $mainScreen.StatusBar.CenterText | Should -Match "Focus: MENU"
            
            $mainScreen.SwitchFocusToContent()
            $mainScreen.StatusBar.CenterText | Should -Match "Focus: CONTENT"
        }
    }
    
    Context "Input Handling" {
        It "Should handle Tab key to cycle screens" {
            $mainScreen.SwitchToScreen("Projects")
            
            $tabKey = New-ConsoleKeyInfo -Key ([System.ConsoleKey]::Tab)
            $handled = $mainScreen.HandleInput($tabKey)
            
            $handled | Should -Be $true
            $mainScreen.CurrentScreenName | Should -Be "Tasks"  # Next screen
        }
        
        It "Should handle Ctrl+Tab to cycle screens backward" {
            $mainScreen.SwitchToScreen("Tasks")
            
            $ctrlTabKey = New-ConsoleKeyInfo -Key ([System.ConsoleKey]::Tab) -Control $true
            $handled = $mainScreen.HandleInput($ctrlTabKey)
            
            $handled | Should -Be $true
            $mainScreen.CurrentScreenName | Should -Be "Projects"  # Previous screen
        }
        
        It "Should handle number keys to switch screens" {
            $key1 = New-ConsoleKeyInfo -KeyChar '1'
            $handled = $mainScreen.HandleInput($key1)
            
            $handled | Should -Be $true
            $mainScreen.CurrentScreenName | Should -Be "Projects"
            
            $key3 = New-ConsoleKeyInfo -KeyChar '3'
            $mainScreen.HandleInput($key3)
            $mainScreen.CurrentScreenName | Should -Be "Time Entry"
        }
        
        It "Should handle / key to show action popup" {
            $mainScreen.SwitchToScreen("Projects")
            
            $slashKey = New-ConsoleKeyInfo -KeyChar '/'
            $handled = $mainScreen.HandleInput($slashKey)
            
            $handled | Should -Be $true
            $mainScreen.ActionPopup | Should -Not -BeNull
            $mainScreen.ActionPopup.IsVisible | Should -Be $true
        }
        
        It "Should handle arrow keys for focus switching" {
            $mainScreen.SwitchToScreen("Projects")
            
            # Right arrow should switch to content
            $rightKey = New-ConsoleKeyInfo -Key ([System.ConsoleKey]::RightArrow)
            $mainScreen.MenuFocused = $true
            $mainScreen.HandleInput($rightKey)
            $mainScreen.MenuFocused | Should -Be $false
            
            # Left arrow should switch to menu
            $leftKey = New-ConsoleKeyInfo -Key ([System.ConsoleKey]::LeftArrow)
            $mainScreen.HandleInput($leftKey)
            $mainScreen.MenuFocused | Should -Be $true
        }
    }
    
    Context "Action Popup" {
        It "Should create action popup with correct items for Projects" {
            $mainScreen.SwitchToScreen("Projects")
            $mainScreen.ShowActionPopup()
            
            $mainScreen.ActionPopup.Items.Count | Should -BeGreaterThan 0
            $itemTexts = $mainScreen.ActionPopup.Items | ForEach-Object { $_.Text }
            $itemTexts | Should -Contain "New Project (n)"
            $itemTexts | Should -Contain "Edit Project (e)"
            $itemTexts | Should -Contain "Delete Project (d)"
        }
        
        It "Should create different actions for different screens" {
            $mainScreen.SwitchToScreen("Tasks")
            $mainScreen.ShowActionPopup()
            
            $itemTexts = $mainScreen.ActionPopup.Items | ForEach-Object { $_.Text }
            $itemTexts | Should -Contain "New Task (n)"
            $itemTexts | Should -Contain "Add Subtask (a)"
        }
    }
    
    Context "Performance" {
        It "Should switch screens quickly" {
            $perf = Measure-Performance -Name "Switch between all screens" -ScriptBlock {
                $screens = @("Projects", "Tasks", "Time Entry", "Files", "Commands", "Macro Factory", "Settings")
                foreach ($screen in $screens) {
                    $mainScreen.SwitchToScreen($screen)
                }
            }
            
            # Should complete all screen switches in under 500ms
            $perf.ElapsedMilliseconds | Should -BeLessThan 500
        }
        
        It "Should handle rapid input efficiently" {
            $perf = Measure-Performance -Name "100 rapid inputs" -ScriptBlock {
                for ($i = 0; $i -lt 100; $i++) {
                    $key = New-ConsoleKeyInfo -Key ([System.ConsoleKey]::DownArrow)
                    $mainScreen.HandleInput($key) | Out-Null
                }
            }
            
            # Should handle 100 inputs in under 200ms
            $perf.ElapsedMilliseconds | Should -BeLessThan 200
        }
    }
    
    Context "Status Bar Updates" {
        It "Should show current screen name in status bar" {
            $mainScreen.SwitchToScreen("Projects")
            $mainScreen.UpdateStatusBar()
            
            $mainScreen.StatusBar.LeftText | Should -Be "Projects"
        }
        
        It "Should show current time in status bar" {
            $mainScreen.UpdateStatusBar()
            
            # Should show time in HH:mm format
            $mainScreen.StatusBar.RightText | Should -Match "\d{2}:\d{2}"
        }
    }
}