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
            $this._normalColor = $this.Theme.GetColor('input.foreground')
            $this._placeholderColor = $this.Theme.GetColor('input.placeholder')
            $this._cursorColor = $this.Theme.GetColor('accent')
            if ($global:Logger) {
                $global:Logger.Debug("MinimalTextBox.UpdateColors: _cursorColor='$($this._cursorColor)', _normalColor='$($this._normalColor)'")
            }
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
        
        # Fill background if focused for better visibility
        if ($this.IsFocused) {
            $focusBg = $this.Theme.GetBgColor('focus.background')
            if ($this.Height -eq 1) {
                # Single line - just fill the line
                $sb.Append([VT]::MoveTo($this.X, $this.Y))
                $sb.Append($focusBg)
                $sb.Append([StringCache]::GetSpaces($this.Width))
            } else {
                # Multi-line - fill all lines
                for ($i = 0; $i -lt $this.Height; $i++) {
                    $sb.Append([VT]::MoveTo($this.X, $this.Y + $i))
                    $sb.Append($focusBg)
                    $sb.Append([StringCache]::GetSpaces($this.Width))
                }
            }
        }
        
        # Render border if enabled OR if focused
        if ($this.ShowBorder -or $this.IsFocused) {
            $borderColor = if ($this.IsFocused) { 
                $this.Theme.GetColor('border.focused') 
            } else { 
                $this.Theme.GetColor('border.normal') 
            }
            # Always show border when focused, even if ShowBorder is false
            if ($this.IsFocused -or $this.ShowBorder) {
                $sb.Append([BorderStyle]::RenderBorder($this.X, $this.Y, $this.Width, $this.Height, $this.BorderType, $borderColor))
            }
        }
        
        # Calculate text position and available width
        $textX = $this.X
        $textY = $this.Y
        $availableWidth = $this.Width
        
        if ($this.ShowBorder) {
            $textX += 1
            $textY += 1
            $availableWidth -= 2
        }
        
        if ($availableWidth -le 0) { $availableWidth = 28 }  # Default width
        
        # Position cursor for text
        $sb.Append([VT]::MoveTo($textX, $textY))
        
        # Determine what to display
        $displayText = ""
        if ($this.Text.Length -gt 0) {
            if ($this.IsPassword) {
                $displayText = '•' * $this.Text.Length
            } else {
                $displayText = $this.Text
            }
        } elseif (-not $this.IsFocused -and $this.Placeholder) {
            # Show placeholder when not focused and empty
            $sb.Append($this._placeholderColor)
            $displayText = $this.Placeholder
        }
        
        # Handle viewport for long text
        if ($displayText.Length -gt $availableWidth) {
            $displayText = $displayText.Substring($this._viewportStart, [Math]::Min($availableWidth, $displayText.Length - $this._viewportStart))
        }
        
        # Pad to width
        if ($displayText.Length -lt $availableWidth) {
            $displayText = $displayText.PadRight($availableWidth)
        }
        
        # Render text
        if ($this.Text.Length -eq 0 -and -not $this.IsFocused) {
            # Placeholder is already colored
        } else {
            $sb.Append($this._normalColor)
        }
        
        if ($this.IsFocused) {
            if ($global:Logger) {
                $global:Logger.Debug("MinimalTextBox.RenderContent: IsFocused=true, _showCursor=$($this._showCursor), cursorPos=$($this._cursorPosition), viewportStart=$($this._viewportStart)")
            }
            # Show text with cursor
            $cursorPos = $this._cursorPosition - $this._viewportStart
            if ($cursorPos -ge 0 -and $cursorPos -le $displayText.Length) {
                # Text before cursor
                if ($cursorPos -gt 0) {
                    $sb.Append($displayText.Substring(0, $cursorPos))
                }
                
                # Cursor
                if ($this._showCursor) {
                    $sb.Append($this._cursorColor)
                    if ($cursorPos -lt $displayText.Length) {
                        $sb.Append('▌')  # Minimal cursor on character
                    } else {
                        $sb.Append('▌')  # Cursor at end
                    }
                    $sb.Append($this._normalColor)
                    
                    # Text after cursor (skip the character under cursor)
                    if ($cursorPos -lt $displayText.Length - 1) {
                        $sb.Append($displayText.Substring($cursorPos + 1))
                    }
                } else {
                    # Text after cursor when not showing cursor
                    if ($cursorPos -lt $displayText.Length) {
                        $sb.Append($displayText.Substring($cursorPos))
                    }
                }
            } else {
                $sb.Append($displayText)
            }
        } else {
            $sb.Append($displayText)
        }
        
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