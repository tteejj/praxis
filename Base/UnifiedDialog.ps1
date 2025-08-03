# UnifiedDialog.ps1 - The ONE dialog system that replaces BaseDialog, SimpleDialog, and CleanDialog
# Solves: Theme null issues, bounds management hell, inconsistent APIs, manual service injection

class UnifiedDialog : Screen {
    # Core properties - simplified from BaseDialog
    [string]$DialogTitle = "Dialog"
    [int]$DialogWidth = 60
    [int]$DialogHeight = 20
    [BorderType]$BorderType = [BorderType]::Rounded
    
    # Event handlers - standardized API
    [scriptblock]$OnSubmit = {}
    [scriptblock]$OnCancel = {}
    
    # Internal state - minimal and reliable
    hidden [int]$_dialogX = 0
    hidden [int]$_dialogY = 0
    
    # Public read-only properties for dialog position (for custom rendering)
    [int] get_DialogX() { return $this._dialogX }
    [int] get_DialogY() { return $this._dialogY }
    hidden [System.Collections.Generic.List[UIElement]]$_fields
    hidden [System.Collections.Generic.List[MinimalButton]]$_buttons
    hidden [bool]$_initialized = $false
    
    # Theme-safe colors - cached once, used everywhere
    hidden [string]$_borderColor = ""
    hidden [string]$_bgColor = ""
    hidden [string]$_titleColor = ""
    hidden [string]$_overlayColor = ""
    
    UnifiedDialog([string]$title) : base() {
        $this.DialogTitle = $title
        $this.Title = $title
        $this._fields = [System.Collections.Generic.List[UIElement]]::new()
        $this._buttons = [System.Collections.Generic.List[MinimalButton]]::new()
        $this.DrawBackground = $false  # Dialog handles its own background
    }
    
    UnifiedDialog([string]$title, [int]$width, [int]$height) : base() {
        $this.DialogTitle = $title
        $this.Title = $title
        $this.DialogWidth = $width
        $this.DialogHeight = $height
        $this._fields = [System.Collections.Generic.List[UIElement]]::new()
        $this._buttons = [System.Collections.Generic.List[MinimalButton]]::new()
        $this.DrawBackground = $false
    }
    
    # SIMPLE FIELD API - like CleanDialog but better
    [void] AddField([string]$name, [string]$label, [string]$defaultValue = "") {
        # Create DialogField for proper label/input layout (like the original)
        if ([DialogField] -ne $null) {  # Check if DialogField class exists
            $field = [DialogField]::new($label, "Enter $label...")
            $field.KeyWidth = 14
            $field.SetValue($defaultValue)
            
            # Store name in a custom property
            $field | Add-Member -NotePropertyName "FieldName" -NotePropertyValue $name
            
            $this._fields.Add($field)
            $this.AddChild($field)
        } else {
            # Fallback to simple text box
            $field = [MinimalTextBox]::new()
            $field.ShowBorder = $false
            $field.Height = 1
            $field.Placeholder = $label
            $field.Text = $defaultValue
            
            $field | Add-Member -NotePropertyName "FieldName" -NotePropertyValue $name
            
            $this._fields.Add($field)
            $this.AddChild($field)
        }
    }
    
    # ADVANCED FIELD API - like BaseDialog but simpler
    [void] AddControl([UIElement]$control) {
        $this._fields.Add($control)
        $this.AddChild($control)
    }
    
    # GET FIELD VALUES - unified API
    [string] GetFieldValue([string]$name) {
        foreach ($field in $this._fields) {
            if ($field.FieldName -eq $name) {
                if ($field -is [MinimalTextBox]) {
                    return $field.Text
                } elseif ($field.GetType().Name -eq "DialogField") {
                    return $field.Value
                }
            }
        }
        return ""
    }
    
    [hashtable] GetAllFieldValues() {
        $values = @{}
        foreach ($field in $this._fields) {
            if ($field.FieldName) {
                if ($field -is [MinimalTextBox]) {
                    $values[$field.FieldName] = $field.Text
                } elseif ($field.GetType().Name -eq "DialogField") {
                    $values[$field.FieldName] = $field.Value
                }
            }
        }
        return $values
    }
    
