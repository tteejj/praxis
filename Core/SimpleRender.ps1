# SimpleRender.ps1 - Dead simple rendering that ACTUALLY WORKS

class SimpleRender {
    # NO CACHING, NO BULLSHIT - JUST RENDER
    
    # Get theme color and ALWAYS include reset
    static [string] Color([string]$key, [ThemeManager]$theme) {
        if (-not $theme) { return "" }
        return $theme.GetColor($key) + [VT]::Reset()
    }
    
    # Get background color and ALWAYS include reset
    static [string] BgColor([string]$key, [ThemeManager]$theme) {
        if (-not $theme) { return "" }
        return $theme.GetBgColor($key) + [VT]::Reset()
    }
    
    # Text with color
    static [string] Text([string]$text, [string]$colorKey, [ThemeManager]$theme) {
        if (-not $theme) { return $text }
        return $theme.GetColor($colorKey) + $text + [VT]::Reset()
    }
    
    # Draw a box with PROPER THEME COLORS
    static [string] Box([int]$x, [int]$y, [int]$w, [int]$h, [ThemeManager]$theme, [string]$title = "") {
        $sb = [System.Text.StringBuilder]::new()
        
        # Get colors FROM THEME
        $borderColor = $theme.GetColor("border.dialog")
        $bgColor = $theme.GetBgColor("surface.dialog")
        $titleColor = $theme.GetColor("text.heading")
        
        # Fill background FIRST
        for ($i = 0; $i -lt $h; $i++) {
            $sb.Append([VT]::MoveTo($x, $y + $i))
            $sb.Append($bgColor)
            $sb.Append(' ' * $w)
        }
        
        # Draw border
        $sb.Append($borderColor)
        
        # Top border
        $sb.Append([VT]::MoveTo($x, $y))
        $sb.Append('╭' + ('─' * ($w - 2)) + '╮')
        
        # Sides
        for ($i = 1; $i -lt $h - 1; $i++) {
            $sb.Append([VT]::MoveTo($x, $y + $i))
            $sb.Append('│')
            $sb.Append([VT]::MoveTo($x + $w - 1, $y + $i))
            $sb.Append('│')
        }
        
        # Bottom border
        $sb.Append([VT]::MoveTo($x, $y + $h - 1))
        $sb.Append('╰' + ('─' * ($w - 2)) + '╯')
        
        # Title if provided
        if ($title) {
            $titleText = " $title "
            $titleX = $x + [int](($w - $titleText.Length) / 2)
            $sb.Append([VT]::MoveTo($titleX, $y))
            $sb.Append($titleColor)
            $sb.Append($titleText)
        }
        
        $sb.Append([VT]::Reset())
        return $sb.ToString()
    }
    
    # Draw a field with label and value - NO GREY!
    static [string] Field([int]$x, [int]$y, [string]$label, [string]$value, [int]$labelWidth, [bool]$focused, [ThemeManager]$theme) {
        $sb = [System.Text.StringBuilder]::new()
        
        $sb.Append([VT]::MoveTo($x, $y))
        
        if ($focused) {
            # Focused: reverse highlight the label
            $sb.Append($theme.GetBgColor("focus.reverse.background"))
            $sb.Append($theme.GetColor("focus.reverse.text"))
            $sb.Append($label.PadRight($labelWidth))
            $sb.Append([VT]::Reset())
            $sb.Append(' ')
            $sb.Append($theme.GetColor("text.primary"))
            $sb.Append($value)
        } else {
            # Not focused: normal colors
            $sb.Append($theme.GetColor("text.secondary"))
            $sb.Append($label.PadRight($labelWidth))
            $sb.Append(' ')
            $sb.Append($theme.GetColor("text.primary"))
            $sb.Append($value)
        }
        
        $sb.Append([VT]::Reset())
        return $sb.ToString()
    }
    
    # Draw a button - SIMPLE AND CLEAN
    static [string] Button([int]$x, [int]$y, [string]$text, [bool]$focused, [ThemeManager]$theme) {
        $sb = [System.Text.StringBuilder]::new()
        
        $width = $text.Length + 4  # Padding
        
        $sb.Append([VT]::MoveTo($x, $y))
        
        if ($focused) {
            # Focused button: bright border
            $borderColor = $theme.GetColor("border.focused")
            $textColor = $theme.GetColor("button.text.focused")
            $bgColor = $theme.GetBgColor("button.background.focused")
        } else {
            # Normal button
            $borderColor = $theme.GetColor("border.normal")
            $textColor = $theme.GetColor("button.text")
            $bgColor = ""  # No background when not focused
        }
        
        # Draw button
        $sb.Append($borderColor)
        $sb.Append('[ ')
        $sb.Append($bgColor)
        $sb.Append($textColor)
        $sb.Append($text)
        $sb.Append([VT]::Reset())
        $sb.Append($borderColor)
        $sb.Append(' ]')
        
        $sb.Append([VT]::Reset())
        return $sb.ToString()
    }
    
    # Clear area - NO GREY!
    static [string] Clear([int]$x, [int]$y, [int]$w, [int]$h) {
        $sb = [System.Text.StringBuilder]::new()
        $spaces = ' ' * $w
        
        for ($i = 0; $i -lt $h; $i++) {
            $sb.Append([VT]::MoveTo($x, $y + $i))
            $sb.Append($spaces)
        }
        
        return $sb.ToString()
    }
}