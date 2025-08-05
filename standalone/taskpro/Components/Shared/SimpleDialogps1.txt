# SimpleDialog.ps1 - Basic dialog component for CommandLibrary
# Simplified version for command editing

class SimpleDialog {
    # Properties
    [int]$X = 0
    [int]$Y = 0
    [int]$Width = 60
    [int]$Height = 15
    [string]$Title = ""
    [bool]$Visible = $true
    
    # Fields
    [hashtable]$Fields = @{}
    [string[]]$FieldOrder = @()
    [int]$CurrentFieldIndex = 0
    
    # Buttons
    [string]$PrimaryButton = "OK"
    [string]$SecondaryButton = "Cancel"
    
    # Events
    [scriptblock]$OnSubmit
    [scriptblock]$OnCancel
    
    # State
    [bool]$DialogResult = $false
    
    SimpleDialog([string]$title, [int]$width, [int]$height) {
        $this.Title = $title
        $this.Width = $width
        $this.Height = $height
        
        # Center on screen - ensure integer coordinates
        $consoleWidth = [Console]::WindowWidth
        $consoleHeight = [Console]::WindowHeight
        $this.X = [Math]::Floor([Math]::Max(0, ($consoleWidth - $width) / 2))
        $this.Y = [Math]::Floor([Math]::Max(0, ($consoleHeight - $height) / 2))
    }
    
    [void] AddField([string]$name, [string]$label, [string]$defaultValue = "") {
        $this.Fields[$name] = @{
            Label = $label
            Value = $defaultValue
            IsReadOnly = $false
        }
        $this.FieldOrder += $name
    }
    
    [void] SetFieldReadOnly([string]$name, [bool]$readOnly) {
        if ($this.Fields.ContainsKey($name)) {
            $this.Fields[$name].IsReadOnly = $readOnly
        }
    }
    
    [string] GetFieldValue([string]$name) {
        if ($this.Fields.ContainsKey($name)) {
            return $this.Fields[$name].Value
        }
        return ""
    }
    
    [void] SetFieldValue([string]$name, [string]$value) {
        if ($this.Fields.ContainsKey($name)) {
            $this.Fields[$name].Value = $value
        }
    }
    
    [void] SetButtons([string]$primary, [string]$secondary) {
        $this.PrimaryButton = $primary
        $this.SecondaryButton = $secondary
    }
    
