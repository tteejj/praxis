# GradientDemoScreen.ps1 - Showcase gradient effects with Synthwave theme

class GradientDemoScreen : Screen {
    [GradientButton]$DemoButton1
    [GradientButton]$DemoButton2
    [GradientButton]$DemoButton3
    [MinimalButton]$BackButton
    
    GradientDemoScreen() : base() {
        $this.Title = "Gradient Effects Demo"
        $this.DrawBackground = $true
    }
    
    [void] OnInitialize() {
        ([Screen]$this).OnInitialize()
        
        # Create gradient buttons with different styles
        $this.DemoButton1 = [GradientButton]::new("Neon Glow")
        $this.DemoButton1.OnClick = { 
            if ($global:Logger) {
                $global:Logger.Info("Neon Glow button clicked!")
            }
        }.GetNewClosure()
        $this.DemoButton1.Initialize($this.ServiceContainer)
        $this.AddChild($this.DemoButton1)
        
        $this.DemoButton2 = [GradientButton]::new("Sunset Vibes")
        $this.DemoButton2.GradientStartKey = "gradient.sunset.start"
        $this.DemoButton2.GradientEndKey = "gradient.sunset.end"
        $this.DemoButton2.OnClick = { 
            if ($global:Logger) {
                $global:Logger.Info("Sunset Vibes button clicked!")
            }
        }.GetNewClosure()
        $this.DemoButton2.Initialize($this.ServiceContainer)
        $this.AddChild($this.DemoButton2)
        
        $this.DemoButton3 = [GradientButton]::new("Error State")
        $this.DemoButton3.GradientStartKey = "gradient.error.start"
        $this.DemoButton3.GradientEndKey = "gradient.error.end"
        $this.DemoButton3.OnClick = { 
            if ($global:Logger) {
                $global:Logger.Info("Error State button clicked!")
            }
        }.GetNewClosure()
        $this.DemoButton3.Initialize($this.ServiceContainer)
        $this.AddChild($this.DemoButton3)
        
        # Regular button for comparison
        $this.BackButton = [MinimalButton]::new("Back (ESC)")
        $this.BackButton.OnClick = { 
            if ($global:ScreenManager) {
                $global:ScreenManager.Pop()
            }
        }.GetNewClosure()
        $this.BackButton.Initialize($this.ServiceContainer)
        $this.AddChild($this.BackButton)
        
        # Focus first button
        if ($this.DemoButton1) {
            $this.DemoButton1.Focus()
        }
    }
    
    [void] OnBoundsChanged() {
        # Center buttons vertically and horizontally
        $centerX = [Math]::Floor($this.Width / 2)
        $centerY = [Math]::Floor($this.Height / 2)
        
        $buttonWidth = 20
        $buttonSpacing = 5
        
        # Position gradient buttons
        $this.DemoButton1.SetBounds(
            $centerX - $buttonWidth / 2,
            $centerY - 6,
            $buttonWidth,
            3
        )
        
        $this.DemoButton2.SetBounds(
            $centerX - $buttonWidth / 2,
            $centerY - 2,
            $buttonWidth,
            3
        )
        
        $this.DemoButton3.SetBounds(
            $centerX - $buttonWidth / 2,
            $centerY + 2,
            $buttonWidth,
            3
        )
        
        # Back button at bottom
        $this.BackButton.SetBounds(
            $centerX - 8,
            $this.Height - 3,
            16,
            1
        )
    }
    
    [string] OnRender() {
        $sb = Get-PooledStringBuilder 2048
        
        # Clear background
        if ($this.DrawBackground) {
            $bg = $this.Theme.GetBgColor('background')
            for ($y = 0; $y -lt $this.Height; $y++) {
                $sb.Append([VT]::MoveTo($this.X, $this.Y + $y))
                $sb.Append($bg)
                $sb.Append(' ' * $this.Width)
            }
        }
        
        # Title
        $titleColor = $this.Theme.GetColor('title')
        $titleX = $this.X + [Math]::Floor(($this.Width - $this.Title.Length) / 2)
        $sb.Append([VT]::MoveTo($titleX, $this.Y + 2))
        $sb.Append($titleColor)
        $sb.Append($this.Title)
        
        # Instructions
        $infoColor = $this.Theme.GetColor('disabled')
        $info = "Tab to navigate, Enter to click"
        $infoX = $this.X + [Math]::Floor(($this.Width - $info.Length) / 2)
        $sb.Append([VT]::MoveTo($infoX, $this.Y + 4))
        $sb.Append($infoColor)
        $sb.Append($info)
        
        # Render children (buttons)
        $sb.Append(([Screen]$this).OnRender())
        
        $sb.Append([VT]::Reset())
        
        $result = $sb.ToString()
        Return-PooledStringBuilder $sb
        return $result
    }
    
    [bool] HandleScreenInput([System.ConsoleKeyInfo]$key) {
        if ($key.Key -eq [System.ConsoleKey]::Escape) {
            if ($global:ScreenManager) {
                $global:ScreenManager.Pop()
            }
            return $true
        }
        return $false
    }
}