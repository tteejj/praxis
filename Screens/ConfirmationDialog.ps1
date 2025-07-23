# ConfirmationDialog.ps1 - Generic confirmation dialog using BaseDialog

class ConfirmationDialog : BaseDialog {
    [string]$Message
    [string]$ConfirmText = "Yes"
    [string]$CancelText = "No"
    
    ConfirmationDialog([string]$message) : base("Confirm") {
        $this.Message = $message
        # Set button texts before initialization
        $this.PrimaryButtonText = $this.ConfirmText
        $this.SecondaryButtonText = $this.CancelText
    }
    
    [void] InitializeContent() {
        # Base dialog handles button creation, we just need to update button texts if needed
        if ($this.PrimaryButton -and $this.ConfirmText -ne "Yes") {
            $this.PrimaryButton.Text = $this.ConfirmText
        }
        
        if ($this.SecondaryButton -and $this.CancelText -ne "No") {
            $this.SecondaryButton.Text = $this.CancelText
        }
        
        # No additional content controls needed for simple confirmation
        # The message is rendered directly in the dialog
    }
    
    [void] OnActivated() {
        ([BaseDialog]$this).OnActivated()
        # Override to focus on cancel button by default (safer)
        if ($this.SecondaryButton) {
            $this.SecondaryButton.Focus()
        }
    }
    
    [void] OnBoundsChanged() {
        # Calculate dialog dimensions based on message
        $messageLines = $this.Message -split "`n"
        $maxLineLength = ($messageLines | ForEach-Object { $_.Length } | Measure-Object -Maximum).Maximum
        $this.DialogWidth = [Math]::Max(40, $maxLineLength + 8)
        $this.DialogHeight = 10 + $messageLines.Count
        
        # Let base class handle the rest
        ([BaseDialog]$this).OnBoundsChanged()
    }
    
    # Override HandleScreenInput to add Y/N shortcuts
    [bool] HandleScreenInput([System.ConsoleKeyInfo]$key) {
        # Let base class handle standard dialog shortcuts first
        if (([BaseDialog]$this).HandleScreenInput($key)) {
            return $true
        }
        
        # Add Y/N shortcuts specific to confirmation dialog
        switch ($key.Key) {
            ([System.ConsoleKey]::Y) {
                if ($key.KeyChar -eq 'Y' -or $key.KeyChar -eq 'y') {
                    $this.HandlePrimaryAction()
                    return $true
                }
            }
            ([System.ConsoleKey]::N) {
                if ($key.KeyChar -eq 'N' -or $key.KeyChar -eq 'n') {
                    $this.HandleSecondaryAction()
                    return $true
                }
            }
        }
        
        return $false
    }
    
    [string] OnRender() {
        $sb = Get-PooledStringBuilder 1024
        
        # Render the base dialog (overlay, box, title, buttons)
        $baseRender = ([BaseDialog]$this).OnRender()
        $sb.Append($baseRender)
        
        # Add our custom content - the message and hint
        if ($this._dialogBounds -and $this._dialogBounds.Count -gt 0) {
            $x = $this._dialogBounds.X
            $y = $this._dialogBounds.Y
            $w = $this._dialogBounds.Width
            $h = $this._dialogBounds.Height
            
            # Draw warning icon in title
            $title = " ⚠ Confirm "
            $titleX = $x + [int](($w - $title.Length) / 2)
            $sb.Append([VT]::MoveTo($titleX, $y))
            $sb.Append($this.Theme.GetColor("warning"))
            $sb.Append($title)
            
            # Draw message
            $messageLines = $this.Message -split "`n"
            $messageY = $y + 2
            $sb.Append($this.Theme.GetColor("foreground"))
            foreach ($line in $messageLines) {
                $lineX = $x + [int](($w - $line.Length) / 2)
                $sb.Append([VT]::MoveTo($lineX, $messageY))
                $sb.Append($line)
                $messageY++
            }
            
            # Draw hint
            $hint = "[Y/N] or use Tab to select"
            $hintX = $x + [int](($w - $hint.Length) / 2)
            $sb.Append([VT]::MoveTo($hintX, $y + $h - 2))
            $sb.Append($this.Theme.GetColor("disabled"))
            $sb.Append($hint)
        }
        
        $sb.Append([VT]::Reset())
        $result = $sb.ToString()
        Return-PooledStringBuilder $sb
        return $result
    }
}