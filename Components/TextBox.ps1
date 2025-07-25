# TextBox.ps1 - Fast text input component
# Adapted from AxiomPhoenix with string-based rendering

class TextBox : UIElement {
    [string]$Text = ""
    [string]$Placeholder = ""
    [int]$MaxLength = 100
    [int]$CursorPosition = 0
    [bool]$ShowBorder = $true
    [bool]$ShowCursor = $true
    [scriptblock]$OnChange = {}
    [scriptblock]$OnSubmit = {}
    
    hidden [int]$_scrollOffset = 0
    hidden [string]$_cachedRender = ""
    hidden [bool]$_needsRender = $true
    hidden [ThemeManager]$Theme
    hidden [hashtable]$_colors = @{}
    
    # Version-based change detection
    hidden [int]$_dataVersion = 0
    hidden [int]$_lastRenderedVersion = -1
    hidden [string]$_cachedVersionRender = ""
    
    TextBox() : base() {
        $this.IsFocusable = $true
        $this.Width = 20
        $this.Height = 3  # Border + content + border
    }
    
    [void] OnInitialize() {
        if ($this.ServiceContainer) {
            $this.Theme = $this.ServiceContainer.GetService("ThemeManager")
            if ($this.Theme) {
                $this.Theme.Subscribe({ $this.OnThemeChanged() })
                $this.OnThemeChanged()
            }
        }
    }
    
    [void] OnThemeChanged() {
        if ($this.Theme) {
            $this._colors = @{
                'input.focused.border' = $this.Theme.GetColor("input.focused.border")
                'input.border' = $this.Theme.GetColor("input.border")
                'input.background' = $this.Theme.GetBgColor("input.background")
                'input.foreground' = $this.Theme.GetColor("input.foreground")
                'input.placeholder' = $this.Theme.GetColor("input.placeholder")
            }
        }
        $this._dataVersion++  # Increment for theme change
        $this._needsRender = $true
        $this.Invalidate()
    }
    
    [string] OnRender() {
        if (-not $this._needsRender) {
            return $this._cachedRender
        }
        
        $sb = Get-PooledStringBuilder 512  # TextBox typically needs moderate capacity
        
        # Colors based on focus state
        $borderColor = if ($this.IsFocused) {
            $this._colors['input.focused.border']
        } else {
            $this._colors['input.border']
        }
        $bgColor = $this._colors['input.background']
        $fgColor = $this._colors['input.foreground']
        $placeholderColor = $this._colors['input.placeholder']
        
        # Content area
        $contentY = $this.Y + 1
        $contentStartX = $this.X + 1
        $contentWidth = $this.Width - 2
        
        if ($this.ShowBorder) {
            # Top border
            $sb.Append([VT]::MoveTo($this.X, $this.Y))
            $sb.Append($borderColor)
            $sb.Append([VT]::TL() + [StringCache]::GetVTHorizontal($this.Width - 2) + [VT]::TR())
            
            # Middle line with content
            $sb.Append([VT]::MoveTo($this.X, $contentY))
            $sb.Append([VT]::V())
            
            # Clear content area
            $sb.Append($bgColor)
            $sb.Append([StringCache]::GetSpaces($contentWidth))
            
            # Right border
            $sb.Append([VT]::MoveTo($this.X + $this.Width - 1, $contentY))
            $sb.Append($borderColor)
            $sb.Append([VT]::V())
            
            # Bottom border
            $sb.Append([VT]::MoveTo($this.X, $this.Y + 2))
            $sb.Append([VT]::BL() + [StringCache]::GetVTHorizontal($this.Width - 2) + [VT]::BR())
        } else {
            # Just clear the content area
            $sb.Append([VT]::MoveTo($this.X, $this.Y))
            $sb.Append($bgColor)
            $sb.Append([StringCache]::GetSpaces($this.Width))
            $contentY = $this.Y
            $contentStartX = $this.X
            $contentWidth = $this.Width
        }
        
        # Render text or placeholder
        $sb.Append([VT]::MoveTo($contentStartX, $contentY))
        
        if ($this.Text.Length -eq 0 -and -not [string]::IsNullOrEmpty($this.Placeholder)) {
            # Show placeholder
            $sb.Append($placeholderColor)
            $placeholderText = if ($this.Placeholder.Length -gt $contentWidth) {
                $this.Placeholder.Substring(0, $contentWidth)
            } else {
                $this.Placeholder
            }
            $sb.Append($placeholderText)
        } else {
            # Calculate scroll offset to keep cursor in view
            if ($this.CursorPosition -lt $this._scrollOffset) {
                $this._scrollOffset = $this.CursorPosition
            } elseif ($this.CursorPosition -ge ($this._scrollOffset + $contentWidth)) {
                $this._scrollOffset = $this.CursorPosition - $contentWidth + 1
            }
            
            # Draw visible portion of text
            $sb.Append($fgColor)
            if ($this.Text.Length -gt $this._scrollOffset) {
                $len = [Math]::Min($contentWidth, $this.Text.Length - $this._scrollOffset)
                $visibleText = $this.Text.Substring($this._scrollOffset, $len)
                $sb.Append($visibleText)
            }
            
            # Draw cursor if focused
            if ($this.IsFocused -and $this.ShowCursor) {
                $cursorScreenPos = $this.CursorPosition - $this._scrollOffset
                if ($cursorScreenPos -ge 0 -and $cursorScreenPos -lt $contentWidth) {
                    $cursorX = $contentStartX + $cursorScreenPos
                    $sb.Append([VT]::MoveTo($cursorX, $contentY))
                    
                    # Reverse video for cursor
                    $charUnderCursor = if ($this.CursorPosition -lt $this.Text.Length) {
                        $this.Text[$this.CursorPosition]
                    } else {
                        ' '
                    }
                    
                    $sb.Append($bgColor)  # Swap colors for cursor
                    if ($this._colors['input.foreground']) {
                        # Create a background color from foreground color
                        $sb.Append("`e[48;2;255;255;255m")  # White background for cursor
                    }
                    $sb.Append($charUnderCursor)
                }
            }
        }
        
        $sb.Append([VT]::Reset())
        
        $this._cachedRender = $sb.ToString()
        Return-PooledStringBuilder $sb  # Return to pool for reuse
        $this._needsRender = $false
        return $this._cachedRender
    }
    
