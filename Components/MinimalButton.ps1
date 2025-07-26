# MinimalButton.ps1 - Clean, minimalist button component

class MinimalButton : FocusableComponent {
    [string]$Text = "Button"
    [scriptblock]$OnClick = {}
    [bool]$IsDefault = $false
    [int]$Padding = 2  # Horizontal padding
    
    # Cached colors
    hidden [string]$_normalColor = ""
    hidden [string]$_accentColor = ""
    
    MinimalButton() : base() {
        $this.Height = 1  # Single line for minimalism
        $this.FocusStyle = 'minimal'
    }
    
    MinimalButton([string]$text) : base() {
        $this.Text = $text
        $this.Height = 1
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
            $this._normalColor = $this.Theme.GetColor('button.foreground')
            $this._accentColor = $this.Theme.GetColor('accent')
        }
    }
    
    [void] SetText([string]$text) {
        if ($this.Text -ne $text) {
            $this.Text = $text
            $this.Invalidate()
        }
    }
    
    [string] RenderContent() {
        $sb = Get-PooledStringBuilder 256
        
        # Position
        $sb.Append([VT]::MoveTo($this.X, $this.Y))
        
        # Clean minimal style
        if ($this.IsFocused) {
            # Focused: accent color with subtle brackets
            $sb.Append($this._accentColor)
            $sb.Append('[ ')
            $sb.Append($this.Text)
            $sb.Append(' ]')
        } else {
            # Normal: just padded text
            $sb.Append($this._normalColor)
            $sb.Append(' ' * $this.Padding)
            $sb.Append($this.Text)
            $sb.Append(' ' * $this.Padding)
        }
        
        # Default indicator
        if ($this.IsDefault) {
            $sb.Append(' •')
        }
        
        $sb.Append([VT]::Reset())
        
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
        }
    }
    
    [void] OnBoundsChanged() {
        # Auto-size width based on text if not set
        if ($this.Width -eq 0) {
            $this.Width = $this.Text.Length + (2 * $this.Padding) + 2
        }
    }
}