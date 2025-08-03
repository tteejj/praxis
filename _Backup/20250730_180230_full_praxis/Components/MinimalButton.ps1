# MinimalButton.ps1 - Clean, minimalist button component

class MinimalButton : FocusableComponent {
    [string]$Text = "Button"
    [scriptblock]$OnClick = {}
    [bool]$IsDefault = $false
    [int]$Padding = 2  # Horizontal padding
    
    # Cached colors
    hidden [string]$_normalColor = ""
    hidden [string]$_accentColor = ""
    hidden [string]$_borderColor = ""
    hidden [string]$_focusReverseBg = ""
    hidden [string]$_focusReverseText = ""
    
    MinimalButton() : base() {
        $this.Height = 3  # Height for border
        $this.FocusStyle = 'minimal'
    }
    
    MinimalButton([string]$text) : base() {
        $this.Text = $text
        $this.Height = 3
        $this.FocusStyle = 'minimal'
    }
    
    [void] OnInitialize() {
        ([FocusableComponent]$this).OnInitialize()
        $this.UpdateColors()
        if ($this.Theme) {
            # Subscribe to theme changes via EventBus
            $eventBus = $this.ServiceContainer.GetService('EventBus')
            if ($eventBus) {
                $eventBus.Subscribe('theme.changed', {
                    param($sender, $eventData)
                    $this.UpdateColors()
                }.GetNewClosure())
            }
        }
    }
    
    [void] UpdateColors() {
        if ($this.Theme) {
            $this._normalColor = $this.Theme.GetColor('button.text')
            $this._accentColor = $this.Theme.GetColor('color.primary')
            $this._borderColor = $this.Theme.GetColor('border.normal')
            $this._focusReverseBg = $this.Theme.GetBgColor('focus.reverse.background')
            $this._focusReverseText = $this.Theme.GetColor('focus.reverse.text')
        }
    }
    
    [void] SetText([string]$text) {
        if ($this.Text -ne $text) {
            $this.Text = $text
            $this.Invalidate()
        }
    }
    
    [string] RenderContent() {
        # Initialize RenderHelper if needed
        [RenderHelper]::Initialize()
        
        $sb = Get-PooledStringBuilder 256
        
        # Always show minimal border
        $borderColor = if ($this.IsFocused) { $this._accentColor } else { $this._borderColor }
        $sb.Append([BorderStyle]::RenderBorder($this.X, $this.Y, $this.Width, $this.Height, [BorderType]::Rounded, $borderColor))
        
        # Calculate content position
        $contentX = $this.X + 1
        $contentY = $this.Y + 1
        
        # Position for text
        $sb.Append([VT]::MoveTo($contentX, $contentY))
        
        # Prepare button text
        $buttonText = $this.Text
        if ($this.IsDefault) {
            $buttonText += " •"
        }
        
        # Use RenderHelper for safe button content rendering
        $sb.Append([RenderHelper]::RenderButtonContent($buttonText, $this.Width, $this.Theme, $this.IsFocused))

        $result = $sb.ToString()
        Return-PooledStringBuilder $sb
        return $result
    }
    
    [bool] OnHandleInput([System.ConsoleKeyInfo]$key) {
        switch ($key.Key) {
            ([System.ConsoleKey]::Enter) {
                $this.Click()
                return $true
            }
            ([System.ConsoleKey]::Spacebar) {
                $this.Click()
                return $true
            }
        }
        return $false
    }
    
    [void] Click() {
        if ($this.OnClick) {
            try {
                & $this.OnClick
            } catch {
                if ($global:Logger) {
                    $global:Logger.Error("Button click error: $_")
                }
            }
        } else {
            if ($global:Logger) {
                $global:Logger.Warning("MinimalButton.Click: No OnClick handler for button '$($this.Text)'")
            }
        }
    }
    
    [void] OnBoundsChanged() {
        # Auto-size width based on text if not set
        if ($this.Width -eq 0) {
            $buttonText = $this.Text
            if ($this.IsDefault) {
                $buttonText += " •"
            }
            $this.Width = $buttonText.Length + (2 * $this.Padding) + 2  # +2 for border
        }
    }
}