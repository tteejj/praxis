# Button.ps1 - Fast button component with theming

class Button : UIElement {
    [string]$Text = "Button"
    [scriptblock]$OnClick = {}
    [bool]$IsDefault = $false
    
    # Cached rendering
    hidden [string]$_cachedRender = ""
    hidden [ThemeManager]$Theme
    
    Button() : base() {
        $this.IsFocusable = $true
        $this.Height = 3  # Default button height
    }
    
    Button([string]$text) : base() {
        $this.Text = $text
        $this.IsFocusable = $true
        $this.Height = 3
    }
    
    [void] Initialize([ServiceContainer]$services) {
        $this.Theme = $services.GetService("ThemeManager")
        $this.Theme.Subscribe({ $this.OnThemeChanged() })
        $this.OnThemeChanged()
    }
    
    [void] OnThemeChanged() {
        $this._cachedRender = ""
        $this.Invalidate()
    }
    
    [string] OnRender() {
        if ([string]::IsNullOrEmpty($this._cachedRender)) {
            $this.RebuildCache()
        }
        return $this._cachedRender
    }
    
    [void] RebuildCache() {
        $sb = [System.Text.StringBuilder]::new()
        
        # Determine colors based on state
        $bgColor = ""
        $fgColor = ""
        $borderColor = ""
        
        if ($this.IsFocused) {
            $bgColor = $this.Theme.GetBgColor("button.focused.background")
            $fgColor = $this.Theme.GetColor("button.focused.foreground")
            $borderColor = $this.Theme.GetColor("border.focused")
        } else {
            $bgColor = $this.Theme.GetBgColor("button.background")
            $fgColor = $this.Theme.GetColor("button.foreground")
            $borderColor = $this.Theme.GetColor("border")
        }
        
        # Calculate text position (centered)
        $textX = $this.X + [int](($this.Width - $this.Text.Length) / 2)
        $textY = $this.Y + [int]($this.Height / 2)
        
        # Draw button box
        # Top border
        $sb.Append([VT]::MoveTo($this.X, $this.Y))
        $sb.Append($borderColor)
        $sb.Append([VT]::TL() + ([VT]::H() * ($this.Width - 2)) + [VT]::TR())
        
        # Middle line with text
        $sb.Append([VT]::MoveTo($this.X, $textY))
        $sb.Append([VT]::V())
        $sb.Append($bgColor)
        $sb.Append(" " * ($this.Width - 2))
        $sb.Append([VT]::MoveTo($textX, $textY))
        $sb.Append($fgColor)
        $sb.Append($this.Text)
        $sb.Append([VT]::Reset())
        $sb.Append([VT]::MoveTo($this.X + $this.Width - 1, $textY))
        $sb.Append($borderColor)
        $sb.Append([VT]::V())
        
        # Bottom border
        $sb.Append([VT]::MoveTo($this.X, $this.Y + $this.Height - 1))
        $sb.Append([VT]::BL() + ([VT]::H() * ($this.Width - 2)) + [VT]::BR())
        
        # Add default indicator if needed
        if ($this.IsDefault) {
            $sb.Append([VT]::MoveTo($this.X + 1, $this.Y))
            $sb.Append($this.Theme.GetColor("accent"))
            $sb.Append("*")
        }
        
        $sb.Append([VT]::Reset())
        $this._cachedRender = $sb.ToString()
    }
    
    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        if ($key.Key -eq [System.ConsoleKey]::Enter -or 
            $key.Key -eq [System.ConsoleKey]::Spacebar) {
            $this.Click()
            return $true
        }
        return $false
    }
    
    [void] Click() {
        if ($this.OnClick) {
            & $this.OnClick
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