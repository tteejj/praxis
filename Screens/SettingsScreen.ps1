# SettingsScreen.ps1 - Settings management screen

class SettingsScreen : Screen {
    [ListBox]$CategoryList
    [DataGrid]$SettingsGrid
    [ConfigurationService]$ConfigService
    [hashtable[]]$CurrentSettings = @()
    [string]$CurrentCategory = ""
    [EventBus]$EventBus
    
    SettingsScreen() : base() {
        $this.Title = "Settings"
    }
    
    [void] OnInitialize() {
        # Get services
        $this.ConfigService = $global:ServiceContainer.GetService("ConfigurationService")
        if (-not $this.ConfigService) {
            $this.ConfigService = [ConfigurationService]::new()
            $global:ServiceContainer.Register("ConfigurationService", $this.ConfigService)
        }
        
        $this.EventBus = $global:ServiceContainer.GetService('EventBus')
        
        # Create category list
        $this.CategoryList = [ListBox]::new()
        $this.CategoryList.Title = "Categories"
        $this.CategoryList.ShowBorder = $true
        # Capture screen reference for callback
        $screen = $this
        $this.CategoryList.OnSelectionChanged = {
            $screen.LoadCategorySettings()
        }.GetNewClosure()
        $this.CategoryList.Initialize($global:ServiceContainer)
        $this.AddChild($this.CategoryList)
        
        # Create settings grid
        $this.SettingsGrid = [DataGrid]::new()
        $this.SettingsGrid.Title = "Settings"
        $this.SettingsGrid.ShowBorder = $true
        $this.SettingsGrid.Initialize($global:ServiceContainer)
        $this.SettingsGrid.SetColumns(@(
            @{Name="Setting"; Header="Setting"; Width=30},
            @{Name="Value"; Header="Value"; Width=20},
            @{Name="Type"; Header="Type"; Width=10}
        ))
        $this.AddChild($this.SettingsGrid)
        
        # Load categories
        $this.LoadCategories()
        
        # No more BindKey - use HandleScreenInput instead
    }
    
