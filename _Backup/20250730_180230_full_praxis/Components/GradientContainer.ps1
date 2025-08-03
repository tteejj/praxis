# GradientContainer.ps1 - Container with gradient borders and backgrounds

class GradientContainer : Container {
    [bool]$UseVerticalGradient = $true
    [bool]$UseHorizontalGradient = $false
    [bool]$GradientBorder = $true
    [bool]$GradientBackground = $false
    [string]$BorderGradientStart = "gradient.border.start"
    [string]$BorderGradientEnd = "gradient.border.end"
    [string]$BackgroundGradientStart = "gradient.bg.start"
    [string]$BackgroundGradientEnd = "gradient.bg.end"
    [int]$BorderThickness = 1
    
    hidden [ThemeManager]$Theme
    hidden [string[]]$_borderGradientColors
    hidden [string[]]$_bgGradientColors
    hidden [bool]$_gradientsInvalid = $true
    
    GradientContainer() : base() {
        $this.DrawBackground = $true
    }
    
    [void] OnInitialize() {
        $this.Theme = $this.ServiceContainer.GetService("ThemeManager")
        
        # Subscribe to EventBus theme changes instead of legacy ThemeManager subscription
        $eventBus = $this.ServiceContainer.GetService('EventBus')
        if ($eventBus) {
            $component = $this
            $eventBus.Subscribe('theme.changed', {
                $component.OnThemeChanged()
            }.GetNewClosure())
        }
        
        $this.OnThemeChanged()
    }
    
    [void] OnThemeChanged() {
        $this._gradientsInvalid = $true
        $this.Invalidate()
    }
    
    [void] OnBoundsChanged() {
        ([Container]$this).OnBoundsChanged()
        $this._gradientsInvalid = $true
    }
    
    hidden [void] UpdateGradients() {
        if (-not $this._gradientsInvalid -or -not $this.Theme) { return }
        
        # Update border gradient
        if ($this.GradientBorder) {
            $steps = if ($this.UseVerticalGradient) { $this.Height } else { $this.Width }
            $this._borderGradientColors = $this.Theme.GetGradient(
                $this.BorderGradientStart,
                $this.BorderGradientEnd,
                [Math]::Max(2, $steps)
            )
        }
        
        # Update background gradient
        if ($this.GradientBackground) {
            $steps = if ($this.UseVerticalGradient) { $this.Height } else { $this.Width }
            $this._bgGradientColors = $this.Theme.GetGradient(
                $this.BackgroundGradientStart,
                $this.BackgroundGradientEnd,
                [Math]::Max(2, $steps)
            )
        }
        
        $this._gradientsInvalid = $false
    }
    
    [string] OnRender() {
        $this.UpdateGradients()
        
        $sb = [System.Text.StringBuilder]::new()
        
        # Render gradient background if enabled
        if ($this.GradientBackground -and $this._bgGradientColors) {
            $this.RenderGradientBackground($sb)
        }
        
        # Render gradient border if enabled
        if ($this.GradientBorder -and $this._borderGradientColors) {
            $this.RenderGradientBorder($sb)
        }
        
        # Render children
        $sb.Append(([Container]$this).OnRender())
        
        return $sb.ToString()
    }
    
    hidden [void] RenderGradientBackground([System.Text.StringBuilder]$sb) {
        if ($this.UseVerticalGradient) {
            # Vertical gradient - different color each row
            for ($y = 0; $y -lt $this.Height; $y++) {
                $colorIndex = [Math]::Min($y, $this._bgGradientColors.Count - 1)
                $color = $this._bgGradientColors[$colorIndex]
                
                $sb.Append([VT]::MoveTo($this.X, $this.Y + $y))
                $sb.Append($color)
                $sb.Append($this.Theme.GetColor('text.primary'))  # Ensure text remains visible
                $sb.Append([StringCache]::GetSpaces($this.Width))
            }
        } else {
            # Horizontal gradient - blend colors across each row
            for ($y = 0; $y -lt $this.Height; $y++) {
                $sb.Append([VT]::MoveTo($this.X, $this.Y + $y))
                
                for ($x = 0; $x -lt $this.Width; $x++) {
                    $colorIndex = [Math]::Floor(($x / $this.Width) * ($this._bgGradientColors.Count - 1))
                    $colorIndex = [Math]::Min($colorIndex, $this._bgGradientColors.Count - 1)
                    $color = $this._bgGradientColors[$colorIndex]
                    
                    $sb.Append($color)
                    $sb.Append(" ")
                }
            }
        }
        
    }
    
