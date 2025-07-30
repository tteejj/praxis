# SettingsScreen.ps1 - Settings management screen

class SettingsScreen : Screen {
    [MinimalListBox]$CategoryList
    [MinimalDataGrid]$SettingsGrid
    [ConfigurationService]$ConfigService
    [hashtable[]]$CurrentSettings = @()
    [string]$CurrentCategory = ""
    [EventBus]$EventBus
    
    SettingsScreen() : base() {
        $this.Title = "Settings"
        $this.DrawBackground = $true
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
        $this.CategoryList = [MinimalListBox]::new()
        $this.CategoryList.ShowBorder = $false  # No border - we'll handle separation ourselves
        $this.CategoryList.BorderType = [BorderType]::None
        # Capture screen reference for callback
        $screen = $this
        $this.CategoryList.OnSelectionChanged = {
            $screen.LoadCategorySettings()
        }.GetNewClosure()
        $this.CategoryList.Initialize($global:ServiceContainer)
        $this.AddChild($this.CategoryList)
        
        # Create settings grid
        $this.SettingsGrid = [MinimalDataGrid]::new()
        $this.SettingsGrid.Title = ""  # No title needed
        $this.SettingsGrid.ShowBorder = $false  # No border
        $this.SettingsGrid.BorderType = [BorderType]::None
        $this.SettingsGrid.ShowTitle = $false
        $this.SettingsGrid.Initialize($global:ServiceContainer)
        $columns = @(
            @{Name="Setting"; Header="Setting"; Width=30; Getter={param($item) $item.Setting}},
            @{Name="Value"; Header="Value"; Width=20; Getter={param($item) $item.Value}},
            @{Name="Type"; Header="Type"; Width=10; Getter={param($item) $item.Type}}
        )
        $this.SettingsGrid.SetColumns($columns)
        
        # Set up Enter key handler for the grid
        $screen = $this
        $this.SettingsGrid.OnItemSelected = {
            param($item)
            $screen.EditSetting()
        }.GetNewClosure()
        
        $this.AddChild($this.SettingsGrid)
        
        # Load categories
        $this.LoadCategories()
        
        # No more BindKey - use HandleScreenInput instead
    }
    
