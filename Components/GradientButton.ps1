# GradientButton.ps1 - Button with gradient border effects (Synthwave showcase)

class GradientButton : FocusableComponent {
    [string]$Text = "Button"
    [scriptblock]$OnClick = {}
    [bool]$IsDefault = $false
    [int]$Padding = 2
    [bool]$UseGradient = $true
    
    # Gradient settings
    [int]$GradientSteps = 10
    [string]$GradientStartKey = "gradient.border.start"
    [string]$GradientEndKey = "gradient.border.end"
    
    # Cached colors
    hidden [hashtable]$_colors = @{}
    hidden [string[]]$_gradientColors = @()
    
    GradientButton() : base() {
        $this.Height = 3  # Need height for gradient effect
        $this.FocusStyle = 'highlight'
    }
    
    GradientButton([string]$text) : base() {
        $this.Text = $text
        $this.Height = 3
        $this.FocusStyle = 'highlight'
    }
    
    [void] OnInitialize() {
        ([FocusableComponent]$this).OnInitialize()
        $this.UpdateColors()
        if ($this.Theme) {
            # Subscribe to theme changes
            $eventBus = $this.ServiceContainer.GetService('EventBus')
            if ($eventBus) {
                $eventBus.Subscribe('theme.changed', {
                    param($sender, $eventData)
                    $this.UpdateColors()
                }.GetNewClosure())
            }
        }
    }
    
    [void] UpdateColors() {
        if ($this.Theme) {
            $this._colors = @{
                normal = $this.Theme.GetColor('button.foreground')
                bg = $this.Theme.GetBgColor('button.background')
                focused = $this.Theme.GetColor('button.focused.foreground')
                focusedBg = $this.Theme.GetBgColor('button.focused.background')
                border = $this.Theme.GetColor('border')
                accent = $this.Theme.GetColor('accent')
            }
            
            # Get gradient colors
            if ($this.UseGradient) {
                $this._gradientColors = $this.Theme.GetGradient(
                    $this.GradientStartKey, 
                    $this.GradientEndKey, 
                    $this.Width
                )
            }
        }
    }
    
    [string] RenderContent() {
        $sb = Get-PooledStringBuilder 512
        
        # Draw gradient border or regular border
        if ($this.UseGradient -and $this._gradientColors.Count -gt 0 -and $this.IsFocused) {
            $this.RenderGradientBorder($sb)
        } else {
            $this.RenderRegularBorder($sb)
        }
        
        # Draw text in center
        $textY = $this.Y + 1
        $textX = $this.X + [Math]::Floor(($this.Width - $this.Text.Length) / 2)
        
        $sb.Append([VT]::MoveTo($textX, $textY))
        
        if ($this.IsFocused) {
            $sb.Append($this._colors.focusedBg)
            $sb.Append($this._colors.focused)
        } else {
            $sb.Append($this._colors.bg)
            $sb.Append($this._colors.normal)
        }
        
        $sb.Append($this.Text)
        
        # Default indicator
        if ($this.IsDefault) {
            $sb.Append(' •')
        }
        
        $sb.Append([VT]::Reset())
        
        $result = $sb.ToString()
        Return-PooledStringBuilder $sb
        return $result
    }
    
