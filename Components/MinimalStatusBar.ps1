# MinimalStatusBar.ps1 - Clean, minimal status bar component

class MinimalStatusBar : UIElement {
    # Status bar sections
    [string]$LeftText = ""
    [string]$CenterText = ""
    [string]$RightText = ""
    
    # Styling
    [bool]$ShowSeparator = $true
    [string]$SeparatorChar = "│"
    [bool]$UseMinimalStyle = $true
    
    # Dynamic content providers
    [scriptblock]$LeftProvider = $null
    [scriptblock]$CenterProvider = $null
    [scriptblock]$RightProvider = $null
    
    # Shortcut hints
    [string[]]$ShortcutHints = @()
    [hashtable[]]$Hints = @()  # Array of @{Key="F1"; Action="Help"}
    
    # Colors
    hidden [hashtable]$_colors = @{}
    hidden [ThemeManager]$Theme
    hidden [KeyboardShortcutManager]$ShortcutManager
    
    MinimalStatusBar() : base() {
        $this.Height = 1  # Single line for minimalism
    }
    
    [void] OnInitialize() {
        $this.Theme = $this.ServiceContainer.GetService('ThemeManager')
        $this.ShortcutManager = $this.ServiceContainer.GetService('KeyboardShortcutManager')
        
        if ($this.Theme) {
            $this.UpdateColors()
            # Subscribe to theme changes via EventBus
            $eventBus = $this.ServiceContainer.GetService('EventBus')
            if ($eventBus) {
                $eventBus.Subscribe('theme.changed', {
                    param($sender, $eventData)
                    $this.UpdateColors()
                }.GetNewClosure())
            }
        }
        
        # Update dynamic content periodically
        if ($this.LeftProvider -or $this.CenterProvider -or $this.RightProvider) {
            $timer = [System.Timers.Timer]::new(1000)  # Update every second
            $timer.Elapsed.Add({
                $this.UpdateDynamicContent()
                $this.Invalidate()
            }.GetNewClosure())
            $timer.Start()
        }
    }
    
    [void] UpdateColors() {
        if ($this.Theme) {
            $this._colors = @{
                background = $this.Theme.GetBgColor('list.header.background')
                text = $this.Theme.GetColor('text.primary')
                separator = $this.Theme.GetColor('border.normal')
                accent = $this.Theme.GetColor('color.primary')
                dim = $this.Theme.GetColor('text.disabled')
            }
        }
    }
    
    [void] UpdateDynamicContent() {
        if ($this.LeftProvider) {
            $this.LeftText = & $this.LeftProvider
        }
        if ($this.CenterProvider) {
            $this.CenterText = & $this.CenterProvider
        }
        if ($this.RightProvider) {
            $this.RightText = & $this.RightProvider
        }
    }
    
    [void] SetHints([hashtable[]]$hints) {
        $this.Hints = $hints
        $this.Invalidate()
    }
    
