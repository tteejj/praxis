# HelpOverlay.ps1 - Help overlay that can be shown on any screen

class HelpOverlay : UIElement {
    [string]$HelpText = ""
    [string]$Title = "Help"
    [bool]$IsVisible = $false
    hidden [int]$_scrollOffset = 0
    
    HelpOverlay() : base() {
        $this.IsFocusable = $true
    }
    
    [void] Show([string]$helpText) {
        $this.HelpText = $helpText
        $this.IsVisible = $true
        $this._scrollOffset = 0
        $this.Focus()
        $this.Invalidate()
    }
    
    [void] Hide() {
        $this.IsVisible = $false
        $this.Invalidate()
    }
    
    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        if (-not $this.IsVisible) {
            return $false
        }
        
        switch ($key.Key) {
            ([System.ConsoleKey]::Escape) {
                $this.Hide()
                return $true
            }
            ([System.ConsoleKey]::F1) {
                $this.Hide()
                return $true
            }
            ([System.ConsoleKey]::UpArrow) {
                if ($this._scrollOffset -gt 0) {
                    $this._scrollOffset--
                    $this.Invalidate()
                }
                return $true
            }
            ([System.ConsoleKey]::DownArrow) {
                $lines = $this.HelpText -split "`n"
                $visibleLines = $this.Height - 6
                if ($this._scrollOffset -lt ($lines.Count - $visibleLines)) {
                    $this._scrollOffset++
                    $this.Invalidate()
                }
                return $true
            }
            ([System.ConsoleKey]::PageUp) {
                $this._scrollOffset = [Math]::Max(0, $this._scrollOffset - 10)
                $this.Invalidate()
                return $true
            }
            ([System.ConsoleKey]::PageDown) {
                $lines = $this.HelpText -split "`n"
                $visibleLines = $this.Height - 6
                $maxScroll = [Math]::Max(0, $lines.Count - $visibleLines)
                $this._scrollOffset = [Math]::Min($maxScroll, $this._scrollOffset + 10)
                $this.Invalidate()
                return $true
            }
        }
        
        return $false
    }
    
    [string] OnRender() {
        if (-not $this.IsVisible) {
            return ""
        }
        
        $sb = Get-PooledStringBuilder 2048
        
        # Calculate overlay dimensions (centered, 80% of screen)
        $overlayWidth = [int]($this.Width * 0.8)
        $overlayHeight = [int]($this.Height * 0.8)
        $overlayX = $this.X + [int](($this.Width - $overlayWidth) / 2)
        $overlayY = $this.Y + [int](($this.Height - $overlayHeight) / 2)
        
        # Draw semi-transparent background (dim the screen behind)
        for ($y = $this.Y; $y -lt $this.Y + $this.Height; $y++) {
            $sb.Append([VT]::MoveTo($this.X, $y))
            $sb.Append($this.Theme.GetColor("disabled"))
            $sb.Append([StringCache]::GetSpaces($this.Width))
        }
        
        # Draw overlay box
        $borderColor = $this.Theme.GetColor("border.focused")
        $bgColor = $this.Theme.GetBgColor("background")
        
        # Fill background
        for ($y = 0; $y -lt $overlayHeight; $y++) {
            $sb.Append([VT]::MoveTo($overlayX, $overlayY + $y))
            $sb.Append($bgColor)
            $sb.Append([StringCache]::GetSpaces($overlayWidth))
        }
        
        # Draw border
        $sb.Append([BorderStyle]::RenderBorder($overlayX, $overlayY, $overlayWidth, $overlayHeight, [BorderType]::Double, $borderColor))
        
        # Draw title
        $titleText = " $($this.Title) - Press ESC to close "
        $titleX = $overlayX + [int](($overlayWidth - $titleText.Length) / 2)
        $sb.Append([VT]::MoveTo($titleX, $overlayY))
        $sb.Append($this.Theme.GetColor("title"))
        $sb.Append($titleText)
        
        # Draw help text
        $textColor = $this.Theme.GetColor("normal")
        $lines = $this.HelpText -split "`n"
        $contentY = $overlayY + 2
        $visibleLines = $overlayHeight - 4
        
        for ($i = 0; $i -lt $visibleLines -and ($i + $this._scrollOffset) -lt $lines.Count; $i++) {
            $line = $lines[$i + $this._scrollOffset]
            
            # Handle special formatting
            if ($line -match '^\s*---+\s*$') {
                # Horizontal rule
                $sb.Append([VT]::MoveTo($overlayX + 1, $contentY + $i))
                $sb.Append($this.Theme.GetColor("border"))
                $sb.Append([StringCache]::GetHorizontalLine($overlayWidth - 2))
            }
            elseif ($line -match '^#\s+(.+)') {
                # Header
                $sb.Append([VT]::MoveTo($overlayX + 2, $contentY + $i))
                $sb.Append($this.Theme.GetColor("title"))
                $sb.Append($matches[1])
            }
            elseif ($line -match '^\s*(\w+)\s+-\s+(.+)') {
                # Key binding
                $key = $matches[1]
                $desc = $matches[2]
                $sb.Append([VT]::MoveTo($overlayX + 2, $contentY + $i))
                $sb.Append($this.Theme.GetColor("accent"))
                $sb.Append($key.PadRight(15))
                $sb.Append($textColor)
                $sb.Append("- $desc")
            }
            else {
                # Normal text
                $sb.Append([VT]::MoveTo($overlayX + 2, $contentY + $i))
                $sb.Append($textColor)
                $maxLength = $overlayWidth - 4
                if ($line.Length -gt $maxLength) {
                    $sb.Append($line.Substring(0, $maxLength))
                } else {
                    $sb.Append($line)
                }
            }
        }
        
        # Draw scroll indicators
        if ($lines.Count -gt $visibleLines) {
            $scrollX = $overlayX + $overlayWidth - 2
            
            if ($this._scrollOffset -gt 0) {
                $sb.Append([VT]::MoveTo($scrollX, $contentY))
                $sb.Append($this.Theme.GetColor("accent"))
                $sb.Append("▲")
            }
            
            if ($this._scrollOffset -lt ($lines.Count - $visibleLines)) {
                $sb.Append([VT]::MoveTo($scrollX, $contentY + $visibleLines - 1))
                $sb.Append($this.Theme.GetColor("accent"))
                $sb.Append("▼")
            }
        }
        
        $sb.Append([VT]::Reset())
        
        $result = $sb.ToString()
        Return-PooledStringBuilder $sb
        return $result
    }
}