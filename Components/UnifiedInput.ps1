# UnifiedInput.ps1 - The ONE input component that replaces MinimalTextBox + DialogField
# Solves: Inconsistent focus handling, theme chaos, different APIs for text input

class UnifiedInput : FocusableComponent {
    # INPUT MODES - Single component, multiple presentation modes
    [UnifiedInputMode]$Mode = [UnifiedInputMode]::Text  # Text, Field, Password, Number
    
    # CORE INPUT PROPERTIES
    [string]$Text = ""
    [string]$Placeholder = ""
    [int]$MaxLength = 0  # 0 = no limit
    [scriptblock]$OnTextChanged = {}
    [scriptblock]$OnEnter = {}
    [scriptblock]$OnEscape = {}
    
    # FIELD MODE PROPERTIES (for UnifiedDialog structured forms)
    [string]$Label = ""
    [int]$LabelWidth = 12  # Width reserved for the label
    [bool]$ShowLabel = $false
    
    # VALIDATION PROPERTIES
    [scriptblock]$Validator = $null  # Custom validation logic
    [string]$ValidationMessage = ""
    [bool]$IsValid = $true
    [bool]$IsRequired = $false
    
    # VISUAL PROPERTIES
    [bool]$ShowBorder = $false  # Most inputs are borderless for clean look
    [BorderType]$BorderType = [BorderType]::Rounded
    [bool]$ReadOnly = $false
    
    # INTERNAL STATE - Cursor and viewport management
    hidden [int]$_cursorPosition = 0
    hidden [int]$_viewportStart = 0
    hidden [bool]$_showCursor = $true
    hidden [System.Timers.Timer]$_cursorTimer = $null
    
    # THEME COLORS - Cached once, consistent everywhere
    hidden [hashtable]$_colors = @{}
    hidden [ThemeManager]$Theme
    
    UnifiedInput() : base() {
        $this.Height = 1  # Single line by default
        $this.IsFocusable = $true
        $this.FocusStyle = 'minimal'
        $this.InitializeCursorTimer()
    }
    
    UnifiedInput([UnifiedInputMode]$mode) : base() {
        $this.Mode = $mode
        $this.Height = 1
        $this.IsFocusable = $true
        $this.FocusStyle = 'minimal'
        
        # Mode-specific defaults
        switch ($mode) {
            ([UnifiedInputMode]::Field) {
                $this.ShowLabel = $true
                $this.Height = 1  # Field mode is still single line
            }
            ([UnifiedInputMode]::Password) {
                # Password mode settings
            }
        }
        
        $this.InitializeCursorTimer()
    }
    
    UnifiedInput([string]$label) : base() {
        $this.Mode = [UnifiedInputMode]::Field
        $this.Label = $label
        $this.ShowLabel = $true
        $this.Height = 1
        $this.IsFocusable = $true
        $this.FocusStyle = 'minimal'
        $this.InitializeCursorTimer()
    }
    
    # ═══════════════════════════════════════════════════════════════════════════════════════
    # INITIALIZATION & THEME MANAGEMENT - Guaranteed consistent theming
    # ═══════════════════════════════════════════════════════════════════════════════════════
    
    [void] OnInitialize() {
        ([FocusableComponent]$this).OnInitialize()
        $this.Theme = $this.ServiceContainer.GetService("ThemeManager")
        
        if ($this.Theme) {
            # Subscribe to theme changes
            $eventBus = $this.ServiceContainer.GetService('EventBus')
            if ($eventBus) {
                $eventBus.Subscribe('theme.changed', {
                    param($sender, $eventData)
                    $this.CacheThemeColors()
                    $this.Invalidate()
                }.GetNewClosure())
            }
            
            $this.CacheThemeColors()
        }
    }
    
