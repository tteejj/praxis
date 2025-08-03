# CleanConfirmationDialog.ps1 - CLEAN confirmation dialog with single-line borders

class CleanConfirmationDialog : CleanDialog {
    [string]$Message
    [string]$ConfirmText = "Yes"
    [string]$CancelText = "No"
    
    CleanConfirmationDialog([string]$message) : base("Confirm", 50, 10) {
        $this.Message = $message
    }
    
    [string] OnRender() {
        if (-not $this.Theme) { return "" }
        
        $sb = [System.Text.StringBuilder]::new()
        
        # Clear screen with theme background
        $bgColor = $this.Theme.GetBgColor("surface.background")
        for ($y = 0; $y -lt [Console]::WindowHeight; $y++) {
            $sb.Append([VT]::MoveTo(0, $y))
            $sb.Append($bgColor)
            $sb.Append(' ' * [Console]::WindowWidth)
        }
        
        # Draw dialog
        $sb.Append([CleanRender]::Dialog($this._x, $this._y, $this.DialogWidth, $this.DialogHeight, $this.DialogTitle, $this.Theme))
        
        # Draw message (centered)
        $messageLines = $this.Message -split "`n"
        $startY = $this._y + 3
        $lineNum = 0
        
        foreach ($line in $messageLines) {
            if ($lineNum -ge 3) { break }  # Max 3 lines
            $centerX = $this._x + [int](($this.DialogWidth - $line.Length) / 2)
            $sb.Append([VT]::MoveTo($centerX, $startY + $lineNum))
            $sb.Append($this.Theme.GetColor("text.primary"))
            $sb.Append($line)
            $lineNum++
        }
        
        # Draw buttons at bottom
        $buttonY = $this._y + $this.DialogHeight - 3
        $buttonSpacing = 12
        $centerX = $this._x + [int]($this.DialogWidth / 2)
        
        # Yes/Confirm button
        $yesX = $centerX - $buttonSpacing
        $yesFocused = ($this.FocusedIndex -eq 0)
        $sb.Append([CleanRender]::Button($yesX, $buttonY, $this.ConfirmText, $yesFocused, $true, $this.Theme))
        
        # No/Cancel button  
        $noX = $centerX + 2
        $noFocused = ($this.FocusedIndex -eq 1)
        $sb.Append([CleanRender]::Button($noX, $buttonY, $this.CancelText, $noFocused, $false, $this.Theme))
        
        $sb.Append([VT]::Reset())
        return $sb.ToString()
    }
    
    [bool] HandleScreenInput([System.ConsoleKeyInfo]$key) {
        switch ($key.Key) {
            ([System.ConsoleKey]::Tab) {
                $this.FocusedIndex = ($this.FocusedIndex + 1) % 2
                $this.Invalidate()
                return $true
            }
            
            ([System.ConsoleKey]::LeftArrow) {
                $this.FocusedIndex = 0
                $this.Invalidate()
                return $true
            }
            
            ([System.ConsoleKey]::RightArrow) {
                $this.FocusedIndex = 1
                $this.Invalidate()
                return $true
            }
            
            ([System.ConsoleKey]::Enter) {
                if ($this.FocusedIndex -eq 0) {
                    # Confirmed
                    if ($this.OnSubmit) {
                        & $this.OnSubmit
                    }
                }
                $this.Close()
                return $true
            }
            
            ([System.ConsoleKey]::Escape) {
                $this.Close()
                return $true
            }
            
            ([System.ConsoleKey]::Y) {
                # Quick confirm
                if ($this.OnSubmit) {
                    & $this.OnSubmit
                }
                $this.Close()
                return $true
            }
            
            ([System.ConsoleKey]::N) {
                # Quick cancel
                $this.Close()
                return $true
            }
        }
        return $false
    }
    
    [void] OnInitialize() {
        ([CleanDialog]$this).OnInitialize()
        # Start with No/Cancel focused (safer)
        $this.FocusedIndex = 1
        $this.MaxFocus = 1
    }
}