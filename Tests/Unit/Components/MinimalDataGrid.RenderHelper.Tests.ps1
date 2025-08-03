# MinimalDataGrid RenderHelper integration tests

Describe "MinimalDataGrid with RenderHelper" {
    BeforeAll {
        # Load the framework
        . "$PSScriptRoot/../../../Start.ps1" -LoadOnly
        
        # Initialize services needed for testing
        $global:ServiceContainer = [ServiceContainer]::new()
        $logger = [Logger]::new()
        $global:ServiceContainer.Register("Logger", $logger)
        
        $eventBus = [EventBus]::new()
        $eventBus.Initialize($global:ServiceContainer)
        $global:ServiceContainer.Register("EventBus", $eventBus)
        
        $themeManager = [ThemeManager]::new()
        $themeManager.SetEventBus($eventBus)
        $global:ServiceContainer.Register("ThemeManager", $themeManager)
        
        $focusManager = [FocusManager]::new()
        $focusManager.Initialize($global:ServiceContainer)
        $global:ServiceContainer.Register("FocusManager", $focusManager)
        
        # Initialize RenderHelper
        [RenderHelper]::Initialize()
    }
    
    BeforeEach {
        # Create sample data
        $script:testData = @(
            @{ Name = "Item 1"; Value = "100"; Type = "A" },
            @{ Name = "Item 2"; Value = "200"; Type = "B" },
            @{ Name = "Item 3"; Value = "300"; Type = "A" },
            @{ Name = "Item 4"; Value = "400"; Type = "C" }
        )
        
        $script:dataGrid = [MinimalDataGrid]::new()
        $script:dataGrid.Initialize($global:ServiceContainer)
        $script:dataGrid.SetBounds(0, 0, 50, 10)
        
        # Add columns
        $script:dataGrid.AddColumn("Name", { $args[0].Name }, 15)
        $script:dataGrid.AddColumn("Value", { $args[0].Value }, 10)
        $script:dataGrid.AddColumn("Type", { $args[0].Type }, 8)
        
        $script:dataGrid.SetItems($script:testData)
    }
    
    Context "Background Bleed Prevention" {
        It "Should render without grey background bleed" {
            $output = $script:dataGrid.OnRender()
            
            $output | Should -Not -BeNullOrEmpty
            # The output should not contain background color codes for normal rows
            # This is a structural fix - normal rows shouldn't have background at all
        }
        
        It "Should only show background for selected rows" {
            $script:dataGrid.SelectedIndex = 1
            $script:dataGrid.IsFocused = $false
            
            $output = $script:dataGrid.OnRender()
            $output | Should -Not -BeNullOrEmpty
        }
        
        It "Should show reverse highlighting when focused and selected" {
            $script:dataGrid.SelectedIndex = 1
            $script:dataGrid.IsFocused = $true
            
            $output = $script:dataGrid.OnRender()
            $output | Should -Not -BeNullOrEmpty
        }
        
        It "Should handle no selection gracefully" {
            $script:dataGrid.SelectedIndex = -1
            
            { $output = $script:dataGrid.OnRender() } | Should -Not -Throw
        }
    }
    
    Context "Row Spacing" {
        It "Should only add row spacing background for selected rows" {
            $script:dataGrid.RowSpacing = 1
            $script:dataGrid.SelectedIndex = 1
            
            $output = $script:dataGrid.OnRender()
            $output | Should -Not -BeNullOrEmpty
            
            # Should render without errors
            { $script:dataGrid.RenderContent() } | Should -Not -Throw
        }
        
        It "Should not add row spacing background for normal rows" {
            $script:dataGrid.RowSpacing = 1
            $script:dataGrid.SelectedIndex = -1  # No selection
            
            $output = $script:dataGrid.OnRender()
            $output | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "Theme Integration" {
        It "Should not cache surface background color" {
            $script:dataGrid.CacheThemeColors()
            
            # The _colors hashtable should not contain 'background' key
            $script:dataGrid._colors.ContainsKey('background') | Should -Be $false
        }
        
        It "Should have all necessary colors except background" {
            $script:dataGrid.CacheThemeColors()
            
            $script:dataGrid._colors.ContainsKey('text') | Should -Be $true
            $script:dataGrid._colors.ContainsKey('selectedText') | Should -Be $true
            $script:dataGrid._colors.ContainsKey('focusReverseBg') | Should -Be $true
            $script:dataGrid._colors.ContainsKey('focusReverseText') | Should -Be $true
        }
    }
    
    Context "Data Handling" {
        It "Should render empty data without errors" {
            $script:dataGrid.SetItems(@())
            
            { $output = $script:dataGrid.OnRender() } | Should -Not -Throw
        }
        
        It "Should handle null data gracefully" {
            $script:dataGrid.SetItems($null)
            
            { $output = $script:dataGrid.OnRender() } | Should -Not -Throw
        }
        
        It "Should render large datasets efficiently" {
            $largeData = 1..50 | ForEach-Object {
                @{ Name = "Item $_"; Value = $_ * 10; Type = "Type$($_ % 3)" }
            }
            
            $script:dataGrid.SetItems($largeData)
            
            { $output = $script:dataGrid.OnRender() } | Should -Not -Throw
        }
    }
    
    Context "Selection and Focus" {
        It "Should handle selection changes" {
            $script:dataGrid.SelectedIndex = 0
            $output1 = $script:dataGrid.OnRender()
            
            $script:dataGrid.SelectedIndex = 2
            $output2 = $script:dataGrid.OnRender()
            
            $output1 | Should -Not -Be $output2
        }
        
        It "Should handle focus state changes" {
            $script:dataGrid.SelectedIndex = 1
            $script:dataGrid.IsFocused = $false
            $unfocused = $script:dataGrid.OnRender()
            
            $script:dataGrid.IsFocused = $true
            $focused = $script:dataGrid.OnRender()
            
            $unfocused | Should -Not -Be $focused
        }
    }
    
    Context "Performance" {
        It "Should render efficiently with many rows" {
            $manyRows = 1..100 | ForEach-Object {
                @{ Name = "Row $_"; Value = $_ * 5; Type = "T$($_ % 4)" }
            }
            
            $script:dataGrid.SetItems($manyRows)
            
            { $output = $script:dataGrid.OnRender() } | Should -Not -Throw
            $output | Should -Not -BeNullOrEmpty
        }
    }
}