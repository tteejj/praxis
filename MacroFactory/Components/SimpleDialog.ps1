# SimpleDialog.ps1 - Simple dialog component for MacroFactory

class SimpleDialog {
    [string]$Title = "Dialog"
    [string]$Message = ""
    [string[]]$Buttons = @("OK", "Cancel")
    [int]$SelectedButton = 0
    [int]$Width = 50
    [int]$Height = 10
    [bool]$IsActive = $true
    [object]$Result = $null
    
    # Colors
    [string]$BorderColor = "`e[38;2;255;200;100m"
    [string]$TitleColor = "`e[38;2;255;255;255m"
    [string]$MessageColor = "`e[38;2;200;200;200m"
    [string]$ButtonColor = "`e[38;2;100;150;255m"
    [string]$SelectedButtonColor = "`e[48;2;100;150;255;38;2;0;0;0m"
    [string]$NormalColor = "`e[0m"
    
    SimpleDialog([string]$title, [string]$message) {
        $this.Title = $title
        $this.Message = $message
    }
    
    [void] Show() {
        # Save current screen
        [Console]::CursorVisible = $false
        
        # Calculate position (center of screen)
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
        
        # Draw shadow (optional, for better visibility)
        for ($i = 1; $i -lt $this.Height; $i++) {
            $sb.Append([VT]::MoveTo($x + 2, $y + $i))
            $sb.Append("`e[38;2;50;50;50m" + ("▒" * $this.Width))
        }
        
        # Draw dialog background
        for ($i = 0; $i -lt $this.Height; $i++) {
            $sb.Append([VT]::MoveTo($x, $y + $i))
            $sb.Append("`e[48;2;30;30;40m" + (" " * $this.Width))
        }
        
        # Draw border
        $sb.Append([VT]::MoveTo($x, $y))
        $sb.Append($this.BorderColor)
        $sb.Append("╭" + ("─" * ($this.Width - 2)) + "╮")
        
        # Draw title
        $titleText = " $($this.Title) "
        $titlePos = $x + [Math]::Floor(($this.Width - $titleText.Length) / 2)
        $sb.Append([VT]::MoveTo($titlePos, $y))
        $sb.Append($this.TitleColor + $titleText + $this.BorderColor)
        
        # Draw sides
        for ($i = 1; $i -lt ($this.Height - 1); $i++) {
            $sb.Append([VT]::MoveTo($x, $y + $i))
            $sb.Append($this.BorderColor + "│" + $this.NormalColor)
            $sb.Append([VT]::MoveTo($x + $this.Width - 1, $y + $i))
            $sb.Append($this.BorderColor + "│")
        }
        
        # Draw message
        $messageLines = $this.WrapText($this.Message, $this.Width - 4)
        $messageY = $y + 2
        foreach ($line in $messageLines) {
            if ($messageY -ge ($y + $this.Height - 3)) { break }
            $sb.Append([VT]::MoveTo($x + 2, $messageY))
            $sb.Append($this.MessageColor + $line)
            $messageY++
        }
        
        # Draw buttons
        $buttonY = $y + $this.Height - 2
        $totalButtonWidth = 0
        foreach ($button in $this.Buttons) {
            $totalButtonWidth += $button.Length + 4
        }
        $totalButtonWidth += ($this.Buttons.Count - 1) * 2
        
        $buttonX = $x + [Math]::Floor(($this.Width - $totalButtonWidth) / 2)
        
        for ($i = 0; $i -lt $this.Buttons.Count; $i++) {
            $button = $this.Buttons[$i]
            $sb.Append([VT]::MoveTo($buttonX, $buttonY))
            
            if ($i -eq $this.SelectedButton) {
                $sb.Append($this.SelectedButtonColor)
            } else {
                $sb.Append($this.ButtonColor)
            }
            
            $sb.Append(" $button ")
            $sb.Append($this.NormalColor)
            
            $buttonX += $button.Length + 6
        }
        
        # Draw bottom border
        $sb.Append([VT]::MoveTo($x, $y + $this.Height - 1))
        $sb.Append($this.BorderColor)
        $sb.Append("╰" + ("─" * ($this.Width - 2)) + "╯")
        $sb.Append($this.NormalColor)
        
        Write-Host -NoNewline $sb.ToString()
    }
    
    [void] HandleInput([System.ConsoleKeyInfo]$key) {
        switch ($key.Key) {
            ([System.ConsoleKey]::LeftArrow) {
                if ($this.SelectedButton -gt 0) {
                    $this.SelectedButton--
                }
            }
            ([System.ConsoleKey]::RightArrow) {
                if ($this.SelectedButton -lt ($this.Buttons.Count - 1)) {
                    $this.SelectedButton++
                }
            }
            ([System.ConsoleKey]::Tab) {
                $this.SelectedButton = ($this.SelectedButton + 1) % $this.Buttons.Count
            }
            ([System.ConsoleKey]::Enter) {
                $this.Result = $this.Buttons[$this.SelectedButton]
                $this.IsActive = $false
            }
            ([System.ConsoleKey]::Escape) {
                $this.Result = "Cancel"
                $this.IsActive = $false
            }
        }
    }
    
    [string[]] WrapText([string]$text, [int]$width) {
        $lines = @()
        $words = $text -split '\s+'
        $currentLine = ""
        
        foreach ($word in $words) {
            if (($currentLine.Length + $word.Length + 1) -le $width) {
                if ($currentLine) {
                    $currentLine += " "
                }
                $currentLine += $word
            } else {
                if ($currentLine) {
                    $lines += $currentLine
                }
                $currentLine = $word
            }
        }
        
        if ($currentLine) {
            $lines += $currentLine
        }
        
        return $lines
    }
}