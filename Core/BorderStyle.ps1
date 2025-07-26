# BorderStyle.ps1 - Unified border rendering system for minimal, elegant UI

enum BorderType {
    None = 0
    Single = 1
    Double = 2
    Rounded = 3
    Minimal = 4  # Just corners
    Dotted = 5
}

class BorderStyle {
    # Border characters for different styles
    static [hashtable] $Styles = @{
        Single = @{
            TL = '┌'; TR = '┐'; BL = '└'; BR = '┘'
            H = '─'; V = '│'
            LT = '├'; RT = '┤'; TT = '┬'; BT = '┴'
            Cross = '┼'
        }
        Double = @{
            TL = '╔'; TR = '╗'; BL = '╚'; BR = '╝'
            H = '═'; V = '║'
            LT = '╠'; RT = '╣'; TT = '╦'; BT = '╩'
            Cross = '╬'
        }
        Rounded = @{
            TL = '╭'; TR = '╮'; BL = '╰'; BR = '╯'
            H = '─'; V = '│'
            LT = '├'; RT = '┤'; TT = '┬'; BT = '┴'
            Cross = '┼'
        }
        Minimal = @{
            TL = '·'; TR = '·'; BL = '·'; BR = '·'
            H = ' '; V = ' '
            LT = ' '; RT = ' '; TT = ' '; BT = ' '
            Cross = ' '
        }
        Dotted = @{
            TL = '·'; TR = '·'; BL = '·'; BR = '·'
            H = '·'; V = '┊'
            LT = '┊'; RT = '┊'; TT = '·'; BT = '·'
            Cross = '·'
        }
    }
    
    # Pre-render border for a given size and style
    static [string] RenderBorder(
        [int]$x, [int]$y, [int]$width, [int]$height,
        [BorderType]$type, [string]$color
    ) {
        if ($type -eq [BorderType]::None -or $width -lt 2 -or $height -lt 2) {
            return ""
        }
        
        $style = [BorderStyle]::Styles[$type.ToString()]
        if (-not $style) { return "" }
        
        $sb = Get-PooledStringBuilder (($width + 10) * $height)
        
        # Apply color if specified
        if ($color) { $sb.Append($color) }
        
        # Top border
        $sb.Append([VT]::MoveTo($x, $y))
        $sb.Append($style.TL)
        if ($width -gt 2) {
            $sb.Append($style.H * ($width - 2))
        }
        $sb.Append($style.TR)
        
        # Side borders
        if ($height -gt 2) {
            for ($i = 1; $i -lt ($height - 1); $i++) {
                $sb.Append([VT]::MoveTo($x, $y + $i))
                $sb.Append($style.V)
                if ($type -eq [BorderType]::Minimal) {
                    # Minimal style - only corners
                } else {
                    $sb.Append([VT]::MoveTo($x + $width - 1, $y + $i))
                    $sb.Append($style.V)
                }
            }
        }
        
        # Bottom border
        $sb.Append([VT]::MoveTo($x, $y + $height - 1))
        $sb.Append($style.BL)
        if ($width -gt 2) {
            if ($type -eq [BorderType]::Minimal) {
                # Minimal - just corners
                $sb.Append(' ' * ($width - 2))
            } else {
                $sb.Append($style.H * ($width - 2))
            }
        }
        $sb.Append($style.BR)
        
        # Reset color
        if ($color) { $sb.Append([VT]::Reset()) }
        
        $result = $sb.ToString()
        Return-PooledStringBuilder $sb
        return $result
    }
    
    # Render border with title (elegant placement)
    static [string] RenderBorderWithTitle(
        [int]$x, [int]$y, [int]$width, [int]$height,
        [BorderType]$type, [string]$color,
        [string]$title, [string]$titleColor
    ) {
        if ($type -eq [BorderType]::None) { return "" }
        
        # Start with basic border
        $border = [BorderStyle]::RenderBorder($x, $y, $width, $height, $type, $color)
        
        if (-not $title -or $title.Length -eq 0) { return $border }
        
        # Add title to top border
        $sb = Get-PooledStringBuilder ($border.Length + $title.Length + 20)
        $sb.Append($border)
        
        # Calculate title position (centered with padding)
        $titleWithPadding = " $title "
        $titleStart = $x + [Math]::Max(2, ($width - $titleWithPadding.Length) / 2)
        
        # Overlay title on top border
        $sb.Append([VT]::MoveTo($titleStart, $y))
        if ($titleColor) { $sb.Append($titleColor) }
        $sb.Append($titleWithPadding)
        if ($titleColor) { $sb.Append([VT]::Reset()) }
        if ($color) { $sb.Append($color) }
        
        $result = $sb.ToString()
        Return-PooledStringBuilder $sb
        return $result
    }
    
    # Get border insets (how much space the border takes)
    static [hashtable] GetInsets([BorderType]$type) {
        if ($type -eq [BorderType]::None) {
            return @{ Top = 0; Left = 0; Right = 0; Bottom = 0 }
        }
        return @{ Top = 1; Left = 1; Right = 1; Bottom = 1 }
    }
}

# Extension method for UIElement
class BorderedElement : UIElement {
    [BorderType]$BorderType = [BorderType]::None
    [string]$BorderTitle = ""
    [bool]$ShowBorder = $false
    
    # Cached border render
    hidden [string]$_cachedBorder = ""
    hidden [string]$_borderColor = ""
    hidden [string]$_borderFocusColor = ""
    
    [void] UpdateBorderColors() {
        if ($this.ServiceContainer) {
            $theme = $this.ServiceContainer.GetService('ThemeManager')
            if ($theme) {
                $this._borderColor = $theme.GetColor('border')
                $this._borderFocusColor = $theme.GetColor('border.focused')
            }
        }
    }
    
    [void] InvalidateBorder() {
        $this._cachedBorder = ""
        $this.Invalidate()
    }
    
    [string] RenderBorder() {
        if (-not $this.ShowBorder -or $this.BorderType -eq [BorderType]::None) {
            return ""
        }
        
        $color = if ($this.IsFocused) { $this._borderFocusColor } else { $this._borderColor }
        
        if ($this.BorderTitle) {
            $titleColor = if ($this.IsFocused -and $this.ServiceContainer) {
                $theme = $this.ServiceContainer.GetService('ThemeManager')
                if ($theme) { $theme.GetColor('accent') } else { "" }
            } else { "" }
            
            return [BorderStyle]::RenderBorderWithTitle(
                $this.X, $this.Y, $this.Width, $this.Height,
                $this.BorderType, $color,
                $this.BorderTitle, $titleColor
            )
        } else {
            return [BorderStyle]::RenderBorder(
                $this.X, $this.Y, $this.Width, $this.Height,
                $this.BorderType, $color
            )
        }
    }
    
    [hashtable] GetContentBounds() {
        $insets = [BorderStyle]::GetInsets($this.BorderType)
        return @{
            X = $this.X + $insets.Left
            Y = $this.Y + $insets.Top
            Width = $this.Width - $insets.Left - $insets.Right
            Height = $this.Height - $insets.Top - $insets.Bottom
        }
    }
}