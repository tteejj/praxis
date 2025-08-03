# MinimalButton RenderHelper integration tests

Describe "MinimalButton with RenderHelper" {
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
        $script:button = [MinimalButton]::new("Test Button")
        $script:button.Initialize($global:ServiceContainer)
        $script:button.SetBounds(0, 0, 15, 3)
    }
    
    Context "RenderHelper Integration" {
        It "Should render button without negative padding errors" {
            # Test with very narrow button (would cause negative padding)
            $script:button.SetBounds(0, 0, 8, 3)  # Width 8, text "Test Button" is 11 chars
            
            { $output = $script:button.RenderContent() } | Should -Not -Throw
            $output = $script:button.RenderContent()
            $output | Should -Not -BeNullOrEmpty
        }
        
        It "Should render focused button with reverse highlighting" {
            $script:button.IsFocused = $true
            $output = $script:button.RenderContent()
            
            $output | Should -Not -BeNullOrEmpty
            $output.Length | Should -BeGreaterThan 0
        }
        
        It "Should render unfocused button normally" {
            $script:button.IsFocused = $false
            $output = $script:button.RenderContent()
            
            $output | Should -Not -BeNullOrEmpty
            $output.Length | Should -BeGreaterThan 0
        }
        
        It "Should handle default button indicator" {
            $script:button.IsDefault = $true
            $output = $script:button.RenderContent()
            
            $output | Should -Not -BeNullOrEmpty
            # Default buttons should have the "•" indicator
        }
        
        It "Should handle empty text" {
            $emptyButton = [MinimalButton]::new("")
            $emptyButton.Initialize($global:ServiceContainer)
            $emptyButton.SetBounds(0, 0, 10, 3)
            
            { $output = $emptyButton.RenderContent() } | Should -Not -Throw
        }
        
        It "Should handle very long text" {
            $longButton = [MinimalButton]::new("This is a very long button text that exceeds the width")
            $longButton.Initialize($global:ServiceContainer)
            $longButton.SetBounds(0, 0, 20, 3)
            
            { $output = $longButton.RenderContent() } | Should -Not -Throw
        }
    }
    
    Context "RenderHelper Button Methods" {
        It "Should render button content safely" {
            $theme = $global:ServiceContainer.GetService("ThemeManager")
            
            # Normal button
            $normal = [RenderHelper]::RenderButtonContent("Test", 10, $theme, $false)
            $normal | Should -Not -BeNullOrEmpty
            
            # Focused button
            $focused = [RenderHelper]::RenderButtonContent("Test", 10, $theme, $true)
            $focused | Should -Not -BeNullOrEmpty
            
            # Should be different
            $normal | Should -Not -Be $focused
        }
        
        It "Should handle narrow width gracefully" {
            $theme = $global:ServiceContainer.GetService("ThemeManager")
            
            # Text longer than available width
            { $output = [RenderHelper]::RenderButtonContent("Long Text", 5, $theme, $false) } | Should -Not -Throw
        }
        
        It "Should calculate padding safely for various scenarios" {
            # Normal case
            [RenderHelper]::CalculatePadding(10, 5, 0) | Should -Be 5
            
            # Width too small
            [RenderHelper]::CalculatePadding(5, 10, 0) | Should -Be 0
            
            # With minimum padding
            [RenderHelper]::CalculatePadding(3, 5, 2) | Should -Be 2
        }
    }
    
    Context "Edge Cases" {
        It "Should handle minimum button size" {
            $script:button.SetBounds(0, 0, 3, 3)  # Minimum size
            
            { $output = $script:button.RenderContent() } | Should -Not -Throw
        }
        
        It "Should handle zero width gracefully" {
            $script:button.SetBounds(0, 0, 0, 3)
            
            { $output = $script:button.RenderContent() } | Should -Not -Throw
        }
        
        It "Should render consistently multiple times" {
            $output1 = $script:button.RenderContent()
            $output2 = $script:button.RenderContent()
            
            $output1 | Should -Be $output2
        }
    }
}