    # AUTOMATIC BUTTON MANAGEMENT
    [void] SetButtons([string]$primaryText, [string]$secondaryText = "Cancel") {
        # Clear existing buttons
        foreach ($button in $this._buttons) {
            $this.RemoveChild($button)
        }
        $this._buttons.Clear()
        
        # Create primary button
        $primaryButton = [MinimalButton]::new($primaryText)
        $primaryButton.IsDefault = $true
        $dialog = $this
        $primaryButton.OnClick = {
            if ($dialog.OnSubmit) { 
                & $dialog.OnSubmit 
            }
            # Don't auto-close - let the OnSubmit handler call Close() if needed
        }.GetNewClosure()
        
        # Create secondary button
        $secondaryButton = [MinimalButton]::new($secondaryText)
        $secondaryButton.OnClick = {
            if ($dialog.OnCancel) { 
                & $dialog.OnCancel 
            }
            $dialog.Close()
        }.GetNewClosure()
        
        $this._buttons.Add($primaryButton)
        $this._buttons.Add($secondaryButton)
        $this.AddChild($primaryButton)
        $this.AddChild($secondaryButton)
    }
    
    # GUARANTEED THEME INITIALIZATION - no more null themes!
    [void] OnInitialize() {
        if ($this._initialized) { return }
        $this._initialized = $true
        
        # FORCE parent initialization to get ServiceContainer and Theme
        ([Screen]$this).OnInitialize()
        
        # GUARANTEE theme is available - fallback to global if needed
        if (-not $this.Theme) {
            $this.Theme = $global:ServiceContainer.GetService('ThemeManager')
        }
        
        # CACHE theme colors once - prevents null theme issues during render
        $this.CacheThemeColors()
        
        # Calculate dialog position
        $this.CalculatePosition()
        
        # Create default buttons if none exist
        if ($this._buttons.Count -eq 0) {
            $this.SetButtons("OK", "Cancel")
        }
        
        # Auto-layout all fields and buttons
        $this.LayoutFields()
    }
    
    [void] CacheThemeColors() {
        if ($this.Theme) {
            $this._borderColor = $this.Theme.GetColor("border.dialog")
            $this._bgColor = $this.Theme.GetBgColor("surface.dialog")
            $this._titleColor = $this.Theme.GetColor("text.heading")
            $this._overlayColor = $this.Theme.GetBgColor("surface.background")
        } else {
            # Safe fallbacks - never null
            $this._borderColor = ""
            $this._bgColor = ""
            $this._titleColor = ""
            $this._overlayColor = ""
        }
    }
    
    # SIMPLE, RELIABLE POSITIONING - no more bounds hell
    [void] CalculatePosition() {
        $consoleW = [Console]::WindowWidth
        $consoleH = [Console]::WindowHeight
        
        # Constrain dialog size to fit console
        $this.DialogWidth = [Math]::Min($this.DialogWidth, $consoleW - 4)
        $this.DialogHeight = [Math]::Min($this.DialogHeight, $consoleH - 4)
        
        # Center dialog
        $this._dialogX = [Math]::Max(1, [int](($consoleW - $this.DialogWidth) / 2))
        $this._dialogY = [Math]::Max(1, [int](($consoleH - $this.DialogHeight) / 2))
    }
    
    # AUTOMATIC FIELD LAYOUT - no manual positioning needed
    [void] LayoutFields() {
        $contentX = $this._dialogX + 2  # Inside border with padding
        $contentY = $this._dialogY + 2  # Below title
        $contentWidth = $this.DialogWidth - 4
        
        # Layout fields vertically
        $currentY = $contentY
        foreach ($field in $this._fields) {
            $field.SetBounds($contentX, $currentY, $contentWidth, $field.Height)
            $currentY += $field.Height + 1  # +1 for spacing
        }
        
        # Layout buttons at bottom
        if ($this._buttons.Count -gt 0) {
            $buttonY = $this._dialogY + $this.DialogHeight - 3
            $buttonWidth = 10
            $buttonSpacing = 4
            $totalButtonWidth = ($this._buttons.Count * $buttonWidth) + (($this._buttons.Count - 1) * $buttonSpacing)
            $startX = $this._dialogX + [int](($this.DialogWidth - $totalButtonWidth) / 2)
            
            for ($i = 0; $i -lt $this._buttons.Count; $i++) {
                $buttonX = $startX + ($i * ($buttonWidth + $buttonSpacing))
                $this._buttons[$i].SetBounds($buttonX, $buttonY, $buttonWidth, 1)
            }
        }
    }
    
