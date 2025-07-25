# Button.ps1 - Fast button component with theming

class Button : UIElement {
    [string]$Text = "Button"
    [scriptblock]$OnClick = {}
    [bool]$IsDefault = $false
    
    # Cached rendering
    hidden [string]$_cachedRender = ""
    hidden [ThemeManager]$Theme
    
    # Version-based change detection
    hidden [int]$_dataVersion = 0
    hidden [int]$_lastRenderedVersion = -1
    hidden [string]$_cachedVersionRender = ""
    
    # Cached theme colors
    hidden [hashtable]$_colors = @{}
    
    Button() : base() {
        $this.IsFocusable = $true
        $this.Height = 3  # Default button height
    }
    
    Button([string]$text) : base() {
        $this.Text = $text
        $this.IsFocusable = $true
        $this.Height = 3
        if ($global:Logger) {
            $global:Logger.Debug("Button created with text: '$text'")
        }
    }
    
    [void] OnInitialize() {
        $this.Theme = $this.ServiceContainer.GetService("ThemeManager")
        if ($this.Theme) {
            $this.Theme.Subscribe({ $this.OnThemeChanged() })
            $this.OnThemeChanged()
        }
        $this.Invalidate()  # Force initial render
    }
    
    [void] OnThemeChanged() {
        # Cache colors on theme change
        if ($this.Theme) {
            $this._colors = @{
                "button.background" = $this.Theme.GetBgColor("button.background")
                "button.foreground" = $this.Theme.GetColor("button.foreground")
                "button.focused.background" = $this.Theme.GetBgColor("button.focused.background")
                "button.focused.foreground" = $this.Theme.GetColor("button.focused.foreground")
                "border" = $this.Theme.GetColor("border")
                "border.focused" = $this.Theme.GetColor("border.focused")
                "accent" = $this.Theme.GetColor("accent")
            }
        }
        $this._cachedRender = ""
        $this.Invalidate()
    }
    
    [void] Invalidate() {
        $this._cachedRender = ""
        ([UIElement]$this).Invalidate()
    }
    
    # Method to properly track text changes
    [void] SetText([string]$text) {
        if ($this.Text -ne $text) {
            $this.Text = $text
            $this._dataVersion++  # Increment on text change
            $this.Invalidate()
        }
    }
    
    [string] OnRender() {
        if ([string]::IsNullOrEmpty($this._cachedRender)) {
            $this.RebuildCache()
        }
        return $this._cachedRender
    }
    
    [void] RebuildCache() {
        # Debug logging removed for performance
        
        # Return early if Theme is not initialized
        if (-not $this.Theme) {
            $this._cachedRender = ""
            return
        }
        
        $sb = Get-PooledStringBuilder 512  # Button rendering typically needs small capacity
        
        # Determine colors based on state
        $bgColor = ""
        $fgColor = ""
        $borderColor = ""
        
        if ($this.IsFocused) {
            $bgColor = $this._colors["button.focused.background"]
            $fgColor = $this._colors["button.focused.foreground"]
            $borderColor = $this._colors["border.focused"]
        } else {
            $bgColor = $this._colors["button.background"]
            $fgColor = $this._colors["button.foreground"]
            $borderColor = $this._colors["border"]
        }
        
        # Calculate text position (centered)
        $textX = $this.X + [Math]::Max(1, [int](($this.Width - $this.Text.Length) / 2))
        $textY = $this.Y + 1  # For height=3, text should be on the middle line
        
        # Debug logging removed for performance
        
        # Draw button box
        # Top border
        $sb.Append([VT]::MoveTo($this.X, $this.Y))
        $sb.Append($borderColor)
        $borderWidth = [Math]::Max(0, $this.Width - 2)
        if ($borderWidth -gt 0) {
            $sb.Append([VT]::TL() + [StringCache]::GetVTHorizontal($borderWidth) + [VT]::TR())
        } else {
            $sb.Append([VT]::TL() + [VT]::TR())
        }
        
        # Middle lines
        for ($y = $this.Y + 1; $y -lt $this.Y + $this.Height - 1; $y++) {
            # Debug logging removed for performance
            
            $sb.Append([VT]::MoveTo($this.X, $y))
            $sb.Append($borderColor)
            $sb.Append([VT]::V())
            
            # Fill line with background, but handle text line specially
            if ($y -eq $textY -and $this.Text) {
                # Draw background up to text
                $sb.Append($bgColor)
                $textStartOffset = [Math]::Max(0, ($this.Width - $this.Text.Length) / 2) - 1
                if ($textStartOffset -gt 0) {
                    $sb.Append([StringCache]::GetSpaces([int]$textStartOffset))
                }
                
                # Draw text
                $sb.Append($fgColor)
                $sb.Append($this.Text)
                
                # Fill rest of line
                $sb.Append($bgColor)
                $remainingSpace = $this.Width - 2 - [int]$textStartOffset - $this.Text.Length
                if ($remainingSpace -gt 0) {
                    $sb.Append([StringCache]::GetSpaces($remainingSpace))
                }
            } else {
                # Non-text lines - just fill with background
                $sb.Append($bgColor)
                $paddingWidth = [Math]::Max(0, $this.Width - 2)
                if ($paddingWidth -gt 0) {
                    $sb.Append([StringCache]::GetSpaces($paddingWidth))
                }
            }
            
            # Draw right border
            $sb.Append([VT]::MoveTo($this.X + $this.Width - 1, $y))
            $sb.Append($borderColor)
            $sb.Append([VT]::V())
            $sb.Append([VT]::Reset())
        }
        
        # Bottom border
        $sb.Append([VT]::MoveTo($this.X, $this.Y + $this.Height - 1))
        if ($borderWidth -gt 0) {
            $sb.Append([VT]::BL() + [StringCache]::GetVTHorizontal($borderWidth) + [VT]::BR())
        } else {
            $sb.Append([VT]::BL() + [VT]::BR())
        }
        
        # Add default indicator if needed
        if ($this.IsDefault) {
            $sb.Append([VT]::MoveTo($this.X + 1, $this.Y))
            $sb.Append($this._colors["accent"])
            $sb.Append("*")
        }
        
        $sb.Append([VT]::Reset())
        $this._cachedRender = $sb.ToString()
        Return-PooledStringBuilder $sb  # Return to pool for reuse
    }
    
    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        try {
            if ($key.Key -eq [System.ConsoleKey]::Enter -or 
                $key.Key -eq [System.ConsoleKey]::Spacebar) {
                $this.Click()
                return $true
            }
            return $false
        } catch {
            if ($global:Logger) {
                $global:Logger.Error("Button.HandleInput: Error processing input - $($_.Exception.Message)")
            }
            return $false
        }
    }
    
    [void] Click() {
        try {
            if ($this.OnClick) {
                & $this.OnClick
            }
        } catch {
            if ($global:Logger) {
                $global:Logger.Error("Button.Click: Error executing OnClick handler - $($_.Exception.Message)")
            }
        }
    }
    
    [void] OnGotFocus() {
        $this._cachedRender = ""
        $this.Invalidate()
    }
    
    [void] OnLostFocus() {
        $this._cachedRender = ""
        $this.Invalidate()
    }
}