# ThemeEditorDialog.ps1 - Full-screen RGB theme editor integrated with AppThemeManager

class ThemeEditorDialog {
    [int]$R = 128
    [int]$G = 128  
    [int]$B = 128
    [string]$CurrentComponent = "R"  # "R", "G", "B"
    [bool]$Running = $true
    [bool]$Cancelled = $false

    [string] Show() {
        $this.Running = $true
        $this.Cancelled = $false
        
        # Hide cursor
        [Console]::CursorVisible = $false
        
        try {
            while ($this.Running) {
                $this.Render()
                $this.HandleInput()
            }
        } finally {
            # Restore cursor
            [Console]::CursorVisible = $true
        }
        
        # Return the generated theme name if completed, empty if cancelled
        if ($this.Cancelled) {
            return ""
        } else {
            return "Custom_$($this.R)_$($this.G)_$($this.B)"
        }
    }

    [void] Render() {
        [Console]::Clear()
        [Console]::SetCursorPosition(0, 0)
        
        $width = [Console]::WindowWidth
        $height = [Console]::WindowHeight
        
        # Title
        $title = "Theme Editor - Create Custom RGB Color"
        [Console]::SetCursorPosition(($width - $title.Length) / 2, 2)
        Write-Host $title -ForegroundColor White
        
        # Current color preview
        $colorCode = [VT]::RGB($this.R, $this.G, $this.B)
        [Console]::SetCursorPosition(($width - 30) / 2, 4)
        Write-Host "${colorCode}██████ PREVIEW COLOR ██████$([VT]::Reset())"
        
        # RGB sliders
        [Console]::SetCursorPosition(($width - 50) / 2, 7)
        $rBar = $this.CreateColorBar($this.R, ($this.CurrentComponent -eq "R"))
        Write-Host "R: $($this.R.ToString().PadLeft(3)) $rBar" -NoNewline
        if ($this.CurrentComponent -eq "R") { Write-Host " ◄" -ForegroundColor Yellow }
        else { Write-Host "" }
        
        [Console]::SetCursorPosition(($width - 50) / 2, 8)
        $gBar = $this.CreateColorBar($this.G, ($this.CurrentComponent -eq "G"))
        Write-Host "G: $($this.G.ToString().PadLeft(3)) $gBar" -NoNewline
        if ($this.CurrentComponent -eq "G") { Write-Host " ◄" -ForegroundColor Yellow }
        else { Write-Host "" }
        
        [Console]::SetCursorPosition(($width - 50) / 2, 9)
        $bBar = $this.CreateColorBar($this.B, ($this.CurrentComponent -eq "B"))
        Write-Host "B: $($this.B.ToString().PadLeft(3)) $bBar" -NoNewline
        if ($this.CurrentComponent -eq "B") { Write-Host " ◄" -ForegroundColor Yellow }
        else { Write-Host "" }
        
        # Instructions
        [Console]::SetCursorPosition(($width - 60) / 2, 12)
        Write-Host "Controls:" -ForegroundColor Cyan
        [Console]::SetCursorPosition(($width - 60) / 2, 13)
        Write-Host "  ↑/↓     - Switch between R, G, B components" -ForegroundColor Gray
        [Console]::SetCursorPosition(($width - 60) / 2, 14)
        Write-Host "  ←/→     - Decrease/Increase selected component" -ForegroundColor Gray
        [Console]::SetCursorPosition(($width - 60) / 2, 15)
        Write-Host "  PgUp/Dn - Large steps (+/- 10)" -ForegroundColor Gray
        [Console]::SetCursorPosition(($width - 60) / 2, 16)
        Write-Host "  Enter   - Save custom theme" -ForegroundColor Green
        [Console]::SetCursorPosition(($width - 60) / 2, 17)
        Write-Host "  Escape  - Cancel" -ForegroundColor Red
    }

    [string] CreateColorBar([int]$value, [bool]$selected) {
        $barWidth = 32
        $fillWidth = [Math]::Round($value / 255.0 * $barWidth)
        
        $bar = ""
        for ($i = 0; $i -lt $barWidth; $i++) {
            if ($i -lt $fillWidth) {
                $bar += "█"
            } else {
                $bar += "░"
            }
        }
        
        if ($selected) {
            return "[" + $bar + "]"
        } else {
            return " " + $bar + " "
        }
    }

    [void] HandleInput() {
        if ([Console]::KeyAvailable) {
            $key = [Console]::ReadKey($true)
            
            switch ($key.Key) {
                ([System.ConsoleKey]::UpArrow) {
                    switch ($this.CurrentComponent) {
                        "R" { $this.CurrentComponent = "B" }
                        "G" { $this.CurrentComponent = "R" }
                        "B" { $this.CurrentComponent = "G" }
                    }
                }
                ([System.ConsoleKey]::DownArrow) {
                    switch ($this.CurrentComponent) {
                        "R" { $this.CurrentComponent = "G" }
                        "G" { $this.CurrentComponent = "B" }
                        "B" { $this.CurrentComponent = "R" }
                    }
                }
                ([System.ConsoleKey]::LeftArrow) {
                    switch ($this.CurrentComponent) {
                        "R" { $this.R = [Math]::Max(0, $this.R - 1) }
                        "G" { $this.G = [Math]::Max(0, $this.G - 1) }
                        "B" { $this.B = [Math]::Max(0, $this.B - 1) }
                    }
                }
                ([System.ConsoleKey]::RightArrow) {
                    switch ($this.CurrentComponent) {
                        "R" { $this.R = [Math]::Min(255, $this.R + 1) }
                        "G" { $this.G = [Math]::Min(255, $this.G + 1) }
                        "B" { $this.B = [Math]::Min(255, $this.B + 1) }
                    }
                }
                ([System.ConsoleKey]::PageUp) {
                    switch ($this.CurrentComponent) {
                        "R" { $this.R = [Math]::Min(255, $this.R + 10) }
                        "G" { $this.G = [Math]::Min(255, $this.G + 10) }
                        "B" { $this.B = [Math]::Min(255, $this.B + 10) }
                    }
                }
                ([System.ConsoleKey]::PageDown) {
                    switch ($this.CurrentComponent) {
                        "R" { $this.R = [Math]::Max(0, $this.R - 10) }
                        "G" { $this.G = [Math]::Max(0, $this.G - 10) }
                        "B" { $this.B = [Math]::Max(0, $this.B - 10) }
                    }
                }
                ([System.ConsoleKey]::Enter) {
                    # Create and register the custom theme
                    $customThemeName = "Custom_$($this.R)_$($this.G)_$($this.B)"
                    $this.CreateCustomTheme($customThemeName)
                    $this.Running = $false
                }
                ([System.ConsoleKey]::Escape) {
                    $this.Running = $false
                    $this.Cancelled = $true
                }
            }
        } else {
            Start-Sleep -Milliseconds 50
        }
    }

    [void] CreateCustomTheme([string]$themeName) {
        # Create a new theme preset based on the current Default theme
        # but with the custom color applied to key elements
        $newTheme = [AppThemeManager]::ThemePresets["Default"].Clone()
        
        # Apply the custom RGB values to main color elements
        $customRGB = @($this.R, $this.G, $this.B)
        $newTheme["Header"] = $customRGB
        $newTheme["Field"] = $customRGB
        $newTheme["Accent"] = $customRGB
        
        # Add the new theme to the presets
        [AppThemeManager]::ThemePresets[$themeName] = $newTheme
        
        # Also add to the theme names array if not already present
        if ([AppThemeManager]::ThemeNames -notcontains $themeName) {
            [AppThemeManager]::ThemeNames += $themeName
        }
    }
}