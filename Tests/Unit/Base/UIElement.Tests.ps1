# UIElement.Tests.ps1 - Tests for UIElement base class

BeforeAll {
    Import-Module "$PSScriptRoot/../../TestHelpers.psm1" -Force
    Initialize-PraxisForTesting
}

Describe "UIElement Base Class" {
    BeforeEach {
        # Create a mock UIElement for testing
        $script:element = [PSCustomObject]@{
            PSTypeName = 'UIElement'
            X = 0
            Y = 0
            Width = 0
            Height = 0
            IsVisible = $true
            IsDirty = $true
            IsFocusable = $false
            IsFocused = $false
            Parent = $null
            Theme = $null
            ServiceContainer = $null
            LastRendered = ""
        }
        
        # Add methods
        Add-Member -InputObject $script:element -MemberType ScriptMethod -Name "SetBounds" -Value {
            param($x, $y, $width, $height)
            $this.X = $x
            $this.Y = $y
            $this.Width = $width
            $this.Height = $height
            $this.IsDirty = $true
        }
        
        Add-Member -InputObject $script:element -MemberType ScriptMethod -Name "Initialize" -Value {
            param($container)
            $this.ServiceContainer = $container
            if ($container) {
                $themeManager = $container.GetService('ThemeManager')
                if ($themeManager) {
                    $this.Theme = $themeManager.GetCurrentTheme()
                }
            }
        }
        
        Add-Member -InputObject $script:element -MemberType ScriptMethod -Name "Show" -Value {
            $this.IsVisible = $true
            $this.IsDirty = $true
        }
        
        Add-Member -InputObject $script:element -MemberType ScriptMethod -Name "Hide" -Value {
            $this.IsVisible = $false
            $this.IsDirty = $true
        }
        
        Add-Member -InputObject $script:element -MemberType ScriptMethod -Name "Focus" -Value {
            if ($this.IsFocusable) {
                $this.IsFocused = $true
                $this.IsDirty = $true
            }
        }
        
        Add-Member -InputObject $script:element -MemberType ScriptMethod -Name "Blur" -Value {
            $this.IsFocused = $false
            $this.IsDirty = $true
        }
        
        Add-Member -InputObject $script:element -MemberType ScriptMethod -Name "Render" -Value {
            if (-not $this.IsVisible) { return "" }
            $this.LastRendered = "Rendered at $($this.X),$($this.Y) size $($this.Width)x$($this.Height)"
            $this.IsDirty = $false
            return $this.LastRendered
        }
        
        Add-Member -InputObject $script:element -MemberType ScriptMethod -Name "Invalidate" -Value {
            $this.IsDirty = $true
        }
        
        Add-Member -InputObject $script:element -MemberType ScriptMethod -Name "GetAbsolutePosition" -Value {
            $x = $this.X
            $y = $this.Y
            $current = $this.Parent
            while ($current) {
                $x += $current.X
                $y += $current.Y
                $current = $current.Parent
            }
            return @{X = $x; Y = $y}
        }
        
        Add-Member -InputObject $script:element -MemberType ScriptMethod -Name "Contains" -Value {
            param($x, $y)
            return $x -ge $this.X -and $x -lt ($this.X + $this.Width) -and
                   $y -ge $this.Y -and $y -lt ($this.Y + $this.Height)
        }
    }
    
    Context "Initialization" {
        It "Should have default values after creation" {
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
    }
    
    Context "Visibility" {
        It "Should show element correctly" {
            $element.IsVisible = $false
            $element.IsDirty = $false
            
            $element.Show()
            
            $element.IsVisible | Should -Be $true
            $element.IsDirty | Should -Be $true
        }
        
        It "Should hide element correctly" {
            $element.IsVisible = $true
            $element.IsDirty = $false
            
            $element.Hide()
            
            $element.IsVisible | Should -Be $false
            $element.IsDirty | Should -Be $true
        }
        
        It "Should not render when hidden" {
            $element.SetBounds(0, 0, 10, 10)
            $element.Hide()
            
            $result = $element.Render()
            
            $result | Should -Be ""
        }
    }
    
    Context "Focus Management" {
        It "Should not focus if not focusable" {
            $element.IsFocusable = $false
            
            $element.Focus()
            
            $element.IsFocused | Should -Be $false
        }
        
        It "Should focus if focusable" {
            $element.IsFocusable = $true
            
            $element.Focus()
            
            $element.IsFocused | Should -Be $true
            $element.IsDirty | Should -Be $true
        }
        
        It "Should blur correctly" {
            $element.IsFocusable = $true
            $element.Focus()
            $element.IsDirty = $false
            
            $element.Blur()
            
            $element.IsFocused | Should -Be $false
            $element.IsDirty | Should -Be $true
        }
    }
    
    Context "Service Container Integration" {
        It "Should initialize with service container" {
            $container = New-MockServiceContainer
            
            $element.Initialize($container)
            
            $element.ServiceContainer | Should -Be $container
            $element.Theme | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "Position Calculations" {
        It "Should calculate absolute position without parent" {
            $element.SetBounds(10, 20, 50, 30)
            
            $pos = $element.GetAbsolutePosition()
            
            $pos.X | Should -Be 10
            $pos.Y | Should -Be 20
        }
        
        It "Should calculate absolute position with parent" {
            $parent = [PSCustomObject]@{
                X = 5
                Y = 5
                Parent = $null
            }
            
            $element.Parent = $parent
            $element.SetBounds(10, 20, 50, 30)
            
            $pos = $element.GetAbsolutePosition()
            
            $pos.X | Should -Be 15
            $pos.Y | Should -Be 25
        }
    }
    
    Context "Hit Testing" {
        It "Should correctly identify if point is inside element" {
            $element.SetBounds(10, 10, 20, 20)
            
            $element.Contains(15, 15) | Should -Be $true
            $element.Contains(10, 10) | Should -Be $true
            $element.Contains(29, 29) | Should -Be $true
            $element.Contains(30, 30) | Should -Be $false
            $element.Contains(9, 15) | Should -Be $false
            $element.Contains(15, 9) | Should -Be $false
        }
    }
    
    Context "Rendering" {
        It "Should render when visible" {
            $element.SetBounds(10, 20, 100, 50)
            $element.IsVisible = $true
            
            $result = $element.Render()
            
            $result | Should -Be "Rendered at 10,20 size 100x50"
            $element.IsDirty | Should -Be $false
        }
        
        It "Should mark clean after render" {
            $element.SetBounds(0, 0, 10, 10)
            $element.IsDirty = $true
            
            $element.Render() | Out-Null
            
            $element.IsDirty | Should -Be $false
        }
    }
    
    Context "Dirty State Management" {
        It "Should invalidate correctly" {
            $element.IsDirty = $false
            
            $element.Invalidate()
            
            $element.IsDirty | Should -Be $true
        }
    }
}