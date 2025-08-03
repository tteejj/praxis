# ContextPopup.ps1 - Small context popup for screen actions

class ContextPopup : UIElement {
    [System.Collections.Generic.List[object]]$Items
    [int]$SelectedIndex = 0
    [scriptblock]$OnSelect = {}
    [scriptblock]$OnCancel = {}
    [string]$Title = "Actions"
    [bool]$IsVisible = $false
    
    # Compact popup styling
    [int]$MaxWidth = 20
    [int]$MaxHeight = 8
    
    # Colors
    hidden [string]$_normalColor = ""
    hidden [string]$_selectedColor = ""
    hidden [string]$_selectedBgColor = ""
    hidden [string]$_borderColor = ""
    
    ContextPopup() : base() {
        $this.Items = [System.Collections.Generic.List[object]]::new()
        $this.Width = $this.MaxWidth
        $this.Height = $this.MaxHeight
        $this.IsVisible = $false
        $this.IsFocusable = $true
    }
    
    [void] Show() {
        $this.IsVisible = $true
        $this.SelectedIndex = 0
        $this.UpdateColors()
        $this.Invalidate()
    }
    
    [void] Hide() {
        $this.IsVisible = $false
        
        # Ensure focus is restored to a valid element
        if ($this.ServiceContainer) {
            $focusManager = $this.ServiceContainer.GetService('FocusManager')
            if ($focusManager) {
                $currentFocus = $focusManager.GetFocused()
                if ($currentFocus -eq $this) {
                    # We're currently focused but hiding, need to restore focus
                    # Let the parent handle focus restoration
                    if ($global:Logger) {
                        $global:Logger.Debug("ContextPopup.Hide: Popup was focused, clearing focus")
                    }
                    $focusManager.ClearFocus()
                }
            }
        }
        
        $this.Invalidate()
        
        if ($global:Logger) {
            $global:Logger.Debug("ContextPopup.Hide: Popup hidden")
        }
    }
    
    
    [void] UpdateColors() {
        if ($this.Theme) {
            try {
                $this._normalColor = $this.Theme.GetColor('text.primary')
                $this._selectedColor = $this.Theme.GetColor('menu.text.selected')
                $this._selectedBgColor = $this.Theme.GetBgColor('menu.background.selected')
                $this._borderColor = $this.Theme.GetColor('border.normal')
            }
            catch {
                if ($global:Logger) {
                    $global:Logger.Error("ContextPopup.UpdateColors: Error updating colors: $_")
                }
            }
        } else {
            # NO FALLBACKS - theme MUST be valid
            $this._normalColor = $this.Theme.GetColor('text.primary')
            $this._selectedColor = $this.Theme.GetColor('color.primary')
            $this._borderColor = $this.Theme.GetColor('border.normal')
        }
    }
    
    [void] AddItem([string]$text, [scriptblock]$action) {
        $this.Items.Add(@{
            Text = $text
            Action = $action
        })
        
        # Auto-size popup based on content
        $this.Height = [Math]::Min($this.Items.Count + 2, $this.MaxHeight) # +2 for border
        $maxTextLength = ($this.Items | ForEach-Object { $_.Text.Length } | Measure-Object -Maximum).Maximum
        $this.Width = [Math]::Min($maxTextLength + 4, $this.MaxWidth) # +4 for border and padding
    }
    