    # FLICKER-FREE RENDERING - single render pass
    [string] OnRender() {
        if (-not $this._initialized) {
            $this.OnInitialize()
        }
        
        $sb = Get-PooledStringBuilder 2048
        
        # 1. Render overlay background
        $this.RenderOverlay($sb)
        
        # 2. Render dialog box with cached colors
        $this.RenderDialogBox($sb)
        
        # 3. Render title with cached colors
        $this.RenderTitle($sb)
        
        # 4. Render all children (fields and buttons) - Screen handles this
        $this.RenderChildren($sb)
        
        $result = $sb.ToString()
        Return-PooledStringBuilder $sb
        return $result
    }
    
    [void] RenderOverlay([System.Text.StringBuilder]$sb) {
        # Use cached overlay color - no theme null checks needed
        if ($this._overlayColor) {
            for ($y = 0; $y -lt [Console]::WindowHeight; $y++) {
                $sb.Append([VT]::MoveTo(0, $y))
                $sb.Append($this._overlayColor)
                $sb.Append(' ' * [Console]::WindowWidth)
            }
        }
    }
    
    [void] RenderDialogBox([System.Text.StringBuilder]$sb) {
        # Fill background with cached color
        if ($this._bgColor) {
            for ($i = 0; $i -lt $this.DialogHeight; $i++) {
                $sb.Append([VT]::MoveTo($this._dialogX, $this._dialogY + $i))
                $sb.Append($this._bgColor)
                $sb.Append(' ' * $this.DialogWidth)
            }
        }
        
        # Draw border using BorderStyle system with cached color
        if ($this._borderColor) {
            $sb.Append([BorderStyle]::RenderBorder(
                $this._dialogX, $this._dialogY, 
                $this.DialogWidth, $this.DialogHeight,
                $this.BorderType, $this._borderColor
            ))
        }
    }
    
    [void] RenderTitle([System.Text.StringBuilder]$sb) {
        if ($this.DialogTitle -and $this._titleColor) {
            $titleText = " $($this.DialogTitle) "
            $titleX = $this._dialogX + [int](($this.DialogWidth - $titleText.Length) / 2)
            
            $sb.Append([VT]::MoveTo($titleX, $this._dialogY))
            $sb.Append($this._titleColor)
            $sb.Append($titleText)
            $sb.Append([VT]::Reset())
        }
    }
    
    [void] RenderChildren([System.Text.StringBuilder]$sb) {
        # Set clip bounds to dialog area
        [RenderHelper]::SetClipBounds($this._dialogX, $this._dialogY, $this.DialogWidth, $this.DialogHeight)
        
        # Render all children (fields and buttons)
        foreach ($child in $this.Children) {
            if ($child.Visible) {
                $sb.Append($child.Render())
            }
        }
        
        # Reset clip bounds
        [RenderHelper]::ResetClipBounds()
    }
    
    # STANDARD INPUT HANDLING - consistent across all dialogs
    [bool] HandleScreenInput([System.ConsoleKeyInfo]$key) {
        switch ($key.Key) {
            ([System.ConsoleKey]::Enter) {
                # Enter submits if not handled by focused component
                if ($this.OnSubmit) { & $this.OnSubmit }
                $this.Close()
                return $true
            }
            ([System.ConsoleKey]::Escape) {
                # Escape always cancels
                if ($this.OnCancel) { & $this.OnCancel }
                $this.Close()
                return $true
            }
        }
        return $false
    }
    
    # RELIABLE DIALOG CLOSING - no focus restoration issues
    [void] Close() {
        if ($global:ScreenManager) {
            $global:ScreenManager.Pop()
        }
    }
    
    # AUTOMATIC FOCUS MANAGEMENT
    [void] OnActivated() {
        ([Screen]$this).OnActivated()
        
        # Focus first field if available
        if ($this._fields.Count -gt 0) {
            $focusManager = $this.GetService('FocusManager')
            if ($focusManager) {
                $focusManager.SetFocus($this._fields[0])
            }
        }
    }
}