    [string] OnRender() {
        $sb = Get-PooledStringBuilder 512
        
        # Move to position
        $sb.Append([VT]::MoveTo($this.X, $this.Y))
        
        # Background and clear line
        if ($this._colors.background -and -not $this.UseMinimalStyle) {
            $sb.Append($this._colors.background)
        }
        
        # Clear the entire line first to prevent artifacts
        # Note: StatusBar width already accounts for being inside the border
        $clearWidth = $this.Width
        $sb.Append(' ' * $clearWidth)
        $sb.Append([VT]::MoveTo($this.X, $this.Y))
        
        # Calculate sections
        $availableWidth = $this.Width
        $leftWidth = [Math]::Min($this.LeftText.Length, [int]($availableWidth * 0.3))
        $rightWidth = [Math]::Min($this.RightText.Length, [int]($availableWidth * 0.3))
        # Always account for 6 separator spaces (3 on each side)
        $separatorSpace = 6
        $centerWidth = $availableWidth - $leftWidth - $rightWidth - $separatorSpace
        
        # Ensure centerWidth is not negative
        if ($centerWidth -lt 0) {
            $centerWidth = 0
            # Recalculate left and right to fit
            $totalSideWidth = $availableWidth - $separatorSpace
            $leftWidth = [Math]::Min($leftWidth, [int]($totalSideWidth / 2))
            $rightWidth = [Math]::Min($rightWidth, $totalSideWidth - $leftWidth)
        }
        
        # Left section
        if ($this.LeftText) {
            $sb.Append($this._colors.text)
            $text = $this.TruncateText($this.LeftText, $leftWidth)
            $sb.Append($text.PadRight($leftWidth))
        } else {
            $sb.Append(' ' * $leftWidth)
        }
        
        # Left separator
        if ($this.ShowSeparator -and $this.CenterText) {
            $sb.Append(' ')
            $sb.Append($this._colors.separator)
            $sb.Append($this.SeparatorChar)
            $sb.Append(' ')
        } else {
            $sb.Append('   ')
        }
        
        # Center section or shortcuts
        if ($this.Hints.Count -gt 0) {
            # Build hints with proper spacing
            $renderedHints = ""
            $first = $true
            foreach ($hint in $this.Hints) {
                if (-not $first) {
                    $renderedHints += "  "
                }
                $first = $false
                $renderedHints += $hint.Key + ":" + $hint.Action
            }
            
            # Truncate if too long
            if ($renderedHints.Length -gt $centerWidth) {
                $renderedHints = $this.TruncateText($renderedHints, $centerWidth)
            }
            
            # Calculate padding for centering
            $actualLength = $renderedHints.Length
            $padding = [Math]::Max(0, [int](($centerWidth - $actualLength) / 2))
            $sb.Append(' ' * $padding)
            
            # Render with key highlighting
            $first = $true
            foreach ($hint in $this.Hints) {
                if (-not $first) {
                    $sb.Append("  ")
                }
                $first = $false
                $sb.Append($this._colors.accent)
                $sb.Append($hint.Key)
                $sb.Append($this._colors.text)
                $sb.Append(":")
                $sb.Append($hint.Action)
            }
            
            # Fill remaining space
            $remaining = $centerWidth - $actualLength - $padding
            if ($remaining -gt 0) {
                $sb.Append(' ' * $remaining)
            }
        } elseif ($this.ShortcutHints.Count -gt 0 -and $this.ShortcutManager) {
            # Render shortcuts instead of center text
            $hintsText = $this.ShortcutManager.RenderShortcutHints($this.ShortcutHints, $centerWidth)
            $sb.Append($hintsText)
            $sb.Append(' ' * [Math]::Max(0, $centerWidth - $hintsText.Length))
        } elseif ($this.CenterText) {
            $sb.Append($this._colors.accent)
            $text = $this.TruncateText($this.CenterText, $centerWidth)
            $padding = [Math]::Max(0, ($centerWidth - $text.Length) / 2)
            $sb.Append(' ' * [int]$padding)
            $sb.Append($text)
            $sb.Append(' ' * [int]($centerWidth - $text.Length - $padding))
        } else {
            $sb.Append(' ' * $centerWidth)
        }
        
        # Right separator
        if ($this.ShowSeparator -and $this.RightText) {
            $sb.Append(' ')
            $sb.Append($this._colors.separator)
            $sb.Append($this.SeparatorChar)
            $sb.Append(' ')
        } else {
            $sb.Append('   ')
        }
        
        # Right section
        if ($this.RightText) {
            $sb.Append($this._colors.dim)
            $text = $this.TruncateText($this.RightText, $rightWidth)
            $sb.Append($text.PadLeft($rightWidth))
        } else {
            $sb.Append(' ' * $rightWidth)
        }
        
        # No need to fill remaining space since we cleared the whole line at the beginning
        
        $result = $sb.ToString()
        Return-PooledStringBuilder $sb
        return $result
    }
    
    [string] TruncateText([string]$text, [int]$maxLength) {
        if ($text.Length -le $maxLength) {
            return $text
        }
        if ($maxLength -le 3) {
            return $text.Substring(0, $maxLength)
        }
        return $text.Substring(0, $maxLength - 1) + "…"
    }
    
    # Helper methods for common status items
    static [string] FormatTime() {
        return [DateTime]::Now.ToString("HH:mm")
    }
    
    static [string] FormatMemory() {
        $process = [System.Diagnostics.Process]::GetCurrentProcess()
        $mb = [Math]::Round($process.WorkingSet64 / 1MB, 1)
        return "Mem: ${mb}MB"
    }
    
    static [string] FormatFPS([double]$fps) {
        return "FPS: $([Math]::Round($fps, 1))"
    }
}

# Specialized status bars
class ScreenStatusBar : MinimalStatusBar {
    [Screen]$ParentScreen
    
    [void] Initialize([Screen]$screen) {
        $this.ParentScreen = $screen
        
        # Default providers
        $this.LeftProvider = {
            if ($this.ParentScreen) {
                return $this.ParentScreen.Name
            }
            return ""
        }.GetNewClosure()
        
        $this.RightProvider = {
            return [MinimalStatusBar]::FormatTime()
        }
        
        # Set common shortcuts
        $this.ShortcutHints = @(
            "F1:Help",
            "Tab:Navigate", 
            "Ctrl+P:Command",
            "Esc:Back"
        )
    }
}

class FileStatusBar : MinimalStatusBar {
    [string]$FilePath = ""
    [int]$Line = 1
    [int]$Column = 1
    [bool]$Modified = $false
    
    [void] OnInitialize() {
        ([MinimalStatusBar]$this).OnInitialize()
        
        $this.LeftProvider = {
            $name = if ($this.FilePath) {
                [System.IO.Path]::GetFileName($this.FilePath)
            } else { "untitled" }
            
            if ($this.Modified) { $name = "*$name" }
            return $name
        }.GetNewClosure()
        
        $this.CenterProvider = {
            return "Ln $($this.Line), Col $($this.Column)"
        }.GetNewClosure()
        
        $this.RightProvider = {
            $items = @()
            if ($this.FilePath) {
                $ext = [System.IO.Path]::GetExtension($this.FilePath)
                if ($ext) { $items += $ext.TrimStart('.').ToUpper() }
            }
            $items += [MinimalStatusBar]::FormatTime()
            return $items -join " │ "
        }.GetNewClosure()
    }
}