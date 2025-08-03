# ActionPropertiesDialog.ps1 - Dialog for editing action properties

class ActionPropertiesDialog : SimpleDialog {
    [BaseAction]$Action
    [hashtable]$Controls = @{}
    [int]$CurrentField = 0
    [hashtable]$Values = @{}
    
    ActionPropertiesDialog([BaseAction]$action) : base("Configure: $($action.Name)", "") {
        $this.Action = $action
        $this.Width = 60
        $this.Height = 10 + ($action.Consumes.Count * 2)
        $this.Buttons = @("Apply", "Cancel")
        
        # Initialize values from action parameters
        foreach ($param in $action.Consumes) {
            $this.Values[$param.Name] = $action.Parameters[$param.Name]
            if ($null -eq $this.Values[$param.Name]) {
                $this.Values[$param.Name] = $param.Default
            }
        }
    }
    
    [void] Show() {
        [Console]::CursorVisible = $false
        
        # Calculate position
        $screenWidth = [Console]::WindowWidth
        $screenHeight = [Console]::WindowHeight
        $x = [Math]::Floor(($screenWidth - $this.Width) / 2)
        $y = [Math]::Floor(($screenHeight - $this.Height) / 2)
        
        while ($this.IsActive) {
            $this.DrawDialog($x, $y)
            
            $key = [Console]::ReadKey($true)
            $this.HandleDialogInput($key)
        }
        
        # Apply changes if user clicked Apply
        if ($this.Result -eq "Apply") {
            foreach ($param in $this.Action.Consumes) {
                $this.Action.Parameters[$param.Name] = $this.Values[$param.Name]
            }
        }
    }
    
    [void] DrawDialog([int]$x, [int]$y) {
        $sb = [System.Text.StringBuilder]::new()
        
        # Draw background
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
        
        # Draw fields
        $fieldY = $y + 2
        $fieldIndex = 0
        
        foreach ($param in $this.Action.Consumes) {
            # Label
            $sb.Append([VT]::MoveTo($x + 2, $fieldY))
            $sb.Append($this.MessageColor + $param.Label + ":")
            
            # Value field
            $valueY = $fieldY + 1
            $sb.Append([VT]::MoveTo($x + 2, $valueY))
            
            $value = $this.Values[$param.Name]
            if ($null -eq $value) { $value = "" }
            
            # Field background
            $fieldBg = if ($fieldIndex -eq $this.CurrentField -and $this.SelectedButton -eq -1) {
                "`e[48;2;60;60;80m"
            } else {
                "`e[48;2;40;40;50m"
            }
            
            $sb.Append($fieldBg)
            
            # Show value based on type
            switch ($param.Type) {
                "Boolean" {
                    $boolText = if ($value -eq "True") { "[X] Yes  [ ] No" } else { "[ ] Yes  [X] No" }
                    $sb.Append(" " + $boolText.PadRight($this.Width - 6) + " ")
                }
                "Choice" {
                    $choiceText = "▼ $value"
                    $sb.Append(" " + $choiceText.PadRight($this.Width - 6) + " ")
                }
                default {
                    $sb.Append(" " + $value.ToString().PadRight($this.Width - 6) + " ")
                }
            }
            
            $sb.Append($this.NormalColor)
            
            $fieldY = $valueY + 2
            $fieldIndex++
        }
        
        # Draw buttons
        $this.DrawButtons($sb, $x, $y)
        
        # Draw bottom border
        $sb.Append([VT]::MoveTo($x, $y + $this.Height - 1))
        $sb.Append($this.BorderColor)
        $sb.Append("╰" + ("─" * ($this.Width - 2)) + "╯")
        $sb.Append($this.NormalColor)
        
        Write-Host -NoNewline $sb.ToString()
        
        # Show cursor for text fields
        if ($this.SelectedButton -eq -1 -and $this.CurrentField -lt $this.Action.Consumes.Count) {
            $param = $this.Action.Consumes[$this.CurrentField]
            if ($param.Type -notin @("Boolean", "Choice")) {
                [Console]::CursorVisible = $true
                $cursorY = $y + 3 + ($this.CurrentField * 3)
                $value = $this.Values[$param.Name]
                if ($null -eq $value) { $value = "" }
                [Console]::SetCursorPosition($x + 3 + $value.Length, $cursorY)
            } else {
                [Console]::CursorVisible = $false
            }
        } else {
            [Console]::CursorVisible = $false
        }
    }
    