    [string] Render() {
        $sb = [System.Text.StringBuilder]::new()
        
        # Clear the dialog area first
        for ($row = 0; $row -lt $this.Height; $row++) {
            [void]$sb.Append([VT]::MoveTo($this.X, $this.Y + $row))
            [void]$sb.Append(" " * $this.Width)
        }
        
        # Draw top border
        [void]$sb.Append([VT]::MoveTo($this.X, $this.Y))
        [void]$sb.Append([VT]::BoxTopLeft())
        [void]$sb.Append([VT]::BoxHorizontal() * ($this.Width - 2))
        [void]$sb.Append([VT]::BoxTopRight())
        
        # Title bar with proper padding
        [void]$sb.Append([VT]::MoveTo($this.X, $this.Y + 1))
        [void]$sb.Append([VT]::BoxVertical())
        [void]$sb.Append([VT]::Bold())
        $titleDisplay = " " + $this.Title + " "
        $totalPadding = $this.Width - 2 - $titleDisplay.Length
        $leftPadding = [Math]::Floor($totalPadding / 2)
        $rightPadding = $totalPadding - $leftPadding
        [void]$sb.Append(" " * $leftPadding)
        [void]$sb.Append($titleDisplay)
        [void]$sb.Append(" " * $rightPadding)
        [void]$sb.Append([VT]::Reset())
        [void]$sb.Append([VT]::BoxVertical())
        
        # Title separator
        [void]$sb.Append([VT]::MoveTo($this.X, $this.Y + 2))
        [void]$sb.Append([VT]::BoxTeeRight())
        [void]$sb.Append([VT]::BoxHorizontal() * ($this.Width - 2))
        [void]$sb.Append([VT]::BoxTeeLeft())
        
        # Fields
        $currentY = $this.Y + 3
        for ($i = 0; $i -lt $this.FieldOrder.Count; $i++) {
            $fieldName = $this.FieldOrder[$i]
            $field = $this.Fields[$fieldName]
            $isCurrentField = ($i -eq $this.CurrentFieldIndex)
            
            # Label
            [void]$sb.Append([VT]::MoveTo($this.X, $currentY))
            [void]$sb.Append([VT]::BoxVertical())
            [void]$sb.Append(" ")
            if ($isCurrentField) {
                [void]$sb.Append([VT]::Yellow())
            }
            [void]$sb.Append($field.Label + ":")
            [void]$sb.Append([VT]::Reset())
            
            # Clear to end of line
            $remainingSpace = $this.Width - 3 - $field.Label.Length - 1
            [void]$sb.Append(" " * $remainingSpace)
            [void]$sb.Append([VT]::BoxVertical())
            $currentY++
            
            # Value
            [void]$sb.Append([VT]::MoveTo($this.X, $currentY))
            [void]$sb.Append([VT]::BoxVertical())
            [void]$sb.Append(" ")
            
            if ($isCurrentField -and -not $field.IsReadOnly) {
                [void]$sb.Append([VT]::Reverse())
            } elseif ($field.IsReadOnly) {
                [void]$sb.Append([VT]::Gray())
            }
            
            $displayValue = $field.Value
            $maxValueLength = $this.Width - 4
            if ($displayValue.Length -gt $maxValueLength) {
                $displayValue = $displayValue.Substring(0, $maxValueLength - 3) + "..."
            }
            
            [void]$sb.Append($displayValue.PadRight($maxValueLength))
            [void]$sb.Append([VT]::Reset())
            [void]$sb.Append([VT]::BoxVertical())
            $currentY += 2
        }
        
        # Fill remaining space
        while ($currentY -lt ($this.Y + $this.Height - 3)) {
            [void]$sb.Append([VT]::MoveTo($this.X, $currentY))
            [void]$sb.Append([VT]::BoxVertical())
            [void]$sb.Append(" " * ($this.Width - 2))
            [void]$sb.Append([VT]::BoxVertical())
            $currentY++
        }
        
        # Button separator
        [void]$sb.Append([VT]::MoveTo($this.X, $this.Y + $this.Height - 3))
        [void]$sb.Append([VT]::BoxTeeRight())
        [void]$sb.Append([VT]::BoxHorizontal() * ($this.Width - 2))
        [void]$sb.Append([VT]::BoxTeeLeft())
        
        # Buttons
        [void]$sb.Append([VT]::MoveTo($this.X, $this.Y + $this.Height - 2))
        [void]$sb.Append([VT]::BoxVertical())
        $buttonArea = $this.Width - 2
        $buttonText = "$($this.PrimaryButton) / $($this.SecondaryButton)"
        $buttonPadding = ($buttonArea - $buttonText.Length) / 2
        [void]$sb.Append(" " * [Math]::Floor($buttonPadding))
        [void]$sb.Append([VT]::Green() + $this.PrimaryButton + [VT]::Reset())
        [void]$sb.Append(" / ")
        [void]$sb.Append([VT]::Red() + $this.SecondaryButton + [VT]::Reset())
        [void]$sb.Append(" " * [Math]::Ceiling($buttonPadding))
        [void]$sb.Append([VT]::BoxVertical())
        
        # Bottom border
        [void]$sb.Append([VT]::MoveTo($this.X, $this.Y + $this.Height - 1))
        [void]$sb.Append([VT]::BoxBottomLeft())
        [void]$sb.Append([VT]::BoxHorizontal() * ($this.Width - 2))
        [void]$sb.Append([VT]::BoxBottomRight())
        
        # Position cursor at end of current field value for input
        if ($this.FieldOrder.Count -gt 0) {
            $fieldName = $this.FieldOrder[$this.CurrentFieldIndex]
            $field = $this.Fields[$fieldName]
            if (-not $field.IsReadOnly) {
                # Calculate cursor position
                $fieldY = $this.Y + 3 + ($this.CurrentFieldIndex * 3) + 1  # Value line
                $cursorX = $this.X + 2 + $field.Value.Length
                if ($cursorX -lt $this.X + $this.Width - 2) {  # Don't go past border
                    [void]$sb.Append([VT]::MoveTo($cursorX, $fieldY))
                }
            }
        }
        
        return $sb.ToString()
    }
    
    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        # Check for immediate exit keys first
        if ($key.Key -eq [System.ConsoleKey]::Escape) {
            if ($this.OnCancel) {
                $this.OnCancel.Invoke()
            }
            $this.DialogResult = $false
            $this.Visible = $false
            return $false  # Close dialog
        }
        
