# ThemeEditorDialog.ps1 - Live theme editing dialog

class ThemeEditorDialog : BaseDialog {
    [MinimalListBox]$ColorList
    [MinimalTextBox]$PreviewBox
    [EnhancedThemeManager]$ThemeManager
    [hashtable]$CurrentTheme = @{}
    [string]$SelectedColorKey = ""
    
    # RGB sliders
    [int]$RedValue = 0
    [int]$GreenValue = 0
    [int]$BlueValue = 0
    
    ThemeEditorDialog() : base("Theme Editor") {
        $this.DialogWidth = 80
        $this.DialogHeight = 30
        $this.PrimaryButtonText = "Apply"
        $this.SecondaryButtonText = "Cancel"
    }
    
    [void] InitializeContent() {
        $this.ThemeManager = $this.ServiceContainer.GetService('ThemeManager')
        
        # Enable live editing
        if ($this.ThemeManager -is [EnhancedThemeManager]) {
            $this.ThemeManager.EnableLiveEdit()
        }
        
        # Create color list
        $this.ColorList = [MinimalListBox]::new()
        $this.ColorList.Title = "Theme Colors"
        $this.ColorList.ShowBorder = $true
        $this.ColorList.Height = 20
        $this.ColorList.OnSelectionChanged = {
            $this.UpdateColorSelection()
        }.GetNewClosure()
        
        $this.AddContentControl($this.ColorList)
        
        # Create preview box
        $this.PreviewBox = [MinimalTextBox]::new()
        $this.PreviewBox.Title = "Preview"
        $this.PreviewBox.ShowBorder = $true
        $this.PreviewBox.ReadOnly = $true
        $this.PreviewBox.MultiLine = $true
        $this.PreviewBox.Height = 10
        
        $this.AddContentControl($this.PreviewBox)
        
        # Load current theme colors
        $this.LoadThemeColors()
        
        # Configure primary button
        $dialog = $this
        $this.OnPrimary = {
            # Changes are already applied in live edit mode
            if ($global:Logger) {
                $global:Logger.Info("Theme changes applied")
            }
        }.GetNewClosure()
    }
    
    [void] LoadThemeColors() {
        $currentThemeName = $this.ThemeManager.GetCurrentTheme()
        $theme = $this.ThemeManager._themes[$currentThemeName]
        
        # Get semantic colors first
        $semanticColors = @()
        $componentColors = @()
        
        foreach ($key in $theme.Keys | Sort-Object) {
            if ($theme[$key] -is [array] -and $theme[$key].Count -eq 3) {
                $item = @{
                    Key = $key
                    RGB = $theme[$key]
                    IsSemantic = [ThemeSystem]::SemanticTokens.ContainsKey($key)
                }
                
                if ($item.IsSemantic) {
                    $semanticColors += $item
                } else {
                    $componentColors += $item
                }
            }
        }
        
        # Combine with semantic first
        $allColors = $semanticColors + $componentColors
        $this.ColorList.SetItems($allColors)
        
        # Custom renderer
        $this.ColorList.ItemRenderer = {
            param($item)
            $rgb = $item.RGB
            $preview = "█"
            $label = $item.Key.PadRight(30)
            
            # Create color preview
            $colorCode = [VT]::RGB($rgb[0], $rgb[1], $rgb[2])
            $prefix = if ($item.IsSemantic) { "◆ " } else { "  " }
            
            return "$prefix$colorCode$preview$preview [VT]::Reset() $label ($($rgb[0]),$($rgb[1]),$($rgb[2]))"
        }
    }
    
    [void] UpdateColorSelection() {
        $selected = $this.ColorList.GetSelectedItem()
        if (-not $selected) { return }
        
        $this.SelectedColorKey = $selected.Key
        $this.RedValue = $selected.RGB[0]
        $this.GreenValue = $selected.RGB[1]
        $this.BlueValue = $selected.RGB[2]
        
        $this.UpdatePreview()
    }
    
