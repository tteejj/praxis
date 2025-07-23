# ProgressBar.ps1 - Progress visualization component based on AxiomPhoenix patterns
# Fast string-based rendering with percentage and status text display

class ProgressBar : UIElement {
    [int]$Value = 0                    # Current progress (0-100)
    [int]$Maximum = 100               # Maximum value (default 100 for percentages)
    [string]$StatusText = ""          # Optional status text
    [bool]$ShowPercentage = $true     # Show percentage text
    [bool]$ShowBorder = $true         # Show border around progress bar
    [string]$Title = ""               # Optional title
    
    # Visual customization
    [char]$FilledChar = [char]0x2588  # █ (full block)
    [char]$EmptyChar = [char]0x2591   # ░ (light shade)
    [string]$ProgressColor = ""       # Color for filled portion
    [string]$CompleteColor = ""       # Color when 100% complete
    [string]$TextColor = ""           # Color for percentage text
    
    hidden [ThemeManager]$Theme
    hidden [string]$_cachedRender = ""
    hidden [int]$_lastValue = -1      # For change detection
    hidden [string]$_lastStatusText = ""
    
    ProgressBar() : base() {
        $this.Height = 5  # Default height (border + bar + percentage + status + border)
        $this.Width = 40  # Default width
    }
    
    [void] Initialize([ServiceContainer]$services) {
        $this.Theme = $services.GetService("ThemeManager")
        if ($this.Theme) {
            $this.Theme.Subscribe({ $this.OnThemeChanged() })
            $this.OnThemeChanged()
        }
    }
    
    [void] OnThemeChanged() {
        # Set theme colors
        if ($this.Theme) {
            if ([string]::IsNullOrEmpty($this.ProgressColor)) {
                $this.ProgressColor = $this.Theme.GetColor("progress.active")
            }
            if ([string]::IsNullOrEmpty($this.CompleteColor)) {
                $this.CompleteColor = $this.Theme.GetColor("progress.complete")
            }
            if ([string]::IsNullOrEmpty($this.TextColor)) {
                $this.TextColor = $this.Theme.GetColor("progress.text")
            }
        }
        
        $this._cachedRender = ""
        $this.Invalidate()
    }
    
    [void] Invalidate() {
        $this._cachedRender = ""
        ([UIElement]$this).Invalidate()
    }
    
    # Public API methods
    [void] SetProgress([int]$value) {
        $this.SetProgress($value, $this.StatusText)
    }
    
    [void] SetProgress([int]$value, [string]$statusText) {
        # Clamp value to valid range
        $this.Value = [Math]::Max(0, [Math]::Min($this.Maximum, $value))
        $this.StatusText = $statusText
        
        # Only invalidate if something actually changed
        if ($this.Value -ne $this._lastValue -or $this.StatusText -ne $this._lastStatusText) {
            $this._lastValue = $this.Value
            $this._lastStatusText = $this.StatusText
            $this.Invalidate()
        }
    }
    
    [int] GetPercentage() {
        if ($this.Maximum -eq 0) {
            return 0
        }
        return [int](($this.Value * 100) / $this.Maximum)
    }
    
    [bool] IsComplete() {
        return $this.Value -ge $this.Maximum
    }
    
    # Rendering
    [string] OnRender() {
        if ([string]::IsNullOrEmpty($this._cachedRender)) {
            $this.RebuildCache()
        }
        return $this._cachedRender
    }
    
