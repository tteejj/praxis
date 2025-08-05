# GapBuffer.ps1 - High-performance text buffer for editing operations
# Uses a gap buffer data structure for optimal performance on typical editing patterns

class GapBuffer {
    # Internal buffer with gap
    hidden [char[]]$_buffer
    hidden [int]$_gapStart
    hidden [int]$_gapEnd
    hidden [int]$_capacity
    
    # Buffer growth parameters
    hidden [int]$_initialCapacity = 1024
    hidden [double]$_growthFactor = 1.5
    hidden [int]$_minGapSize = 128
    
    # Statistics for debugging/optimization
    [int]$InsertCount = 0
    [int]$DeleteCount = 0
    [int]$MoveCount = 0
    [int]$GrowCount = 0
    
    GapBuffer() {
        $this._capacity = $this._initialCapacity
        $this._buffer = [char[]]::new($this._capacity)
        $this._gapStart = 0
        $this._gapEnd = $this._capacity
    }
    
    GapBuffer([int]$initialCapacity) {
        $this._capacity = [Math]::Max($initialCapacity, $this._minGapSize)
        $this._buffer = [char[]]::new($this._capacity)
        $this._gapStart = 0
        $this._gapEnd = $this._capacity
    }
    
    GapBuffer([string]$text) {
        $textLength = $text.Length
        $this._capacity = [Math]::Max($textLength + $this._minGapSize, $this._initialCapacity)
        $this._buffer = [char[]]::new($this._capacity)
        
        # Copy text to buffer
        if ($textLength -gt 0) {
            [array]::Copy($text.ToCharArray(), 0, $this._buffer, 0, $textLength)
        }
        
        $this._gapStart = $textLength
        $this._gapEnd = $this._capacity
    }
    
    # --- Public Properties ---
    
    [int] GetLength() {
        return $this._capacity - ($this._gapEnd - $this._gapStart)
    }
    
    [int] GetCapacity() {
        return $this._capacity
    }
    
    [int] GetGapSize() {
        return $this._gapEnd - $this._gapStart
    }
    
    # --- Core Operations ---
    
    [void] MoveGapTo([int]$position) {
        if ($position -lt 0 -or $position -gt $this.GetLength()) {
            throw "Position $position is out of range (0-$($this.GetLength()))"
        }
        
        if ($position -eq $this._gapStart) {
            return  # Gap is already at the correct position
        }
        
        $this.MoveCount++
        
        if ($position -lt $this._gapStart) {
            # Move gap left - shift text right
            $moveSize = $this._gapStart - $position
            $sourceStart = $position
            $destStart = $this._gapEnd - $moveSize
            
            [array]::Copy($this._buffer, $sourceStart, $this._buffer, $destStart, $moveSize)
            
            $this._gapStart = $position
            $this._gapEnd -= $moveSize
        } else {
            # Move gap right - shift text left
            $moveSize = $position - $this._gapStart
            $sourceStart = $this._gapEnd
            $destStart = $this._gapStart
            
            [array]::Copy($this._buffer, $sourceStart, $this._buffer, $destStart, $moveSize)
            
            $this._gapStart = $position
            $this._gapEnd += $moveSize
        }
    }
    
    [void] EnsureGapSize([int]$minSize) {
        $currentGapSize = $this._gapEnd - $this._gapStart
        if ($currentGapSize -ge $minSize) {
            return  # Gap is already large enough
        }
        
        # Calculate new capacity
        $currentLength = $this.GetLength()
        $neededCapacity = $currentLength + $minSize
        $newCapacity = [Math]::Max([int]($this._capacity * $this._growthFactor), $neededCapacity)
        
        $this.GrowCount++
        
        # Create new buffer
        $newBuffer = [char[]]::new($newCapacity)
        
        # Copy text before gap
        if ($this._gapStart -gt 0) {
            [array]::Copy($this._buffer, 0, $newBuffer, 0, $this._gapStart)
        }
        
        # Copy text after gap
        $textAfterGap = $this._capacity - $this._gapEnd
        if ($textAfterGap -gt 0) {
            $newGapEnd = $newCapacity - $textAfterGap
            [array]::Copy($this._buffer, $this._gapEnd, $newBuffer, $newGapEnd, $textAfterGap)
            $this._gapEnd = $newGapEnd
        } else {
            $this._gapEnd = $newCapacity
        }
        
        $this._buffer = $newBuffer
        $this._capacity = $newCapacity
    }
    
    # --- Text Operations ---
    
    [void] Insert([int]$position, [char]$char) {
        $this.MoveGapTo($position)
        $this.EnsureGapSize(1)
        
        $this._buffer[$this._gapStart] = $char
        $this._gapStart++
        $this.InsertCount++
    }
    
