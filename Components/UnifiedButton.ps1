# UnifiedButton.ps1 - The ONE button component with consistent theming and behavior
# Enhances MinimalButton with proper theme integration and unified API

class UnifiedButton : FocusableComponent {
    # BUTTON PROPERTIES
    [string]$Text = "Button"
    [scriptblock]$OnClick = {}
    [bool]$IsDefault = $false
    [bool]$IsEnabled = $true
    [int]$Padding = 1  # Horizontal padding inside button
    
    # VISUAL PROPERTIES
    [bool]$ShowBorder = $true
    [BorderType]$BorderType = [BorderType]::Rounded
    [UnifiedButtonStyle]$Style = [UnifiedButtonStyle]::Normal  # Normal, Primary, Secondary
    
    # INTERNAL STATE
    hidden [bool]$_isPressed = $false
    
    # THEME COLORS - Cached once, consistent everywhere
    hidden [hashtable]$_colors = @{}
    hidden [ThemeManager]$Theme
    
    UnifiedButton() : base() {
        $this.Height = 3  # Height includes border
        $this.IsFocusable = $true
        $this.FocusStyle = 'minimal'
    }
    
    UnifiedButton([string]$text) : base() {
        $this.Text = $text
        $this.Height = 3
        $this.IsFocusable = $true
        $this.FocusStyle = 'minimal'
    }
    
