# ConfirmationDialog.ps1 - Generic confirmation dialog using UnifiedDialog

class ConfirmationDialog : UnifiedDialog {
    [string]$Message
    [string]$ConfirmText = "Yes" 
    [string]$CancelText = "No"
    
    ConfirmationDialog() : base("Confirm", 40, 8) {
        $this.Message = "Are you sure?"
        $this.InitializeDialog()
    }
    
    ConfirmationDialog([string]$message) : base("Confirm", 40, 8) {
        $this.Message = $message
        $this.InitializeDialog()
    }
    
    ConfirmationDialog([string]$message, [string]$confirmText, [string]$cancelText) : base("Confirm", 40, 8) {
        $this.Message = $message
        $this.ConfirmText = $confirmText
        $this.CancelText = $cancelText
        $this.InitializeDialog()
    }
    
    [void] InitializeDialog() {
        # Calculate dialog dimensions based on message
        $messageLines = $this.Message -split "`n"
        $maxLineLength = ($messageLines | ForEach-Object { $_.Length } | Measure-Object -Maximum).Maximum
        $this.DialogWidth = [Math]::Max(40, $maxLineLength + 8)
        $this.DialogHeight = 8 + $messageLines.Count
        
        # No input fields needed - just display the message
        # Set button labels
        $this.SetButtons($this.ConfirmText, $this.CancelText)
        
        # Set up submit handler for confirmation
        $dialog = $this
        $this.OnSubmit = { $dialog.Confirm() }.GetNewClosure()
    }
    
    [void] Confirm() {
        # Just close - the caller should check the dialog result
        $this.Close()
    }
    
    # Override OnActivated to focus on cancel button by default (safer)
    [void] OnActivated() {
        ([UnifiedDialog]$this).OnActivated()
        
        # Focus the cancel button by default for safety
        if ($this._buttons.Count -gt 1) {
            $focusManager = $this.GetService('FocusManager')
            if ($focusManager) {
                $focusManager.SetFocus($this._buttons[1])  # Cancel button
            }
        }
    }
    
    # Override HandleScreenInput to add Y/N shortcuts
    [bool] HandleScreenInput([System.ConsoleKeyInfo]$key) {
        # Let base class handle standard dialog shortcuts first
        if (([UnifiedDialog]$this).HandleScreenInput($key)) {
            return $true
        }
        
        # Add Y/N shortcuts specific to confirmation dialog
        switch ($key.Key) {
            ([System.ConsoleKey]::Y) {
                if ($key.KeyChar -eq 'Y' -or $key.KeyChar -eq 'y') {
                    if ($this.OnSubmit) { & $this.OnSubmit }
                    return $true
                }
            }
            ([System.ConsoleKey]::N) {
                if ($key.KeyChar -eq 'N' -or $key.KeyChar -eq 'n') {
                    if ($this.OnCancel) { & $this.OnCancel }
                    $this.Close()
                    return $true
                }
            }
        }
        
        return $false
    }
    
    # Override OnRender to display the message
    [string] OnRender() {
        # Get base rendering
        $baseRender = ([UnifiedDialog]$this).OnRender()
        
        # If no message to display, just return base
        if (-not $this.Message) {
            return $baseRender
        }
        
        $sb = Get-PooledStringBuilder 1024
        $sb.Append($baseRender)
        
        # Add the confirmation message in the content area
        $messageLines = $this.Message -split "`n"
        $messageY = $this._dialogY + 3  # Below title, inside dialog
        
        if ($this.Theme) {
            $sb.Append($this.Theme.GetColor("text.primary"))
        }
        
        foreach ($line in $messageLines) {
            $lineX = $this._dialogX + [int](($this.DialogWidth - $line.Length) / 2)
            $sb.Append([VT]::MoveTo($lineX, $messageY))
            $sb.Append($line)
            $messageY++
        }
        
        # Add Y/N hint
        $hint = "[Y/N] or use Tab to select"
        $hintX = $this._dialogX + [int](($this.DialogWidth - $hint.Length) / 2)
        $sb.Append([VT]::MoveTo($hintX, $this._dialogY + $this.DialogHeight - 4))
        if ($this.Theme) {
            $sb.Append($this.Theme.GetColor("text.disabled"))
        }
        $sb.Append($hint)
        
        $result = $sb.ToString()
        Return-PooledStringBuilder $sb
        return $result
    }
}