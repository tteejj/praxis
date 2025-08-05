# VT100.ps1 - VT100 terminal control sequences

class VT {
    # Basic cursor movement
    static [string] MoveTo([int]$x, [int]$y) {
        return "`e[$($y + 1);$($x + 1)H"
    }
    
    static [string] MoveUp([int]$lines) {
        return "`e[$($lines)A"
    }
    
    static [string] MoveDown([int]$lines) {
        return "`e[$($lines)B"
    }
    
    static [string] MoveRight([int]$columns) {
        return "`e[$($columns)C"
    }
    
    static [string] MoveLeft([int]$columns) {
        return "`e[$($columns)D"
    }
    
    # Screen control
    static [string] Clear() {
        return "`e[2J`e[H"
    }
    
    static [string] ClearLine() {
        return "`e[K"
    }
    
    static [string] ClearLineFromCursor() {
        return "`e[0K"
    }
    
    static [string] ClearLineToCursor() {
        return "`e[1K"
    }
    
    static [string] ClearEntireLine() {
        return "`e[2K"
    }
    
    # Cursor visibility
    static [string] HideCursor() {
        return "`e[?25l"
    }
    
    static [string] ShowCursor() {
        return "`e[?25h"
    }
    
    # Colors (256-color mode)
    static [string] FgColor([int]$color) {
        return "`e[38;5;$($color)m"
    }
    
    static [string] BgColor([int]$color) {
        return "`e[48;5;$($color)m"
    }
    
    # RGB colors
    static [string] FgRGB([int]$r, [int]$g, [int]$b) {
        return "`e[38;2;$r;$g;${b}m"
    }
    
    static [string] BgRGB([int]$r, [int]$g, [int]$b) {
        return "`e[48;2;$r;$g;${b}m"
    }
    
    # Reset
    static [string] Reset() {
        return "`e[0m"
    }
    
    # Text styles
    static [string] Bold() {
        return "`e[1m"
    }
    
    static [string] Dim() {
        return "`e[2m"
    }
    
    static [string] Italic() {
        return "`e[3m"
    }
    
    static [string] Underline() {
        return "`e[4m"
    }
    
    static [string] Reverse() {
        return "`e[7m"
    }
    
    # Common color shortcuts
    static [string] Red() {
        return "`e[31m"
    }
    
    static [string] Green() {
        return "`e[32m"
    }
    
    static [string] Yellow() {
        return "`e[33m"
    }
    
    static [string] Blue() {
        return "`e[34m"
    }
    
    static [string] Magenta() {
        return "`e[35m"
    }
    
    static [string] Cyan() {
        return "`e[36m"
    }
    
    static [string] White() {
        return "`e[37m"
    }
    
    static [string] BrightRed() {
        return "`e[91m"
    }
    
    static [string] BrightGreen() {
        return "`e[92m"
    }
    
    static [string] BrightYellow() {
        return "`e[93m"
    }
    
    static [string] BrightBlue() {
        return "`e[94m"
    }
    
    static [string] BrightMagenta() {
        return "`e[95m"
    }
    
    static [string] BrightCyan() {
        return "`e[96m"
    }
    
    static [string] BrightWhite() {
        return "`e[97m"
    }
}