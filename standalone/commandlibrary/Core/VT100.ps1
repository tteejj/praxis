# VT100.ps1 - Enhanced terminal control utilities for CommandLibrary
# Based on TaskPro's advanced VT100 implementation with True Color Support

class VT {
    # Gradient cache for performance optimization
    static [hashtable]$_gradientCache = @{}
    static [int]$_maxCacheSize = 100  # Prevent unbounded growth
    
    # Core ANSI escape sequences
    static [string] $ESC = "`e"
    static [string] $CSI = "`e["
    
    # Cursor control
    static [string] MoveTo([int]$x, [int]$y) {
        return [VT]::CSI + "$($y + 1);$($x + 1)H"
    }
    
    static [string] MoveUp([int]$lines = 1) {
        return [VT]::CSI + "${lines}A"
    }
    
    static [string] MoveDown([int]$lines = 1) {
        return [VT]::CSI + "${lines}B"
    }
    
    static [string] MoveRight([int]$cols = 1) {
        return [VT]::CSI + "${cols}C"
    }
    
    static [string] MoveLeft([int]$cols = 1) {
        return [VT]::CSI + "${cols}D"
    }
    
    # Screen control
    static [string] Clear() {
        return [VT]::CSI + "2J" + [VT]::CSI + "H"
    }
    
    static [string] ClearLine() {
        return [VT]::CSI + "2K"
    }
    
    static [string] ClearToEnd() {
        return [VT]::CSI + "0K"
    }
    
    # Cursor visibility
    static [string] ShowCursor() {
        return [VT]::CSI + "?25h"
    }
    
    static [string] HideCursor() {
        return [VT]::CSI + "?25l"
    }
    
    # Colors - 256 color support
    static [string] ForegroundColor([int]$color) {
        return [VT]::CSI + "38;5;${color}m"
    }
    
    static [string] BackgroundColor([int]$color) {
        return [VT]::CSI + "48;5;${color}m"
    }
    
    # 24-bit True Color
    static [string] RGB([int]$r, [int]$g, [int]$b) { 
        return "`e[38;2;$r;$g;$($b)m" 
    }
    static [string] RGBBG([int]$r, [int]$g, [int]$b) { 
        return "`e[48;2;$r;$g;$($b)m" 
    }
    
    # Legacy compatibility
    static [string] ForegroundRGB([int]$r, [int]$g, [int]$b) {
        return [VT]::RGB($r, $g, $b)
    }
    
    static [string] BackgroundRGB([int]$r, [int]$g, [int]$b) {
        return [VT]::RGBBG($r, $g, $b)
    }
    
    # Text styling
    static [string] Bold() {
        return [VT]::CSI + "1m"
    }
    
    static [string] Dim() {
        return [VT]::CSI + "2m"
    }
    
    static [string] Underline() {
        return [VT]::CSI + "4m"
    }
    
    static [string] Reverse() {
        return [VT]::CSI + "7m"
    }
    
    static [string] Reset() {
        return [VT]::CSI + "0m"
    }
    
    # Convenience color methods
    static [string] Red() { return [VT]::ForegroundColor(9) }
    static [string] Green() { return [VT]::ForegroundColor(10) }
    static [string] Yellow() { return [VT]::ForegroundColor(11) }
    static [string] Blue() { return [VT]::ForegroundColor(12) }
    static [string] Magenta() { return [VT]::ForegroundColor(13) }
    static [string] Cyan() { return [VT]::ForegroundColor(14) }
    static [string] White() { return [VT]::ForegroundColor(15) }
    static [string] Gray() { return [VT]::ForegroundColor(8) }
    
    # Box drawing - single lines for speed
    static [string] TL() { return "┌" }     # Top left
    static [string] TR() { return "┐" }     # Top right
    static [string] BL() { return "└" }     # Bottom left
    static [string] BR() { return "┘" }     # Bottom right
    static [string] H() { return "─" }      # Horizontal
    static [string] V() { return "│" }      # Vertical
    static [string] Cross() { return "┼" }  # Cross
    static [string] T() { return "┬" }      # T down
    static [string] B() { return "┴" }      # T up
    static [string] L() { return "├" }      # T right
    static [string] R() { return "┤" }      # T left
    
    # Double lines for emphasis
    static [string] DTL() { return "╔" }
    static [string] DTR() { return "╗" }
    static [string] DBL() { return "╚" }
    static [string] DBR() { return "╝" }
    static [string] DH() { return "═" }
    static [string] DV() { return "║" }
    
