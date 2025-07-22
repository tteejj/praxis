# ConfirmationDialog.ps1 - Generic confirmation dialog

class ConfirmationDialog : Screen {
    [string]$Message
    [string]$ConfirmText = "Yes"
    [string]$CancelText = "No"
    [Button]$ConfirmButton
    [Button]$CancelButton
    [scriptblock]$OnConfirm = {}
    [scriptblock]$OnCancel = {}
    
    ConfirmationDialog([string]$message) : base() {
        $this.Title = "Confirm"
        $this.Message = $message
        $this.DrawBackground = $true
    }
    
    [void] OnInitialize() {
        # Create buttons
        $this.ConfirmButton = [Button]::new($this.ConfirmText)
        # Capture dialog reference
        $dialog = $this
        $this.ConfirmButton.OnClick = {
            if ($dialog.OnConfirm) {
                & $dialog.OnConfirm
            }
        }.GetNewClosure()
        $this.ConfirmButton.Initialize($global:ServiceContainer)
        $this.AddChild($this.ConfirmButton)
        
        $this.CancelButton = [Button]::new($this.CancelText)
        $this.CancelButton.OnClick = {
            if ($dialog.OnCancel) {
                & $dialog.OnCancel
            }
        }.GetNewClosure()
        $this.CancelButton.Initialize($global:ServiceContainer)
        $this.AddChild($this.CancelButton)
        
        # Key bindings
        $this.BindKey([System.ConsoleKey]::Escape, { 
            if ($this.OnCancel) {
                & $this.OnCancel
            }
        })
        $this.BindKey([System.ConsoleKey]::Tab, { $this.FocusNext() })
        $this.BindKey([System.ConsoleKey]::Enter, {
            $focused = $this.FindFocused()
            if ($focused -eq $this.ConfirmButton) {
                & $this.ConfirmButton.OnClick
            } elseif ($focused -eq $this.CancelButton) {
                & $this.CancelButton.OnClick
            }
        })
        $this.BindKey('y', { & $this.ConfirmButton.OnClick })
        $this.BindKey('Y', { & $this.ConfirmButton.OnClick })
        $this.BindKey('n', { & $this.CancelButton.OnClick })
        $this.BindKey('N', { & $this.CancelButton.OnClick })
    }
    
    [void] OnBoundsChanged() {
        # Calculate dialog dimensions based on message
        $messageLines = $this.Message -split "`n"
        $maxLineLength = ($messageLines | ForEach-Object { $_.Length } | Measure-Object -Maximum).Maximum
        $dialogWidth = [Math]::Max(40, $maxLineLength + 8)
        $dialogHeight = 10 + $messageLines.Count
        $centerX = [int](($this.Width - $dialogWidth) / 2)
        $centerY = [int](($this.Height - $dialogHeight) / 2)
        
        # Position buttons (use similar logic to ProjectsScreen)
        $buttonY = $centerY + $dialogHeight - 3
        $buttonHeight = 3
        $buttonSpacing = 2
        $maxButtonWidth = 12
        $totalButtonWidth = ($maxButtonWidth * 2) + $buttonSpacing
        
        # Center buttons if dialog is wide enough
        if ($dialogWidth -gt $totalButtonWidth) {
            $buttonStartX = $centerX + [int](($dialogWidth - $totalButtonWidth) / 2)
            $buttonWidth = $maxButtonWidth
        } else {
            $buttonStartX = $centerX + 2
            $buttonWidth = [int](($dialogWidth - 4 - $buttonSpacing) / 2)
        }
        
        $this.ConfirmButton.SetBounds(
            $buttonStartX,
            $buttonY,
            $buttonWidth,
            $buttonHeight
        )
        
        $this.CancelButton.SetBounds(
            $buttonStartX + $buttonWidth + $buttonSpacing,
            $buttonY,
            $buttonWidth,
            $buttonHeight
        )
        
        # Store dialog bounds for rendering
        $this._dialogBounds = @{
            X = $centerX
            Y = $centerY
            Width = $dialogWidth
            Height = $dialogHeight
        }
    }
    
    [void] OnActivated() {
        ([Screen]$this).OnActivated()
        # Focus on cancel button by default (safer)
        $this.CancelButton.Focus()
    }
    
    hidden [hashtable]$_dialogBounds
    
    [string] OnRender() {
        $sb = [System.Text.StringBuilder]::new()
        
        # First, clear the entire screen with a dark overlay
        $overlayBg = [VT]::RGBBG(16, 16, 16)  # Dark gray overlay
        for ($y = 0; $y -lt $this.Height; $y++) {
            $sb.Append([VT]::MoveTo(0, $y))
            $sb.Append($overlayBg)
            $sb.Append(" " * $this.Width)
        }
        
        if ($this._dialogBounds) {
            # Draw dialog box
            $borderColor = $this.Theme.GetColor("dialog.border")
            $bgColor = $this.Theme.GetBgColor("dialog.background")
            $titleColor = $this.Theme.GetColor("dialog.title")
            $warningColor = $this.Theme.GetColor("warning")
            
            $x = $this._dialogBounds.X
            $y = $this._dialogBounds.Y
            $w = $this._dialogBounds.Width
            $h = $this._dialogBounds.Height
            
            # Fill background
            for ($i = 0; $i -lt $h; $i++) {
                $sb.Append([VT]::MoveTo($x, $y + $i))
                $sb.Append($bgColor)
                $sb.Append(" " * $w)
            }
            
            # Draw border
            $sb.Append([VT]::MoveTo($x, $y))
            $sb.Append($borderColor)
            $sb.Append([VT]::TL() + ([VT]::H() * ($w - 2)) + [VT]::TR())
            
            for ($i = 1; $i -lt $h - 1; $i++) {
                $sb.Append([VT]::MoveTo($x, $y + $i))
                $sb.Append([VT]::V())
                $sb.Append([VT]::MoveTo($x + $w - 1, $y + $i))
                $sb.Append([VT]::V())
            }
            
            $sb.Append([VT]::MoveTo($x, $y + $h - 1))
            $sb.Append([VT]::BL() + ([VT]::H() * ($w - 2)) + [VT]::BR())
            
            # Draw title with warning icon
            $title = " ⚠ Confirm "
            $titleX = $x + [int](($w - $title.Length) / 2)
            $sb.Append([VT]::MoveTo($titleX, $y))
            $sb.Append($warningColor)
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
        
        # Render children
        foreach ($child in $this.Children) {
            if ($child.Visible) {
                $sb.Append($child.Render())
            }
        }
        
        $sb.Append([VT]::Reset())
        return $sb.ToString()
    }
    
    [void] FocusNext() {
        if ($this.ConfirmButton.IsFocused) {
            $this.CancelButton.Focus()
        } else {
            $this.ConfirmButton.Focus()
        }
    }
}