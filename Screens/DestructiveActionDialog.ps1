# DestructiveActionDialog.ps1 - Enhanced confirmation dialog for potentially dangerous operations

class DestructiveActionDialog : BaseDialog {
    [string]$ActionType       # "Delete", "Move", "Overwrite", etc.
    [string]$Description      # Detailed description of the action
    [string[]]$AffectedItems  # List of files/paths that will be affected
    [string]$WarningMessage   # Additional warning text
    [bool]$RequireExplicitConfirm = $true  # Require typing confirmation
    [string]$ConfirmationPhrase = ""       # What user must type to confirm
    [bool]$IsHighRisk = $false  # Whether this is a high-risk operation
    
    # UI Elements
    [System.Collections.ArrayList]$ContentElements
    [MinimalTextBox]$ConfirmationInput
    [bool]$ConfirmationValid = $false
    
    DestructiveActionDialog([string]$actionType, [string[]]$items) : base("⚠ Destructive Action") {
        $this.ActionType = $actionType
        $this.AffectedItems = $items
        $this.ContentElements = [System.Collections.ArrayList]::new()
        
        # Set confirmation phrase based on action type
        switch ($actionType.ToLower()) {
            "delete" { 
                $this.ConfirmationPhrase = "DELETE"
                $this.IsHighRisk = $true
                $this.Description = "This will move items to recycle bin"
                $this.WarningMessage = "Files can be restored from recycle bin"
            }
            "permanent-delete" { 
                $this.ConfirmationPhrase = "PERMANENTLY DELETE"
                $this.IsHighRisk = $true
                $this.Description = "This will PERMANENTLY delete items"
                $this.WarningMessage = "⚠ This action CANNOT be undone!"
            }
            "overwrite" { 
                $this.ConfirmationPhrase = "OVERWRITE"
                $this.IsHighRisk = $true
                $this.Description = "This will overwrite existing files"
                $this.WarningMessage = "Original files will be lost"
            }
            default { 
                $this.ConfirmationPhrase = $actionType.ToUpper()
                $this.Description = "This action may cause data loss"
            }
        }
        
        # Configure dialog appearance
        $this.PrimaryButtonText = "Cancel"      # Default to safe option
        $this.SecondaryButtonText = $actionType
        $this.DialogWidth = 70
        $this.DialogHeight = 15 + [Math]::Min($items.Count, 8)  # Limit display of items
    }
    
    [void] InitializeContent() {
        # Create confirmation input if required
        if ($this.RequireExplicitConfirm) {
            $this.ConfirmationInput = [MinimalTextBox]::new()
            $this.ConfirmationInput.Placeholder = "Type '$($this.ConfirmationPhrase)' to confirm"
            $this.ConfirmationInput.Width = 50
            $this.ConfirmationInput.Height = 1
            $this.ConfirmationInput.OnTextChanged = {
                $this.ValidateConfirmation()
            }.GetNewClosure()
            
            $this.AddChild($this.ConfirmationInput)
        }
        
        # Override button setup to make Cancel the primary action (safer)
        if ($this.PrimaryButton) {
            $this.PrimaryButton.Text = "Cancel"
            $this.PrimaryButton.OnClick = { $this.HandleSecondaryAction() }.GetNewClosure()
        }
        
        if ($this.SecondaryButton) {
            $this.SecondaryButton.Text = $this.ActionType
            $this.SecondaryButton.Enabled = -not $this.RequireExplicitConfirm
            $this.SecondaryButton.OnClick = { $this.HandlePrimaryAction() }.GetNewClosure()
        }
    }
    
    [void] ValidateConfirmation() {
        if ($this.ConfirmationInput) {
            $inputText = $this.ConfirmationInput.Text.Trim()
            $this.ConfirmationValid = ($inputText -eq $this.ConfirmationPhrase)
            
            if ($this.SecondaryButton) {
                $this.SecondaryButton.Enabled = $this.ConfirmationValid
                $this.Invalidate()
            }
        }
    }
    
    [void] OnActivated() {
        ([BaseDialog]$this).OnActivated()
        
        # Focus on cancel button by default (safer)
        if ($this.PrimaryButton) {
            $this.PrimaryButton.Focus()
        }
    }
    
