# NumberInputDialog.ps1 - Dialog for numeric input using BaseDialog

class NumberInputDialog : BaseDialog {
    [string]$Prompt
    [decimal]$DefaultValue
    [decimal]$MinValue
    [decimal]$MaxValue
    [bool]$AllowDecimals
    [MinimalTextBox]$InputBox
    [scriptblock]$OnSubmit = {}
    
    NumberInputDialog([string]$prompt) : base("Number Input") {
        $this.Prompt = $prompt
        $this.DefaultValue = 0
        $this.MinValue = [decimal]::MinValue
        $this.MaxValue = [decimal]::MaxValue
        $this.AllowDecimals = $true
        $this.DialogWidth = 50
        $this.DialogHeight = 10
        $this.PrimaryButtonText = "OK"
        $this.SecondaryButtonText = "Cancel"
    }
    
    NumberInputDialog([string]$prompt, [decimal]$defaultValue) : base("Number Input") {
        $this.Prompt = $prompt
        $this.DefaultValue = $defaultValue
        $this.MinValue = [decimal]::MinValue
        $this.MaxValue = [decimal]::MaxValue
        $this.AllowDecimals = $true
        $this.DialogWidth = 50
        $this.DialogHeight = 10
        $this.PrimaryButtonText = "OK"
        $this.SecondaryButtonText = "Cancel"
    }
    
    NumberInputDialog([string]$prompt, [decimal]$defaultValue, [decimal]$minValue, [decimal]$maxValue) : base("Number Input") {
        $this.Prompt = $prompt
        $this.DefaultValue = $defaultValue
        $this.MinValue = $minValue
        $this.MaxValue = $maxValue
        $this.AllowDecimals = $true
        $this.DialogWidth = 50
        $this.DialogHeight = 10
        $this.PrimaryButtonText = "OK"
        $this.SecondaryButtonText = "Cancel"
    }
    
    [void] InitializeContent() {
        # Create input textbox
        $this.InputBox = [MinimalTextBox]::new()
        $this.InputBox.Text = $this.DefaultValue.ToString()
        $this.InputBox.Placeholder = "Enter number..."
        $this.InputBox.ShowBorder = $false  # Dialog provides the border
        $this.InputBox.Height = 1
        
        # Add validation on text change
        $dialog = $this
        $this.InputBox.OnTextChanged = {
            $dialog.ValidateInput()
        }.GetNewClosure()
        
        $this.AddContentControl($this.InputBox, 1)
        
        # Set up primary action handler
        $this.OnPrimary = {
            if ($dialog.ValidateInput()) {
                $value = [decimal]::Parse($dialog.InputBox.Text)
                if ($dialog.OnSubmit) {
                    & $dialog.OnSubmit $value
                }
            }
        }.GetNewClosure()
        
        # OnCancel is automatically handled by BaseDialog's OnSecondary
    }
    
    [bool] ValidateInput() {
        $text = $this.InputBox.Text.Trim()
        
        # Check if empty
        if ([string]::IsNullOrEmpty($text)) {
            return $false
        }
        
        # Check decimal places
        if (-not $this.AllowDecimals -and $text.Contains('.')) {
            return $false
        }
        
        # Try to parse as decimal
        $value = 0
        if (-not [decimal]::TryParse($text, [ref]$value)) {
            return $false
        }
        
        # Check range
        if ($value -lt $this.MinValue -or $value -gt $this.MaxValue) {
            return $false
        }
        
        return $true
    }
    
    [void] PositionContentControls([int]$dialogX, [int]$dialogY) {
        # Position the prompt label and input box
        $controlWidth = $this.DialogWidth - ($this.DialogPadding * 2)
        
        # Calculate prompt lines
        $promptLines = $this.Prompt -split "`n"
        $currentY = $dialogY + 2
        
        # Position input box after prompt
        $this.InputBox.SetBounds(
            $dialogX + $this.DialogPadding,
            $currentY + $promptLines.Count + 1,
            $controlWidth,
            1
        )
    }
    
    [string] OnRender() {
        $sb = Get-PooledStringBuilder 1024
        
        # First render the base dialog
        $baseRender = ([BaseDialog]$this).OnRender()
        $sb.Append($baseRender)
        
        # Then render the prompt
        if ($this.Prompt) {
            $promptLines = $this.Prompt -split "`n"
            $promptY = $this._dialogBounds.Y + 2
            
            foreach ($line in $promptLines) {
                $sb.Append([VT]::MoveTo($this._dialogBounds.X + $this.DialogPadding, $promptY))
                $sb.Append($this.Theme.GetColor("dialog.title"))
                $sb.Append($line)
                $sb.Append([VT]::Reset())
                $promptY++
            }
        }
        
        # Show validation hint if needed
        if (-not $this.ValidateInput() -and $this.InputBox.Text.Length -gt 0) {
            $hintY = $this.InputBox.Y + 2
            $sb.Append([VT]::MoveTo($this._dialogBounds.X + $this.DialogPadding, $hintY))
            $sb.Append($this.Theme.GetColor("error"))
            
            if ($this.MinValue -ne [decimal]::MinValue -and $this.MaxValue -ne [decimal]::MaxValue) {
                $sb.Append("Enter a number between $($this.MinValue) and $($this.MaxValue)")
            } elseif (-not $this.AllowDecimals -and $this.InputBox.Text.Contains('.')) {
                $sb.Append("Decimals not allowed")
            } else {
                $sb.Append("Invalid number")
            }
            $sb.Append([VT]::Reset())
        }
        
        $result = $sb.ToString()
        Return-PooledStringBuilder $sb
        return $result
    }
    
    # Helper method for compatibility
    [decimal] GetValue() {
        $value = 0
        if ([decimal]::TryParse($this.InputBox.Text, [ref]$value)) {
            return $value
        }
        return $this.DefaultValue
    }
}