    [void] RebuildCache() {
        $sb = [System.Text.StringBuilder]::new()
        
        # Colors
        $borderColor = if ($this.Theme) { $this.Theme.GetColor("border") } else { "" }
        $titleColor = if ($this.Theme) { $this.Theme.GetColor("title") } else { "" }
        $normalColor = if ($this.Theme) { $this.Theme.GetColor("normal") } else { "" }
        
        # Determine progress color based on completion
        $currentProgressColor = if ($this.IsComplete()) { 
            if ([string]::IsNullOrEmpty($this.CompleteColor)) { $this.ProgressColor } else { $this.CompleteColor }
        } else { 
            $this.ProgressColor 
        }
        
        # Calculate dimensions
        $contentY = $this.Y
        $contentHeight = $this.Height
        $barWidth = $this.Width - ($this.ShowBorder ? 2 : 0)
        
        if ($this.ShowBorder) {
            # Top border
            $sb.Append([VT]::MoveTo($this.X, $this.Y))
            $sb.Append($borderColor)
            $sb.Append([VT]::TL() + ([VT]::H() * ($this.Width - 2)) + [VT]::TR())
            $contentY++
            $contentHeight--
            
            # Title
            if ($this.Title) {
                $sb.Append([VT]::MoveTo($this.X + 1, $contentY))
                $sb.Append($titleColor)
                $titleText = $this.Title.PadRight($barWidth).Substring(0, $barWidth)
                $sb.Append($titleText)
                $contentY++
                $contentHeight--
            }
        } else {
            # Title without border
            if ($this.Title) {
                $sb.Append([VT]::MoveTo($this.X, $contentY))
                $sb.Append($titleColor)
                $titleText = $this.Title.PadRight($this.Width).Substring(0, $this.Width)
                $sb.Append($titleText)
                $contentY++
                $contentHeight--
            }
        }
        
        # Calculate bar dimensions
        $percentage = $this.GetPercentage()
        $filledWidth = if ($barWidth -gt 0) { [Math]::Floor($barWidth * $percentage / 100) } else { 0 }
        $emptyWidth = $barWidth - $filledWidth
        
        # Render progress bar
        $sb.Append([VT]::MoveTo($this.X + ($this.ShowBorder ? 1 : 0), $contentY))
        
        # Filled portion
        if ($filledWidth -gt 0) {
            $sb.Append($currentProgressColor)
            $sb.Append([string]$this.FilledChar * $filledWidth)
        }
        
        # Empty portion  
        if ($emptyWidth -gt 0) {
            $sb.Append($normalColor)
            $sb.Append([string]$this.EmptyChar * $emptyWidth)
        }
        
        $contentY++
        $contentHeight--
        
        # Percentage text (centered)
        if ($this.ShowPercentage) {
            $percentText = "$percentage%"
            $textX = $this.X + ($this.Width - $percentText.Length) / 2
            $sb.Append([VT]::MoveTo([int]$textX, $contentY))
            $sb.Append($this.TextColor)
            $sb.Append($percentText)
            $contentY++
            $contentHeight--
        }
        
        # Status text (left-aligned, truncated if needed)
        if ($this.StatusText -and $contentHeight -gt ($this.ShowBorder ? 1 : 0)) {
            $sb.Append([VT]::MoveTo($this.X + ($this.ShowBorder ? 1 : 0), $contentY))
            $sb.Append($normalColor)
            
            $statusWidth = $this.Width - ($this.ShowBorder ? 2 : 0)
            if ($this.StatusText.Length -gt $statusWidth) {
                $truncated = $this.StatusText.Substring(0, $statusWidth - 3) + "..."
                $sb.Append($truncated)
            } else {
                $paddedStatus = $this.StatusText.PadRight($statusWidth).Substring(0, $statusWidth)
                $sb.Append($paddedStatus)
            }
            $contentY++
            $contentHeight--
        }
        
        # Side borders for remaining height
        if ($this.ShowBorder) {
            while ($contentHeight -gt 1) {
                $sb.Append([VT]::MoveTo($this.X, $contentY))
                $sb.Append($borderColor)
                $sb.Append([VT]::V())
                
                $sb.Append([VT]::MoveTo($this.X + $this.Width - 1, $contentY))
                $sb.Append($borderColor)
                $sb.Append([VT]::V())
                
                $contentY++
                $contentHeight--
            }
            
            # Bottom border
            $sb.Append([VT]::MoveTo($this.X, $contentY))
            $sb.Append($borderColor)
            $sb.Append([VT]::BL() + ([VT]::H() * ($this.Width - 2)) + [VT]::BR())
        }
        
        $sb.Append([VT]::Reset())
        $this._cachedRender = $sb.ToString()
    }
    
    # Animation helper method (for future use)
    [void] AnimateTo([int]$targetValue, [int]$durationMs = 1000) {
        # Basic animation - could be enhanced with timer/events
        $startValue = $this.Value
        $steps = [Math]::Max(1, $durationMs / 50)  # 50ms per step
        $increment = ($targetValue - $startValue) / $steps
        
        for ($i = 0; $i -lt $steps; $i++) {
            $currentValue = $startValue + ($increment * ($i + 1))
            $this.SetProgress([int]$currentValue)
            Start-Sleep -Milliseconds 50
        }
        
        # Ensure we reach the exact target
        $this.SetProgress($targetValue)
    }
    
    # No input handling needed for progress bar
    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        return $false
    }
}