# MinimalTextBox.ps1 - Clean, minimalist text input component

class MinimalTextBox : FocusableComponent {
    [string]$Text = ""
    [string]$Placeholder = ""
    [int]$MaxLength = 0  # 0 = no limit
    [bool]$IsPassword = $false
    [bool]$ShowBorder = $true
    [BorderType]$BorderType = [BorderType]::Rounded
    [scriptblock]$OnTextChanged = {}
    [scriptblock]$OnEnter = {}
    
    # Cursor and viewport
    hidden [int]$_cursorPosition = 0
    hidden [int]$_viewportStart = 0
    hidden [bool]$_showCursor = $true
    
    # Cached colors
    hidden [string]$_normalColor = ""
    hidden [string]$_placeholderColor = ""
    hidden [string]$_cursorColor = ""
    hidden [string]$_focusReverseBg = ""
    hidden [string]$_focusReverseText = ""
    
    MinimalTextBox() : base() {
        $this.Height = 3  # 1 line + 2 for borders
        $this.FocusStyle = 'minimal'
    }
    
    [void] OnInitialize() {
        ([FocusableComponent]$this).OnInitialize()
        $this.UpdateColors()
        if ($this.Theme) {
            # Subscribe to theme changes via EventBus
            $eventBus = $this.ServiceContainer.GetService('EventBus')
            if ($eventBus) {
                $eventBus.Subscribe('theme.changed', {
                    param($sender, $eventData)
                    $this.UpdateColors()
                }.GetNewClosure())
            }
        }
    }
    
    [void] UpdateColors() {
        if ($this.Theme) {
            $this._normalColor = $this.Theme.GetColor('input.text')
            $this._placeholderColor = $this.Theme.GetColor('input.placeholder')
            $this._cursorColor = $this.Theme.GetColor('color.primary')
            $this._focusReverseBg = $this.Theme.GetBgColor('focus.reverse.background')
            $this._focusReverseText = $this.Theme.GetColor('focus.reverse.text')
        }
    }
    
    [void] SetText([string]$newText) {
        if ($this.MaxLength -gt 0 -and $newText.Length -gt $this.MaxLength) {
            $newText = $newText.Substring(0, $this.MaxLength)
        }
        
        if ($this.Text -ne $newText) {
            $this.Text = $newText
            $this._cursorPosition = $newText.Length
            $this.UpdateViewport()
            $this.Invalidate()
            
            if ($this.OnTextChanged) {
                & $this.OnTextChanged
            }
        }
    }
    
    [string] RenderContent() {
        $sb = Get-PooledStringBuilder 512
        
        # NEW FOCUS SYSTEM: Only show border when focused
        if ($this.IsFocused) {
            $borderColor = $this.Theme.GetColor('border.input.focused')
            $sb.Append([BorderStyle]::RenderBorder($this.X, $this.Y, $this.Width, $this.Height, $this.BorderType, $borderColor))
        }
        
        # Calculate text position and available width
        $textX = $this.X
        $textY = $this.Y
        $availableWidth = $this.Width
        
        # Adjust for border when focused
        if ($this.IsFocused) {
            $textX += 1
            $textY += 1
            $availableWidth -= 2
        }
        
        if ($availableWidth -le 0) { $availableWidth = 28 }  # Default width
        
        # Determine what to display
        $displayText = ""
        $useReverse = $this.IsFocused
        
        if ($this.Text.Length -gt 0) {
            if ($this.IsPassword) {
                $displayText = '•' * $this.Text.Length
            } else {
                $displayText = $this.Text
            }
        } elseif (-not $this.IsFocused -and $this.Placeholder) {
            # Show placeholder when not focused and empty
            $displayText = $this.Placeholder
            $useReverse = $false
        }
        
        # Handle viewport for long text
        if ($displayText.Length -gt $availableWidth) {
            $displayText = $displayText.Substring($this._viewportStart, [Math]::Min($availableWidth, $displayText.Length - $this._viewportStart))
        }
        
        # Fill entire text area with reverse background when focused
        if ($useReverse) {
            # Fill the entire text area with reverse background
            $sb.Append([VT]::MoveTo($textX, $textY))
            $sb.Append($this._focusReverseBg)
            $sb.Append($this._focusReverseText)
            
            # Pad text to full width for complete reverse highlighting
            $paddedText = $displayText.PadRight($availableWidth)
            
            if ($this._showCursor -and $this._cursorPosition -ge $this._viewportStart -and $this._cursorPosition -lt ($this._viewportStart + $availableWidth)) {
                # Show cursor within reverse text
                $cursorPos = $this._cursorPosition - $this._viewportStart
                
                # Text before cursor
                if ($cursorPos -gt 0) {
                    $sb.Append($paddedText.Substring(0, $cursorPos))
                }
                
                # Cursor character (use original theme colors for contrast)
                $sb.Append($this._cursorColor)
                if ($cursorPos -lt $paddedText.Length) {
                    $sb.Append('▌')
                } else {
                    $sb.Append('▌')
                }
                
                # Resume reverse colors and continue text
                $sb.Append($this._focusReverseText)
                if ($cursorPos -lt $paddedText.Length - 1) {
                    $sb.Append($paddedText.Substring($cursorPos + 1))
                }
            } else {
                # No cursor or cursor outside viewport
                $sb.Append($paddedText)
            }
        } else {
            # Unfocused - normal rendering
            $sb.Append([VT]::MoveTo($textX, $textY))
            
            if ($this.Text.Length -eq 0 -and $this.Placeholder) {
                # Placeholder text
                $sb.Append($this._placeholderColor)
                $sb.Append($displayText.PadRight($availableWidth))
            } else {
                # Normal text
                $sb.Append($this._normalColor)
                $sb.Append($displayText.PadRight($availableWidth))
            }
        }
        
        # Reset colors to prevent bleed
        $sb.Append([VT]::Reset())

        $result = $sb.ToString()
        Return-PooledStringBuilder $sb
        return $result
    }
    
