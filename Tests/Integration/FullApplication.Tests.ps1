# FullApplication.Tests.ps1 - Integration tests for full application flow

BeforeAll {
    Import-Module "$PSScriptRoot/../TestHelpers.psm1" -Force
    
    # Load all PRAXIS components
    $praxisRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    
    # Source all files in order
    . "$praxisRoot/Core/VT100.ps1"
    . "$praxisRoot/Core/BorderStyle.ps1"
    . "$praxisRoot/Core/StringCache.ps1"
    . "$praxisRoot/Core/StringBuilderPool.ps1"
    . "$praxisRoot/Core/EventNames.ps1"
    
    # Base classes
    . "$praxisRoot/Base/UIElement.ps1"
    . "$praxisRoot/Base/Container.ps1"
    . "$praxisRoot/Base/Screen.ps1"
    . "$praxisRoot/Base/BaseDialog.ps1"
    . "$praxisRoot/Base/FocusableComponent.ps1"
    
    # Models
    Get-ChildItem "$praxisRoot/Models/*.ps1" | ForEach-Object { . $_.FullName }
    
    # Services
    Get-ChildItem "$praxisRoot/Services/*.ps1" | ForEach-Object { . $_.FullName }
    
    # Components
    Get-ChildItem "$praxisRoot/Components/*.ps1" | ForEach-Object { . $_.FullName }
    
    # Screens
    Get-ChildItem "$praxisRoot/Screens/*.ps1" | ForEach-Object { . $_.FullName }
    
    # Create real service container
    function New-IntegrationServiceContainer {
        $container = [ServiceContainer]::new()
        
        # Core services
        $container.Register('Logger', [Logger]::new("$praxisRoot/Tests/test.log"))
        $container.Register('EventBus', [EventBus]::new())
        $container.Register('ThemeManager', [ThemeManager]::new())
        $container.Register('FocusManager', [FocusManager]::new())
        
        # Initialize ThemeManager
        $themeManager = $container.GetService('ThemeManager')
        $themeManager.Initialize($container)
        $themeManager.LoadTheme('Default')
        
        # Data services
        $container.Register('ProjectService', [ProjectService]::new())
        $container.Register('TaskService', [TaskService]::new())
        $container.Register('TimeTrackingService', [TimeTrackingService]::new())
        $container.Register('CommandService', [CommandService]::new())
        $container.Register('ConfigurationService', [ConfigurationService]::new())
        
        # ScreenManager
        $screenManager = [ScreenManager]::new()
        $screenManager.Initialize($container)
        $container.Register('ScreenManager', $screenManager)
        
        # Set global variables
        $global:ServiceContainer = $container
        $global:Logger = $container.GetService('Logger')
        $global:ScreenManager = $screenManager
        
        return $container
    }
}

