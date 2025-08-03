# CleanTextInputDialog.ps1 - CLEAN text input dialog with single-line borders

class CleanTextInputDialog : CleanDialog {
    [string]$Prompt
    [string]$DefaultValue
    [string]$InputValue
    [scriptblock]$OnTextSubmit = {}
    
    CleanTextInputDialog([string]$prompt) : base("Input", 50, 10) {
        $this.Prompt = $prompt
        $this.DefaultValue = ""
        $this.InputValue = ""
    }
    
    CleanTextInputDialog([string]$prompt, [string]$defaultValue) : base("Input", 50, 10) {
        $this.Prompt = $prompt
        $this.DefaultValue = $defaultValue
        $this.InputValue = $defaultValue
    }
    
    [void] OnInitialize() {
        ([CleanDialog]$this).OnInitialize()
        
        # Set up submit handler
        $dialog = $this
        $this.OnSubmit = {
            if ($dialog.OnTextSubmit) {
                & $dialog.OnTextSubmit $dialog.InputValue
            }
        }.GetNewClosure()
        
        # Only two focus positions: input field and buttons
        $this.MaxFocus = 2
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
        
        # Draw prompt
        $promptX = $this._x + 2
        $promptY = $this._y + 2
        $sb.Append([VT]::MoveTo($promptX, $promptY))
        $sb.Append($this.Theme.GetColor("text.secondary"))
        $sb.Append($this.Prompt)
        
        # Draw input field
        $fieldY = $promptY + 2
        $fieldWidth = $this.DialogWidth - 4
        $focused = ($this.FocusedIndex -eq 0)
        
        $sb.Append([VT]::MoveTo($promptX, $fieldY))
        
        if ($focused) {
            # Focused: background highlight
            $sb.Append($this.Theme.GetBgColor("state.focused"))
            $sb.Append($this.Theme.GetColor("text.primary"))
        } else {
            $sb.Append($this.Theme.GetColor("text.primary"))
        }
        
        # Draw input value with cursor
        $displayValue = $this.InputValue
        if ($focused) {
            $displayValue += "█"  # Cursor
        }
        
        if ($displayValue.Length -gt $fieldWidth) {
            $displayValue = $displayValue.Substring($displayValue.Length - $fieldWidth)
        }
        
        $sb.Append($displayValue.PadRight($fieldWidth))
        
        # Draw buttons at bottom
        $buttonY = $this._y + $this.DialogHeight - 3
        $buttonSpacing = 12
        $centerX = $this._x + [int]($this.DialogWidth / 2)
        
        # OK button
        $okX = $centerX - $buttonSpacing
        $okFocused = ($this.FocusedIndex -eq 1)
        $sb.Append([CleanRender]::Button($okX, $buttonY, "OK", $okFocused, $true, $this.Theme))
        
        # Cancel button
        $cancelX = $centerX + 2
        $cancelFocused = ($this.FocusedIndex -eq 2)
        $sb.Append([CleanRender]::Button($cancelX, $buttonY, "Cancel", $cancelFocused, $false, $this.Theme))
        
        $sb.Append([VT]::Reset())
        return $sb.ToString()
    }
    
    [bool] HandleScreenInput([System.ConsoleKeyInfo]$key) {
        switch ($key.Key) {
            ([System.ConsoleKey]::Tab) {
                if ($key.Modifiers -band [System.ConsoleModifiers]::Shift) {
                    $this.FocusedIndex--
                    if ($this.FocusedIndex -lt 0) {
                        $this.FocusedIndex = $this.MaxFocus
                    }
                } else {
                    $this.FocusedIndex++
                    if ($this.FocusedIndex -gt $this.MaxFocus) {
                        $this.FocusedIndex = 0
                    }
                }
                $this.Invalidate()
                return $true
            }
            
            ([System.ConsoleKey]::Enter) {
                if ($this.FocusedIndex -eq 0) {
                    # In input field - move to OK button
                    $this.FocusedIndex = 1
                    $this.Invalidate()
                } elseif ($this.FocusedIndex -eq 1) {
                    # OK button
                    if ($this.OnSubmit) {
                        & $this.OnSubmit
                    }
                    $this.Close()
                } elseif ($this.FocusedIndex -eq 2) {
                    # Cancel button
                    $this.Close()
                }
                return $true
            }
            
            ([System.ConsoleKey]::Escape) {
                $this.Close()
                return $true
            }
            
            ([System.ConsoleKey]::Backspace) {
                if ($this.FocusedIndex -eq 0 -and $this.InputValue.Length -gt 0) {
                    $this.InputValue = $this.InputValue.Substring(0, $this.InputValue.Length - 1)
                    $this.Invalidate()
                }
                return $true
            }
            
            default {
                # Text input
                if ($key.KeyChar -and $key.KeyChar -ge ' ' -and $this.FocusedIndex -eq 0) {
                    $this.InputValue += $key.KeyChar
                    $this.Invalidate()
                    return $true
                }
            }
        }
        return $false
    }
}