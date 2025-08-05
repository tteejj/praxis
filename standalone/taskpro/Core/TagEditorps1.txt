# TagEditor.ps1 - Simple tag editor for tasks

class TagEditor {
    [int]$X
    [int]$Y
    [int]$Width
    [int]$Height
    [string]$TagString = ""
    [int]$CursorPos = 0
    [string[]]$Tags = @()
    
    TagEditor() {}
    
    [void] SetBounds([int]$x, [int]$y, [int]$width, [int]$height) {
        $this.X = $x
        $this.Y = $y
        $this.Width = $width
        $this.Height = $height
    }
    
    [void] SetTags([string[]]$tags) {
        $this.Tags = $tags
        if ($tags.Count -gt 0) {
            $this.TagString = "#" + ($tags -join " #")
        } else {
            $this.TagString = ""
        }
        $this.CursorPos = $this.TagString.Length
    }
    
    [string[]] GetTags() {
        if ([string]::IsNullOrWhiteSpace($this.TagString)) {
            return @()
        }
        
        # Split by # and filter out empty entries
        $tagParts = $this.TagString -split '#' | Where-Object { $_.Trim() -ne "" }
        $cleanTags = @()
        
        foreach ($part in $tagParts) {
            $cleanTag = $part.Trim() -replace '\s+', '-'  # Replace spaces with dashes
            if ($cleanTag -ne "") {
                $cleanTags += $cleanTag
            }
        }
        
        return $cleanTags
    }
    
    [string] Render() {
        $sb = [System.Text.StringBuilder]::new()
        
        # Editor border
        [void]$sb.Append([VT]::MoveTo($this.X, $this.Y))
        [void]$sb.Append("┌" + ("─" * ($this.Width - 2)) + "┐")
        
        [void]$sb.Append([VT]::MoveTo($this.X, $this.Y + 1))
        [void]$sb.Append("│ Tags: ")
        
        # Show tag input with cursor
        $displayText = $this.TagString
        if ($displayText.Length -gt ($this.Width - 10)) {
            # Scroll text if too long
            $startPos = [Math]::Max(0, $this.CursorPos - ($this.Width - 15))
            $displayText = $displayText.Substring($startPos)
        }
        
        [void]$sb.Append($displayText)
        
        # Pad the rest of the line
        $remainingSpace = $this.Width - 8 - $displayText.Length
        if ($remainingSpace -gt 0) {
            [void]$sb.Append(" " * $remainingSpace)
        }
        [void]$sb.Append("│")
        
        [void]$sb.Append([VT]::MoveTo($this.X, $this.Y + 2))
        [void]$sb.Append("│ Format: #work #urgent #client-name")
        [void]$sb.Append(" " * ($this.Width - 35))
        [void]$sb.Append("│")
        
        [void]$sb.Append([VT]::MoveTo($this.X, $this.Y + 3))
        [void]$sb.Append("└" + ("─" * ($this.Width - 2)) + "┘")
        
        # Position cursor in input field
        $cursorX = $this.X + 8 + [Math]::Min($this.CursorPos, $this.Width - 10)
        [void]$sb.Append([VT]::MoveTo($cursorX, $this.Y + 1))
        [void]$sb.Append([VT]::ShowCursor())
        
        return $sb.ToString()
    }
    
    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        switch ($key.Key) {
            ([System.ConsoleKey]::LeftArrow) {
                if ($this.CursorPos -gt 0) {
                    $this.CursorPos--
                }
                return $true
            }
            ([System.ConsoleKey]::RightArrow) {
                if ($this.CursorPos -lt $this.TagString.Length) {
                    $this.CursorPos++
                }
                return $true
            }
            ([System.ConsoleKey]::Home) {
                $this.CursorPos = 0
                return $true
            }
            ([System.ConsoleKey]::End) {
                $this.CursorPos = $this.TagString.Length
                return $true
            }
            ([System.ConsoleKey]::Backspace) {
                if ($this.CursorPos -gt 0) {
                    $this.TagString = $this.TagString.Remove($this.CursorPos - 1, 1)
                    $this.CursorPos--
                }
                return $true
            }
            ([System.ConsoleKey]::Delete) {
                if ($this.CursorPos -lt $this.TagString.Length) {
                    $this.TagString = $this.TagString.Remove($this.CursorPos, 1)
                }
                return $true
            }
            ([System.ConsoleKey]::Enter) {
                return $false  # Signal completion
            }
            ([System.ConsoleKey]::Escape) {
                return $false  # Signal completion
            }
            default {
                if ($key.KeyChar -and -not [char]::IsControl($key.KeyChar)) {
                    # Insert character at cursor position
                    $this.TagString = $this.TagString.Insert($this.CursorPos, $key.KeyChar)
                    $this.CursorPos++
                }
                return $true
            }
        }
        return $true  # Fallback return
    }
}