    [void] OnGotFocus() {
        $this.ShowCursor = $true
        $this._dataVersion++  # Increment for focus change
        $this._needsRender = $true
        $this.Invalidate()
        if ($global:Logger) {
            $global:Logger.Debug("TextBox.OnGotFocus: ShowCursor=$($this.ShowCursor)")
        }
    }
    
    [void] OnLostFocus() {
        $this.ShowCursor = $false
        $this._dataVersion++  # Increment for focus change
        $this._needsRender = $true
        $this.Invalidate()
        if ($global:Logger) {
            $global:Logger.Debug("TextBox.OnLostFocus: ShowCursor=$($this.ShowCursor)")
        }
    }
    
    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        try {
            $handled = $true
            $oldText = $this.Text
            
            switch ($key.Key) {
            ([System.ConsoleKey]::LeftArrow) {
                if ($this.CursorPosition -gt 0) {
                    $this.CursorPosition--
                    $this._dataVersion++  # Increment for cursor move
                }
            }
            ([System.ConsoleKey]::RightArrow) {
                if ($this.CursorPosition -lt $this.Text.Length) {
                    $this.CursorPosition++
                    $this._dataVersion++  # Increment for cursor move
                }
            }
            ([System.ConsoleKey]::Home) {
                $this.CursorPosition = 0
                $this._dataVersion++  # Increment for cursor move
            }
            ([System.ConsoleKey]::End) {
                $this.CursorPosition = $this.Text.Length
                $this._dataVersion++  # Increment for cursor move
            }
            ([System.ConsoleKey]::Backspace) {
                if ($this.CursorPosition -gt 0) {
                    $this.Text = $this.Text.Remove($this.CursorPosition - 1, 1)
                    $this.CursorPosition--
                }
            }
            ([System.ConsoleKey]::Delete) {
                if ($this.CursorPosition -lt $this.Text.Length) {
                    $this.Text = $this.Text.Remove($this.CursorPosition, 1)
                }
            }
            ([System.ConsoleKey]::Enter) {
                try {
                    if ($this.OnSubmit) {
                        & $this.OnSubmit $this.Text
                    }
                } catch {
                    if ($global:Logger) {
                        $global:Logger.Error("TextBox.HandleInput: Error executing OnSubmit handler - $($_.Exception.Message)")
                    }
                }
            }
            ([System.ConsoleKey]::Tab) {
                # Don't handle Tab - let parent handle focus navigation
                $handled = $false
            }
            ([System.ConsoleKey]::Escape) {
                # Don't handle Escape - let parent handle it
                $handled = $false
            }
            default {
                if ($key.KeyChar -and -not [char]::IsControl($key.KeyChar)) {
                    if ($this.Text.Length -lt $this.MaxLength) {
                        $this.Text = $this.Text.Insert($this.CursorPosition, $key.KeyChar)
                        $this.CursorPosition++
                    }
                } else {
                    $handled = $false
                }
            }
        }
        
            if ($handled) {
                # Increment version if text was modified
                if ($oldText -ne $this.Text) {
                    $this._dataVersion++
                }
                
                # Call OnChange if text was modified
                if ($oldText -ne $this.Text -and $this.OnChange) {
                    try {
                        & $this.OnChange $this.Text
                    } catch {
                        if ($global:Logger) {
                            $global:Logger.Error("TextBox.HandleInput: Error executing OnChange handler - $($_.Exception.Message)")
                        }
                    }
                }
                $this._needsRender = $true
                $this.Invalidate()
            }
            
            return $handled
        } catch {
            if ($global:Logger) {
                $global:Logger.Error("TextBox.HandleInput: Error processing input - $($_.Exception.Message)")
            }
            return $false
        }
    }
    
    # Helper methods
    [void] SetText([string]$text) {
        if ($text.Length -le $this.MaxLength) {
            $this.Text = $text
            $this.CursorPosition = $text.Length
            $this._dataVersion++  # Increment on text change
            $this._needsRender = $true
            $this.Invalidate()
        }
    }
    
    [void] Clear() {
        $this.Text = ""
        $this.CursorPosition = 0
        $this._scrollOffset = 0
        $this._needsRender = $true
        $this.Invalidate()
    }
}