    [void] RenderGradientBorder([System.Text.StringBuilder]$sb) {
        # Top border with gradient
        $sb.Append([VT]::MoveTo($this.X, $this.Y))
        $gradientIndex = 0
        $step = [Math]::Max(1, [Math]::Floor($this._gradientColors.Count / $this.Width))
        
        for ($i = 0; $i -lt $this.Width; $i++) {
            $colorIndex = [Math]::Min($gradientIndex, $this._gradientColors.Count - 1)
            $sb.Append($this._gradientColors[$colorIndex])
            $sb.Append('─')
            $gradientIndex += $step
        }
        
        # Side borders with vertical gradient effect
        $sideGradient = $this.Theme.GetGradient(
            $this.GradientStartKey,
            $this.GradientEndKey,
            $this.Height
        )
        
        # Left border
        $sb.Append($sideGradient[0])
        $sb.Append([VT]::MoveTo($this.X, $this.Y))
        $sb.Append('┌')
        $sb.Append([VT]::MoveTo($this.X, $this.Y + 1))
        $sb.Append($sideGradient[1])
        $sb.Append('│')
        $sb.Append([VT]::MoveTo($this.X, $this.Y + 2))
        $sb.Append($sideGradient[2])
        $sb.Append('└')
        
        # Right border
        $sb.Append($sideGradient[0])
        $sb.Append([VT]::MoveTo($this.X + $this.Width - 1, $this.Y))
        $sb.Append('┐')
        $sb.Append([VT]::MoveTo($this.X + $this.Width - 1, $this.Y + 1))
        $sb.Append($sideGradient[1])
        $sb.Append('│')
        $sb.Append([VT]::MoveTo($this.X + $this.Width - 1, $this.Y + 2))
        $sb.Append($sideGradient[2])
        $sb.Append('┘')
        
        # Bottom border with gradient (reversed)
        $sb.Append([VT]::MoveTo($this.X + 1, $this.Y + 2))
        $gradientIndex = $this._gradientColors.Count - 1
        $step = [Math]::Max(1, [Math]::Floor($this._gradientColors.Count / ($this.Width - 2)))
        
        for ($i = 1; $i -lt $this.Width - 1; $i++) {
            $colorIndex = [Math]::Max(0, $gradientIndex)
            $sb.Append($this._gradientColors[$colorIndex])
            $sb.Append('─')
            $gradientIndex -= $step
        }
        
        # Fill background
        $sb.Append([VT]::MoveTo($this.X + 1, $this.Y + 1))
        $sb.Append($this._colors.focusedBg)
        $sb.Append(' ' * ($this.Width - 2))
    }
    
    [void] RenderRegularBorder([System.Text.StringBuilder]$sb) {
        # Simple border for non-focused state
        $borderColor = if ($this.IsFocused) { $this._colors.accent } else { $this._colors.border }
        
        $sb.Append($borderColor)
        
        # Top border
        $sb.Append([VT]::MoveTo($this.X, $this.Y))
        $sb.Append('┌')
        $sb.Append('─' * ($this.Width - 2))
        $sb.Append('┐')
        
        # Middle line with background
        $sb.Append([VT]::MoveTo($this.X, $this.Y + 1))
        $sb.Append('│')
        
        if ($this.IsFocused) {
            $sb.Append($this._colors.focusedBg)
        } else {
            $sb.Append($this._colors.bg)
        }
        $sb.Append(' ' * ($this.Width - 2))
        $sb.Append($borderColor)
        $sb.Append('│')
        
        # Bottom border
        $sb.Append([VT]::MoveTo($this.X, $this.Y + 2))
        $sb.Append('└')
        $sb.Append('─' * ($this.Width - 2))
        $sb.Append('┘')
    }
    
    [bool] OnHandleInput([System.ConsoleKeyInfo]$key) {
        switch ($key.Key) {
            ([System.ConsoleKey]::Enter) {
                $this.Click()
                return $true
            }
            ([System.ConsoleKey]::Spacebar) {
                $this.Click()
                return $true
            }
        }
        return $false
    }
    
    [void] Click() {
        if ($this.OnClick) {
            try {
                & $this.OnClick
            } catch {
                if ($global:Logger) {
                    $global:Logger.Error("GradientButton click error: $_")
                }
            }
        }
    }
    
    [void] OnBoundsChanged() {
        # Auto-size width based on text if not set
        if ($this.Width -eq 0) {
            $this.Width = [Math]::Max($this.Text.Length + (2 * $this.Padding) + 2, 12)
        }
        
        # Update gradient colors when size changes
        $this.UpdateColors()
    }
}