        switch ($key.Key) {
            ([System.ConsoleKey]::Tab) {
                $this.NextField()
                return $true
            }
            ([System.ConsoleKey]::UpArrow) {
                $this.PreviousField()
                return $true
            }
            ([System.ConsoleKey]::DownArrow) {
                $this.NextField()
                return $true
            }
            ([System.ConsoleKey]::Enter) {
                if ($this.OnSubmit) {
                    $this.OnSubmit.Invoke()
                }
                $this.DialogResult = $true
                $this.Visible = $false
                return $false  # Close dialog
            }
            ([System.ConsoleKey]::Backspace) {
                $this.RemoveCharacter()
                return $true
            }
        }
        
        # Handle character input only for current field if not read-only
        if ($key.KeyChar -and -not [char]::IsControl($key.KeyChar)) {
            if ($this.FieldOrder.Count -gt 0) {
                $fieldName = $this.FieldOrder[$this.CurrentFieldIndex]
                $field = $this.Fields[$fieldName]
                if (-not $field.IsReadOnly) {
                    $this.AddCharacter($key.KeyChar)
                    return $true
                }
            }
        }
        
        return $true
    }
    
    [void] NextField() {
        if ($this.FieldOrder.Count -gt 0) {
            $this.CurrentFieldIndex = ($this.CurrentFieldIndex + 1) % $this.FieldOrder.Count
        }
    }
    
    [void] PreviousField() {
        if ($this.FieldOrder.Count -gt 0) {
            $this.CurrentFieldIndex = ($this.CurrentFieldIndex - 1 + $this.FieldOrder.Count) % $this.FieldOrder.Count
        }
    }
    
    [void] AddCharacter([char]$char) {
        if ($this.FieldOrder.Count -gt 0) {
            $fieldName = $this.FieldOrder[$this.CurrentFieldIndex]
            $field = $this.Fields[$fieldName]
            if (-not $field.IsReadOnly) {
                $field.Value += $char
            }
        }
    }
    
    [void] RemoveCharacter() {
        if ($this.FieldOrder.Count -gt 0) {
            $fieldName = $this.FieldOrder[$this.CurrentFieldIndex]
            $field = $this.Fields[$fieldName]
            if (-not $field.IsReadOnly -and $field.Value.Length -gt 0) {
                $field.Value = $field.Value.Substring(0, $field.Value.Length - 1)
            }
        }
    }
    
    # Main dialog execution method
    [bool] Show() {
        $originalCursor = $true
        try {
            $originalCursor = [Console]::CursorVisible
            [Console]::CursorVisible = $false
        } catch {
            # Console operations not supported in this environment
        }
        
        try {
            # Store previous render for comparison
            $lastRender = ""
            
            while ($this.Visible) {
                # Build the full dialog render
                $currentRender = $this.Render()
                
                # Only output if something changed
                if ($currentRender -ne $lastRender) {
                    [Console]::Clear()
                    Write-Host -NoNewline $currentRender
                    $lastRender = $currentRender
                }
                
                # Handle input (defensive)
                try {
                    if ([Console]::KeyAvailable) {
                        $key = [Console]::ReadKey($true)
                        if (-not $this.HandleInput($key)) {
                            break
                        }
                    }
                } catch {
                    # Console input not available - exit gracefully
                    break
                }
                
                Start-Sleep -Milliseconds 50
            }
            
            return $this.DialogResult
        } finally {
            try {
                [Console]::CursorVisible = $originalCursor
            } catch {
                # Console operations not supported
            }
        }
    }
}