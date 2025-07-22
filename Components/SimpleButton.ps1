# SimpleButton.ps1 - Minimal button for testing

class SimpleButton : UIElement {
    [string]$Text = ""
    
    SimpleButton([string]$text) : base() {
        $this.Text = $text
        $this.IsFocusable = $true
        $this.Height = 3
    }
    
    [void] Initialize([ServiceContainer]$services) {
        # No theme, just basic
    }
    
    [string] OnRender() {
        $sb = [System.Text.StringBuilder]::new()
        
        # Simple box with text
        # Top border
        $sb.Append([VT]::MoveTo($this.X, $this.Y))
        $sb.Append("┌")
        for ($i = 0; $i -lt $this.Width - 2; $i++) {
            $sb.Append("─")
        }
        $sb.Append("┐")
        
        # Middle line with text
        $sb.Append([VT]::MoveTo($this.X, $this.Y + 1))
        $sb.Append("│")
        
        # Center the text
        $padding = $this.Width - 2 - $this.Text.Length
        $leftPad = [int]($padding / 2)
        $rightPad = $padding - $leftPad
        
        # Add left padding
        for ($i = 0; $i -lt $leftPad; $i++) {
            $sb.Append(" ")
        }
        
        # Add text
        $sb.Append($this.Text)
        
        # Add right padding
        for ($i = 0; $i -lt $rightPad; $i++) {
            $sb.Append(" ")
        }
        
        $sb.Append("│")
        
        # Bottom border
        $sb.Append([VT]::MoveTo($this.X, $this.Y + 2))
        $sb.Append("└")
        for ($i = 0; $i -lt $this.Width - 2; $i++) {
            $sb.Append("─")
        }
        $sb.Append("┘")
        
        return $sb.ToString()
    }
}