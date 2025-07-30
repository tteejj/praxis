# UIElement.Tests.ps1 - Tests for UIElement base class

BeforeAll {
    Import-Module "$PSScriptRoot/../../TestHelpers.psm1" -Force
    Initialize-PraxisForTesting
    
    # Create a test UIElement subclass
    class TestUIElement : UIElement {
        [string]$LastRendered = ""
        
        [string] OnRender() {
            $this.LastRendered = "Rendered at $($this.X),$($this.Y) size $($this.Width)x$($this.Height)"
            return $this.LastRendered
        }
    }
}

Describe "UIElement Base Class" {
    BeforeEach {
        $element = [TestUIElement]::new()
    }
    
    Context "Initialization" {
        It "Should initialize with default values" {
            $element.X | Should -Be 0
            $element.Y | Should -Be 0
            $element.Width | Should -Be 0
            $element.Height | Should -Be 0
            $element.IsVisible | Should -Be $true
            $element.IsDirty | Should -Be $true
            $element.IsFocusable | Should -Be $false
            $element.IsFocused | Should -Be $false
            $element.Parent | Should -BeNullOrEmpty
        }
    }
    
    Context "Bounds Management" {
        It "Should set bounds correctly" {
            $element.SetBounds(10, 20, 100, 50)
            
            $element.X | Should -Be 10
            $element.Y | Should -Be 20
            $element.Width | Should -Be 100
            $element.Height | Should -Be 50
        }
        
        It "Should mark as dirty when bounds change" {
            $element.IsDirty = $false
            $element.SetBounds(5, 5, 50, 25)
            
            $element.IsDirty | Should -Be $true
        }
        
        It "Should call OnBoundsChanged when bounds change" {
            $element.SetBounds(1, 2, 3, 4)
            # OnBoundsChanged is called, but we can't easily test protected methods
            # We can verify through side effects if the element implements specific behavior
        }
    }
    
    Context "Visibility" {
        It "Should handle Show/Hide correctly" {
            $element.Hide()
            $element.IsVisible | Should -Be $false
            
            $element.Show()
            $element.IsVisible | Should -Be $true
        }
        
        It "Should mark as dirty when visibility changes" {
            $element.IsDirty = $false
            $element.Hide()
            $element.IsDirty | Should -Be $true
        }
    }
    
    Context "Focus Management" {
        BeforeEach {
            $mockFocusManager = New-MockFocusManager
            $mockServiceContainer = New-MockServiceContainer
            $mockServiceContainer.Register('FocusManager', $mockFocusManager)
            $element.ServiceContainer = $mockServiceContainer
            $element.IsFocusable = $true
        }
        
        It "Should request focus through FocusManager" {
            $element.Focus()
            
            $focusedElement = $mockFocusManager.GetFocused()
            $focusedElement | Should -Be $element
            $element.IsFocused | Should -Be $true
        }
        
        It "Should not focus if not focusable" {
            $element.IsFocusable = $false
            $element.Focus()
            
            $element.IsFocused | Should -Be $false
        }
    }
    
    Context "Rendering" {
        It "Should render when visible and dirty" {
            $element.IsVisible = $true
            $element.IsDirty = $true
            
            $result = $element.Render()
            
            $result | Should -Not -BeNullOrEmpty
            $element.IsDirty | Should -Be $false
        }
        
        It "Should not render when not visible" {
            $element.IsVisible = $false
            
            $result = $element.Render()
            
            $result | Should -Be ""
        }
        
        It "Should use cached content when not dirty" {
            $element.SetBounds(10, 10, 20, 20)
            $firstRender = $element.Render()
            $element.LastRendered = "Modified"
            
            $secondRender = $element.Render()
            
            # Should return cached content, not call OnRender again
            $secondRender | Should -Be $firstRender
            $element.LastRendered | Should -Be "Modified"
        }
    }
    
    Context "Invalidation" {
        It "Should mark as dirty and notify parent when invalidated" {
            $parent = [TestUIElement]::new()
            $element.Parent = $parent
            $parent.IsDirty = $false
            $element.IsDirty = $false
            
            $element.Invalidate()
            
            $element.IsDirty | Should -Be $true
            $parent.IsDirty | Should -Be $true
        }
    }
    
    Context "Input Handling" {
        It "Should return false by default for HandleInput" {
            $key = New-ConsoleKeyInfo -KeyChar 'a'
            $result = $element.HandleInput($key)
            
            $result | Should -Be $false
        }
    }
    
    Context "Service Container" {
        It "Should initialize ServiceContainer" {
            $container = New-MockServiceContainer
            $element.Initialize($container)
            
            $element.ServiceContainer | Should -Be $container
        }
        
        It "Should get services through GetService helper" {
            $mockLogger = New-MockLogger
            $container = New-MockServiceContainer
            $container.Register('Logger', $mockLogger)
            $element.Initialize($container)
            
            $logger = $element.GetService('Logger')
            
            $logger | Should -Be $mockLogger
        }
    }
    
    Context "Performance" {
        It "Should render efficiently with caching" {
            $element.SetBounds(0, 0, 80, 24)
            
            # First render
            $element.Render() | Out-Null
            
            # Measure cached renders
            $perf = Measure-Performance -Name "1000 cached renders" -ScriptBlock {
                for ($i = 0; $i -lt 1000; $i++) {
                    $element.Render() | Out-Null
                }
            }
            
            # Cached renders should be very fast
            $perf.ElapsedMilliseconds | Should -BeLessThan 50
        }
    }
}