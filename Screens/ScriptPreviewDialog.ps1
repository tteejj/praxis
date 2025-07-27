# ScriptPreviewDialog.ps1 - Dialog for previewing generated IDEAScript code

class ScriptPreviewDialog : BaseDialog {
    hidden [string]$_scriptContent
    hidden [MinimalTextBox]$_scriptTextBox
    hidden [int]$_scrollOffset = 0
    
    ScriptPreviewDialog([string]$scriptContent) : base("IDEAScript Preview") {
        $this._scriptContent = $scriptContent
        $this.DialogWidth = 80
        $this.DialogHeight = 30
        $this.PrimaryButtonText = "Copy to Clipboard"
        $this.SecondaryButtonText = "Close"
    }
    
    [void] InitializeContent() {
        # Create a readonly text box to display the script
        $this._scriptTextBox = [MinimalTextBox]::new()
        $this._scriptTextBox.ReadOnly = $true
        $this._scriptTextBox.MultiLine = $true
        $this._scriptTextBox.ShowBorder = $true
        $this._scriptTextBox.BorderType = [BorderType]::Single
        $this._scriptTextBox.Text = $this._scriptContent
        
        $this.AddContentControl($this._scriptTextBox)
        
        # Configure button actions
        $dialog = $this
        $this.OnPrimary = {
            try {
                Set-Clipboard -Value $dialog._scriptContent
                
                # Show toast notification if available
                $toastService = $dialog.ServiceContainer.GetService('ToastService')
                if ($toastService) {
                    $toastService.ShowToast("Script copied to clipboard!", [ToastType]::Success)
                }
                
                if ($global:Logger) {
                    $global:Logger.Info("IDEAScript copied to clipboard")
                }
            } catch {
                if ($global:Logger) {
                    $global:Logger.Error("Failed to copy to clipboard: $_")
                }
            }
        }.GetNewClosure()
    }
    
    [void] PositionContentControls([int]$dialogX, [int]$dialogY) {
        # Position the text box to fill most of the dialog
        $padding = 2
        $controlWidth = $this.DialogWidth - ($padding * 2)
        $controlHeight = $this.DialogHeight - 6  # Leave room for title and buttons
        
        $this._scriptTextBox.SetBounds(
            $dialogX + $padding,
            $dialogY + 2,
            $controlWidth,
            $controlHeight
        )
    }
    
    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        # Handle scrolling
        switch ($key.Key) {
            ([System.ConsoleKey]::PageUp) {
                if ($this._scriptTextBox.IsFocused) {
                    $this._scrollOffset = [Math]::Max(0, $this._scrollOffset - 10)
                    $this.Invalidate()
                    return $true
                }
            }
            ([System.ConsoleKey]::PageDown) {
                $lines = $this._scriptContent -split "`n"
                $maxScroll = [Math]::Max(0, $lines.Count - $this._scriptTextBox.Height + 2)
                if ($this._scriptTextBox.IsFocused) {
                    $this._scrollOffset = [Math]::Min($maxScroll, $this._scrollOffset + 10)
                    $this.Invalidate()
                    return $true
                }
            }
            ([System.ConsoleKey]::Home) {
                if ($this._scriptTextBox.IsFocused -and $key.Modifiers -eq [System.ConsoleModifiers]::Control) {
                    $this._scrollOffset = 0
                    $this.Invalidate()
                    return $true
                }
            }
            ([System.ConsoleKey]::End) {
                if ($this._scriptTextBox.IsFocused -and $key.Modifiers -eq [System.ConsoleModifiers]::Control) {
                    $lines = $this._scriptContent -split "`n"
                    $this._scrollOffset = [Math]::Max(0, $lines.Count - $this._scriptTextBox.Height + 2)
                    $this.Invalidate()
                    return $true
                }
            }
        }
        
        # Let base class handle other input
        return ([BaseDialog]$this).HandleInput($key)
    }
    
    [string] OnRender() {
        $sb = Get-PooledStringBuilder 2048
        
        # First render the base dialog
        $baseRender = ([BaseDialog]$this).OnRender()
        $sb.Append($baseRender)
        
        # Add scroll indicators if needed
        $lines = $this._scriptContent -split "`n"
        $visibleLines = $this._scriptTextBox.Height - 2
        
        if ($lines.Count -gt $visibleLines) {
            $x = $this._dialogBounds.X + $this.DialogWidth - 3
            $y = $this._dialogBounds.Y + 2
            
            # Show scroll position indicator
            $sb.Append([VT]::MoveTo($x, $y))
            $sb.Append($this.Theme.GetColor("disabled"))
            
            if ($this._scrollOffset -gt 0) {
                $sb.Append("▲")
            } else {
                $sb.Append(" ")
            }
            
            $maxScroll = $lines.Count - $visibleLines
            if ($this._scrollOffset -lt $maxScroll) {
                $sb.Append([VT]::MoveTo($x, $y + $visibleLines - 1))
                $sb.Append("▼")
            }
            
            # Show line numbers
            $sb.Append([VT]::MoveTo($this._dialogBounds.X + 2, $this._dialogBounds.Y + $this.DialogHeight - 3))
            $sb.Append($this.Theme.GetColor("disabled"))
            $sb.Append("Lines: $($this._scrollOffset + 1)-$([Math]::Min($lines.Count, $this._scrollOffset + $visibleLines)) of $($lines.Count)")
        }
        
        $sb.Append([VT]::Reset())
        
        $result = $sb.ToString()
        Return-PooledStringBuilder $sb
        return $result
    }
}