# TextInputDialog.ps1 - Simple dialog for text input

class TextInputDialog : Screen {
    [string]$Prompt
    [string]$DefaultValue
    [string]$Placeholder
    [TextBox]$InputBox
    [Button]$OkButton
    [Button]$CancelButton
    [scriptblock]$OnSubmit = {}
    [scriptblock]$OnCancel = {}
    
    TextInputDialog([string]$prompt) : base() {
        $this.Title = "Input"
        $this.Prompt = $prompt
        $this.DefaultValue = ""
        $this.Placeholder = "Enter text..."
        $this.DrawBackground = $true
    }
    
    TextInputDialog([string]$prompt, [string]$defaultValue) : base() {
        $this.Title = "Input"
        $this.Prompt = $prompt
        $this.DefaultValue = $defaultValue
        $this.Placeholder = "Enter text..."
        $this.DrawBackground = $true
    }
    
    [void] OnInitialize() {
        # Create input textbox
        $this.InputBox = [TextBox]::new()
        $this.InputBox.Text = $this.DefaultValue
        $this.InputBox.Placeholder = $this.Placeholder
        $this.InputBox.Initialize($global:ServiceContainer)
        $this.AddChild($this.InputBox)
        
        # Create buttons
        $this.OkButton = [Button]::new("OK")
        # Capture dialog reference
        $dialog = $this
        $this.OkButton.OnClick = {
            if ($dialog.OnSubmit) {
                & $dialog.OnSubmit $dialog.InputBox.Text
            }
        }.GetNewClosure()
        $this.OkButton.Initialize($global:ServiceContainer)
        $this.AddChild($this.OkButton)
        
        $this.CancelButton = [Button]::new("Cancel")
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
            if ($focused -eq $this.InputBox -or $focused -eq $this.OkButton) {
                & $this.OkButton.OnClick
            } elseif ($focused -eq $this.CancelButton) {
                & $this.CancelButton.OnClick
            }
        })
    }
    
    [void] OnActivated() {
        ([Screen]$this).OnActivated()
        # Focus on input box and select all text
        $this.InputBox.Focus()
        # TODO: Add SelectAll method to TextBox
    }
    
    [void] OnBoundsChanged() {
        # Calculate dialog dimensions based on prompt
        $promptLines = $this.Prompt -split "`n"
        $maxLineLength = ($promptLines | ForEach-Object { $_.Length } | Measure-Object -Maximum).Maximum
        $dialogWidth = [Math]::Max(50, $maxLineLength + 8)
        $dialogHeight = 10 + $promptLines.Count
        $centerX = [int](($this.Width - $dialogWidth) / 2)
        $centerY = [int](($this.Height - $dialogHeight) / 2)
        
        # Position components
        $this.InputBox.SetBounds($centerX + 2, $centerY + 2 + $promptLines.Count + 1, $dialogWidth - 4, 3)
        
        # Position buttons (use similar logic to ProjectsScreen)
        $buttonY = $centerY + $dialogHeight - 4
        $buttonHeight = 3
        $buttonSpacing = 2
        $maxButtonWidth = 10
        $totalButtonWidth = ($maxButtonWidth * 2) + $buttonSpacing
        
        # Center buttons if dialog is wide enough
        if ($dialogWidth -gt $totalButtonWidth) {
            $buttonStartX = $centerX + [int](($dialogWidth - $totalButtonWidth) / 2)
            $buttonWidth = $maxButtonWidth
        } else {
            $buttonStartX = $centerX + 2
            $buttonWidth = [int](($dialogWidth - 4 - $buttonSpacing) / 2)
        }
        
        $this.OkButton.SetBounds(
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
            
            # Draw title
            $title = " $($this.Title) "
            $titleX = $x + [int](($w - $title.Length) / 2)
            $sb.Append([VT]::MoveTo($titleX, $y))
            $sb.Append($titleColor)
            $sb.Append($title)
            
            # Draw prompt
            $promptLines = $this.Prompt -split "`n"
            $promptY = $y + 2
            $sb.Append($this.Theme.GetColor("foreground"))
            foreach ($line in $promptLines) {
                $lineX = $x + 2
                $sb.Append([VT]::MoveTo($lineX, $promptY))
                $sb.Append($line)
                $promptY++
            }
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
        $focusableChildren = $this.Children | Where-Object { $_.IsFocusable -and $_.Visible }
        if ($focusableChildren.Count -eq 0) { return }
        
        $currentIndex = -1
        for ($i = 0; $i -lt $focusableChildren.Count; $i++) {
            if ($focusableChildren[$i].IsFocused) {
                $currentIndex = $i
                break
            }
        }
        
        $nextIndex = ($currentIndex + 1) % $focusableChildren.Count
        $focusableChildren[$nextIndex].Focus()
    }
}