    [bool] HandleInput([System.ConsoleKeyInfo]$keyInfo) {
        if (-not $this.IsVisible) { return $false }
        
        switch ($keyInfo.Key) {
            ([System.ConsoleKey]::UpArrow) {
                if ($this.Items.Count -gt 0) {
                    $this.SelectedIndex = ($this.SelectedIndex - 1 + $this.Items.Count) % $this.Items.Count
                    $this.Invalidate()
                }
                return $true
            }
            ([System.ConsoleKey]::DownArrow) {
                if ($this.Items.Count -gt 0) {
                    $this.SelectedIndex = ($this.SelectedIndex + 1) % $this.Items.Count
                    $this.Invalidate()
                }
                return $true
            }
            ([System.ConsoleKey]::Enter) {
                if ($this.Items.Count -gt 0 -and $this.SelectedIndex -ge 0) {
                    $selectedItem = $this.Items[$this.SelectedIndex]
                    # Execute action BEFORE hiding to maintain focus chain
                    if ($selectedItem.Action) {
                        if ($global:Logger) {
                            $global:Logger.Debug("ContextPopup.Enter: Executing action for '$($selectedItem.Text)'")
                        }
                        & $selectedItem.Action
                    }
                    # Now hide and call OnSelect
                    $this.Hide()
                    & $this.OnSelect $selectedItem
                }
                return $true
            }
            ([System.ConsoleKey]::Escape) {
                $this.Hide()
                & $this.OnCancel
                return $true
            }
        }
        
        # Handle space key same as Enter
        if ($keyInfo.KeyChar -eq ' ') {
            if ($this.Items.Count -gt 0 -and $this.SelectedIndex -ge 0) {
                $selectedItem = $this.Items[$this.SelectedIndex]
                # Execute action BEFORE hiding to maintain focus chain
                if ($selectedItem.Action) {
                    if ($global:Logger) {
                        $global:Logger.Debug("ContextPopup.Space: Executing action for '$($selectedItem.Text)'")
                    }
                    & $selectedItem.Action
                }
                # Now hide and call OnSelect
                $this.Hide()
                & $this.OnSelect $selectedItem
            }
            return $true
        }
        
        # For letter keys, just hide popup and let MainScreen handle
        if ($keyInfo.KeyChar -match '[a-zA-Z]') {
            $this.Hide()
            return $false  # Pass through to MainScreen
        }
        
        return $false
    }
    
    [string] OnRender() {
        if (-not $this.IsVisible) { return "" }
        
        try {
            $sb = Get-PooledStringBuilder 512
            
            # No background color - we're an overlay
            $bgColor = ""
        
        # Simple clean border with proper theming
        $sb.Append([VT]::Reset())
        
        # Calculate actual width based on longest item
        $actualWidth = ($this.Items | ForEach-Object { $_.Text.Length } | Measure-Object -Maximum).Maximum + 4
        
        # Top border
        $sb.Append([VT]::MoveTo($this.X, $this.Y))
        $sb.Append($this._borderColor)
        $sb.Append("┌" + ("─" * ($actualWidth - 2)) + "┐")
        
        # Items with side borders
        for ($i = 0; $i -lt $this.Items.Count; $i++) {
            $y = $this.Y + $i + 1
            
            # Left border
            $sb.Append([VT]::MoveTo($this.X, $y))
            $sb.Append($this._borderColor)
            $sb.Append("│")
            
            # Item content
            $sb.Append([VT]::MoveTo($this.X + 1, $y))
            
            $item = $this.Items[$i]
            $text = $item.Text
            if ($text.Length -gt ($this.Width - 3)) {
                $text = $text.Substring(0, $this.Width - 4) + "…"
            }
            
            if ($i -eq $this.SelectedIndex) {
                $sb.Append($this._selectedColor)
                $sb.Append("▸")
            } else {
                $sb.Append($this._normalColor)
                $sb.Append(" ")
            }
            
            # Pad the text to fill the width minus borders and indicator
            $sb.Append($text.PadRight($actualWidth - 3))
            
            # Right border
            $sb.Append([VT]::MoveTo($this.X + $actualWidth - 1, $y))
            $sb.Append($this._borderColor)
            $sb.Append("│")
        }
        
        # Bottom border
        $sb.Append([VT]::MoveTo($this.X, $this.Y + $this.Items.Count + 1))
        $sb.Append($this._borderColor)
        $sb.Append("└" + ("─" * ($actualWidth - 2)) + "┘")
        
        # Reset colors at the end to prevent bleeding
        $sb.Append([VT]::Reset())
            
            $result = $sb.ToString()
            Return-PooledStringBuilder $sb
            return $result
        }
        catch {
            if ($global:Logger) {
                $global:Logger.Error("ContextPopup.OnRender: Error rendering popup: $_")
            }
            return ""
        }
    }
}