    # Handle screen-specific input
    [bool] HandleScreenInput([System.ConsoleKeyInfo]$key) {
        switch ($key.Key) {
            ([System.ConsoleKey]::LeftArrow) { 
                if ($this.SettingsGrid.IsFocused) {
                    $this.CategoryList.Focus()
                    return $true
                }
            }
            ([System.ConsoleKey]::RightArrow) { 
                if ($this.CategoryList.IsFocused) {
                    $this.SettingsGrid.Focus()
                    return $true
                }
            }
            ([System.ConsoleKey]::Enter) { 
                $this.EditSetting()
                return $true
            }
        }
        
        switch ($key.KeyChar) {
            'e' { $this.EditSetting(); return $true }
            'r' { $this.ResetCategory(); return $true }
            'R' { $this.ResetAll(); return $true }
            's' { $this.SaveSettings(); return $true }
        }
        
        return $false
    }
    
    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        # Let base class handle the input
        return ([Screen]$this).HandleInput($key)
    }
    
    [void] OnActivated() {
        ([Screen]$this).OnActivated()
        $this.CategoryList.Focus()
        # Settings are loaded automatically when selection changes
    }
    
    [void] OnBoundsChanged() {
        # Split the width between category list and settings grid
        $categoryWidth = 25
        $gridWidth = [Math]::Max(10, $this.Width - $categoryWidth)
        
        # Set bounds for category list
        $this.CategoryList.SetBounds(
            $this.X,
            $this.Y,
            $categoryWidth,
            $this.Height
        )
        
        # Set bounds for settings grid
        $this.SettingsGrid.SetBounds(
            $this.X + $categoryWidth,
            $this.Y,
            $gridWidth,
            $this.Height
        )
    }
    
    [void] LoadCategories() {
        $config = $this.ConfigService.GetAll()
        $categories = @()
        
        foreach ($key in $config.Keys | Sort-Object) {
            if ($config[$key] -is [hashtable]) {
                $categories += @{
                    Name = $key
                    DisplayName = $this.FormatCategoryName($key)
                }
            }
        }
        
        $this.CategoryList.SetItems($categories)
        $this.CategoryList.ItemRenderer = { param($cat) $cat.DisplayName }
        
        if ($categories.Count -gt 0) {
            $this.CategoryList.SelectIndex(0)
            # LoadCategorySettings is now called automatically by OnSelectionChanged
        }
    }
    
    [void] LoadCategorySettings() {
        $selected = $this.CategoryList.GetSelectedItem()
        if (-not $selected) { return }
        
        $this.CurrentCategory = $selected.Name
        $categoryConfig = $this.ConfigService.Get($this.CurrentCategory)
        
        if ($categoryConfig -is [hashtable]) {
            $settings = @()
            
            foreach ($key in $categoryConfig.Keys | Sort-Object) {
                $value = $categoryConfig[$key]
                $type = $this.GetValueType($value)
                
                $settings += @{
                    Setting = $this.FormatSettingName($key)
                    Value = $this.FormatValue($value)
                    Type = $type
                    Key = $key
                    RawValue = $value
                }
            }
            
            $this.CurrentSettings = $settings
            $this.SettingsGrid.SetItems($settings)
            $this.SettingsGrid.Title = "Settings - $($selected.DisplayName)"
        }
    }
    
    [void] EditSetting() {
        if (-not $this.SettingsGrid.IsFocused) { return }
        
        $selected = $this.SettingsGrid.GetSelectedItem()
        if (-not $selected) { return }
        
        $path = "$($this.CurrentCategory).$($selected.Key)"
        $currentValue = $selected.RawValue
        
        # Create appropriate dialog based on type
        $dialog = $null
        
        switch ($selected.Type) {
            "Boolean" {
                # Simple toggle
                $newValue = -not $currentValue
                $this.ConfigService.Set($path, $newValue)
                
                # Publish config changed event
                if ($this.EventBus) {
                    $this.EventBus.Publish([EventNames]::ConfigChanged, @{
                        Path = $path
                        OldValue = $currentValue
                        NewValue = $newValue
                        Category = $this.CurrentCategory
                    })
                }
                
                $this.LoadCategorySettings()
                return
            }
            "Number" {
                # TODO: Create NumberInputDialog
                if ($global:Logger) {
                    $global:Logger.Info("Number editing not yet implemented")
                }
            }
            "String" {
                # TODO: Create TextInputDialog
                if ($global:Logger) {
                    $global:Logger.Info("String editing not yet implemented")
                }
            }
        }
    }
    
    [void] ResetCategory() {
        if (-not $this.CurrentCategory) { return }
        
        $message = "Reset all settings in '$($this.CurrentCategory)' to defaults?"
        $dialog = [ConfirmationDialog]::new($message)
        $dialog.OnConfirm = {
            $this.ConfigService.ResetSection($this.CurrentCategory)
            $this.LoadCategorySettings()
            if ($global:ScreenManager) {
                $global:ScreenManager.Pop()
            }
        }.GetNewClosure()
        
        $dialog.OnCancel = {
            if ($global:ScreenManager) {
                $global:ScreenManager.Pop()
            }
        }
        
        if ($global:ScreenManager) {
            $global:ScreenManager.Push($dialog)
        }
    }
    
    [void] ResetAll() {
        $message = "Reset ALL settings to defaults?`n`nThis cannot be undone!"
        $dialog = [ConfirmationDialog]::new($message)
        $dialog.ConfirmText = "Reset All"
        $dialog.OnConfirm = {
            $this.ConfigService.Reset()
            $this.LoadCategories()
            if ($global:ScreenManager) {
                $global:ScreenManager.Pop()
            }
        }.GetNewClosure()
        
        $dialog.OnCancel = {
            if ($global:ScreenManager) {
                $global:ScreenManager.Pop()
            }
        }
        
        if ($global:ScreenManager) {
            $global:ScreenManager.Push($dialog)
        }
    }
    
    [void] SaveSettings() {
        $this.ConfigService.Save()
        if ($global:Logger) {
            $global:Logger.Info("Settings saved")
        }
    }
    
    [void] FocusNext() {
        if ($this.CategoryList.IsFocused) {
            $this.SettingsGrid.Focus()
        } else {
            $this.CategoryList.Focus()
        }
        $this.Invalidate()
    }
    
    hidden [string] FormatCategoryName([string]$name) {
        # Convert PascalCase to Title Case
        $formatted = $name -creplace '([A-Z])', ' $1'
        return $formatted.Trim()
    }
    
    hidden [string] FormatSettingName([string]$name) {
        # Convert camelCase/PascalCase to Title Case
        $formatted = $name -creplace '([A-Z])', ' $1'
        $formatted = $formatted.Substring(0,1).ToUpper() + $formatted.Substring(1)
        return $formatted.Trim()
    }
    
    hidden [string] FormatValue($value) {
        if ($value -eq $null) { return "<null>" }
        if ($value -is [bool]) { return $(if ($value) { "Yes" } else { "No" }) }
        if ($value -is [hashtable]) { return "<nested>" }
        if ($value -is [array]) { return "<array[$($value.Count)]>" }
        return $value.ToString()
    }
    
    hidden [string] GetValueType($value) {
        if ($value -eq $null) { return "Null" }
        if ($value -is [bool]) { return "Boolean" }
        if ($value -is [int] -or $value -is [long] -or $value -is [double]) { return "Number" }
        if ($value -is [string]) { return "String" }
        if ($value -is [hashtable]) { return "Object" }
        if ($value -is [array]) { return "Array" }
        return "Unknown"
    }
    
    [string] OnRender() {
        $sb = [System.Text.StringBuilder]::new()
        
        # Render base
        $sb.Append(([Container]$this).OnRender())
        
        # Render status bar
        $statusY = $this.Y + $this.Height - 1
        $sb.Append([VT]::MoveTo($this.X, $statusY))
        $sb.Append($this.Theme.GetColor("border"))
        $sb.Append("─" * $this.Width)
        
        $sb.Append([VT]::MoveTo($this.X + 1, $statusY))
        $sb.Append($this.Theme.GetColor("disabled"))
        $sb.Append(" [Tab]Navigate [Enter/E]Edit [R]Reset Category [Shift+R]Reset All [S]Save")
        
        $sb.Append([VT]::Reset())
        return $sb.ToString()
    }
}