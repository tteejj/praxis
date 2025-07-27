# ActionPropertiesDialog.ps1 - Dialog for configuring action parameters
# Dynamically builds UI based on action's Consumes metadata

class ActionPropertiesDialog : BaseDialog {
    hidden [BaseAction]$_action
    hidden [hashtable]$_controls = @{} # Stores the created UI controls
    hidden [int]$_currentY = 2  # Track Y position for control placement

    ActionPropertiesDialog([BaseAction]$action) : base("Configure: $($action.Name)") {
        $this._action = $action
        $this.DialogWidth = 70
        # Dynamic height based on the number of parameters
        $this.DialogHeight = 10 + ($action.Consumes.Count * 4) 
        $this.PrimaryButtonText = "Apply"
    }

    [void] InitializeContent() {
        $controlWidth = $this.DialogWidth - ($this.DialogPadding * 2)
        
        foreach ($param in $this._action.Consumes) {
            $control = $null
            $currentValue = if ($this._action.Parameters.ContainsKey($param.Name)) {
                $this._action.Parameters[$param.Name]
            } else {
                $param.Default
            }

            # Create label for the control
            $label = [UIElement]::new()
            $label.Height = 1
            $this.AddChild($label)
            
            # Create different controls based on the parameter type
            switch ($param.Type) {
                "Field" {
                    # Create button to open field picker
                    $control = [MinimalButton]::new()
                    $control.Text = if ($currentValue) { $currentValue.ToString() } else { "Click to select field..." }
                    $control.Height = 3
                    $control.Width = $controlWidth
                    
                    $paramName = $param.Name
                    $dialog = $this
                    $control.OnClick = {
                        $fieldPicker = [FieldPickerDialog]::new()
                        $fieldPicker.Title = "Select $($param.Label)"
                        $fieldPicker.AllowMultiple = $false
                        $fieldPicker.Initialize($dialog.ServiceContainer)
                        
                        $fieldPicker.OnFieldSelected = {
                            param($fieldName)
                            $dialog._action.Parameters[$paramName] = $fieldName
                            $control.Text = $fieldName
                            $dialog.Invalidate()
                        }.GetNewClosure()
                        
                        $global:ScreenManager.Push($fieldPicker)
                    }.GetNewClosure()
                }
                "FieldList" {
                    # Create button to open multi-field picker
                    $control = [MinimalButton]::new()
                    $control.Text = if ($currentValue) { $currentValue.ToString() } else { "Click to select fields..." }
                    $control.Height = 3
                    $control.Width = $controlWidth
                    
                    $paramName = $param.Name
                    $dialog = $this
                    $control.OnClick = {
                        $fieldPicker = [FieldPickerDialog]::new()
                        $fieldPicker.Title = "Select $($param.Label)"
                        $fieldPicker.AllowMultiple = $true
                        $fieldPicker.Initialize($dialog.ServiceContainer)
                        
                        $fieldPicker.OnFieldSelected = {
                            param($fieldNames)
                            $dialog._action.Parameters[$paramName] = $fieldNames
                            $control.Text = $fieldNames
                            $dialog.Invalidate()
                        }.GetNewClosure()
                        
                        $global:ScreenManager.Push($fieldPicker)
                    }.GetNewClosure()
                }
                "Boolean" {
                    # Use a ListBox for boolean choice
                    $control = [MinimalListBox]::new()
                    $control.SetItems(@("True", "False"))
                    $control.Height = 4
                    $control.ShowBorder = $true
                    $control.BorderType = [BorderType]::Rounded
                    if ($currentValue -ne $null) {
                        $boolValue = [bool]::Parse($currentValue.ToString())
                        $index = if ($boolValue) { 0 } else { 1 }
                        $control.SelectIndex($index)
                    }
                }
                "Choice" {
                    $control = [MinimalListBox]::new()
                    $control.SetItems($param.Options)
                    $control.Height = [Math]::Min($param.Options.Count + 2, 6)
                    $control.ShowBorder = $true
                    $control.BorderType = [BorderType]::Rounded
                    if ($currentValue) {
                        $index = [array]::IndexOf($param.Options, $currentValue)
                        if ($index -ge 0) {
                            $control.SelectIndex($index)
                        }
                    }
                }
                default { # "String", "Database", etc.
                    $control = [MinimalTextBox]::new()
                    $control.Placeholder = $param.Description
                    $control.ShowBorder = $false
                    $control.Height = 1
                    if ($currentValue) {
                        $control.Text = $currentValue.ToString()
                    }
                }
            }
            
            # Add the control
            $this.AddContentControl($control)
            $this._controls[$param.Name] = @{
                Control = $control
                Label = $param.Label
                Type = $param.Type
            }
        }

        # Configure primary action handler
        $dialog = $this
        $this.OnPrimary = {
            foreach ($name in $dialog._controls.Keys) {
                $controlInfo = $dialog._controls[$name]
                $control = $controlInfo.Control
                $value = $null
                
                if ($control -is [MinimalTextBox]) {
                    $value = $control.Text
                } elseif ($control -is [MinimalListBox]) {
                    $value = $control.GetSelectedItem()
                } elseif ($control -is [MinimalButton]) {
                    # For buttons, the value is already stored in Parameters
                    $value = $dialog._action.Parameters[$name]
                }
                
                if ($value -ne $null -and $value -ne "") {
                    $dialog._action.Parameters[$name] = $value
                }
            }
            
            if ($global:Logger) {
                $global:Logger.Debug("ActionPropertiesDialog: Updated parameters for $($dialog._action.Name)")
                foreach ($key in $dialog._action.Parameters.Keys) {
                    $global:Logger.Debug("  $key = $($dialog._action.Parameters[$key])")
                }
            }
        }.GetNewClosure()
    }

    [void] PositionContentControls([int]$dialogX, [int]$dialogY) {
        # Custom positioning for parameter controls
        $controlWidth = $this.DialogWidth - ($this.DialogPadding * 2)
        $currentY = $dialogY + 2
        $controlIndex = 0
        
        foreach ($param in $this._action.Consumes) {
            $controlInfo = $this._controls[$param.Name]
            $control = $controlInfo.Control
            
            # Position label (rendered as part of border title)
            # For now, we'll render labels separately
            
            # Position the control
            $control.SetBounds(
                $dialogX + $this.DialogPadding,
                $currentY,
                $controlWidth,
                $control.Height
            )
            
            $currentY += $control.Height + 2  # Add spacing between controls
            $controlIndex++
        }
    }

    [string] OnRender() {
        $sb = Get-PooledStringBuilder 1024
        
        # First render the base dialog
        $baseRender = ([BaseDialog]$this).OnRender()
        $sb.Append($baseRender)
        
        # Then render labels for each control
        $dialogX = $this._dialogBounds.X
        $dialogY = $this._dialogBounds.Y
        $currentY = $dialogY + 2
        
        foreach ($param in $this._action.Consumes) {
            $controlInfo = $this._controls[$param.Name]
            $label = $controlInfo.Label
            
            # Render label above the control
            $sb.Append([VT]::MoveTo($dialogX + $this.DialogPadding, $currentY - 1))
            $sb.Append($this.Theme.GetColor("dialog.title"))
            $sb.Append($label + ":")
            $sb.Append([VT]::Reset())
            
            $control = $controlInfo.Control
            $currentY += $control.Height + 2
        }
        
        $result = $sb.ToString()
        Return-PooledStringBuilder $sb
        return $result
    }
}