    [void] CacheThemeColors() {
        if ($this.Theme) {
            $this._colors = @{
                # Text colors - all amber
                text = $this.Theme.GetColor('input.text')
                placeholder = $this.Theme.GetColor('input.placeholder')
                label = $this.Theme.GetColor('text.secondary')
                
                # Background colors
                background = $this.Theme.GetBgColor('input.background')
                
                # Focus colors - unified with UnifiedDialog and UnifiedList
                focusReverseBg = $this.Theme.GetBgColor('focus.reverse.background')
                focusReverseText = $this.Theme.GetColor('focus.reverse.text')
                
                # Border colors
                border = $this.Theme.GetColor('border.input')
                borderFocused = $this.Theme.GetColor('border.input.focused')
                
                # Validation colors
                error = $this.Theme.GetColor('status.error')
                success = $this.Theme.GetColor('status.success')
                
                # Cursor color
                cursor = $this.Theme.GetColor('color.primary')
            }
        }
    }
    
    [void] InitializeCursorTimer() {
        # Cursor blink timer for smooth user experience
        $this._cursorTimer = [System.Timers.Timer]::new(500)  # 500ms blink
        $this._cursorTimer.AutoReset = $true
        
        $input = $this
        $this._cursorTimer.add_Elapsed({
            $input._showCursor = -not $input._showCursor
            if ($input.IsFocused) {
                $input.Invalidate()
            }
        })
    }
    
    # ═══════════════════════════════════════════════════════════════════════════════════════
    # TEXT MANAGEMENT - Unified text handling with validation
    # ═══════════════════════════════════════════════════════════════════════════════════════
    
    [void] SetText([string]$newText) {
        # Apply max length constraint
        if ($this.MaxLength -gt 0 -and $newText.Length -gt $this.MaxLength) {
            $newText = $newText.Substring(0, $this.MaxLength)
        }
        
        if ($this.Text -ne $newText) {
            $this.Text = $newText
            $this._cursorPosition = [Math]::Min($this._cursorPosition, $newText.Length)
            $this.UpdateViewport()
            $this.ValidateInput()
            $this.Invalidate()
            
            if ($this.OnTextChanged) {
                & $this.OnTextChanged
            }
        }
    }
    
    [void] ValidateInput() {
        $this.IsValid = $true
        $this.ValidationMessage = ""
        
        # Required field validation
        if ($this.IsRequired -and $this.Text.Length -eq 0) {
            $this.IsValid = $false
            $this.ValidationMessage = "This field is required"
            return
        }
        
        # Custom validation
        if ($this.Validator) {
            try {
                $result = & $this.Validator $this.Text
                if ($result -is [bool]) {
                    $this.IsValid = $result
                    if (-not $result) {
                        $this.ValidationMessage = "Invalid input"
                    }
                } elseif ($result -is [hashtable] -and $result.ContainsKey('Valid')) {
                    $this.IsValid = $result.Valid
                    if ($result.ContainsKey('Message')) {
                        $this.ValidationMessage = $result.Message
                    }
                }
            } catch {
                $this.IsValid = $false
                $this.ValidationMessage = "Validation error: $_"
            }
        }
    }
    
    [void] UpdateViewport() {
        # Ensure cursor is visible within the available width
        $availableWidth = $this.GetInputWidth()
        
        if ($this._cursorPosition -lt $this._viewportStart) {
            $this._viewportStart = $this._cursorPosition
        } elseif ($this._cursorPosition -ge ($this._viewportStart + $availableWidth)) {
            $this._viewportStart = $this._cursorPosition - $availableWidth + 1
        }
        
        # Bounds check
        $this._viewportStart = [Math]::Max(0, $this._viewportStart)
        $maxViewport = [Math]::Max(0, $this.Text.Length - $availableWidth + 1)
        $this._viewportStart = [Math]::Min($this._viewportStart, $maxViewport)
    }
    
