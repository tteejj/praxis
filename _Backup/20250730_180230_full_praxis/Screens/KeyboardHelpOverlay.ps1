# KeyboardHelpOverlay.ps1 - Keyboard shortcut help overlay

class KeyboardHelpOverlay : Screen {
    hidden [string]$Context = ""
    hidden [MinimalListBox]$CategoryList
    hidden [MinimalListBox]$ShortcutList
    hidden [hashtable]$ShortcutsByCategory = @{}
    hidden [hashtable]$CategorizedShortcuts = @{}
    
    KeyboardHelpOverlay([string]$context = "") : base() {
        $this.Title = "Keyboard Shortcuts"
        $this.Context = $context
        $this.DrawBackground = $true
    }
    
    [void] OnInitialize() {
        ([Screen]$this).OnInitialize()
        
        # Get services
        $shortcutManager = $this.ServiceContainer.GetService('ShortcutManager')
        $themeManager = $this.ServiceContainer.GetService('ThemeManager')
        
        if ($themeManager) {
            # Set overlay background using theme
            $overlayColor = $themeManager.GetBgColor('surface.background')
            $this.SetBackgroundColor($overlayColor)
        }
        
        # Create category list (left panel)
        $this.CategoryList = [MinimalListBox]::new()
        $this.CategoryList.Title = "Categories"
        $this.CategoryList.Initialize($this.ServiceContainer)
        
        # Create shortcut list (right panel)
        $this.ShortcutList = [MinimalListBox]::new()
        $this.ShortcutList.Title = "Shortcuts"
        $this.ShortcutList.SelectionEnabled = $false
        $this.ShortcutList.Initialize($this.ServiceContainer)
        
        # Load shortcuts
        $this.LoadShortcuts()
        
        # Set up category selection handler
        $this.CategoryList.OnSelectionChanged = {
            $this.UpdateShortcutDisplay()
        }.GetNewClosure()
        
        # Add children
        $this.AddChild($this.CategoryList)
        $this.AddChild($this.ShortcutList)
        
        # Register shortcuts for this overlay
        $this.RegisterShortcuts()
        
        # Initial display
        $this.UpdateShortcutDisplay()
    }
    
    [void] RegisterShortcuts() {
        $shortcutManager = $this.ServiceContainer.GetService('ShortcutManager')
        if (-not $shortcutManager) { return }
        
        # ESC or F1 to close
        $shortcutManager.RegisterShortcut(@{
            Id = "help.close"
            Name = "Close Help"
            Description = "Close help overlay"
            Key = [System.ConsoleKey]::Escape
            # Scope = # [ShortcutScope]::Screen
            ScreenType = "KeyboardHelpOverlay"
            Priority = 100
            Action = { 
                if ($global:ScreenManager) {
                    $global:ScreenManager.Pop()
                }
            }
        })
        
        $shortcutManager.RegisterShortcut(@{
            Id = "help.close_f1"
            Name = "Close Help"
            Description = "Close help overlay"
            Key = [System.ConsoleKey]::F1
            # Scope = # [ShortcutScope]::Screen
            ScreenType = "KeyboardHelpOverlay"
            Priority = 100
            Action = { 
                if ($global:ScreenManager) {
                    $global:ScreenManager.Pop()
                }
            }
        })
    }
    
    [void] OnBoundsChanged() {
        ([Screen]$this).OnBoundsChanged()
        
        if (-not $this.CategoryList -or -not $this.ShortcutList) { return }
        
        # Calculate modal dimensions
        $modalWidth = [Math]::Min(80, $this.Width - 10)
        $modalHeight = [Math]::Min(30, $this.Height - 6)
        $modalX = [Math]::Floor(($this.Width - $modalWidth) / 2)
        $modalY = [Math]::Floor(($this.Height - $modalHeight) / 2)
        
        # Title and border take up space
        $contentHeight = $modalHeight - 4
        $categoryWidth = [Math]::Floor($modalWidth * 0.3)
        $shortcutWidth = $modalWidth - $categoryWidth - 2
        
        # Position category list (left side)
        $this.CategoryList.SetBounds(
            $this.X + $modalX + 1,
            $this.Y + $modalY + 2,
            $categoryWidth,
            $contentHeight
        )
        
        # Position shortcut list (right side)
        $this.ShortcutList.SetBounds(
            $this.X + $modalX + $categoryWidth + 2,
            $this.Y + $modalY + 2,
            $shortcutWidth,
            $contentHeight
        )
    }
    