    [void] DrawButtons([System.Text.StringBuilder]$sb, [int]$x, [int]$y) {
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
    }
    
    [void] HandleDialogInput([System.ConsoleKeyInfo]$key) {
        if ($this.SelectedButton -eq -1) {
            # Field editing mode
            $this.HandleFieldInput($key)
        } else {
            # Button selection mode
            $this.HandleInput($key)
        }
    }
    
    [void] HandleFieldInput([System.ConsoleKeyInfo]$key) {
        if ($this.CurrentField -ge $this.Action.Consumes.Count) { return }
        
        $param = $this.Action.Consumes[$this.CurrentField]
        $currentValue = $this.Values[$param.Name]
        if ($null -eq $currentValue) { $currentValue = "" }
        
        switch ($key.Key) {
            ([System.ConsoleKey]::Tab) {
                if ($key.Modifiers -band [System.ConsoleModifiers]::Shift) {
                    # Shift+Tab - go to previous field
                    if ($this.CurrentField -gt 0) {
                        $this.CurrentField--
                    } else {
                        # Move to buttons
                        $this.SelectedButton = 0
                    }
                } else {
                    # Tab - go to next field or buttons
                    if ($this.CurrentField -lt ($this.Action.Consumes.Count - 1)) {
                        $this.CurrentField++
                    } else {
                        # Move to buttons
                        $this.SelectedButton = 0
                    }
                }
            }
            ([System.ConsoleKey]::UpArrow) {
                if ($this.CurrentField -gt 0) {
                    $this.CurrentField--
                }
            }
            ([System.ConsoleKey]::DownArrow) {
                if ($this.CurrentField -lt ($this.Action.Consumes.Count - 1)) {
                    $this.CurrentField++
                } else {
                    $this.SelectedButton = 0
                }
            }
            ([System.ConsoleKey]::Enter) {
                if ($param.Type -eq "Boolean") {
                    # Toggle boolean
                    $this.Values[$param.Name] = if ($currentValue -eq "True") { "False" } else { "True" }
                } elseif ($param.Type -eq "Choice") {
                    # Cycle through choices
                    $currentIndex = [array]::IndexOf($param.Options, $currentValue)
                    $nextIndex = ($currentIndex + 1) % $param.Options.Count
                    $this.Values[$param.Name] = $param.Options[$nextIndex]
                } else {
                    # Move to next field
                    if ($this.CurrentField -lt ($this.Action.Consumes.Count - 1)) {
                        $this.CurrentField++
                    } else {
                        $this.SelectedButton = 0
                    }
                }
            }
            ([System.ConsoleKey]::Escape) {
                $this.Result = "Cancel"
                $this.IsActive = $false
            }
            ([System.ConsoleKey]::Backspace) {
                if ($param.Type -notin @("Boolean", "Choice") -and $currentValue.Length -gt 0) {
                    $this.Values[$param.Name] = $currentValue.Substring(0, $currentValue.Length - 1)
                }
            }
            default {
                # Text input for string fields
                if ($param.Type -notin @("Boolean", "Choice") -and $key.KeyChar -and 
                    [char]::IsControl($key.KeyChar) -eq $false) {
                    $this.Values[$param.Name] = $currentValue + $key.KeyChar
                }
            }
        }
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
                if ($key.Modifiers -band [System.ConsoleModifiers]::Shift) {
                    # Go back to fields
                    $this.SelectedButton = -1
                    $this.CurrentField = $this.Action.Consumes.Count - 1
                } else {
                    $this.SelectedButton = ($this.SelectedButton + 1) % $this.Buttons.Count
                }
            }
            ([System.ConsoleKey]::UpArrow) {
                # Go back to fields
                $this.SelectedButton = -1
                $this.CurrentField = $this.Action.Consumes.Count - 1
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
}