    # Legacy compatibility
    static [string] BoxHorizontal() { return [VT]::H() }
    static [string] BoxVertical() { return [VT]::V() }
    static [string] BoxTopLeft() { return [VT]::TL() }
    static [string] BoxTopRight() { return [VT]::TR() }
    static [string] BoxBottomLeft() { return [VT]::BL() }
    static [string] BoxBottomRight() { return [VT]::BR() }
    static [string] BoxCross() { return [VT]::Cross() }
    static [string] BoxTeeDown() { return [VT]::T() }
    static [string] BoxTeeUp() { return [VT]::B() }
    static [string] BoxTeeRight() { return [VT]::L() }
    static [string] BoxTeeLeft() { return [VT]::R() }
}

# Global convenience functions
function Write-VT {
    param([string]$Text)
    Write-Host -NoNewline $Text
}

function Clear-Screen {
    Write-VT ([VT]::Clear())
}

function Hide-Cursor {
    Write-VT ([VT]::HideCursor())
}

function Show-Cursor {
    Write-VT ([VT]::ShowCursor())
}

# Gradient support and measurement helpers
# Gradient support
function Get-GradientColors {
    param([int[]]$startRGB, [int[]]$endRGB, [int]$steps)
    return [VT]::VerticalGradient($startRGB, $endRGB, $steps)
}

# Enhanced VT100 additions 

# Add gradient interpolation support
class VTGradient {
    static [string] InterpolateRGB([int[]]$startRGB, [int[]]$endRGB, [double]$position) {
        # Position should be between 0.0 and 1.0
        $position = [Math]::Max(0.0, [Math]::Min(1.0, $position))
        
        $r = [int]($startRGB[0] + ($endRGB[0] - $startRGB[0]) * $position)
        $g = [int]($startRGB[1] + ($endRGB[1] - $startRGB[1]) * $position)
        $b = [int]($startRGB[2] + ($endRGB[2] - $startRGB[2]) * $position)
        
        return [VT]::RGB($r, $g, $b)
    }
    
    static [string[]] VerticalGradient([int[]]$startRGB, [int[]]$endRGB, [int]$steps) {
        # Create cache key
        $key = "$($startRGB -join ',')_$($endRGB -join ',')_$steps"
        
        # Check cache first
        if ([VT]::_gradientCache.ContainsKey($key)) {
            return [VT]::_gradientCache[$key]
        }
        
        # Prevent cache from growing too large
        if ([VT]::_gradientCache.Count -ge [VT]::_maxCacheSize) {
            # Clear oldest entries (simple approach - clear half the cache)
            $keysToRemove = [VT]::_gradientCache.Keys | Select-Object -First ([VT]::_maxCacheSize / 2)
            foreach ($oldKey in $keysToRemove) {
                [VT]::_gradientCache.Remove($oldKey)
            }
        }
        
        # Compute gradient
        $gradient = [string[]]::new($steps)
        for ($i = 0; $i -lt $steps; $i++) {
            $position = $i / [double]($steps - 1)
            $gradient[$i] = [VTGradient]::InterpolateRGB($startRGB, $endRGB, $position)
        }
        
        # Cache result
        [VT]::_gradientCache[$key] = $gradient
        return $gradient
    }
    
    static [string[]] HorizontalGradient([int[]]$startRGB, [int[]]$endRGB, [int]$steps) {
        # Same calculation as vertical, but will be applied per-character
        return [VTGradient]::VerticalGradient($startRGB, $endRGB, $steps)
    }
}

# Layout measurement helpers
class Measure {
    static [int] TextWidth([string]$text) {
        # Remove ANSI sequences for accurate measurement
        $clean = $text -replace '\x1b\[[0-9;]*m', ''
        return $clean.Length
    }
    
    static [string] Truncate([string]$text, [int]$maxWidth) {
        $clean = $text -replace '\x1b\[[0-9;]*m', ''
        if ($clean.Length -le $maxWidth) { return $text }
        return $clean.Substring(0, $maxWidth - 3) + "..."
    }
    
    static [string] Pad([string]$text, [int]$width, [string]$align = "Left") {
        $textWidth = [Measure]::TextWidth($text)
        if ($textWidth -ge $width) { return [Measure]::Truncate($text, $width) }
        
        $padding = $width - $textWidth
        switch ($align) {
            "Left" { return $text + (" " * $padding) }
            "Right" { return (" " * $padding) + $text }
            "Center" { 
                $left = [int]($padding / 2)
                $right = $padding - $left
                return (" " * $left) + $text + (" " * $right)
            }
        }
        return $text
    }
}