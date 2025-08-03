# VT100.ps1 - VT100/ANSI escape sequences for terminal control
# Simplified version for MacroFactory

class VT {
    # Cursor Movement
    static [string] MoveTo([int]$x, [int]$y) { return "`e[$($y);$($x)H" }
    static [string] Up([int]$n = 1) { return "`e[$($n)A" }
    static [string] Down([int]$n = 1) { return "`e[$($n)B" }
    static [string] Right([int]$n = 1) { return "`e[$($n)C" }
    static [string] Left([int]$n = 1) { return "`e[$($n)D" }
    
    # Clear
    static [string] Clear() { return "`e[2J`e[H" }
    static [string] ClearLine() { return "`e[2K" }
    static [string] ClearToEnd() { return "`e[0K" }
    static [string] ClearToStart() { return "`e[1K" }
    
    # Cursor Visibility
    static [string] HideCursor() { return "`e[?25l" }
    static [string] ShowCursor() { return "`e[?25h" }
    
    # Save/Restore
    static [string] SavePosition() { return "`e[s" }
    static [string] RestorePosition() { return "`e[u" }
    
    # Colors
    static [string] Reset() { return "`e[0m" }
    static [string] Bold() { return "`e[1m" }
    static [string] Dim() { return "`e[2m" }
    static [string] Underline() { return "`e[4m" }
    static [string] Blink() { return "`e[5m" }
    static [string] Reverse() { return "`e[7m" }
    
    # Standard Colors
    static [string] Black() { return "`e[30m" }
    static [string] Red() { return "`e[31m" }
    static [string] Green() { return "`e[32m" }
    static [string] Yellow() { return "`e[33m" }
    static [string] Blue() { return "`e[34m" }
    static [string] Magenta() { return "`e[35m" }
    static [string] Cyan() { return "`e[36m" }
    static [string] White() { return "`e[37m" }
    
    # Background Colors
    static [string] BgBlack() { return "`e[40m" }
    static [string] BgRed() { return "`e[41m" }
    static [string] BgGreen() { return "`e[42m" }
    static [string] BgYellow() { return "`e[43m" }
    static [string] BgBlue() { return "`e[44m" }
    static [string] BgMagenta() { return "`e[45m" }
    static [string] BgCyan() { return "`e[46m" }
    static [string] BgWhite() { return "`e[47m" }
    
    # RGB Colors
    static [string] Rgb([int]$r, [int]$g, [int]$b) { return "`e[38;2;$r;$g;$($b)m" }
    static [string] BgRgb([int]$r, [int]$g, [int]$b) { return "`e[48;2;$r;$g;$($b)m" }
}