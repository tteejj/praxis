# CleanDialog.ps1 - Dialog that renders PROPERLY with clean borders

class CleanDialog : Screen {
    [string]$DialogTitle
    [int]$DialogWidth = 60
    [int]$DialogHeight = 20
    [hashtable]$Fields = [ordered]@{}
    [int]$FocusedIndex = 0
    [int]$MaxFocus = 0
    [scriptblock]$OnSubmit = {}
    
    hidden [int]$_x
    hidden [int]$_y
    
    CleanDialog([string]$title, [int]$width, [int]$height) : base() {
        $this.DialogTitle = $title
        $this.DialogWidth = $width
        $this.DialogHeight = $height
        $this.Title = $title
    }
    
    [void] AddField([string]$name, [string]$label, [string]$value = "") {
        $this.Fields[$name] = @{
            Label = $label
            Value = $value
            Index = $this.Fields.Count
        }
        $this.MaxFocus = $this.Fields.Count + 1  # +2 for buttons, -1 for 0-based
    }
    
    [string] GetFieldValue([string]$name) {
        if ($this.Fields.Contains($name)) {
            return $this.Fields[$name].Value
        }
        return ""
    }
    
    [void] OnInitialize() {
        ([Screen]$this).OnInitialize()
        
        # Calculate centered position
        $consoleW = [Console]::WindowWidth
        $consoleH = [Console]::WindowHeight
        
        # Constrain size
        $this.DialogWidth = [Math]::Min($this.DialogWidth, $consoleW - 4)
        $this.DialogHeight = [Math]::Min($this.DialogHeight, $consoleH - 4)
        
        # Center
        $this._x = [Math]::Max(1, [int](($consoleW - $this.DialogWidth) / 2))
        $this._y = [Math]::Max(1, [int](($consoleH - $this.DialogHeight) / 2))
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
        
        # Draw fields
        $fieldY = $this._y + 2
        $fieldX = $this._x + 2
        $fieldWidth = $this.DialogWidth - 4
        
        foreach ($fieldName in $this.Fields.Keys) {
            $field = $this.Fields[$fieldName]
            $focused = ($this.FocusedIndex -eq $field.Index)
            
            $sb.Append([CleanRender]::Field(
                $fieldX,
                $fieldY,
                $fieldWidth,
                $field.Label + ':',
                $field.Value,
                $focused,
                $this.Theme
            ))
            
            $fieldY += 2  # Space between fields
        }
        
        # Draw buttons at bottom
        $buttonY = $this._y + $this.DialogHeight - 3
        $buttonSpacing = 12
        $centerX = $this._x + [int]($this.DialogWidth / 2)
        
        # OK button
        $okX = $centerX - $buttonSpacing
        $okFocused = ($this.FocusedIndex -eq $this.Fields.Count)
        $sb.Append([CleanRender]::Button($okX, $buttonY, "OK", $okFocused, $true, $this.Theme))
        
        # Cancel button
        $cancelX = $centerX + 2
        $cancelFocused = ($this.FocusedIndex -eq $this.Fields.Count + 1)
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
                if ($this.FocusedIndex -eq $this.Fields.Count) {
                    # OK button
                    if ($this.OnSubmit) {
                        & $this.OnSubmit
                    }
                    $this.Close()
                } elseif ($this.FocusedIndex -eq $this.Fields.Count + 1) {
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
                if ($this.FocusedIndex -lt $this.Fields.Count) {
                    # In a field
                    $fieldName = $this.Fields.Keys | Where-Object { $this.Fields[$_].Index -eq $this.FocusedIndex } | Select-Object -First 1
                    if ($fieldName -and $this.Fields[$fieldName].Value.Length -gt 0) {
                        $this.Fields[$fieldName].Value = $this.Fields[$fieldName].Value.Substring(0, $this.Fields[$fieldName].Value.Length - 1)
                        $this.Invalidate()
                    }
                }
                return $true
            }
            
            default {
                # Text input
                if ($key.KeyChar -and $key.KeyChar -ge ' ' -and $this.FocusedIndex -lt $this.Fields.Count) {
                    $fieldName = $this.Fields.Keys | Where-Object { $this.Fields[$_].Index -eq $this.FocusedIndex } | Select-Object -First 1
                    if ($fieldName) {
                        $this.Fields[$fieldName].Value += $key.KeyChar
                        $this.Invalidate()
                    }
                    return $true
                }
            }
        }
        return $false
    }
    
    [void] Close() {
        if ($global:ScreenManager) {
            $global:ScreenManager.Pop()
        }
    }
}