    [void] UpdatePreview() {
        $preview = [System.Text.StringBuilder]::new()
        
        # Show current color
        $preview.AppendLine("Selected: $($this.SelectedColorKey)")
        $preview.AppendLine("")
        $preview.AppendLine("RGB Values:")
        $preview.AppendLine("  Red:   $($this.RedValue)")
        $preview.AppendLine("  Green: $($this.GreenValue)")
        $preview.AppendLine("  Blue:  $($this.BlueValue)")
        $preview.AppendLine("")
        
        # Show color swatch
        $color = [VT]::RGB($this.RedValue, $this.GreenValue, $this.BlueValue)
        $bg = [VT]::RGBBG($this.RedValue, $this.GreenValue, $this.BlueValue)
        $preview.AppendLine("Preview:")
        $preview.AppendLine("  $color████████[VT]::Reset() Foreground")
        $preview.AppendLine("  $bg    [VT]::Reset() Background")
        
        $this.PreviewBox.Text = $preview.ToString()
    }
    
    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        # RGB adjustment shortcuts when color is selected
        if ($this.SelectedColorKey -and $this.ColorList.IsFocused) {
            $changed = $false
            
            switch ($key.Key) {
                ([System.ConsoleKey]::R) {
                    if ($key.Modifiers -eq [System.ConsoleModifiers]::Shift) {
                        $this.RedValue = [Math]::Min(255, $this.RedValue + 10)
                    } else {
                        $this.RedValue = [Math]::Max(0, $this.RedValue - 10)
                    }
                    $changed = $true
                }
                ([System.ConsoleKey]::G) {
                    if ($key.Modifiers -eq [System.ConsoleModifiers]::Shift) {
                        $this.GreenValue = [Math]::Min(255, $this.GreenValue + 10)
                    } else {
                        $this.GreenValue = [Math]::Max(0, $this.GreenValue - 10)
                    }
                    $changed = $true
                }
                ([System.ConsoleKey]::B) {
                    if ($key.Modifiers -eq [System.ConsoleModifiers]::Shift) {
                        $this.BlueValue = [Math]::Min(255, $this.BlueValue + 10)
                    } else {
                        $this.BlueValue = [Math]::Max(0, $this.BlueValue - 10)
                    }
                    $changed = $true
                }
            }
            
            if ($changed) {
                $this.ApplyColorChange()
                return $true
            }
        }
        
        # Copy color code
        if ($key.Key -eq [System.ConsoleKey]::C -and $key.Modifiers -eq [System.ConsoleModifiers]::Control) {
            if ($this.SelectedColorKey) {
                $code = "@($($this.RedValue), $($this.GreenValue), $($this.BlueValue))"
                Set-Clipboard -Value $code
                
                $toastService = $this.ServiceContainer.GetService('ToastService')
                if ($toastService) {
                    $toastService.ShowToast("Color code copied!", [ToastType]::Success)
                }
                return $true
            }
        }
        
        return ([BaseDialog]$this).HandleInput($key)
    }
    
    [void] ApplyColorChange() {
        if (-not $this.SelectedColorKey) { return }
        
        $newRgb = @($this.RedValue, $this.GreenValue, $this.BlueValue)
        
        # Apply to live theme
        if ($this.ThemeManager -is [EnhancedThemeManager]) {
            $this.ThemeManager.SetLiveColor($this.SelectedColorKey, $newRgb)
        }
        
        # Update list item
        $selected = $this.ColorList.GetSelectedItem()
        if ($selected) {
            $selected.RGB = $newRgb
        }
        
        # Refresh display
        $this.ColorList.Invalidate()
        $this.UpdatePreview()
    }
    
    [void] PositionContentControls([int]$dialogX, [int]$dialogY) {
        $padding = 2
        
        # Position color list (left side)
        $listWidth = 50
        $this.ColorList.SetBounds(
            $dialogX + $padding,
            $dialogY + 2,
            $listWidth,
            18
        )
        
        # Position preview box (right side)
        $previewX = $dialogX + $padding + $listWidth + 2
        $previewWidth = $this.DialogWidth - $listWidth - ($padding * 2) - 2
        $this.PreviewBox.SetBounds(
            $previewX,
            $dialogY + 2,
            $previewWidth,
            10
        )
    }
    
    [string] OnRender() {
        $sb = Get-PooledStringBuilder 2048
        
        # Render base dialog
        $baseRender = ([BaseDialog]$this).OnRender()
        $sb.Append($baseRender)
        
        # Add help text
        $helpY = $this._dialogBounds.Y + $this.DialogHeight - 6
        $helpX = $this._dialogBounds.X + $this.DialogWidth - 30
        
        $sb.Append([VT]::MoveTo($helpX, $helpY))
        $sb.Append($this.Theme.GetColor("disabled"))
        $sb.Append("R/G/B: -10  Shift+R/G/B: +10")
        
        $sb.Append([VT]::MoveTo($helpX, $helpY + 1))
        $sb.Append("Ctrl+C: Copy color code")
        
        # Show accessibility info if semantic color selected
        if ($this.SelectedColorKey -and [ThemeSystem]::SemanticTokens.ContainsKey($this.SelectedColorKey)) {
            $sb.Append([VT]::MoveTo($this._dialogBounds.X + 2, $helpY + 3))
            $sb.Append($this.Theme.GetColor("info"))
            $sb.Append("◆ Semantic color - affects multiple components")
        }
        
        $sb.Append([VT]::Reset())
        
        $result = $sb.ToString()
        Return-PooledStringBuilder $sb
        return $result
    }
}