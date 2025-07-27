# TextInputDialog.ps1 - Simple dialog for text input using BaseDialog

class TextInputDialog : BaseDialog {
    [string]$Prompt
    [string]$DefaultValue
    [string]$Placeholder
    [MinimalTextBox]$InputBox
    [scriptblock]$OnSubmit = {}
    
    TextInputDialog([string]$prompt) : base("Input") {
        $this.Prompt = $prompt
        $this.DefaultValue = ""
        $this.Placeholder = "Enter text..."
        $this.DialogWidth = 50
        $this.DialogHeight = 10
        $this.PrimaryButtonText = "OK"
        $this.SecondaryButtonText = "Cancel"
    }
    
    TextInputDialog([string]$prompt, [string]$defaultValue) : base("Input") {
        $this.Prompt = $prompt
        $this.DefaultValue = $defaultValue
        $this.Placeholder = "Enter text..."
        $this.DialogWidth = 50
        $this.DialogHeight = 10
        $this.PrimaryButtonText = "OK"
        $this.SecondaryButtonText = "Cancel"
    }
    
    [void] InitializeContent() {
        # Create input textbox
        $this.InputBox = [MinimalTextBox]::new()
        $this.InputBox.Text = $this.DefaultValue
        $this.InputBox.Placeholder = $this.Placeholder
        $this.InputBox.ShowBorder = $false  # Dialog provides the border
        $this.InputBox.Height = 1
        $this.AddContentControl($this.InputBox, 1)
        
        # Set up primary action handler
        $dialog = $this
        $this.OnPrimary = {
            if ($dialog.OnSubmit) {
                & $dialog.OnSubmit $dialog.InputBox.Text
            }
        }.GetNewClosure()
        
        # OnCancel is automatically handled by BaseDialog's OnSecondary
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
        
        $result = $sb.ToString()
        Return-PooledStringBuilder $sb
        return $result
    }
    
    # Helper method for compatibility
    [string] GetValue() {
        return $this.InputBox.Text
    }
}