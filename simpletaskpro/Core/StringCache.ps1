# Core/StringCache.ps1 - Pre-cached strings for common rendering patterns
# Optimizes string multiplication operations that allocate frequently
# Direct adaptation from Praxis for immediate performance boost

class StringCache {
    # Cache for space strings of various lengths
    static [hashtable]$Spaces = @{}
    
    # Cache for horizontal line strings
    static [hashtable]$HLines = @{}
    
    # Cache for VT100 cursor movement sequences
    static [hashtable]$CursorMoves = @{}
    
    # Maximum cached length to prevent excessive memory usage
    static [int]$MaxCacheLength = 200
    
    # Initialize the cache with common sizes
    static [void] Initialize() {
        # StringCache: Initializing with max length (no logging dependency)
        
        # Pre-populate common sizes for spaces (1-200)
        for ($i = 1; $i -le [StringCache]::MaxCacheLength; $i++) {
            [StringCache]::Spaces[$i] = " " * $i
        }
        
        # Pre-populate common sizes for horizontal lines
        for ($i = 1; $i -le [StringCache]::MaxCacheLength; $i++) {
            [StringCache]::HLines[$i] = "─" * $i
        }
        
        # StringCache: Initialized (no logging dependency)
    }
    
    # Get spaces of specified width (most commonly used)
    static [string] GetSpaces([int]$width) {
        if ($width -le 0) { return "" }
        
        # Use cache for common sizes
        if ($width -le [StringCache]::MaxCacheLength) {
            return [StringCache]::Spaces[$width]
        }
        
        # For larger widths, build dynamically (rare case)
        # StringCache: Building dynamic spaces string (no logging)
        return " " * $width
    }
    
    # Get horizontal lines of specified width
    static [string] GetHorizontalLine([int]$width) {
        if ($width -le 0) { return "" }
        
        # Use cache for common sizes
        if ($width -le [StringCache]::MaxCacheLength) {
            return [StringCache]::HLines[$width]
        }
        
        # For larger widths, build dynamically
        # StringCache: Building dynamic horizontal line (no logging)
        return "─" * $width
    }
    
    # Get repeated character string (generic version)
    static [string] GetRepeatedChar([char]$char, [int]$count) {
        if ($count -le 0) { return "" }
        
        # Use optimized caches for common characters
        if ($char -eq ' ' -and $count -le [StringCache]::MaxCacheLength) {
            return [StringCache]::Spaces[$count]
        }
        if ($char -eq '─' -and $count -le [StringCache]::MaxCacheLength) {
            return [StringCache]::HLines[$count]
        }
        
        # For other characters or large counts, build dynamically
        return [string]$char * $count
    }
    
    # VT100 cursor movement (cached for performance)
    static [string] GetCursorMove([int]$x, [int]$y) {
        $key = "$x,$y"
        
        if ([StringCache]::CursorMoves.ContainsKey($key)) {
            return [StringCache]::CursorMoves[$key]
        }
        
        # Cache cursor moves for positions up to 100x100 (common screen areas)
        if ($x -le 100 -and $y -le 100 -and [StringCache]::CursorMoves.Count -lt 1000) {
            $sequence = "`e[$($y + 1);$($x + 1)H"
            [StringCache]::CursorMoves[$key] = $sequence
            return $sequence
        }
        
        # For larger coordinates, don't cache (to prevent memory bloat)
        return "`e[$($y + 1);$($x + 1)H"
    }
    
    # Common border characters (cached)
    static [hashtable]$BorderChars = @{
        TopLeft = "┌"
        TopRight = "┐"
        BottomLeft = "└"
        BottomRight = "┘"
        Horizontal = "─"
        Vertical = "│"
        Cross = "┼"
        TDown = "┬"
        TUp = "┴"
        TRight = "├"
        TLeft = "┤"
    }
    
    # Get border character
    static [string] GetBorderChar([string]$type) {
        if ([StringCache]::BorderChars.ContainsKey($type)) {
            return [StringCache]::BorderChars[$type]
        }
        return ""
    }
    
    # Build a simple horizontal border line
    static [string] GetHorizontalBorder([int]$width, [string]$leftChar = "├", [string]$rightChar = "┤", [string]$fillChar = "─") {
        if ($width -le 2) { return "" }
        
        $innerWidth = $width - 2
        $fill = if ($fillChar -eq "─") { 
            [StringCache]::GetHorizontalLine($innerWidth) 
        } else { 
            [StringCache]::GetRepeatedChar($fillChar[0], $innerWidth) 
        }
        
        return "$leftChar$fill$rightChar"
    }
    
    # Get cache statistics (for debugging/monitoring)
    static [hashtable] GetCacheStats() {
        return @{
            SpaceStrings = [StringCache]::Spaces.Count
            LineStrings = [StringCache]::HLines.Count
            CursorMoves = [StringCache]::CursorMoves.Count
            MaxCacheLength = [StringCache]::MaxCacheLength
            TotalCachedItems = ([StringCache]::Spaces.Count + [StringCache]::HLines.Count + [StringCache]::CursorMoves.Count)
        }
    }
    
    # Clear caches (for memory management if needed)
    static [void] ClearCaches() {
        $stats = [StringCache]::GetCacheStats()
        # StringCache: Clearing caches (no logging)
        
        [StringCache]::Spaces.Clear()
        [StringCache]::HLines.Clear()
        [StringCache]::CursorMoves.Clear()
        
        # Re-initialize with basic sizes
        [StringCache]::Initialize()
    }
}

# Auto-initialize the cache when module loads
[StringCache]::Initialize()