# TextInputDialog.ps1 - Simple text input dialog

class TextInputDialog : SimpleDialog {
    [string]$Prompt
    [string]$InputText = ""
    
    TextInputDialog([string]$title, [string]$prompt) : base($title, "") {
        $this.Prompt = $prompt
        $this.Width = 50
        $this.Height = 8
        $this.Buttons = @("OK", "Cancel")
    }
    
    [void] Show() {
        [Console]::CursorVisible = $true
        
        # Calculate position
        $screenWidth = [Console]::WindowWidth
        $screenHeight = [Console]::WindowHeight
        $x = [Math]::Floor(($screenWidth - $this.Width) / 2)
        $y = [Math]::Floor(($screenHeight - $this.Height) / 2)
        
        $editingMode = $true
        
        while ($this.IsActive) {
            $this.DrawInputDialog($x, $y, $editingMode)
            
            $key = [Console]::ReadKey($true)
            
            if ($editingMode) {
                switch ($key.Key) {
                    ([System.ConsoleKey]::Tab) {
                        $editingMode = $false
                        $this.SelectedButton = 0
                    }
                    ([System.ConsoleKey]::Enter) {
                        $this.Result = "OK"
                        $this.IsActive = $false
                    }
                    ([System.ConsoleKey]::Escape) {
                        $this.Result = "Cancel"
                        $this.IsActive = $false
                    }
                    ([System.ConsoleKey]::Backspace) {
                        if ($this.InputText.Length -gt 0) {
                            $this.InputText = $this.InputText.Substring(0, $this.InputText.Length - 1)
                        }
                    }
                    default {
                        if ($key.KeyChar -and [char]::IsControl($key.KeyChar) -eq $false) {
                            $this.InputText += $key.KeyChar
                        }
                    }
                }
            } else {
                switch ($key.Key) {
                    ([System.ConsoleKey]::Tab) {
                        if ($key.Modifiers -band [System.ConsoleModifiers]::Shift) {
                            $editingMode = $true
                        } else {
                            $this.SelectedButton = ($this.SelectedButton + 1) % $this.Buttons.Count
                        }
                    }
                    ([System.ConsoleKey]::UpArrow) {
                        $editingMode = $true
                    }
                    default {
                        $this.HandleInput($key)
                    }
                }
            }
        }
        
        [Console]::CursorVisible = $false
    }
    
    [void] DrawInputDialog([int]$x, [int]$y, [bool]$editingMode) {
        # Use parent's Draw method for basic dialog
        $this.Draw($x, $y)
        
        # Draw prompt
        $sb = [System.Text.StringBuilder]::new()
        $sb.Append([VT]::MoveTo($x + 2, $y + 2))
        $sb.Append($this.MessageColor + $this.Prompt)
        
        # Draw input field
        $fieldY = $y + 4
        $sb.Append([VT]::MoveTo($x + 2, $fieldY))
        
        $fieldBg = if ($editingMode) {
            "`e[48;2;60;60;80m"
        } else {
            "`e[48;2;40;40;50m"
        }
        
        $sb.Append($fieldBg)
        $sb.Append(" " + $this.InputText.PadRight($this.Width - 6) + " ")
        $sb.Append($this.NormalColor)
        
        Write-Host -NoNewline $sb.ToString()
        
        # Position cursor
        if ($editingMode) {
            [Console]::SetCursorPosition($x + 3 + $this.InputText.Length, $fieldY)
        }
    }
}