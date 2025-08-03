# CleanRender.ps1 - ACTUAL clean rendering with single-line borders

class CleanRender {
    # Single-line box characters
    static [hashtable]$BoxChars = @{
        TL = '╭'  # Top left
        TR = '╮'  # Top right
        BL = '╰'  # Bottom left
        BR = '╯'  # Bottom right
        H = '─'   # Horizontal
        V = '│'   # Vertical
    }
    
    # Draw clean dialog with single-line borders
    static [string] Dialog([int]$x, [int]$y, [int]$w, [int]$h, [string]$title, [ThemeManager]$theme) {
        $sb = [System.Text.StringBuilder]::new()
        
        # Colors from theme
        $borderColor = $theme.GetColor("border.dialog")
        $bgColor = $theme.GetBgColor("surface.dialog")
        $titleColor = $theme.GetColor("text.heading")
        $reset = [VT]::Reset()
        
        # Fill background first
        for ($i = 0; $i -lt $h; $i++) {
            $sb.Append([VT]::MoveTo($x, $y + $i))
            $sb.Append($bgColor)
            $sb.Append(' ' * $w)
            $sb.Append($reset)
        }
        
        # Draw border
        $sb.Append($borderColor)
        
        # Top line
        $sb.Append([VT]::MoveTo($x, $y))
        $sb.Append([CleanRender]::BoxChars.TL)
        $sb.Append([CleanRender]::BoxChars.H * ($w - 2))
        $sb.Append([CleanRender]::BoxChars.TR)
        
        # Sides
        for ($i = 1; $i -lt $h - 1; $i++) {
            $sb.Append([VT]::MoveTo($x, $y + $i))
            $sb.Append([CleanRender]::BoxChars.V)
            $sb.Append([VT]::MoveTo($x + $w - 1, $y + $i))
            $sb.Append([CleanRender]::BoxChars.V)
        }
        
        # Bottom line
        $sb.Append([VT]::MoveTo($x, $y + $h - 1))
        $sb.Append([CleanRender]::BoxChars.BL)
        $sb.Append([CleanRender]::BoxChars.H * ($w - 2))
        $sb.Append([CleanRender]::BoxChars.BR)
        
        # Title (centered)
        if ($title) {
            $titleText = " $title "
            $titleX = $x + [int](($w - $titleText.Length) / 2)
            $sb.Append([VT]::MoveTo($titleX, $y))
            $sb.Append($titleColor)
            $sb.Append($titleText)
        }
        
        $sb.Append($reset)
        return $sb.ToString()
    }
    
    # Draw field with ONLY background highlight when focused
    static [string] Field([int]$x, [int]$y, [int]$width, [string]$label, [string]$value, [bool]$focused, [ThemeManager]$theme) {
        $sb = [System.Text.StringBuilder]::new()
        
        $sb.Append([VT]::MoveTo($x, $y))
        
        # Label (fixed width)
        $labelWidth = 15
        $labelText = $label.PadRight($labelWidth)
        
        if ($focused) {
            # ONLY background highlight - text stays normal color
            $sb.Append($theme.GetBgColor("state.focused"))
            $sb.Append($theme.GetColor("text.primary"))
        } else {
            $sb.Append($theme.GetColor("text.secondary"))
        }
        
        $sb.Append($labelText)
        $sb.Append(' ')
        
        # Value
        $valueWidth = $width - $labelWidth - 1
        $valueText = if ($value.Length -gt $valueWidth) {
            $value.Substring(0, $valueWidth - 1) + '…'
        } else {
            $value.PadRight($valueWidth)
        }
        
        $sb.Append($theme.GetColor("text.primary"))
        $sb.Append($valueText)
        
        $sb.Append([VT]::Reset())
        return $sb.ToString()
    }
    
    # Clean button with single-line borders
    static [string] Button([int]$x, [int]$y, [string]$text, [bool]$focused, [bool]$isDefault, [ThemeManager]$theme) {
        $sb = [System.Text.StringBuilder]::new()
        
        $sb.Append([VT]::MoveTo($x, $y))
        
        if ($focused) {
            # Focused: bright border, background highlight
            $sb.Append($theme.GetBgColor("button.background.focused"))
            $sb.Append($theme.GetColor("border.focused"))
        } else {
            # Normal: regular border
            $sb.Append($theme.GetColor("border.normal"))
        }
        
        # Single-line button style
        $sb.Append('[')
        $sb.Append($theme.GetColor("button.text"))
        $sb.Append(" $text ")
        
        if ($isDefault) {
            $sb.Append('•')
        }
        
        $borderColor = if ($focused) { "border.focused" } else { "border.normal" }
        $sb.Append($theme.GetColor($borderColor))
        $sb.Append(']')
        
        $sb.Append([VT]::Reset())
        return $sb.ToString()
    }
    
    # List item with ONLY background highlight
    static [string] ListItem([int]$x, [int]$y, [int]$width, [string]$text, [bool]$selected, [bool]$focused, [ThemeManager]$theme) {
        $sb = [System.Text.StringBuilder]::new()
        
        $sb.Append([VT]::MoveTo($x, $y))
        
        # Prepare text
        $displayText = if ($text.Length -gt $width - 2) {
            $text.Substring(0, $width - 3) + '…'
        } else {
            $text
        }
        
        if ($selected -and $focused) {
            # Selected + focused: background highlight only
            $sb.Append($theme.GetBgColor("state.focused"))
            $sb.Append($theme.GetColor("text.primary"))
            $sb.Append('▸ ')
        } elseif ($selected) {
            # Selected: different background
            $sb.Append($theme.GetBgColor("state.selected"))
            $sb.Append($theme.GetColor("text.primary"))
            $sb.Append('  ')
        } else {
            # Normal: no background
            $sb.Append($theme.GetColor("text.primary"))
            $sb.Append('  ')
        }
        
        $sb.Append($displayText.PadRight($width - 2))
        $sb.Append([VT]::Reset())
        
        return $sb.ToString()
    }
}