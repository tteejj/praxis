# SimpleDialog.ps1 - Dialog that ACTUALLY DISPLAYS CORRECTLY

class SimpleDialog : Screen {
    [string]$DialogTitle = "Dialog"
    [int]$DialogWidth = 60
    [int]$DialogHeight = 20
    [hashtable]$Fields = @{}  # Field definitions
    [hashtable]$Values = @{}  # Field values
    [string]$FocusedField = ""
    [bool]$ButtonFocused = $false
    [scriptblock]$OnOK = {}
    [scriptblock]$OnCancel = {}
    
    # Dialog bounds
    hidden [int]$_dialogX
    hidden [int]$_dialogY
    
    SimpleDialog([string]$title) : base() {
        $this.DialogTitle = $title
        $this.Title = $title  # For screen manager
    }
    
    [void] AddField([string]$name, [string]$label, [string]$defaultValue = "") {
        $this.Fields[$name] = @{
            Label = $label
            Order = $this.Fields.Count
        }
        $this.Values[$name] = $defaultValue
        
        # Set first field as focused
        if (-not $this.FocusedField) {
            $this.FocusedField = $name
        }
    }
    
    [void] OnInitialize() {
        ([Screen]$this).OnInitialize()
        $this.CalculateBounds()
    }
    
    [void] CalculateBounds() {
        # Simple center calculation that WORKS
        $consoleW = [Console]::WindowWidth
        $consoleH = [Console]::WindowHeight
        
        # Ensure dialog fits
        $this.DialogWidth = [Math]::Min($this.DialogWidth, $consoleW - 4)
        $this.DialogHeight = [Math]::Min($this.DialogHeight, $consoleH - 4)
        
        # Center it
        $this._dialogX = [int](($consoleW - $this.DialogWidth) / 2)
        $this._dialogY = [int](($consoleH - $this.DialogHeight) / 2)
    }
    
    [string] OnRender() {
        if (-not $this.Theme) { return "" }
        
        $sb = [System.Text.StringBuilder]::new()
        
        # Dim background with THEME COLOR
        $bgColor = $this.Theme.GetBgColor("surface.background")
        for ($y = 0; $y -lt [Console]::WindowHeight; $y++) {
            $sb.Append([VT]::MoveTo(0, $y))
            $sb.Append($bgColor)
            $sb.Append(' ' * [Console]::WindowWidth)
        }
        
        # Draw dialog box
        $sb.Append([SimpleRender]::Box(
            $this._dialogX, 
            $this._dialogY, 
            $this.DialogWidth, 
            $this.DialogHeight, 
            $this.Theme, 
            $this.DialogTitle
        ))
        
        # Draw fields
        $fieldY = $this._dialogY + 2
        $labelWidth = 15
        
        foreach ($fieldName in $this.Fields.Keys | Sort-Object { $this.Fields[$_].Order }) {
            $field = $this.Fields[$fieldName]
            $value = $this.Values[$fieldName]
            $focused = ($fieldName -eq $this.FocusedField -and -not $this.ButtonFocused)
            
            $sb.Append([SimpleRender]::Field(
                $this._dialogX + 2,
                $fieldY,
                $field.Label + ":",
                $value,
                $labelWidth,
                $focused,
                $this.Theme
            ))
            
            $fieldY += 2
        }
        
        # Draw buttons at bottom
        $buttonY = $this._dialogY + $this.DialogHeight - 3
        $okX = $this._dialogX + [int]($this.DialogWidth / 2) - 10
        $cancelX = $this._dialogX + [int]($this.DialogWidth / 2) + 2
        
        $sb.Append([SimpleRender]::Button(
            $okX, $buttonY, "OK", 
            ($this.ButtonFocused -and $this.FocusedField -eq "OK"),
            $this.Theme
        ))
        
        $sb.Append([SimpleRender]::Button(
            $cancelX, $buttonY, "Cancel",
            ($this.ButtonFocused -and $this.FocusedField -eq "Cancel"),
            $this.Theme
        ))
        
        $sb.Append([VT]::Reset())
        return $sb.ToString()
    }
    
    [bool] HandleScreenInput([System.ConsoleKeyInfo]$key) {
        switch ($key.Key) {
            ([System.ConsoleKey]::Tab) {
                $this.NextField()
                $this.Invalidate()
                return $true
            }
            ([System.ConsoleKey]::Enter) {
                if ($this.ButtonFocused) {
                    if ($this.FocusedField -eq "OK") {
                        if ($this.OnOK) { & $this.OnOK }
                        $this.Close()
                    } else {
                        if ($this.OnCancel) { & $this.OnCancel }
                        $this.Close()
                    }
                    return $true
                }
            }
            ([System.ConsoleKey]::Escape) {
                if ($this.OnCancel) { & $this.OnCancel }
                $this.Close()
                return $true
            }
            default {
                # Handle typing in fields
                if (-not $this.ButtonFocused -and $key.KeyChar -ge ' ') {
                    $this.Values[$this.FocusedField] += $key.KeyChar
                    $this.Invalidate()
                    return $true
                }
            }
        }
        return $false
    }
    
    [void] NextField() {
        if ($this.ButtonFocused) {
            if ($this.FocusedField -eq "OK") {
                $this.FocusedField = "Cancel"
            } else {
                # Go back to first field
                $this.ButtonFocused = $false
                $firstField = $this.Fields.Keys | Sort-Object { $this.Fields[$_].Order } | Select-Object -First 1
                $this.FocusedField = $firstField
            }
        } else {
            # Find next field
            $orderedFields = $this.Fields.Keys | Sort-Object { $this.Fields[$_].Order }
            $currentIndex = $orderedFields.IndexOf($this.FocusedField)
            
            if ($currentIndex -lt $orderedFields.Count - 1) {
                $this.FocusedField = $orderedFields[$currentIndex + 1]
            } else {
                # Move to buttons
                $this.ButtonFocused = $true
                $this.FocusedField = "OK"
            }
        }
    }
    
    [void] Close() {
        if ($global:ScreenManager) {
            $global:ScreenManager.Pop()
        }
    }
}