    [void] UpdateViewport() {
        # Ensure cursor is visible
        if ($this._cursorPosition -lt $this._viewportStart) {
            $this._viewportStart = $this._cursorPosition
        } elseif ($this._cursorPosition -ge ($this._viewportStart + $this.Width)) {
            $this._viewportStart = $this._cursorPosition - $this.Width + 1
        }
        
        # Clamp viewport
        $this._viewportStart = [Math]::Max(0, $this._viewportStart)
    }
    
    [bool] OnHandleInput([System.ConsoleKeyInfo]$key) {
        $oldText = $this.Text
        
        switch ($key.Key) {
            ([System.ConsoleKey]::LeftArrow) {
                if ($this._cursorPosition -gt 0) {
                    $this._cursorPosition--
                    $this.UpdateViewport()
                    $this.Invalidate()
                }
                return $true
            }
            ([System.ConsoleKey]::RightArrow) {
                if ($this._cursorPosition -lt $this.Text.Length) {
                    $this._cursorPosition++
                    $this.UpdateViewport()
                    $this.Invalidate()
                }
                return $true
            }
            ([System.ConsoleKey]::Home) {
                $this._cursorPosition = 0
                $this._viewportStart = 0
                $this.Invalidate()
                return $true
            }
            ([System.ConsoleKey]::End) {
                $this._cursorPosition = $this.Text.Length
                $this.UpdateViewport()
                $this.Invalidate()
                return $true
            }
            ([System.ConsoleKey]::Backspace) {
                if ($this._cursorPosition -gt 0) {
                    $this.Text = $this.Text.Remove($this._cursorPosition - 1, 1)
                    $this._cursorPosition--
                    $this.UpdateViewport()
                    $this.Invalidate()
                    if ($this.OnTextChanged) { & $this.OnTextChanged }
                }
                return $true
            }
            ([System.ConsoleKey]::Delete) {
                if ($this._cursorPosition -lt $this.Text.Length) {
                    $this.Text = $this.Text.Remove($this._cursorPosition, 1)
                    $this.Invalidate()
                    if ($this.OnTextChanged) { & $this.OnTextChanged }
                }
                return $true
            }
            ([System.ConsoleKey]::Enter) {
                if ($this.OnEnter) {
                    & $this.OnEnter
                }
                return $true
            }
            default {
                # Handle character input
                if ($key.KeyChar -and $key.KeyChar -ge ' ') {
                    if ($this.MaxLength -eq 0 -or $this.Text.Length -lt $this.MaxLength) {
                        $this.Text = $this.Text.Insert($this._cursorPosition, $key.KeyChar)
                        $this._cursorPosition++
                        $this.UpdateViewport()
                        $this.Invalidate()
                        if ($this.OnTextChanged) { & $this.OnTextChanged }
                    }
                    return $true
                }
            }
        }
        
        return $false
    }
    
    [void] OnGotFocus() {
        $this._showCursor = $true
        ([FocusableComponent]$this).OnGotFocus()
    }
    
    [void] OnLostFocus() {
        $this._showCursor = $false
        ([FocusableComponent]$this).OnLostFocus()
    }
}