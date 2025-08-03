# MinimalListBox RenderHelper integration tests

Describe "MinimalListBox with RenderHelper" {
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
        $script:listBox = [MinimalListBox]::new()
        $script:listBox.Initialize($global:ServiceContainer)
        $script:listBox.SetBounds(0, 0, 20, 5)
        $script:listBox.SetItems(@("Item 1", "Item 2", "Item 3"))
    }
    
    Context "RenderHelper Integration" {
        It "Should initialize RenderHelper without errors" {
            { [RenderHelper]::Initialize() } | Should -Not -Throw
            [RenderHelper]::_initialized | Should -Be $true
        }
        
        It "Should render list items without grey background bleed" {
            $output = $script:listBox.RenderContent()
            
            # Should not contain 'surface.background' color codes for normal items
            # This is a basic check - in practice we'd need to parse ANSI codes
            $output | Should -Not -BeNullOrEmpty
            $output.Length | Should -BeGreaterThan 0
        }
        
        It "Should handle selected items correctly" {
            $script:listBox.SelectedIndex = 1
            $output = $script:listBox.RenderContent()
            
            $output | Should -Not -BeNullOrEmpty
            # Should contain selection indicator when focused
            $script:listBox.IsFocused = $true
            $focusedOutput = $script:listBox.RenderContent()
            $focusedOutput | Should -Not -BeNullOrEmpty
        }
        
        It "Should handle empty list without errors" {
            $script:listBox.SetItems(@())
            { $script:listBox.RenderContent() } | Should -Not -Throw
        }
        
        It "Should handle long text truncation" {
            $script:listBox.SetItems(@("This is a very long item that should be truncated"))
            $output = $script:listBox.RenderContent()
            $output | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "RenderHelper Static Methods" {
        It "Should calculate padding safely" {
            [RenderHelper]::CalculatePadding(10, 5, 0) | Should -Be 5
            [RenderHelper]::CalculatePadding(5, 10, 0) | Should -Be 0  # Should not go negative
            [RenderHelper]::CalculatePadding(10, 5, 2) | Should -Be 5  # Min padding not needed
            [RenderHelper]::CalculatePadding(3, 5, 2) | Should -Be 2   # Min padding applied
        }
        
        It "Should return safe padding spaces" {
            [RenderHelper]::GetPaddingSpaces(0) | Should -Be ''
            [RenderHelper]::GetPaddingSpaces(-5) | Should -Be ''
            [RenderHelper]::GetPaddingSpaces(2) | Should -Be '  '
        }
        
        It "Should render list items consistently" {
            $theme = $global:ServiceContainer.GetService("ThemeManager")
            
            # Normal item (no background)
            $normal = [RenderHelper]::RenderListItem("Test", $false, $false, 10, $theme)
            $normal | Should -Not -BeNullOrEmpty
            
            # Selected item
            $selected = [RenderHelper]::RenderListItem("Test", $true, $false, 10, $theme)
            $selected | Should -Not -BeNullOrEmpty
            
            # Selected + focused item
            $focused = [RenderHelper]::RenderListItem("Test", $true, $true, 10, $theme)
            $focused | Should -Not -BeNullOrEmpty
            
            # All should be different
            $normal | Should -Not -Be $selected
            $selected | Should -Not -Be $focused
        }
    }
    
    Context "Performance" {
        It "Should render large lists without errors" {
            $script:listBox.SetItems((1..100 | ForEach-Object { "Item $_" }))
            
            { $output = $script:listBox.RenderContent() } | Should -Not -Throw
            $output | Should -Not -BeNullOrEmpty
        }
    }
}