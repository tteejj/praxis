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
            'b' { $this.CreateBackup(); return $true }
            'B' { $this.RestoreBackup(); return $true }
        }
        
        return $false
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
        
        # Special handling for theme selection
        if ($path -eq "Theme.CurrentTheme") {
            # Show theme selection dialog
            $this.ShowThemeSelectionDialog($currentValue)
            return
        }
        
        # Special handling for theme editing
        if ($path -eq "Theme.EditTheme") {
            $this.ShowThemeEditor()
            return
        }
        
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
                $dialog = [NumberInputDialog]::new("Edit $($selected.Setting)", "Enter new value:", $currentValue)
                $dialog.OnConfirm = {
                    param($result)
                    $this.ConfigService.Set($path, $result)
                    
                    # Publish config changed event
                    if ($this.EventBus) {
                        $this.EventBus.Publish([EventNames]::ConfigChanged, @{
                            Path = $path
                            OldValue = $currentValue
                            NewValue = $result
                            Category = $this.CurrentCategory
                        })
                    }
                    
                    # Apply vertical spacing immediately if changed
                    if ($path -eq "UI.VerticalSpacing") {
                        [Spacing]::Component.ElementGap = $result
                        # Force full screen refresh
                        if ($global:ScreenManager) {
                            $global:ScreenManager.Invalidate()
                        }
                    }
                    
                    $this.LoadCategorySettings()
                }.GetNewClosure()
                
                if ($global:ScreenManager) {
                    $global:ScreenManager.Push($dialog)
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
            # Don't call Pop() - BaseDialog handles that
        }.GetNewClosure()
        
        # Don't need OnCancel - BaseDialog handles ESC by default
        
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
            # Don't call Pop() - BaseDialog handles that
        }.GetNewClosure()
        
        # Don't need OnCancel - BaseDialog handles ESC by default
        
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
    
    [void] CreateBackup() {
        $backupService = $global:ServiceContainer.GetService("BackupService")
        if (-not $backupService) {
            $backupService = [BackupService]::new()
            $global:ServiceContainer.Register("BackupService", $backupService)
        }
        
        try {
            $backupPath = $backupService.CreateBackup("Settings backup")
            $message = "Backup created successfully:`n$backupPath"
            $dialog = [ConfirmationDialog]::new($message)
            $dialog.ShowCancel = $false
            $dialog.ConfirmText = "OK"
            
            if ($global:ScreenManager) {
                $global:ScreenManager.Push($dialog)
            }
        }
        catch {
            $message = "Backup failed:`n$_"
            $dialog = [ConfirmationDialog]::new($message)
            $dialog.ShowCancel = $false
            $dialog.ConfirmText = "OK"
            
            if ($global:ScreenManager) {
                $global:ScreenManager.Push($dialog)
            }
        }
    }
    
    [void] RestoreBackup() {
        $backupService = $global:ServiceContainer.GetService("BackupService")
        if (-not $backupService) {
            $backupService = [BackupService]::new()
            $global:ServiceContainer.Register("BackupService", $backupService)
        }
        
        $backups = $backupService.ListBackups()
        if ($backups.Count -eq 0) {
            $message = "No backups found."
            $dialog = [ConfirmationDialog]::new($message)
            $dialog.ShowCancel = $false
            $dialog.ConfirmText = "OK"
            
            if ($global:ScreenManager) {
                $global:ScreenManager.Push($dialog)
            }
            return
        }
        
        # TODO: Create backup selection dialog
        # For now, restore the most recent backup
        $latestBackup = $backups[0]
        
        $message = "Restore from backup?`n`nBackup: $($latestBackup.Name)`nDate: $($latestBackup.Timestamp)`n`nThis will replace all current data!"
        $dialog = [ConfirmationDialog]::new($message)
        $dialog.ConfirmText = "Restore"
        $dialog.OnConfirm = {
            try {
                $backupService.RestoreBackup($latestBackup.Name)
                
                # Reload configuration
                $this.ConfigService.Load()
                $this.LoadCategories()
                
                $message = "Restore completed successfully.`nRestart the application for all changes to take effect."
                $dialog2 = [ConfirmationDialog]::new($message)
                $dialog2.ShowCancel = $false
                $dialog2.ConfirmText = "OK"
                
                if ($global:ScreenManager) {
                    $global:ScreenManager.Push($dialog2)
                }
            }
            catch {
                $message = "Restore failed:`n$_"
                $dialog2 = [ConfirmationDialog]::new($message)
                $dialog2.ShowCancel = $false
                $dialog2.ConfirmText = "OK"
                
                if ($global:ScreenManager) {
                    $global:ScreenManager.Push($dialog2)
                }
            }
        }.GetNewClosure()
        
        if ($global:ScreenManager) {
            $global:ScreenManager.Push($dialog)
        }
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
    
    [void] ShowThemeSelectionDialog([string]$currentTheme) {
        $themeManager = $global:ServiceContainer.GetService("ThemeManager")
        if (-not $themeManager) { return }
        
        $themes = $themeManager.GetThemeNames()
        
        # Create selection dialog
        $dialog = [SelectionDialog]::new()
        $dialog.Title = "Select Theme"
        $dialog.Prompt = "Choose a theme:"
        $dialog.Initialize($this.ServiceContainer)
        
        # Format theme list with preview
        $items = @()
        foreach ($theme in $themes) {
            $items += @{
                Name = $theme
                Display = if ($theme -eq $currentTheme) { "● $theme (current)" } else { "  $theme" }
            }
        }
        
        # Add option to install more themes
        $items += @{
            Name = "_install"
            Display = "↓ Install More Themes..."
        }
        
        # Add option to edit themes
        $items += @{
            Name = "_edit"
            Display = "✎ Edit Current Theme..."
        }
        
        $dialog.SetItems($items)
        $dialog.ItemRenderer = { param($item) $item.Display }
        
        $screen = $this
        $dialog.OnSelect = {
            param($item)
            
            if ($item.Name -eq "_install") {
                $screen.InstallThemeTemplates()
            }
            elseif ($item.Name -eq "_edit") {
                $screen.ShowThemeEditor()
            }
            else {
                # Apply selected theme
                $screen.ConfigService.Set("Theme.CurrentTheme", $item.Name)
                $themeManager.SetTheme($item.Name)
                
                # Publish event
                if ($screen.EventBus) {
                    $screen.EventBus.Publish([EventNames]::ConfigChanged, @{
                        Path = "Theme.CurrentTheme"
                        OldValue = $currentTheme
                        NewValue = $item.Name
                        Category = "Theme"
                    })
                }
                
                $screen.LoadCategorySettings()
            }
        }.GetNewClosure()
        
        $global:ScreenManager.Push($dialog)
    }
    
    [void] ShowThemeEditor() {
        $editor = [ThemeEditorDialog]::new()
        $editor.Initialize($this.ServiceContainer)
        
        $screen = $this
        $editor.OnPrimary = {
            # Refresh settings after editing
            $screen.LoadCategorySettings()
        }.GetNewClosure()
        
        $global:ScreenManager.Push($editor)
    }
    
    [void] InstallThemeTemplates() {
        # Create confirmation dialog
        $message = @"
Install additional theme templates?

This will add the following themes:
• High Contrast - Maximum accessibility
• Solarized Dark - Popular color scheme
• Dracula - Dark purple theme
• Nord - Arctic color palette
• Monokai - Classic code editor theme
"@
        
        $dialog = [ConfirmationDialog]::new($message)
        $dialog.Title = "Install Themes"
        $dialog.Initialize($this.ServiceContainer)
        
        $screen = $this
        $dialog.OnPrimary = {
            try {
                # Install theme templates
                [ThemeTemplates]::CreateHighContrast()
                [ThemeTemplates]::CreateSolarizedDark()
                [ThemeTemplates]::CreateDracula()
                [ThemeTemplates]::CreateNord()
                [ThemeTemplates]::CreateMonokai()
                
                # Update available themes in config
                $themes = $global:ServiceContainer.GetService("ThemeManager").GetThemeNames()
                $screen.ConfigService.Set("Theme.AvailableThemes", $themes)
                
                # Show success
                $successDialog = [ConfirmationDialog]::new("Themes installed successfully!")
                $successDialog.Title = "Success"
                $successDialog.ShowCancel = $false
                $successDialog.Initialize($screen.ServiceContainer)
                $global:ScreenManager.Push($successDialog)
                
            } catch {
                $errorDialog = [ConfirmationDialog]::new("Failed to install themes: $_")
                $errorDialog.Title = "Error"
                $errorDialog.ShowCancel = $false
                $errorDialog.Initialize($screen.ServiceContainer)
                $global:ScreenManager.Push($errorDialog)
            }
        }.GetNewClosure()
        
        $global:ScreenManager.Push($dialog)
    }
    
    [string] OnRender() {
        $sb = Get-PooledStringBuilder 1024
        
        # Render base
        $sb.Append(([Container]$this).OnRender())
        
        # Render status bar
        $statusY = $this.Y + $this.Height - 1
        $sb.Append([VT]::MoveTo($this.X, $statusY))
        $sb.Append($this.Theme.GetColor("border"))
        $sb.Append([StringCache]::GetHorizontalLine($this.Width))
        
        $sb.Append([VT]::MoveTo($this.X + 1, $statusY))
        $sb.Append($this.Theme.GetColor("disabled"))
        $sb.Append(" [Tab]Nav [Enter/E]Edit [R]Reset [Shift+R]Reset All [S]Save [B]Backup [Shift+B]Restore")
        
        $sb.Append([VT]::Reset())
        
        $result = $sb.ToString()
        Return-PooledStringBuilder $sb
        return $result
    }
}