Describe "Full Application Integration" {
    BeforeEach {
        $container = New-IntegrationServiceContainer
        $global:ServiceContainer = $container
    }
    
    AfterEach {
        # Clean up global variables
        $global:ServiceContainer = $null
        $global:Logger = $null
        $global:ScreenManager = $null
    }
    
    Context "Application Startup" {
        It "Should create and initialize MainScreen" {
            $mainScreen = [MainScreen]::new()
            { $mainScreen.Initialize($container) } | Should -Not -Throw
            
            $mainScreen.ServiceContainer | Should -Be $container
            $mainScreen.MenuList | Should -Not -BeNull
            $mainScreen.StatusBar | Should -Not -BeNull
        }
        
        It "Should handle screen manager push/pop correctly" {
            $screenManager = $container.GetService('ScreenManager')
            $mainScreen = [MainScreen]::new()
            $mainScreen.Initialize($container)
            
            { $screenManager.Push($mainScreen) } | Should -Not -Throw
            $screenManager.CurrentScreen | Should -Be $mainScreen
            
            # Push a dialog
            $dialog = [ConfirmationDialog]::new("Test message")
            $dialog.Initialize($container)
            { $screenManager.Push($dialog) } | Should -Not -Throw
            
            # Pop should return to main screen
            $screenManager.Pop()
            $screenManager.CurrentScreen | Should -Be $mainScreen
        }
    }
    
    Context "Screen Navigation Flow" {
        It "Should navigate between all screens without errors" {
            $mainScreen = [MainScreen]::new()
            $mainScreen.Initialize($container)
            $mainScreen.SetBounds(0, 0, 80, 24)
            
            $screens = @("Projects", "Tasks", "Time Entry", "Files", "Commands", "Macro Factory", "Settings")
            
            foreach ($screen in $screens) {
                { $mainScreen.SwitchToScreen($screen) } | Should -Not -Throw
                $mainScreen.CurrentScreenName | Should -Be $screen
                $mainScreen.CurrentScreen | Should -Not -BeNull
            }
        }
        
        It "Should handle Tab cycling through screens" {
            $mainScreen = [MainScreen]::new()
            $mainScreen.Initialize($container)
            $mainScreen.SetBounds(0, 0, 80, 24)
            
            # Start at Projects
            $mainScreen.SwitchToScreen("Projects")
            
            # Tab should go to Tasks
            $tabKey = New-ConsoleKeyInfo -Key ([System.ConsoleKey]::Tab)
            $mainScreen.HandleInput($tabKey)
            $mainScreen.CurrentScreenName | Should -Be "Tasks"
            
            # Tab again should go to Time Entry
            $mainScreen.HandleInput($tabKey)
            $mainScreen.CurrentScreenName | Should -Be "Time Entry"
        }
    }
    
    Context "CRUD Operations Flow" {
        It "Should complete full project CRUD cycle" {
            $projectService = $container.GetService('ProjectService')
            $eventBus = $container.GetService('EventBus')
            
            # Track events
            $events = [System.Collections.ArrayList]::new()
            $eventBus.Subscribe([EventNames]::ProjectCreated, {
                param($s, $e)
                $events.Add(@{Type="Created"; Data=$e}) | Out-Null
            })
            $eventBus.Subscribe([EventNames]::ProjectUpdated, {
                param($s, $e)
                $events.Add(@{Type="Updated"; Data=$e}) | Out-Null
            })
            $eventBus.Subscribe([EventNames]::ProjectDeleted, {
                param($s, $e)
                $events.Add(@{Type="Deleted"; Data=$e}) | Out-Null
            })
            
            # Create
            $project = $projectService.AddProject("Test Project")
            $project | Should -Not -BeNull
            $project.FullProjectName | Should -Be "Test Project"
            
            # Read
            $projects = $projectService.GetAllProjects()
            $projects | Should -Contain $project
            
            # Update
            $project.FullProjectName = "Updated Project"
            $projectService.UpdateProject($project)
            
            # Delete
            $projectService.DeleteProject($project.Id)
            
            # Verify events were fired
            $events.Count | Should -Be 3
            $events[0].Type | Should -Be "Created"
            $events[1].Type | Should -Be "Updated"
            $events[2].Type | Should -Be "Deleted"
        }
    }
    
    Context "Action Popup Integration" {
        It "Should show action popup and execute actions" {
            $mainScreen = [MainScreen]::new()
            $mainScreen.Initialize($container)
            $mainScreen.SetBounds(0, 0, 80, 24)
            
            # Switch to Projects screen
            $mainScreen.SwitchToScreen("Projects")
            
            # Show action popup
            $mainScreen.ShowActionPopup()
            $mainScreen.ActionPopup | Should -Not -BeNull
            $mainScreen.ActionPopup.IsVisible | Should -Be $true
            
            # Verify actions are available
            $actionTexts = $mainScreen.ActionPopup.Items | ForEach-Object { $_.Text }
            $actionTexts | Should -Contain "New Project (n)"
            
            # Simulate selecting an action with space
            $spaceKey = New-ConsoleKeyInfo -KeyChar ' '
            $handled = $mainScreen.ActionPopup.HandleInput($spaceKey)
            $handled | Should -Be $true
        }
    }
    
    Context "Focus Management Flow" {
        It "Should manage focus correctly across components" {
            $focusManager = $container.GetService('FocusManager')
            $mainScreen = [MainScreen]::new()
            $mainScreen.Initialize($container)
            $mainScreen.SetBounds(0, 0, 80, 24)
            
            # Initially menu should be focused
            $mainScreen.OnActivated()
            $focused = $focusManager.GetFocused()
            $focused | Should -Be $mainScreen.MenuList
            
            # Switch focus to content
            $mainScreen.SwitchToScreen("Projects")
            $mainScreen.SwitchFocusToContent()
            
            $focused = $focusManager.GetFocused()
            $focused | Should -Not -Be $mainScreen.MenuList
        }
    }
    
    Context "Theme Integration" {
        It "Should apply theme to all components" {
            $themeManager = $container.GetService('ThemeManager')
            $mainScreen = [MainScreen]::new()
            $mainScreen.Initialize($container)
            
            # Components should have theme
            $mainScreen.Theme | Should -Not -BeNull
            $mainScreen.MenuList.Theme | Should -Not -BeNull
            $mainScreen.StatusBar.Theme | Should -Not -BeNull
            
            # Switch theme
            $themeManager.LoadTheme('Monochrome')
            
            # Theme should be updated
            $currentTheme = $themeManager.GetCurrentTheme()
            $currentTheme.Name | Should -Be 'Monochrome'
        }
    }
    
    Context "Error Handling" {
        It "Should handle missing services gracefully" {
            $emptyContainer = [ServiceContainer]::new()
            $screen = [ProjectsScreen]::new()
            
            # Should not throw even with missing services
            { $screen.Initialize($emptyContainer) } | Should -Not -Throw
        }
        
        It "Should handle invalid input gracefully" {
            $mainScreen = [MainScreen]::new()
            $mainScreen.Initialize($container)
            
            # Invalid key should not throw
            $invalidKey = New-ConsoleKeyInfo -KeyChar ([char]0) -Key ([System.ConsoleKey]::NoName)
            { $mainScreen.HandleInput($invalidKey) } | Should -Not -Throw
        }
    }
    
    Context "Performance Under Load" {
        It "Should handle rapid screen switching" {
            $mainScreen = [MainScreen]::new()
            $mainScreen.Initialize($container)
            $mainScreen.SetBounds(0, 0, 80, 24)
            
            # Add data to services
            $projectService = $container.GetService('ProjectService')
            for ($i = 1; $i -le 50; $i++) {
                $projectService.AddProject("Project $i") | Out-Null
            }
            
            # Rapid screen switching
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            for ($i = 0; $i -lt 20; $i++) {
                $mainScreen.SwitchToScreen("Projects")
                $mainScreen.SwitchToScreen("Tasks")
            }
            $stopwatch.Stop()
            
            # Should complete 40 switches in under 2 seconds
            $stopwatch.ElapsedMilliseconds | Should -BeLessThan 2000
        }
    }
}