    [int] GetInputWidth() {
        $width = $this.Width
        
        # Account for border
        if ($this.ShowBorder) {
            $width -= 2
        }
        
        # Account for label in Field mode
        if ($this.Mode -eq [UnifiedInputMode]::Field -and $this.ShowLabel) {
            $width -= ($this.LabelWidth + 1)  # +1 for space between label and input
        }
        
        return [Math]::Max(1, $width)
    }
    
    # ═══════════════════════════════════════════════════════════════════════════════════════
    # RENDERING SYSTEM - Mode-specific rendering with consistent theming
    # ═══════════════════════════════════════════════════════════════════════════════════════
    
    [string] RenderContent() {
        $sb = Get-PooledStringBuilder 512
        
        try {
            # Render border if enabled
            if ($this.ShowBorder) {
                $borderColor = if ($this.IsFocused) { $this._colors.borderFocused } else { $this._colors.border }
                if (-not $this.IsValid) {
                    $borderColor = $this._colors.error
                }
                
                $borderStr = [BorderStyle]::RenderBorder(
                    $this.X, $this.Y, $this.Width, $this.Height + 2,  # +2 for border
                    $this.BorderType, $borderColor
                )
                [void]$sb.Append($borderStr)
            }
            
            # Render based on mode
            switch ($this.Mode) {
                ([UnifiedInputMode]::Field) {
                    $this.RenderFieldMode($sb)
                }
                default {
                    $this.RenderTextMode($sb)
                }
            }
            
            # Render validation message if present
            if (-not $this.IsValid -and $this.ValidationMessage) {
                $this.RenderValidationMessage($sb)
            }
            
            return $sb.ToString()
        }
        finally {
            Return-PooledStringBuilder $sb
        }
    }
    
    [void] RenderFieldMode([System.Text.StringBuilder]$sb) {
        # Field mode: Label + Input on same line (like DialogField)
        $contentX = if ($this.ShowBorder) { $this.X + 1 } else { $this.X }
        $contentY = if ($this.ShowBorder) { $this.Y + 1 } else { $this.Y }
        
        [void]$sb.Append([VT]::MoveTo($contentX, $contentY))
        
        if ($this.IsFocused -and $this.ShowLabel) {
            # REVERSE HIGHLIGHTING for label when focused (like DialogField)
            [void]$sb.Append($this._colors.focusReverseBg)
            [void]$sb.Append($this._colors.focusReverseText)
            $labelText = "$($this.Label):"
            [void]$sb.Append($labelText.PadRight($this.LabelWidth))
            
            # Space between label and input
            [void]$sb.Append([VT]::Reset())
            [void]$sb.Append(' ')
            
            # Input field with normal colors
            [void]$sb.Append($this._colors.text)
            $this.RenderInputField($sb, $contentX + $this.LabelWidth + 1, $contentY)
        } elseif ($this.ShowLabel) {
            # Unfocused label
            [void]$sb.Append($this._colors.label)
            $labelText = "$($this.Label):"
            [void]$sb.Append($labelText.PadRight($this.LabelWidth))
            [void]$sb.Append(' ')
            
            # Input field
            [void]$sb.Append($this._colors.text)
            $this.RenderInputField($sb, $contentX + $this.LabelWidth + 1, $contentY)
        } else {
            # No label
            $this.RenderInputField($sb, $contentX, $contentY)
        }
        
        [void]$sb.Append([VT]::Reset())
    }
    
    [void] RenderTextMode([System.Text.StringBuilder]$sb) {
        # Simple text input mode
        $contentX = if ($this.ShowBorder) { $this.X + 1 } else { $this.X }
        $contentY = if ($this.ShowBorder) { $this.Y + 1 } else { $this.Y }
        
        $this.RenderInputField($sb, $contentX, $contentY)
    }
    