    [void] Insert([int]$position, [string]$text) {
        if ([string]::IsNullOrEmpty($text)) {
            return
        }
        
        $this.MoveGapTo($position)
        $this.EnsureGapSize($text.Length)
        
        $chars = $text.ToCharArray()
        [array]::Copy($chars, 0, $this._buffer, $this._gapStart, $chars.Length)
        $this._gapStart += $chars.Length
        $this.InsertCount++
    }
    
    [void] Delete([int]$position, [int]$count = 1) {
        if ($count -le 0) {
            return
        }
        
        $length = $this.GetLength()
        if ($position -lt 0 -or $position -ge $length) {
            return  # Position out of bounds
        }
        
        # Clamp count to available characters
        $count = [Math]::Min($count, $length - $position)
        if ($count -le 0) {
            return
        }
        
        $this.MoveGapTo($position)
        
        # Expand gap to include deleted characters
        $this._gapEnd += $count
        $this.DeleteCount++
    }
    
    [char] GetChar([int]$position) {
        $length = $this.GetLength()
        if ($position -lt 0 -or $position -ge $length) {
            return [char]0  # Return null character for out of bounds
        }
        
        if ($position -lt $this._gapStart) {
            return $this._buffer[$position]
        } else {
            return $this._buffer[$position + ($this._gapEnd - $this._gapStart)]
        }
    }
    
    [string] GetText([int]$start, [int]$count) {
        $length = $this.GetLength()
        if ($start -lt 0 -or $start -ge $length -or $count -le 0) {
            return ""
        }
        
        # Clamp count to available characters
        $count = [Math]::Min($count, $length - $start)
        $chars = [char[]]::new($count)
        
        for ($i = 0; $i -lt $count; $i++) {
            $chars[$i] = $this.GetChar($start + $i)
        }
        
        return [string]::new($chars)
    }
    
    [string] GetText() {
        return $this.GetText(0, $this.GetLength())
    }
    
    [string] GetSubstring([int]$start, [int]$length) {
        return $this.GetText($start, $length)
    }
    
    # --- Advanced Operations ---
    
    [void] Clear() {
        $this._gapStart = 0
        $this._gapEnd = $this._capacity
        
        # Optional: Clear the buffer for security
        [array]::Clear($this._buffer, 0, $this._capacity)
    }
    
    [void] SetText([string]$text) {
        $this.Clear()
        if (-not [string]::IsNullOrEmpty($text)) {
            $this.Insert(0, $text)
        }
    }
    
    [int] IndexOf([char]$char, [int]$startIndex = 0) {
        $length = $this.GetLength()
        for ($i = $startIndex; $i -lt $length; $i++) {
            if ($this.GetChar($i) -eq $char) {
                return $i
            }
        }
        return -1
    }
    
    [int] IndexOf([string]$text, [int]$startIndex = 0) {
        if ([string]::IsNullOrEmpty($text)) {
            return -1
        }
        
        $length = $this.GetLength()
        $textLength = $text.Length
        
        for ($i = $startIndex; $i -le $length - $textLength; $i++) {
            $match = $true
            for ($j = 0; $j -lt $textLength; $j++) {
                if ($this.GetChar($i + $j) -ne $text[$j]) {
                    $match = $false
                    break
                }
            }
            if ($match) {
                return $i
            }
        }
        return -1
    }
    
    [int] LastIndexOf([char]$char, [int]$startIndex = -1) {
        $length = $this.GetLength()
        if ($startIndex -eq -1) {
            $startIndex = $length - 1
        }
        
        for ($i = $startIndex; $i -ge 0; $i--) {
            if ($this.GetChar($i) -eq $char) {
                return $i
            }
        }
        return -1
    }
    
    # --- Debugging and Statistics ---
    
    [hashtable] GetStatistics() {
        return @{
            Length = $this.GetLength()
            Capacity = $this._capacity
            GapSize = $this.GetGapSize()
            GapStart = $this._gapStart
            GapEnd = $this._gapEnd
            InsertCount = $this.InsertCount
            DeleteCount = $this.DeleteCount
            MoveCount = $this.MoveCount
            GrowCount = $this.GrowCount
            Efficiency = if ($this.MoveCount -gt 0) { 
                [Math]::Round(($this.InsertCount + $this.DeleteCount) / [double]$this.MoveCount, 2) 
            } else { 
                "N/A" 
            }
        }
    }
    
    [void] ResetStatistics() {
        $this.InsertCount = 0
        $this.DeleteCount = 0
        $this.MoveCount = 0
        $this.GrowCount = 0
    }
    
    [string] ToString() {
        return $this.GetText()
    }
    
    # --- Validation (for debugging) ---
    
    [bool] ValidateStructure() {
        if ($this._gapStart -lt 0 -or $this._gapStart -gt $this._capacity) {
            return $false
        }
        if ($this._gapEnd -lt $this._gapStart -or $this._gapEnd -gt $this._capacity) {
            return $false
        }
        if ($this._capacity -le 0) {
            return $false
        }
        return $true
    }
}