    [bool] HandleScreenInput([System.ConsoleKeyInfo]$key) {
        # Let base class handle standard dialog shortcuts first
        if (([BaseDialog]$this).HandleScreenInput($key)) {
            return $true
        }
        
        # Enhanced keyboard shortcuts
        switch ($key.Key) {
            ([System.ConsoleKey]::Escape) {
                $this.HandleSecondaryAction()  # Cancel
                return $true
            }
            ([System.ConsoleKey]::Enter) {
                if ($this.RequireExplicitConfirm) {
                    if ($this.ConfirmationValid) {
                        $this.HandlePrimaryAction()  # Confirm
                    } else {
                        # Focus confirmation input if not valid
                        if ($this.ConfirmationInput) {
                            $this.ConfirmationInput.Focus()
                        }
                    }
                } else {
                    $this.HandlePrimaryAction()  # Confirm
                }
                return $true
            }
        }
        
        return $false
    }
    
    [string] OnRender() {
        $sb = Get-PooledStringBuilder 2048
        
        # Render the base dialog (overlay, box, title, buttons)
        $baseRender = ([BaseDialog]$this).OnRender()
        $sb.Append($baseRender)
        
        # Add our custom content
        if ($this._dialogBounds -and $this._dialogBounds.Count -gt 0) {
            $x = $this._dialogBounds.X
            $y = $this._dialogBounds.Y
            $w = $this._dialogBounds.Width
            $h = $this._dialogBounds.Height
            
            $currentY = $y + 3  # Start below title
            
            # Action type and description
            $actionTitle = "$($this.ActionType.ToUpper()) - $($this.AffectedItems.Count) item(s)"
            $titleX = $x + [int](($w - $actionTitle.Length) / 2)
            $sb.Append([VT]::MoveTo($titleX, $currentY))
            $sb.Append($this.Theme.GetColorSafe("status.error"))
            $sb.Append($actionTitle)
            $currentY += 2
            
            # Description
            $sb.Append([VT]::MoveTo($x + 2, $currentY))
            $sb.Append($this.Theme.GetColorSafe("text.primary"))
            $sb.Append($this.Description)
            $currentY += 2
            
            # Warning message if high risk
            if ($this.IsHighRisk -and $this.WarningMessage) {
                $sb.Append([VT]::MoveTo($x + 2, $currentY))
                $sb.Append($this.Theme.GetColorSafe("status.warning"))
                $sb.Append($this.WarningMessage)
                $currentY += 2
            }
            
            # Affected items (show first few)
            $sb.Append([VT]::MoveTo($x + 2, $currentY))
            $sb.Append($this.Theme.GetColorSafe("text.secondary"))
            $sb.Append("Affected items:")
            $currentY++
            
            $itemsToShow = [Math]::Min($this.AffectedItems.Count, 6)
            for ($i = 0; $i -lt $itemsToShow; $i++) {
                $item = Split-Path $this.AffectedItems[$i] -Leaf
                if ($item.Length -gt ($w - 6)) {
                    $item = "..." + $item.Substring($item.Length - ($w - 9))
                }
                
                $sb.Append([VT]::MoveTo($x + 4, $currentY))
                $sb.Append($this.Theme.GetColorSafe("text.disabled"))
                $sb.Append("• $item")
                $currentY++
            }
            
            if ($this.AffectedItems.Count -gt $itemsToShow) {
                $sb.Append([VT]::MoveTo($x + 4, $currentY))
                $sb.Append($this.Theme.GetColorSafe("text.disabled"))
                $sb.Append("... and $($this.AffectedItems.Count - $itemsToShow) more")
                $currentY++
            }
            
            # Confirmation input section
            if ($this.RequireExplicitConfirm) {
                $currentY++
                $sb.Append([VT]::MoveTo($x + 2, $currentY))
                $sb.Append($this.Theme.GetColorSafe("status.warning"))
                $sb.Append("Type '$($this.ConfirmationPhrase)' to confirm:")
                $currentY++
                
                # Position confirmation input
                if ($this.ConfirmationInput) {
                    $this.ConfirmationInput.X = $x + 4
                    $this.ConfirmationInput.Y = $currentY
                    $this.ConfirmationInput.Width = $w - 8
                }
                $currentY += 2
            }
            
            # Usage hint
            $hint = if ($this.RequireExplicitConfirm) {
                "Enter confirmation text, then press Tab to select action"
            } else {
                "Press Tab to select action, Escape to cancel"
            }
            
            $hintX = $x + [int](($w - $hint.Length) / 2)
            $sb.Append([VT]::MoveTo($hintX, $y + $h - 2))
            $sb.Append($this.Theme.GetColorSafe("text.disabled"))
            $sb.Append($hint)
        }

        $result = $sb.ToString()
        Return-PooledStringBuilder $sb
        return $result
    }
}