    [void] RenderInputField([System.Text.StringBuilder]$sb, [int]$x, [int]$y) {
        [void]$sb.Append([VT]::MoveTo($x, $y))
        
        # Background color
        if ($this._colors.background) {
            [void]$sb.Append($this._colors.background)
        }
        
        # Determine display text
        $displayText = ""
        $cursorDisplayPos = 0
        
        if ($this.Text.Length -gt 0) {
            if ($this.Mode -eq [UnifiedInputMode]::Password) {
                $displayText = '•' * $this.Text.Length
            } else {
                $displayText = $this.Text
            }
            
            # Apply viewport
            $inputWidth = $this.GetInputWidth()
            if ($displayText.Length -gt $inputWidth) {
                $endPos = [Math]::Min($this._viewportStart + $inputWidth, $displayText.Length)
                $displayText = $displayText.Substring($this._viewportStart, $endPos - $this._viewportStart)
            }
            
            $cursorDisplayPos = $this._cursorPosition - $this._viewportStart
        } elseif (-not $this.IsFocused -and $this.Placeholder) {
            # Show placeholder when not focused and no text
            [void]$sb.Append($this._colors.placeholder)
            $displayText = $this.Placeholder
            $inputWidth = $this.GetInputWidth()
            if ($displayText.Length -gt $inputWidth) {
                $displayText = $displayText.Substring(0, $inputWidth)
            }
        }
        
        # Render text
        [void]$sb.Append($displayText)
        
        # Render cursor if focused and not readonly
        if ($this.IsFocused -and -not $this.ReadOnly -and $this._showCursor) {
            $cursorX = $x + $cursorDisplayPos
            [void]$sb.Append([VT]::MoveTo($cursorX, $y))
            [void]$sb.Append($this._colors.cursor)
            
            if ($cursorDisplayPos -lt $displayText.Length) {
                # Cursor over character - use reverse
                [void]$sb.Append([VT]::Reverse())
                [void]$sb.Append($displayText[$cursorDisplayPos])
                [void]$sb.Append([VT]::Reset())
            } else {
                # Cursor at end - show block cursor
                [void]$sb.Append('█')
            }
        }
        
        [void]$sb.Append([VT]::Reset())
    }
    
    [void] RenderValidationMessage([System.Text.StringBuilder]$sb) {
        # Render validation message below the input
        $messageY = $this.Y + $this.Height + 1
        if ($this.ShowBorder) {
            $messageY += 2
        }
        
        [void]$sb.Append([VT]::MoveTo($this.X, $messageY))
        [void]$sb.Append($this._colors.error)
        [void]$sb.Append("⚠ $($this.ValidationMessage)")
        [void]$sb.Append([VT]::Reset())
    }
    
    # ═══════════════════════════════════════════════════════════════════════════════════════
    # INPUT HANDLING - Consistent text editing across all modes
    # ═══════════════════════════════════════════════════════════════════════════════════════
    
    [bool] OnHandleInput([System.ConsoleKeyInfo]$key) {
        if ($this.ReadOnly) {
            # Read-only mode - only handle navigation
            switch ($key.Key) {
                ([System.ConsoleKey]::Enter) {
                    if ($this.OnEnter) { & $this.OnEnter }
                    return $true
                }
                ([System.ConsoleKey]::Escape) {
                    if ($this.OnEscape) { & $this.OnEscape }
                    return $true
                }
            }
            return $false
        }
        
        $handled = $true
        
        switch ($key.Key) {
            ([System.ConsoleKey]::LeftArrow) {
                if ($this._cursorPosition -gt 0) {
                    $this._cursorPosition--
                    $this.UpdateViewport()
                    $this.Invalidate()
                }
            }
            ([System.ConsoleKey]::RightArrow) {
                if ($this._cursorPosition -lt $this.Text.Length) {
                    $this._cursorPosition++
                    $this.UpdateViewport()
                    $this.Invalidate()
                }
            }
            ([System.ConsoleKey]::Home) {
                $this._cursorPosition = 0
                $this.UpdateViewport()
                $this.Invalidate()
            }
            ([System.ConsoleKey]::End) {
                $this._cursorPosition = $this.Text.Length
                $this.UpdateViewport()
                $this.Invalidate()
            }
            ([System.ConsoleKey]::Backspace) {
                if ($this._cursorPosition -gt 0) {
                    $newText = $this.Text.Substring(0, $this._cursorPosition - 1) + $this.Text.Substring($this._cursorPosition)
                    $this._cursorPosition--
                    $this.SetText($newText)
                }
            }
            ([System.ConsoleKey]::Delete) {
                if ($this._cursorPosition -lt $this.Text.Length) {
                    $newText = $this.Text.Substring(0, $this._cursorPosition) + $this.Text.Substring($this._cursorPosition + 1)
                    $this.SetText($newText)
                }
            }
            ([System.ConsoleKey]::Enter) {
                if ($this.OnEnter) { & $this.OnEnter }
            }
            ([System.ConsoleKey]::Escape) {
                if ($this.OnEscape) { & $this.OnEscape }
            }
            default {
                # Handle character input
                if (-not [char]::IsControl($key.KeyChar)) {
                    $this.InsertCharacter($key.KeyChar)
                } else {
                    $handled = $false
                }
            }
        }
        
        return $handled
    }
    
