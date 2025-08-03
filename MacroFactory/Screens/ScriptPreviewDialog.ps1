# ScriptPreviewDialog.ps1 - Dialog for previewing generated scripts

class ScriptPreviewDialog {
    [string]$Script
    [int]$ScrollTop = 0
    [string[]]$Lines
    [int]$Width = 80
    [int]$Height = 24
    [bool]$IsActive = $true
    
    # Colors
    [string]$BorderColor = "`e[38;2;100;200;100m"
    [string]$TitleColor = "`e[38;2;255;255;255m"
    [string]$ScriptColor = "`e[38;2;200;200;200m"
    [string]$CommentColor = "`e[38;2;100;200;100m"
    [string]$KeywordColor = "`e[38;2;100;150;255m"
    [string]$NormalColor = "`e[0m"
    
    ScriptPreviewDialog([string]$script) {
        $this.Script = $script
        $this.Lines = $script -split "`n"
    }
    
    [void] Show() {
        [Console]::CursorVisible = $false
        
        # Calculate position
        $screenWidth = [Console]::WindowWidth
        $screenHeight = [Console]::WindowHeight
        $x = [Math]::Floor(($screenWidth - $this.Width) / 2)
        $y = [Math]::Floor(($screenHeight - $this.Height) / 2)
        
        while ($this.IsActive) {
            $this.Draw($x, $y)
            
            $key = [Console]::ReadKey($true)
            $this.HandleInput($key)
        }
    }
    
    [void] Draw([int]$x, [int]$y) {
        $sb = [System.Text.StringBuilder]::new()
        
        # Draw background
        for ($i = 0; $i -lt $this.Height; $i++) {
            $sb.Append([VT]::MoveTo($x, $y + $i))
            $sb.Append("`e[48;2;20;20;30m" + (" " * $this.Width))
        }
        
        # Draw border
        $sb.Append([VT]::MoveTo($x, $y))
        $sb.Append($this.BorderColor)
        $sb.Append("╭" + ("─" * ($this.Width - 2)) + "╮")
        
        # Draw title
        $titleText = " IDEAScript Preview "
        $titlePos = $x + [Math]::Floor(($this.Width - $titleText.Length) / 2)
        $sb.Append([VT]::MoveTo($titlePos, $y))
        $sb.Append($this.TitleColor + $titleText + $this.BorderColor)
        
        # Draw sides and content
        $contentHeight = $this.Height - 4
        for ($i = 0; $i -lt $contentHeight; $i++) {
            $lineY = $y + $i + 1
            $sb.Append([VT]::MoveTo($x, $lineY))
            $sb.Append($this.BorderColor + "│" + $this.NormalColor)
            
            # Draw script line
            $lineIndex = $this.ScrollTop + $i
            if ($lineIndex -lt $this.Lines.Count) {
                $line = $this.Lines[$lineIndex]
                $formattedLine = $this.FormatScriptLine($line)
                
                # Truncate if too long
                $plainLine = $line -replace '\e\[[0-9;]*m', ''
                if ($plainLine.Length -gt ($this.Width - 4)) {
                    $line = $plainLine.Substring(0, $this.Width - 7) + "..."
                    $formattedLine = $this.FormatScriptLine($line)
                }
                
                $sb.Append(" " + $formattedLine.PadRight($this.Width - 3))
            } else {
                $sb.Append(" " * ($this.Width - 2))
            }
            
            $sb.Append([VT]::MoveTo($x + $this.Width - 1, $lineY))
            $sb.Append($this.BorderColor + "│" + $this.NormalColor)
        }
        
        # Draw instructions
        $sb.Append([VT]::MoveTo($x, $y + $this.Height - 3))
        $sb.Append($this.BorderColor + "├" + ("─" * ($this.Width - 2)) + "┤")
        
        $sb.Append([VT]::MoveTo($x + 2, $y + $this.Height - 2))
        $sb.Append("`e[38;2;150;150;150m↑↓:Scroll | Escape:Close | Ctrl+C:Copy to Clipboard`e[0m")
        
        # Draw bottom border
        $sb.Append([VT]::MoveTo($x, $y + $this.Height - 1))
        $sb.Append($this.BorderColor)
        $sb.Append("╰" + ("─" * ($this.Width - 2)) + "╯")
        $sb.Append($this.NormalColor)
        
        Write-Host -NoNewline $sb.ToString()
    }
    
    [string] FormatScriptLine([string]$line) {
        # Simple syntax highlighting for VBScript/IDEAScript
        if ($line.Trim().StartsWith("'")) {
            return $this.CommentColor + $line + $this.NormalColor
        }
        
        # Keywords
        $keywords = @("Sub", "End Sub", "Function", "End Function", "Dim", "Set", 
                      "If", "Then", "Else", "End If", "For", "Next", "Do", "Loop",
                      "Option Explicit", "On Error", "GoTo", "Exit Sub")
        
        $formattedLine = $line
        foreach ($keyword in $keywords) {
            $formattedLine = $formattedLine -replace "\b$keyword\b", 
                ($this.KeywordColor + $keyword + $this.ScriptColor)
        }
        
        return $this.ScriptColor + $formattedLine + $this.NormalColor
    }
    
    [void] HandleInput([System.ConsoleKeyInfo]$key) {
        switch ($key.Key) {
            ([System.ConsoleKey]::UpArrow) {
                if ($this.ScrollTop -gt 0) {
                    $this.ScrollTop--
                }
            }
            ([System.ConsoleKey]::DownArrow) {
                $maxScroll = [Math]::Max(0, $this.Lines.Count - ($this.Height - 4))
                if ($this.ScrollTop -lt $maxScroll) {
                    $this.ScrollTop++
                }
            }
            ([System.ConsoleKey]::PageUp) {
                $this.ScrollTop = [Math]::Max(0, $this.ScrollTop - ($this.Height - 4))
            }
            ([System.ConsoleKey]::PageDown) {
                $maxScroll = [Math]::Max(0, $this.Lines.Count - ($this.Height - 4))
                $this.ScrollTop = [Math]::Min($maxScroll, $this.ScrollTop + ($this.Height - 4))
            }
            ([System.ConsoleKey]::Home) {
                $this.ScrollTop = 0
            }
            ([System.ConsoleKey]::End) {
                $this.ScrollTop = [Math]::Max(0, $this.Lines.Count - ($this.Height - 4))
            }
            ([System.ConsoleKey]::C) {
                if ($key.Modifiers -band [System.ConsoleModifiers]::Control) {
                    # Copy to clipboard (Windows only)
                    try {
                        $this.Script | Set-Clipboard
                        # Show confirmation briefly
                        [Console]::SetCursorPosition(2, [Console]::WindowHeight - 1)
                        Write-Host -NoNewline "`e[38;2;100;255;100mCopied to clipboard!`e[0m"
                        Start-Sleep -Milliseconds 1000
                    } catch {
                        # Clipboard not available
                    }
                }
            }
            ([System.ConsoleKey]::Escape) {
                $this.IsActive = $false
            }
            ([System.ConsoleKey]::Q) {
                $this.IsActive = $false
            }
        }
    }
}