    hidden [void] RenderGradientBorder([System.Text.StringBuilder]$sb) {
        if ($this.BorderThickness -lt 1) { return }
        
        if ($this.UseVerticalGradient) {
            # Vertical gradient on sides
            for ($y = 0; $y -lt $this.Height; $y++) {
                $colorIndex = [Math]::Min($y, $this._borderGradientColors.Count - 1)
                $color = $this._borderGradientColors[$colorIndex]
                
                # Left border
                $sb.Append([VT]::MoveTo($this.X, $this.Y + $y))
                $sb.Append($color)
                for ($i = 0; $i -lt $this.BorderThickness; $i++) {
                    $sb.Append("█")
                }
                
                # Right border
                if ($this.Width -gt ($this.BorderThickness * 2)) {
                    $sb.Append([VT]::MoveTo($this.X + $this.Width - $this.BorderThickness, $this.Y + $y))
                    $sb.Append($color)
                    for ($i = 0; $i -lt $this.BorderThickness; $i++) {
                        $sb.Append("█")
                    }
                }
            }
            
            # Top and bottom with horizontal gradient
            if ($this.UseHorizontalGradient) {
                # Top border
                for ($x = 0; $x -lt $this.Width; $x++) {
                    $colorIndex = [Math]::Floor(($x / $this.Width) * ($this._borderGradientColors.Count - 1))
                    $colorIndex = [Math]::Min($colorIndex, $this._borderGradientColors.Count - 1)
                    $color = $this._borderGradientColors[$colorIndex]
                    
                    $sb.Append([VT]::MoveTo($this.X + $x, $this.Y))
                    $sb.Append($color)
                    $sb.Append("▀")
                }
                
                # Bottom border
                for ($x = 0; $x -lt $this.Width; $x++) {
                    $colorIndex = [Math]::Floor(($x / $this.Width) * ($this._borderGradientColors.Count - 1))
                    $colorIndex = [Math]::Min($colorIndex, $this._borderGradientColors.Count - 1)
                    $color = $this._borderGradientColors[$colorIndex]
                    
                    $sb.Append([VT]::MoveTo($this.X + $x, $this.Y + $this.Height - 1))
                    $sb.Append($color)
                    $sb.Append("▄")
                }
            } else {
                # Solid color top/bottom
                $topColor = $this._borderGradientColors[0]
                $bottomColor = $this._borderGradientColors[$this._borderGradientColors.Count - 1]
                
                # Top
                $sb.Append([VT]::MoveTo($this.X, $this.Y))
                $sb.Append($topColor)
                $sb.Append("▄" * $this.Width)
                
                # Bottom
                $sb.Append([VT]::MoveTo($this.X, $this.Y + $this.Height - 1))
                $sb.Append($bottomColor)
                $sb.Append("▀" * $this.Width)
            }
        } else {
            # Horizontal gradient across all borders
            $this.RenderHorizontalGradientBorder($sb)
        }

    }
    
    hidden [void] RenderHorizontalGradientBorder([System.Text.StringBuilder]$sb) {
        # Implementation for pure horizontal gradient borders
        for ($y = 0; $y -lt $this.Height; $y++) {
            if ($y -eq 0 -or $y -eq $this.Height - 1) {
                # Top and bottom borders
                for ($x = 0; $x -lt $this.Width; $x++) {
                    $colorIndex = [Math]::Floor(($x / $this.Width) * ($this._borderGradientColors.Count - 1))
                    $colorIndex = [Math]::Min($colorIndex, $this._borderGradientColors.Count - 1)
                    $color = $this._borderGradientColors[$colorIndex]
                    
                    $sb.Append([VT]::MoveTo($this.X + $x, $this.Y + $y))
                    $sb.Append($color)
                    if ($y -eq 0) { $sb.Append("▀") } else { $sb.Append("▄") }
                }
            } else {
                # Side borders only
                $leftColorIndex = 0
                $rightColorIndex = $this._borderGradientColors.Count - 1
                
                # Left
                $sb.Append([VT]::MoveTo($this.X, $this.Y + $y))
                $sb.Append($this._borderGradientColors[$leftColorIndex])
                $sb.Append("█")
                
                # Right
                if ($this.Width -gt 1) {
                    $sb.Append([VT]::MoveTo($this.X + $this.Width - 1, $this.Y + $y))
                    $sb.Append($this._borderGradientColors[$rightColorIndex])
                    $sb.Append("█")
                }
            }
        }
    }
}