    [void] InsertCharacter([char]$char) {
        # Insert character at cursor position
        $newText = $this.Text.Substring(0, $this._cursorPosition) + $char + $this.Text.Substring($this._cursorPosition)
        $this._cursorPosition++
        $this.SetText($newText)
    }
    
    # ═══════════════════════════════════════════════════════════════════════════════════════
    # FOCUS MANAGEMENT - Proper cursor control
    # ═══════════════════════════════════════════════════════════════════════════════════════
    
    [void] OnFocusGained() {
        ([FocusableComponent]$this).OnFocusGained()
        if ($this._cursorTimer) {
            $this._cursorTimer.Start()
        }
        $this._showCursor = $true
        $this.Invalidate()
    }
    
    [void] OnFocusLost() {
        ([FocusableComponent]$this).OnFocusLost()
        if ($this._cursorTimer) {
            $this._cursorTimer.Stop()
        }
        $this._showCursor = $false
        $this.ValidateInput()  # Final validation when losing focus
        $this.Invalidate()
    }
    
    # ═══════════════════════════════════════════════════════════════════════════════════════
    # PUBLIC API - Simple, consistent methods
    # ═══════════════════════════════════════════════════════════════════════════════════════
    
    [void] Clear() {
        $this.SetText("")
        $this._cursorPosition = 0
        $this._viewportStart = 0
    }
    
    [void] SelectAll() {
        $this._cursorPosition = $this.Text.Length
        $this._viewportStart = 0
        $this.UpdateViewport()
        $this.Invalidate()
    }
    
    [void] SetLabel([string]$label) {
        if ($this.Label -ne $label) {
            $this.Label = $label
            $this.ShowLabel = $label.Length -gt 0
            $this.Invalidate()
        }
    }
    
    [void] SetReadOnly([bool]$readOnly) {
        if ($this.ReadOnly -ne $readOnly) {
            $this.ReadOnly = $readOnly
            if ($readOnly -and $this._cursorTimer) {
                $this._cursorTimer.Stop()
                $this._showCursor = $false
            }
            $this.Invalidate()
        }
    }
    
    # ═══════════════════════════════════════════════════════════════════════════════════════
    # CLEANUP - Proper resource disposal
    # ═══════════════════════════════════════════════════════════════════════════════════════
    
    [void] Dispose() {
        if ($this._cursorTimer) {
            $this._cursorTimer.Stop()
            $this._cursorTimer.Dispose()
            $this._cursorTimer = $null
        }
        ([FocusableComponent]$this).Dispose()
    }
}

# Supporting enum
enum UnifiedInputMode {
    Text = 0      # Basic text input (replaces MinimalTextBox)
    Field = 1     # Label + input (replaces DialogField)
    Password = 2  # Password input with masking
    Number = 3    # Numeric input with validation
}