    [void] LoadShortcuts() {
        $shortcutManager = $this.ServiceContainer.GetService('ShortcutManager')
        if (-not $shortcutManager) { return }
        
        # Get all shortcuts
        $allShortcuts = $shortcutManager.GetAllShortcuts()
        
        # Clear existing data
        $this.ShortcutsByCategory.Clear()
        $this.CategorizedShortcuts.Clear()
        
        # Categorize shortcuts
        foreach ($shortcut in $allShortcuts) {
            if (-not $shortcut.Enabled) { continue }
            
            # $category = switch ($shortcut.Scope) {
            #     ([ShortcutScope]::Global) { "Global" }
            #     ([ShortcutScope]::Screen) { 
            #         if ($shortcut.ScreenType) {
            #             $shortcut.ScreenType -replace 'Screen$', ''
            #         } else {
            #             "Screen"
            #         }
            #     }
            #     default { "Other" }
            # }
            
            # Simplified category assignment since ShortcutManager is deprecated
            $category = "Deprecated"
            
            if (-not $this.ShortcutsByCategory.ContainsKey($category)) {
                $this.ShortcutsByCategory[$category] = @()
            }
            
            $this.ShortcutsByCategory[$category] += @{
                Key = $shortcut.GetDisplayText()
                Name = $shortcut.Name
                Description = $shortcut.Description
            }
        }
        
        # Create category items
        $categories = @("Global") + ($this.ShortcutsByCategory.Keys | Where-Object { $_ -ne "Global" } | Sort-Object)
        $categoryItems = $categories | ForEach-Object { 
            "$_ ($($this.ShortcutsByCategory[$_].Count))"
        }
        
        $this.CategoryList.SetItems($categoryItems)
        
        # Store the actual category names for lookup
        $this.CategorizedShortcuts = $this.ShortcutsByCategory
    }
    
    [void] UpdateShortcutDisplay() {
        if (-not $this.CategoryList -or -not $this.ShortcutList) { return }
        
        $selectedItem = $this.CategoryList.GetSelectedItem()
        if (-not $selectedItem) { 
            $this.ShortcutList.SetItems(@())
            return 
        }
        
        # Extract category name (remove count)
        $categoryName = $selectedItem -replace ' \(\d+\)$', ''
        
        if ($this.CategorizedShortcuts.ContainsKey($categoryName)) {
            $shortcuts = $this.CategorizedShortcuts[$categoryName]
            
            # Format shortcuts for display
            $items = $shortcuts | ForEach-Object {
                $key = $_.Key.PadRight(15)
                "$key $($_.Name)"
            }
            
            $this.ShortcutList.SetItems($items)
        } else {
            $this.ShortcutList.SetItems(@())
        }
    }
    
    [void] OnActivated() {
        ([Screen]$this).OnActivated()
        
        # Base Screen.OnActivated() already handles focusing first element
        # No additional focus logic needed - let the base implementation handle it
    }
    
    [string] OnRender() {
        $sb = [System.Text.StringBuilder]::new()
        
        # Render base screen (background)
        [void]$sb.Append(([Screen]$this).OnRender())
        
        # Calculate modal bounds
        $modalWidth = [Math]::Min(80, $this.Width - 10)
        $modalHeight = [Math]::Min(30, $this.Height - 6)
        $modalX = [Math]::Floor(($this.Width - $modalWidth) / 2) + $this.X
        $modalY = [Math]::Floor(($this.Height - $modalHeight) / 2) + $this.Y
        
        # Draw modal box
        if ($this.Theme) {
            $borderColor = $this.Theme.GetFgColor('border')
            $bgColor = $this.Theme.GetBgColor('surface.background')
            $titleColor = $this.Theme.GetFgColor('primary')
            
            # Draw background
            for ($y = 0; $y -lt $modalHeight; $y++) {
                [void]$sb.Append([VT]::MoveTo($modalX, $modalY + $y))
                [void]$sb.Append($bgColor)
                [void]$sb.Append(' ' * $modalWidth)
            }
            
            # Draw border
            [void]$sb.Append($borderColor)
            [void]$sb.Append([BorderStyle]::DrawBorder(
                [BorderType]::Rounded,
                $modalX,
                $modalY,
                $modalWidth,
                $modalHeight
            ))
            
            # Draw title
            $title = " $($this.Title) "
            if ($this.Context) {
                $title = " $($this.Title) - $($this.Context) "
            }
            $titleX = $modalX + [Math]::Floor(($modalWidth - $title.Length) / 2)
            [void]$sb.Append([VT]::MoveTo($titleX, $modalY))
            [void]$sb.Append($titleColor)
            [void]$sb.Append($title)
            
            # Draw help text at bottom
            $helpText = " ESC/F1: Close "
            $helpX = $modalX + $modalWidth - $helpText.Length - 2
            [void]$sb.Append([VT]::MoveTo($helpX, $modalY + $modalHeight - 1))
            [void]$sb.Append($borderColor)
            [void]$sb.Append($helpText)
            
            [void]$sb.Append([VT]::Reset())
        }
        
        return $sb.ToString()
    }
}

# Helper class for easy access
class HelpManager {
    static [void] ShowHelp([string]$context = "") {
        $help = [KeyboardHelpOverlay]::new($context)
        if ($global:ScreenManager) {
            $global:ScreenManager.Push($help)
        }
    }
}