    # Handle screen-specific input
    [bool] HandleScreenInput([System.ConsoleKeyInfo]$key) {
        if ($global:Logger) {
            $global:Logger.Debug("SettingsScreen.HandleScreenInput: Key=$($key.Key) Char='$($key.KeyChar)'")
        }
        switch ($key.Key) {
            ([System.ConsoleKey]::Enter) { 
                if ($global:Logger) {
                    $global:Logger.Debug("SettingsScreen: Enter key detected, calling EditSetting()")
                }
                $this.EditSetting()
                return $true
            }
            ([System.ConsoleKey]::Tab) {
                # Toggle focus between CategoryList and SettingsGrid
                if ($this.CategoryList.IsFocused) {
                    if ($this.SettingsGrid.Items.Count -gt 0) {
                        $this.SettingsGrid.Focus()
                    }
                } else {
                    $this.CategoryList.Focus()
                }
                return $true
            }
            ([System.ConsoleKey]::LeftArrow) {
                # Focus category list
                $this.CategoryList.Focus()
                return $true
            }
            ([System.ConsoleKey]::RightArrow) {
                # Focus settings grid if it has items
                if ($this.SettingsGrid.Items.Count -gt 0) {
                    $this.SettingsGrid.Focus()
                }
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
            't' { 
                if ($global:Logger) {
                    $global:Logger.Info("SettingsScreen: 't' key pressed - cycling theme")
                }
                # Quick theme selector - navigate to Theme category and show theme selector
                $this.SelectThemeCategory()
                return $true 
            }
            'T' { 
                # Also handle uppercase T
                if ($global:Logger) {
                    $global:Logger.Info("SettingsScreen: 'T' key pressed - cycling theme")
                }
                $this.SelectThemeCategory()
                return $true 
            }
        }
        
        return $false
    }

    [void] OnActivated() {
        ([Screen]$this).OnActivated()
        
        # Set initial focus to category list
        if ($this.CategoryList) {
            $this.CategoryList.Focus()
        }
    }
    
    [void] OnBoundsChanged() {
        # Only update bounds if components exist
        if (-not $this.CategoryList -or -not $this.SettingsGrid) { return }
        
        # Account for border
        $innerX = $this.X + 1
        $innerY = $this.Y + 1
        $innerWidth = $this.Width - 2
        $innerHeight = $this.Height - 2
        
        # Split the width between category list and settings grid
        $categoryWidth = 28  # Fixed width for categories
        $separatorWidth = 1  # Vertical separator
        $gridWidth = [Math]::Max(10, $innerWidth - $categoryWidth - $separatorWidth)
        
        # Set bounds for category list
        $this.CategoryList.SetBounds(
            $innerX,
            $innerY,
            $categoryWidth,
            $innerHeight
        )
        
        # Set bounds for settings grid (after separator)
        $this.SettingsGrid.SetBounds(
            $innerX + $categoryWidth + $separatorWidth,
            $innerY,
            $gridWidth,
            $innerHeight
        )
    }
    
    [void] LoadCategories() {
        $config = $this.ConfigService.GetAll()
        if (-not $config) {
            if ($global:Logger) {
                $global:Logger.Warning("SettingsScreen.LoadCategories: ConfigService.GetAll() returned null")
            }
            $config = @{}
        }
        
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
        $this.CategoryList.ItemFormatter = { param($cat) $cat.DisplayName }
        
        if ($categories.Count -gt 0) {
            $this.CategoryList.SelectedIndex = 0
            # Explicitly load the first category's settings
            $this.LoadCategorySettings()
        }
    }
    
    [void] LoadCategorySettings() {
        if ($global:Logger) {
            $global:Logger.Debug("SettingsScreen.LoadCategorySettings: Called")
        }
        
        $selected = $this.CategoryList.GetSelectedItem()
        if (-not $selected) {
            if ($global:Logger) {
                $global:Logger.Debug("SettingsScreen.LoadCategorySettings: No selected item")
            }
            return
        }
        
        $this.CurrentCategory = $selected.Name
        $categoryConfig = $this.ConfigService.Get($this.CurrentCategory)
        
        if ($categoryConfig -is [hashtable]) {
            $settings = @()
            
            # For Theme category, put CurrentTheme first
            if ($selected.Name -eq "Theme") {
                if ($global:Logger) {
                    $global:Logger.Debug("LoadCategorySettings: Theme category detected")
                    $global:Logger.Debug("  Keys in categoryConfig: $($categoryConfig.Keys -join ', ')")
                }
                # Add CurrentTheme first
                if ($categoryConfig.ContainsKey("CurrentTheme")) {
                    $value = $categoryConfig["CurrentTheme"]
                    $settings += @{
                        Setting = $this.FormatSettingName("CurrentTheme")
                        Value = "▸ $value ◂ [Press Enter to change]"
                        Type = $this.GetValueType($value)
                        Key = "CurrentTheme"
                        RawValue = $value
                    }
                    if ($global:Logger) {
                        $global:Logger.Debug("  Added CurrentTheme as first item")
                    }
                }
                
                # Then add other settings except CurrentTheme
                foreach ($key in $categoryConfig.Keys | Sort-Object) {
                    if ($key -eq "CurrentTheme") { continue }
                    
                    $value = $categoryConfig[$key]
                    $type = $this.GetValueType($value)
                    
                    # Special formatting for EditTheme
                    $displayValue = if ($key -eq "EditTheme") {
                        "✎ Press Enter to open theme editor"
                    } else {
                        $this.FormatValue($value)
                    }
                    
                    $settings += @{
                        Setting = $this.FormatSettingName($key)
                        Value = $displayValue
                        Type = $type
                        Key = $key
                        RawValue = $value
                    }
                }
            }
            else {
                # Normal alphabetical sorting for other categories
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
            }
            
            $this.CurrentSettings = $settings
            
            if ($global:Logger) {
                $global:Logger.Debug("SettingsScreen.LoadCategorySettings: Loading $($settings.Count) settings for category '$($selected.DisplayName)'")
            }
            
            # For Theme category, reset selection before setting items
            if ($selected.Name -eq "Theme") {
                $this.SettingsGrid.SelectedIndex = 0
            }
            
            $this.SettingsGrid.SetItems($settings)
            $this.SettingsGrid.Title = "Settings - $($selected.DisplayName)"
            
            # Force selection to first item for Theme category
            if ($selected.Name -eq "Theme" -and $settings.Count -gt 0) {
                $this.SettingsGrid.SelectedIndex = 0
                $this.SettingsGrid.Invalidate()
            }
        }
    }
    
    [void] EditSetting() {
        if ($global:Logger) {
            $global:Logger.Debug("SettingsScreen.EditSetting: Called")
            $global:Logger.Debug("  CategoryList.IsFocused: $($this.CategoryList.IsFocused)")
            $global:Logger.Debug("  SettingsGrid.IsFocused: $($this.SettingsGrid.IsFocused)")
            $global:Logger.Debug("  SettingsGrid.Items.Count: $($this.SettingsGrid.Items.Count)")
        }
        
        # If CategoryList has focus, move focus to SettingsGrid first
        if ($this.CategoryList.IsFocused -and $this.SettingsGrid.Items.Count -gt 0) {
            $this.SettingsGrid.Focus()
        }
        
        if (-not $this.SettingsGrid.IsFocused) { 
            if ($global:Logger) {
                $global:Logger.Debug("SettingsScreen.EditSetting: Grid not focused, returning")
            }
            return 
        }
        
        $selected = $this.SettingsGrid.GetSelectedItem()
        if (-not $selected) { return }
        
        $path = "$($this.CurrentCategory).$($selected.Key)"
        $currentValue = $selected.RawValue
        
        if ($global:Logger) {
            $global:Logger.Debug("SettingsScreen.EditSetting: Path=$path, Key=$($selected.Key), Category=$($this.CurrentCategory)")
        }
        
        # Create appropriate dialog based on type
        $dialog = $null
        
        # Special handling for theme selection
        if ($path -eq "Theme.CurrentTheme") {
            if ($global:Logger) {
                $global:Logger.Info("SettingsScreen.EditSetting: Cycling theme")
            }
            # Just cycle to next theme
            $this.SelectThemeCategory()
            return
        }
        
        # Special handling for theme editing
        if ($path -eq "Theme.EditTheme") {
            $this.ShowThemeEditor()
            return
        }
        
        # Special handling for template items
        if ($path -match "Templates\.(TimeEntry|Commands|Macros)\.Items") {
            $templateType = $Matches[1]
            $this.ShowTemplateEditor($templateType, $currentValue)
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
                $dialog.OnPrimary = {
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
                $dialog = [TextInputDialog]::new("Edit $($selected.Setting)", $currentValue)
                $dialog.OnSubmit = {
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
                    
                    $this.LoadCategorySettings()
                }.GetNewClosure()
                
                if ($global:ScreenManager) {
                    $global:ScreenManager.Push($dialog)
                }
            }
        }
    }
    
    [void] ResetCategory() {
        if (-not $this.CurrentCategory) { return }
        
        $message = "Reset all settings in '$($this.CurrentCategory)' to defaults?"
        $dialog = [ConfirmationDialog]::new($message)
        $dialog.OnPrimary = {
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
        $dialog.OnPrimary = {
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
        $dialog.OnPrimary = {
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
        if ($value -is [array]) { 
            # Special handling for template arrays
            if ($value.Count -gt 0 -and $value[0] -is [hashtable] -and $value[0].ContainsKey("Name")) {
                return "[$($value.Count) templates] (Click to edit)"
            }
            return "<array[$($value.Count)]>" 
        }
        
        # Special formatting for specific settings
        if ($value -is [string]) {
            # Don't double-format already formatted values
            if ($value -match "[\[▸◂]") {
                return $value  # Already formatted
            }
        }
        
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
        # Just cycle themes
        $this.SelectThemeCategory()
    }
    
    [void] ShowThemeEditor() {
        # Just cycle themes for now
        $this.SelectThemeCategory()
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

    [void] ShowTemplateEditor([string]$templateType, $currentTemplates) {
        # Create template list editor dialog
        $dialog = [BaseDialog]::new("Edit $templateType Templates")
        $dialog.DialogWidth = 70
        $dialog.DialogHeight = 20
        $dialog.PrimaryButtonText = "Save"
        $dialog.SecondaryButtonText = "Cancel"
        
        # Create a data grid to show templates
        $templateGrid = [MinimalDataGrid]::new()
        $templateGrid.ShowBorder = $true
        $templateGrid.BorderType = [BorderType]::Rounded
        
        # Define columns based on template type
        $columns = $null
        switch ($templateType) {
            "TimeEntry" {
                $columns = @(
                    @{Name="Name"; Header="Name"; Width=20}
                    @{Name="ProjectID"; Header="Project"; Width=15}
                    @{Name="Description"; Header="Description"; Width=25}
                    @{Name="DefaultHours"; Header="Hours"; Width=6}
                )
            }
            "Commands" {
                $columns = @(
                    @{Name="Name"; Header="Name"; Width=20}
                    @{Name="Template"; Header="Template"; Width=35}
                    @{Name="Description"; Header="Description"; Width=25}
                )
            }
            "Macros" {
                $columns = @(
                    @{Name="Name"; Header="Name"; Width=20}
                    @{Name="Description"; Header="Description"; Width=30}
                    @{Name="ActionCount"; Header="Actions"; Width=8; 
                      Getter={param($item) if ($item.Actions) { $item.Actions.Count } else { 0 }}}
                )
            }
        }
        
        if ($columns) {
            $templateGrid.SetColumns($columns)
        }
        $templateGrid.Initialize($this.ServiceContainer)
        
        # Load current templates
        $templateList = [System.Collections.ArrayList]::new()
        if ($currentTemplates -and $currentTemplates.Count -gt 0) {
            $templateList.AddRange($currentTemplates)
        }
        $templateGrid.SetItems($templateList)
        
        # Add to dialog
        $dialog.AddChild($templateGrid)
        $dialog.Initialize($this.ServiceContainer)
        
        # Position the grid
        $dialog.OnBoundsChanged = {
            $dialogBounds = $dialog._dialogBounds
            $templateGrid.SetBounds(
                $dialogBounds.X + 2,
                $dialogBounds.Y + 2,
                $dialogBounds.Width - 4,
                $dialogBounds.Height - 6  # Leave room for buttons
            )
        }.GetNewClosure()
        
        # Add keyboard shortcuts for template management
        $screen = $this
        $dialog.HandleScreenInput = {
            param($key)
            switch ($key.KeyChar) {
                'a' {  # Add new template
                    $screen.AddTemplate($templateType, $templateList, $templateGrid)
                    return $true
                }
                'e' {  # Edit selected template
                    $selected = $templateGrid.GetSelectedItem()
                    if ($selected) {
                        $screen.EditTemplate($templateType, $selected, $templateGrid)
                    }
                    return $true
                }
                'd' {  # Delete selected template
                    $idx = $templateGrid.SelectedIndex
                    if ($idx -ge 0 -and $idx -lt $templateList.Count) {
                        $templateList.RemoveAt($idx)
                        $templateGrid.SetItems($templateList)
                    }
                    return $true
                }
            }
            return $false
        }.GetNewClosure()
        
        # Save handler
        $dialog.OnPrimary = {
            # Save the updated templates back to config
            $path = "Templates.$templateType.Items"
            $screen.ConfigService.Set($path, $templateList.ToArray())
            
            # Publish event
            if ($screen.EventBus) {
                $screen.EventBus.Publish([EventNames]::ConfigChanged, @{
                    Path = $path
                    Category = "Templates"
                })
            }
            
            # Refresh settings display
            $screen.LoadCategorySettings()
        }.GetNewClosure()
        
        # Show help in title
        $dialog.Title = "Edit $templateType Templates (a:Add e:Edit d:Delete)"
        
        $global:ScreenManager.Push($dialog)
    }
    
    [void] AddTemplate([string]$templateType, $templateList, $templateGrid) {
        switch ($templateType) {
            "TimeEntry" {
                $this.AddTimeEntryTemplate($templateList, $templateGrid)
            }
            "Commands" {
                $this.AddCommandTemplate($templateList, $templateGrid)
            }
            "Macros" {
                $this.AddMacroTemplate($templateList, $templateGrid)
            }
        }
    }
    
    [void] AddTimeEntryTemplate($templateList, $templateGrid) {
        # Create a simple form dialog for time entry template
        $dialog = [BaseDialog]::new("Add Time Entry Template")
        $dialog.DialogWidth = 50
        $dialog.DialogHeight = 15
        
        # Create input fields
        $nameBox = [MinimalTextBox]::new()
        $nameBox.Title = "Template Name"
        $nameBox.Placeholder = "e.g., Daily Standup"
        
        $projectBox = [MinimalTextBox]::new()
        $projectBox.Title = "Project ID"
        $projectBox.Placeholder = "e.g., Internal"
        
        $descBox = [MinimalTextBox]::new()
        $descBox.Title = "Description"
        $descBox.Placeholder = "e.g., Daily team standup"
        
        $hoursBox = [MinimalTextBox]::new()
        $hoursBox.Title = "Default Hours"
        $hoursBox.Text = "0.25"
        
        # Add controls
        $dialog.AddChild($nameBox)
        $dialog.AddChild($projectBox)
        $dialog.AddChild($descBox)
        $dialog.AddChild($hoursBox)
        $dialog.Initialize($this.ServiceContainer)
        
        # Layout controls vertically
        $y = $dialog._dialogBounds.Y + 2
        $x = $dialog._dialogBounds.X + 2
        $width = $dialog._dialogBounds.Width - 4
        
        $nameBox.SetBounds($x, $y, $width, 1)
        $projectBox.SetBounds($x, $y + 2, $width, 1)
        $descBox.SetBounds($x, $y + 4, $width, 1)
        $hoursBox.SetBounds($x, $y + 6, $width, 1)
        
        # Save handler
        $dialog.OnPrimary = {
            $newTemplate = @{
                Name = $nameBox.Text
                ProjectID = $projectBox.Text
                Description = $descBox.Text
                DefaultHours = [double]::Parse($hoursBox.Text)
                DefaultDays = @("Monday", "Tuesday", "Wednesday", "Thursday", "Friday")
            }
            
            $templateList.Add($newTemplate)
            $templateGrid.SetItems($templateList)
        }.GetNewClosure()
        
        $global:ScreenManager.Push($dialog)
    }
    
    [void] AddCommandTemplate($templateList, $templateGrid) {
        # Create form for command template
        $dialog = [BaseDialog]::new("Add Command Template")
        $dialog.DialogWidth = 60
        $dialog.DialogHeight = 15
        
        $nameBox = [MinimalTextBox]::new()
        $nameBox.Title = "Template Name"
        $nameBox.Placeholder = "e.g., Export to CSV"
        
        $templateBox = [MinimalTextBox]::new()
        $templateBox.Title = "Command Template"
        $templateBox.Placeholder = "IDEA@EXPORT DATABASE {DATABASE} TO {FILE}.CSV"
        
        $descBox = [MinimalTextBox]::new()
        $descBox.Title = "Description"
        $descBox.Placeholder = "Export database to CSV format"
        
        # Add controls
        $dialog.AddChild($nameBox)
        $dialog.AddChild($templateBox)
        $dialog.AddChild($descBox)
        $dialog.Initialize($this.ServiceContainer)
        
        # Layout
        $y = $dialog._dialogBounds.Y + 2
        $x = $dialog._dialogBounds.X + 2
        $width = $dialog._dialogBounds.Width - 4
        
        $nameBox.SetBounds($x, $y, $width, 1)
        $templateBox.SetBounds($x, $y + 2, $width, 1)
        $descBox.SetBounds($x, $y + 4, $width, 1)
        
        # Save handler
        $dialog.OnPrimary = {
            # Extract placeholders from template
            $placeholders = @()
            $matches = [regex]::Matches($templateBox.Text, '\{([^}]+)\}')
            foreach ($match in $matches) {
                $placeholders += $match.Groups[1].Value
            }
            
            $newTemplate = @{
                Name = $nameBox.Text
                Template = $templateBox.Text
                Description = $descBox.Text
                Placeholders = $placeholders
            }
            
            $templateList.Add($newTemplate)
            $templateGrid.SetItems($templateList)
        }.GetNewClosure()
        
        $global:ScreenManager.Push($dialog)
    }
    
    [void] AddMacroTemplate($templateList, $templateGrid) {
        # For now, show a message that macro templates should be created in Visual Macro Factory
        $dialog = [ConfirmationDialog]::new(
            "Macro templates should be created in the Visual Macro Factory screen.`n`n" +
            "Go to the Macro Factory tab to build macros visually,`n" +
            "then save them as templates from there."
        )
        $dialog.Title = "Create Macro Template"
        $dialog.ShowCancel = $false
        $dialog.Initialize($this.ServiceContainer)
        
        $global:ScreenManager.Push($dialog)
    }
    
    [void] EditTemplate([string]$templateType, $template, $templateGrid) {
        # For simplicity, remove and re-add
        # In a real implementation, you'd edit in place
        $toastService = $this.ServiceContainer.GetService('ToastService')
        if ($toastService) {
            $toastService.ShowToast("Edit: Remove and re-add template", [ToastType]::Info, 2000)
        }
    }
    
    [string] OnRender() {
        $sb = Get-PooledStringBuilder 4096
        
        # Draw outer border
        $theme = $this.ServiceContainer.GetService('ThemeManager')
        if ($theme) {
            $borderColor = $theme.GetColor('border.normal')
            $sb.Append([BorderStyle]::RenderBorderWithTitle(
                $this.X, $this.Y, $this.Width, $this.Height,
                [BorderType]::Rounded, $borderColor,
                "Settings", $theme.GetColor('color.primary')
            ))
            
            # Draw vertical separator
            $separatorX = $this.X + 29  # After category list
            $separatorColor = $theme.GetColor('border.normal')
            $sb.Append($separatorColor)
            
            # Draw vertical line
            for ($y = $this.Y + 1; $y -lt $this.Y + $this.Height - 1; $y++) {
                $sb.Append([VT]::MoveTo($separatorX, $y))
                $sb.Append('│')
            }
            
            # Connect to top border
            $sb.Append([VT]::MoveTo($separatorX, $this.Y))
            $sb.Append('┬')
            
            # Connect to bottom border
            $sb.Append([VT]::MoveTo($separatorX, $this.Y + $this.Height - 1))
            $sb.Append('┴')

        }
        
        # Render children (category list and settings grid)
        $sb.Append(([Screen]$this).OnRender())
        
        $result = $sb.ToString()
        Return-PooledStringBuilder $sb
        return $result
    }
    
    [void] SelectThemeCategory() {
        if ($global:Logger) {
            $global:Logger.Info("SettingsScreen: Cycling to next theme")
        }
        
        # Simple theme cycling
        $themeManager = $this.ServiceContainer.GetService('ThemeManager')
        if (-not $themeManager) { return }
        
        $themes = $themeManager.GetThemeNames()
        $current = $themeManager.GetCurrentTheme()
        $currentIndex = [Array]::IndexOf($themes, $current)
        $nextIndex = ($currentIndex + 1) % $themes.Count
        $nextTheme = $themes[$nextIndex]
        
        if ($global:Logger) {
            $global:Logger.Info("SettingsScreen: Changing theme from '$current' to '$nextTheme'")
        }
        
        # Apply the theme
        $themeManager.SetTheme($nextTheme)
        
        # Update config
        $this.ConfigService.Set("Theme.CurrentTheme", $nextTheme)
        
        # Save immediately
        $this.ConfigService.Save()
        
        # Publish event
        if ($this.EventBus) {
            $this.EventBus.Publish([EventNames]::ConfigChanged, @{
                Path = "Theme.CurrentTheme"
                OldValue = $current
                NewValue = $nextTheme
                Category = "Theme"
            })
        }
        
        # Force full application refresh
        $screenManager = $this.ServiceContainer.GetService('ScreenManager')
        if ($screenManager) {
            $screenManager.Invalidate()
        }
        
        # Update display
        $this.LoadSettings()
        
        # Force parent to redraw
        if ($this.Parent) {
            $this.Parent.Invalidate()
        }
    }
    
    [void] ChangeTheme() {
        # Alias for SelectThemeCategory - cycles through themes
        $this.SelectThemeCategory()
    }
    
    [void] ExportSettings() {
        # Export current settings to a file
        try {
            $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
            $exportPath = Join-Path $this.ConfigService.ConfigDirectory "settings_export_$timestamp.json"
            
            $settings = $this.ConfigService.GetAll()
            $json = $settings | ConvertTo-Json -Depth 10
            Set-Content -Path $exportPath -Value $json -Encoding UTF8
            
            $toastService = $this.ServiceContainer.GetService('ToastService')
            if ($toastService) {
                $toastService.Show("Settings exported to: $exportPath", [ToastType]::Success, 3000)
            }
        }
        catch {
            $toastService = $this.ServiceContainer.GetService('ToastService')
            if ($toastService) {
                $toastService.Show("Export failed: $($_.Exception.Message)", [ToastType]::Error, 3000)
            }
            
            if ($global:Logger) {
                $global:Logger.Error("SettingsScreen.ExportSettings: $_")
            }
        }
    }
    
    [void] ImportSettings() {
        # Import settings from a file
        $dialog = [FilePickerDialog]::new()
        $dialog.Title = "Import Settings"
        $dialog.Filter = "*.json"
        $dialog.StartPath = $this.ConfigService.ConfigDirectory
        
        $screen = $this
        $dialog.OnFileSelected = {
            param($filePath)
            try {
                $json = Get-Content -Path $filePath -Raw -Encoding UTF8
                $settings = $json | ConvertFrom-Json -AsHashtable
                
                # Merge with existing settings
                foreach ($key in $settings.Keys) {
                    $screen.ConfigService.Set($key, $settings[$key])
                }
                
                $screen.ConfigService.Save()
                $screen.LoadCategories()
                
                $toastService = $screen.ServiceContainer.GetService('ToastService')
                if ($toastService) {
                    $toastService.Show("Settings imported successfully!", [ToastType]::Success, 2000)
                }
            }
            catch {
                $toastService = $screen.ServiceContainer.GetService('ToastService')
                if ($toastService) {
                    $toastService.Show("Import failed: $($_.Exception.Message)", [ToastType]::Error, 3000)
                }
                
                if ($global:Logger) {
                    $global:Logger.Error("SettingsScreen.ImportSettings: $_")
                }
            }
        }.GetNewClosure()
        
        if ($global:ScreenManager) {
            $global:ScreenManager.Push($dialog)
        }
    }
    
    [void] ResetSettings() {
        # Alias for ResetAll
        $this.ResetAll()
    }
}