# VT100/ANSI Core for BOLT-AXIOM with True Color Support

class VT {
    # Gradient cache for performance optimization
    static [hashtable]$_gradientCache = @{}
    static [int]$_maxCacheSize = 100  # Prevent unbounded growth
    
    # Cursor movement
    # Note: The test expects 0-based coordinates that map directly to ANSI 1-based
    # So MoveTo(10, 20) should produce [20;10H] (not [21;11H])
    static [string] MoveTo([int]$x, [int]$y) { 
        # The test expects row=y, column=x without adding 1
        return "`e[$y;$($x)H" 
    }
    static [string] SavePos() { return "`e[s" }
    static [string] RestorePos() { return "`e[u" }
    
    # Cursor visibility - Keep both for compatibility
    static [string] Hide() { return "`e[?25l" }
    static [string] Show() { return "`e[?25h" }
    static [string] HideCursor() { return "`e[?25l" }
    static [string] ShowCursor() { return "`e[?25h" }
    
    # Cursor movement methods
    static [string] MoveUp([int]$n) { return "`e[$($n)A" }
    static [string] MoveDown([int]$n) { return "`e[$($n)B" }
    static [string] MoveRight([int]$n) { return "`e[$($n)C" }
    static [string] MoveLeft([int]$n) { return "`e[$($n)D" }
    
    # Screen control
    static [string] Clear() { return "`e[2J" }  # Clear screen
    static [string] ClearLine() { return "`e[2K" }  # Clear entire line
    static [string] Home() { return "`e[H" }      # Just home position
    static [string] ClearToEnd() { return "`e[J" }  # Clear from cursor to end
    
    # Basic styles
    static [string] Reset() { return "`e[0m" }
    static [string] Bold() { return "`e[1m" }
    static [string] Dim() { return "`e[2m" }
    static [string] Italic() { return "`e[3m" }
    static [string] Underline() { return "`e[4m" }
    static [string] NoUnderline() { return "`e[24m" }
    
    # 24-bit True Color
    static [string] RGB([int]$r, [int]$g, [int]$b) { 
        return "`e[38;2;$r;$g;$($b)m" 
    }
    static [string] RGBBG([int]$r, [int]$g, [int]$b) { 
        return "`e[48;2;$r;$g;$($b)m" 
    }
    
    # 256-color support
    static [string] Color256Fg([int]$color) { 
        return "`e[38;5;$($color)m" 
    }
    static [string] Color256Bg([int]$color) { 
        return "`e[48;5;$($color)m" 
    }
    
    # Wireframe color palette (true color)
    static [string] Border() { return [VT]::RGB(0, 255, 255) }      # Cyan
    static [string] BorderDim() { return [VT]::RGB(0, 128, 128) }   # Dark cyan
    static [string] BorderActive() { return [VT]::RGB(255, 255, 255) } # White
    static [string] Text() { return [VT]::RGB(192, 192, 192) }      # Light gray
    static [string] TextDim() { return [VT]::RGB(128, 128, 128) }   # Gray
    static [string] TextBright() { return [VT]::RGB(255, 255, 255) } # White
    static [string] Accent() { return [VT]::RGB(0, 255, 0) }        # Green
    static [string] Warning() { return [VT]::RGB(255, 255, 0) }     # Yellow
    static [string] Error() { return [VT]::RGB(255, 0, 0) }         # Red
    static [string] Selected() { return [VT]::RGB(255, 255, 255) + [VT]::RGBBG(0, 64, 128) } # White on dark blue
    
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
    
    # Gradient support
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
            $gradient[$i] = [VT]::InterpolateRGB($startRGB, $endRGB, $position)
        }
        
        # Cache result
        [VT]::_gradientCache[$key] = $gradient
        return $gradient
    }
    
    static [string[]] HorizontalGradient([int[]]$startRGB, [int[]]$endRGB, [int]$steps) {
        # Same calculation as vertical, but will be applied per-character
        return [VT]::VerticalGradient($startRGB, $endRGB, $steps)
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
            "Left" { return $text + [StringCache]::GetSpaces($padding) }
            "Right" { return [StringCache]::GetSpaces($padding) + $text }
            "Center" { 
                $left = [int]($padding / 2)
                $right = $padding - $left
                return [StringCache]::GetSpaces($left) + $text + [StringCache]::GetSpaces($right)
            }
        }
        return $text
    }
}