    UnifiedButton([string]$text, [scriptblock]$onClick) : base() {
        $this.Text = $text
        $this.OnClick = $onClick
        $this.Height = 3
        $this.IsFocusable = $true
        $this.FocusStyle = 'minimal'
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
                # Normal state colors
                text = $this.Theme.GetColor('button.text')
                background = $this.Theme.GetBgColor('button.background')
                border = $this.Theme.GetColor('border.normal')
                
                # Hover state colors
                textHover = $this.Theme.GetColor('button.text')
                backgroundHover = $this.Theme.GetBgColor('button.background.hover')
                
                # Pressed state colors  
                textPressed = $this.Theme.GetColor('button.text')
                backgroundPressed = $this.Theme.GetBgColor('button.background.pressed')
                
                # Focused state colors - unified with other components
                textFocused = $this.Theme.GetColor('focus.reverse.text')
                backgroundFocused = $this.Theme.GetBgColor('focus.reverse.background')
                borderFocused = $this.Theme.GetColor('border.focused')
                
                # Disabled state colors
                textDisabled = $this.Theme.GetColor('text.disabled')
                backgroundDisabled = $this.Theme.GetBgColor('surface.elevated')
                borderDisabled = $this.Theme.GetColor('text.disabled')
                
                # Primary button colors (for IsDefault)
                primaryText = $this.Theme.GetColor('color.primary')
                primaryBorder = $this.Theme.GetColor('color.primary')
            }
        }
    }
    
    # ═══════════════════════════════════════════════════════════════════════════════════════
    # RENDERING SYSTEM - Consistent button appearance across all dialogs
    # ═══════════════════════════════════════════════════════════════════════════════════════
    
    [string] RenderContent() {
        $sb = Get-PooledStringBuilder 256
        
        try {
            # Determine button state colors
            $textColor = ""
            $bgColor = ""
            $borderColor = ""
            
            if (-not $this.IsEnabled) {
                # Disabled state
                $textColor = $this._colors.textDisabled
                $bgColor = $this._colors.backgroundDisabled
                $borderColor = $this._colors.borderDisabled
            } elseif ($this.IsFocused) {
                # Focused state - use reverse highlighting like other unified components
                $textColor = $this._colors.textFocused
                $bgColor = $this._colors.backgroundFocused
                $borderColor = $this._colors.borderFocused
            } elseif ($this._isPressed) {
                # Pressed state
                $textColor = $this._colors.textPressed
                $bgColor = $this._colors.backgroundPressed
                $borderColor = $this._colors.border
            } else {
                # Normal state
                $textColor = $this._colors.text
                $bgColor = $this._colors.background
                $borderColor = $this._colors.border
                
                # Primary button styling
                if ($this.IsDefault -or $this.Style -eq [UnifiedButtonStyle]::Primary) {
                    $textColor = $this._colors.primaryText
                    $borderColor = $this._colors.primaryBorder
                }
            }
            
            # Render border
            if ($this.ShowBorder) {
                $borderStr = [BorderStyle]::RenderBorder(
                    $this.X, $this.Y, $this.Width, $this.Height,
                    $this.BorderType, $borderColor
                )
                [void]$sb.Append($borderStr)
            }
            
            # Render button content
            $contentX = if ($this.ShowBorder) { $this.X + 1 } else { $this.X }
            $contentY = if ($this.ShowBorder) { $this.Y + 1 } else { $this.Y }
            $contentWidth = if ($this.ShowBorder) { $this.Width - 2 } else { $this.Width }
            $contentHeight = if ($this.ShowBorder) { $this.Height - 2 } else { $this.Height }
            
            # Fill background
            if ($bgColor) {
                for ($row = 0; $row -lt $contentHeight; $row++) {
                    [void]$sb.Append([VT]::MoveTo($contentX, $contentY + $row))
                    [void]$sb.Append($bgColor)
                    [void]$sb.Append([StringCache]::GetSpaces($contentWidth))
                }
            }
            
            # Render button text (centered)
            $this.RenderButtonText($sb, $contentX, $contentY, $contentWidth, $contentHeight, $textColor, $bgColor)
            
            # Reset colors
            [void]$sb.Append([VT]::Reset())
            
            return $sb.ToString()
        }
        finally {
            Return-PooledStringBuilder $sb
        }
    }
    
    [void] RenderButtonText([System.Text.StringBuilder]$sb, [int]$x, [int]$y, [int]$width, [int]$height, [string]$textColor, [string]$bgColor) {
        # Prepare button text
        $buttonText = $this.Text
        if ($this.IsDefault) {
            $buttonText += " ●"  # Default button indicator
        }
        
        # Truncate if too long
        $maxWidth = $width - (2 * $this.Padding)
        if ($buttonText.Length -gt $maxWidth) {
            $buttonText = $buttonText.Substring(0, [Math]::Max(1, $maxWidth - 1)) + "…"
        }
        
        # Center text horizontally and vertically
        $textX = $x + [int](($width - $buttonText.Length) / 2)
        $textY = $y + [int]($height / 2)
        
        [void]$sb.Append([VT]::MoveTo($textX, $textY))
        if ($bgColor) {
            [void]$sb.Append($bgColor)
        }
        [void]$sb.Append($textColor)
        [void]$sb.Append($buttonText)
    }
    
    # ═══════════════════════════════════════════════════════════════════════════════════════
    # INPUT HANDLING - Consistent button interaction
    # ═══════════════════════════════════════════════════════════════════════════════════════
    
    [bool] OnHandleInput([System.ConsoleKeyInfo]$key) {
        if (-not $this.IsEnabled) {
            return $false
        }
        
        switch ($key.Key) {
            ([System.ConsoleKey]::Enter) {
                $this.Click()
                return $true
            }
            ([System.ConsoleKey]::Spacebar) {
                $this.Click()
                return $true
            }
        }
        
        return $false
    }
    
    [void] Click() {
        if (-not $this.IsEnabled) {
            return
        }
        
        # Visual feedback - brief pressed state
        $this._isPressed = $true
        $this.Invalidate()
        
        # Execute click handler
        if ($this.OnClick) {
            & $this.OnClick
        }
        
        # Reset pressed state after brief delay
        $button = $this
        $timer = [System.Timers.Timer]::new(100)  # 100ms press effect
        $timer.AutoReset = $false
        $timer.add_Elapsed({
            $button._isPressed = $false
            $button.Invalidate()
            $timer.Dispose()
        })
        $timer.Start()
    }
    
    # ═══════════════════════════════════════════════════════════════════════════════════════
    # PUBLIC API - Simple, consistent methods
    # ═══════════════════════════════════════════════════════════════════════════════════════
    
    [void] SetText([string]$text) {
        if ($this.Text -ne $text) {
            $this.Text = $text
            $this.Invalidate()
        }
    }
    
    [void] SetEnabled([bool]$enabled) {
        if ($this.IsEnabled -ne $enabled) {
            $this.IsEnabled = $enabled
            $this.IsFocusable = $enabled  # Disabled buttons can't be focused
            $this.Invalidate()
        }
    }
    
    [void] SetDefault([bool]$isDefault) {
        if ($this.IsDefault -ne $isDefault) {
            $this.IsDefault = $isDefault
            $this.Invalidate()
        }
    }
    
    [void] SetStyle([UnifiedButtonStyle]$style) {
        if ($this.Style -ne $style) {
            $this.Style = $style
            $this.Invalidate()
        }
    }
    
    # ═══════════════════════════════════════════════════════════════════════════════════════
    # FOCUS MANAGEMENT - Consistent with other unified components
    # ═══════════════════════════════════════════════════════════════════════════════════════
    
    [void] OnFocusGained() {
        ([FocusableComponent]$this).OnFocusGained()
        $this.Invalidate()
    }
    
    [void] OnFocusLost() {
        ([FocusableComponent]$this).OnFocusLost()
        $this._isPressed = $false  # Clear pressed state when losing focus
        $this.Invalidate()
    }
}

# Supporting enum
enum UnifiedButtonStyle {
    Normal = 0    # Standard button
    Primary = 1   # Primary action button (same as IsDefault)
    Secondary = 2 # Secondary action button
}