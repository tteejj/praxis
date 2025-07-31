# Comprehensive Pester tests for ConfigurationService

$SpeedTUIRoot = Split-Path -Parent $PSScriptRoot
Set-Location $SpeedTUIRoot

BeforeAll {
    # Load dependencies with explicit paths
    . "./Core/Logger.ps1"
    . "./Services/DataService.ps1"
    . "./Services/ConfigurationService.ps1"
    
    # Create test data directory
    $SpeedTUIRoot = (Get-Location).Path
    $script:TestDataPath = Join-Path $SpeedTUIRoot "TestData"
    if (-not (Test-Path $script:TestDataPath)) {
        New-Item -Path $script:TestDataPath -ItemType Directory -Force
    }
}

Describe "ConfigurationService Tests" {
    BeforeEach {
        # Create fresh service instance with test data path
        $script:service = [ConfigurationService]::new()
        $script:service.DataDirectory = $script:TestDataPath
        $script:service.FileName = "test_config"
        $script:service.AutoSave = $false  # Disable auto-save for testing
        
        # Clear any existing test data
        $testFile = Join-Path $script:TestDataPath "test_config.json"
        if (Test-Path $testFile) {
            Remove-Item $testFile -Force
        }
        
        # Initialize with defaults
        $script:service.InitializeDefaultSettings()
        $script:service.Settings = $script:service.DefaultSettings.Clone()
    }
    
    AfterEach {
        # Clean up test files
        $testFile = Join-Path $script:TestDataPath "test_config.json"
        if (Test-Path $testFile) {
            Remove-Item $testFile -Force
        }
    }
    
    Context "Service Initialization" {
        It "Should initialize with default settings" {
            $service = [ConfigurationService]::new()
            
            $service | Should -Not -BeNull
            $service.Settings | Should -Not -BeNull
            $service.DefaultSettings | Should -Not -BeNull
            $service.ConfigVersion | Should -Be "1.0"
            $service.FileName | Should -Be "config"
        }
        
        It "Should have all required default sections" {
            $requiredSections = @("Application", "UI", "Colors", "Editor", "TimeTracking", "Commands", "Files", "Network", "Shortcuts", "Recent", "Advanced")
            
            foreach ($section in $requiredSections) {
                $script:service.DefaultSettings.ContainsKey($section) | Should -Be $true
                $script:service.DefaultSettings[$section] | Should -BeOfType [hashtable]
            }
        }
        
        It "Should have sensible default values" {
            $script:service.GetSetting("Application.Name") | Should -Be "SpeedTUI"
            $script:service.GetSetting("Application.AutoSave") | Should -Be $true
            $script:service.GetSetting("UI.Theme") | Should -Be "Default"
            $script:service.GetSetting("Editor.TabSize") | Should -Be 4
            $script:service.GetSetting("TimeTracking.DefaultHoursPerDay") | Should -Be 8.0
        }
    }
    
    Context "Setting Management" {
        It "Should get setting by path" {
            $appName = $script:service.GetSetting("Application.Name")
            $appName | Should -Be "SpeedTUI"
            
            $tabSize = $script:service.GetSetting("Editor.TabSize")
            $tabSize | Should -Be 4
        }
        
        It "Should return null for non-existent setting" {
            $result = $script:service.GetSetting("NonExistent.Setting")
            $result | Should -BeNull
        }
        
        It "Should set setting by path" {
            $script:service.SetSetting("Application.Name", "TestApp")
            $result = $script:service.GetSetting("Application.Name")
            $result | Should -Be "TestApp"
        }
        
        It "Should set nested setting by path" {
            $script:service.SetSetting("UI.Colors.Primary", "Blue")
            $result = $script:service.GetSetting("UI.Colors.Primary")
            $result | Should -Be "Blue"
        }
        
        It "Should check if setting exists" {
            $script:service.HasSetting("Application.Name") | Should -Be $true
            $script:service.HasSetting("NonExistent.Setting") | Should -Be $false
        }
        
        It "Should remove setting" {
            $script:service.SetSetting("Test.Setting", "Value")
            $script:service.HasSetting("Test.Setting") | Should -Be $true
            
            $script:service.RemoveSetting("Test.Setting")
            $script:service.HasSetting("Test.Setting") | Should -Be $false
        }
        
        It "Should get entire section" {
            $uiSection = $script:service.GetSection("UI")
            $uiSection | Should -BeOfType [hashtable]
            $uiSection.ContainsKey("Theme") | Should -Be $true
        }
        
        It "Should set entire section" {
            $newSection = @{
                TestSetting1 = "Value1"
                TestSetting2 = "Value2"
            }
            
            $script:service.SetSection("TestSection", $newSection)
            $result = $script:service.GetSection("TestSection")
            
            $result.TestSetting1 | Should -Be "Value1"
            $result.TestSetting2 | Should -Be "Value2"
        }
    }
    
    Context "Configuration Persistence" {
        It "Should save configuration" {
            $script:service.SetSetting("Test.SavedSetting", "SavedValue")
            $script:service.SaveConfiguration()
            
            $testFile = Join-Path $script:TestDataPath "test_config.json"
            Test-Path $testFile | Should -Be $true
        }
        
        It "Should load saved configuration" {
            # Save a configuration
            $script:service.SetSetting("Test.LoadSetting", "LoadValue")
            $script:service.SaveConfiguration()
            
            # Create new service and load
            $newService = [ConfigurationService]::new()
            $newService.DataDirectory = $script:TestDataPath
            $newService.FileName = "test_config"
            $newService.LoadConfiguration()
            
            $result = $newService.GetSetting("Test.LoadSetting")
            $result | Should -Be "LoadValue"
        }
        
        It "Should merge settings with defaults on load" {
            # Save partial configuration
            $partialConfig = @{
                Application = @{
                    Name = "PartialApp"
                }
                CustomSection = @{
                    CustomSetting = "CustomValue"
                }
            }
            
            $script:service.Settings = $partialConfig
            $script:service.SaveConfiguration()
            
            # Load and verify merge
            $script:service.LoadConfiguration()
            
            # Should have custom values
            $script:service.GetSetting("Application.Name") | Should -Be "PartialApp"
            $script:service.GetSetting("CustomSection.CustomSetting") | Should -Be "CustomValue"
            
            # Should have default values for missing settings
            $script:service.GetSetting("Application.AutoSave") | Should -Be $true
            $script:service.GetSetting("UI.Theme") | Should -Be "Default"
        }
    }
    
    Context "Theme Management" {
        It "Should get current theme" {
            $theme = $script:service.GetCurrentTheme()
            $theme | Should -Be "Default"
        }
        
        It "Should set theme" {
            $script:service.SetTheme("Dark")
            $theme = $script:service.GetCurrentTheme()
            $theme | Should -Be "Dark"
        }
        
        It "Should get theme colors" {
            $colors = $script:service.GetThemeColors()
            $colors | Should -BeOfType [hashtable]
            $colors.ContainsKey("Background") | Should -Be $true
            $colors.ContainsKey("Foreground") | Should -Be $true
        }
        
        It "Should set theme color" {
            $script:service.SetThemeColor("Accent", "Purple")
            $accentColor = $script:service.GetSetting("Colors.Accent")
            $accentColor | Should -Be "Purple"
        }
        
        It "Should create custom theme" {
            $customColors = @{
                Background = "Navy"
                Foreground = "Silver"
                Accent = "Orange"
            }
            
            $result = $script:service.CreateCustomTheme("Custom", $customColors)
            $result | Should -BeOfType [hashtable]
            
            $savedTheme = $script:service.GetSetting("Themes.Custom")
            $savedTheme.Background | Should -Be "Navy"
        }
        
        It "Should get available themes" {
            # Create custom theme first
            $script:service.CreateCustomTheme("MyTheme", @{Background = "Blue"})
            
            $themes = $script:service.GetAvailableThemes()
            $themes | Should -Contain "Default"
            $themes | Should -Contain "Dark"
            $themes | Should -Contain "Light"
            $themes | Should -Contain "MyTheme"
        }
    }
    
    Context "Shortcut Management" {
        It "Should get shortcut" {
            $saveShortcut = $script:service.GetShortcut("Save")
            $saveShortcut | Should -Be "Ctrl+S"
        }
        
        It "Should set shortcut" {
            $script:service.SetShortcut("CustomAction", "Ctrl+Alt+C")
            $result = $script:service.GetShortcut("CustomAction")
            $result | Should -Be "Ctrl+Alt+C"
        }
        
        It "Should get all shortcuts" {
            $shortcuts = $script:service.GetAllShortcuts()
            $shortcuts | Should -BeOfType [hashtable]
            $shortcuts.ContainsKey("Save") | Should -Be $true
            $shortcuts.ContainsKey("Open") | Should -Be $true
        }
        
        It "Should reset shortcuts to defaults" {
            # Modify a shortcut
            $script:service.SetShortcut("Save", "F2")
            $script:service.GetShortcut("Save") | Should -Be "F2"
            
            # Reset shortcuts
            $script:service.ResetShortcuts()
            $script:service.GetShortcut("Save") | Should -Be "Ctrl+S"
        }
        
        It "Should check if shortcut is in use" {
            $script:service.IsShortcutInUse("Ctrl+S") | Should -Be $true
            $script:service.IsShortcutInUse("Ctrl+Alt+Z") | Should -Be $false
        }
    }
    
    Context "Recent Items Management" {
        It "Should add and get recent files" {
            $script:service.AddRecentFile("C:\test\file1.txt")
            $script:service.AddRecentFile("C:\test\file2.txt")
            
            $recentFiles = $script:service.GetRecentFiles()
            $recentFiles.Count | Should -Be 2
            $recentFiles[0] | Should -Be "C:\test\file2.txt"  # Most recent first
            $recentFiles[1] | Should -Be "C:\test\file1.txt"
        }
        
        It "Should limit recent files to max count" {
            # Set small limit for testing
            $script:service.SetSetting("Recent.MaxFiles", 3)
            
            # Add more files than the limit
            for ($i = 1; $i -le 5; $i++) {
                $script:service.AddRecentFile("C:\test\file$i.txt")
            }
            
            $recentFiles = $script:service.GetRecentFiles()
            $recentFiles.Count | Should -Be 3
            $recentFiles[0] | Should -Be "C:\test\file5.txt"  # Most recent
        }
        
        It "Should remove duplicates when adding recent files" {
            $script:service.AddRecentFile("C:\test\duplicate.txt")
            $script:service.AddRecentFile("C:\test\other.txt")
            $script:service.AddRecentFile("C:\test\duplicate.txt")  # Add same file again
            
            $recentFiles = $script:service.GetRecentFiles()
            $recentFiles.Count | Should -Be 2
            $recentFiles[0] | Should -Be "C:\test\duplicate.txt"  # Should be first now
        }
        
        It "Should clear recent files" {
            $script:service.AddRecentFile("C:\test\file.txt")
            $script:service.ClearRecentFiles()
            
            $recentFiles = $script:service.GetRecentFiles()
            $recentFiles.Count | Should -Be 0
        }
        
        It "Should manage recent projects" {
            $script:service.AddRecentProject("PROJECT-001")
            $script:service.AddRecentProject("PROJECT-002")
            
            $recentProjects = $script:service.GetRecentProjects()
            $recentProjects.Count | Should -Be 2
            $recentProjects[0] | Should -Be "PROJECT-002"
        }
        
        It "Should manage recent searches" {
            $script:service.AddRecentSearch("git status")
            $script:service.AddRecentSearch("docker ps")
            
            $recentSearches = $script:service.GetRecentSearches()
            $recentSearches.Count | Should -Be 2
            $recentSearches[0] | Should -Be "docker ps"
        }
    }
    
    Context "Configuration Validation" {
        It "Should validate correct configuration" {
            $isValid = $script:service.ValidateConfiguration()
            $isValid | Should -Be $true
        }
        
        It "Should detect missing required sections" {
            # Remove required section
            $script:service.Settings.Remove("Application")
            
            $isValid = $script:service.ValidateConfiguration()
            $isValid | Should -Be $false
        }
        
        It "Should detect invalid log level" {
            $script:service.SetSetting("Application.LogLevel", "InvalidLevel")
            
            $isValid = $script:service.ValidateConfiguration()
            $isValid | Should -Be $false
        }
        
        It "Should detect missing theme" {
            $script:service.SetSetting("UI.Theme", "")
            
            $isValid = $script:service.ValidateConfiguration()
            $isValid | Should -Be $false
        }
    }
    
    Context "Reset Functionality" {
        It "Should reset to defaults" {
            # Modify settings
            $script:service.SetSetting("Application.Name", "ModifiedApp")
            $script:service.SetSetting("UI.Theme", "ModifiedTheme")
            
            # Reset
            $script:service.ResetToDefaults()
            
            # Verify reset
            $script:service.GetSetting("Application.Name") | Should -Be "SpeedTUI"
            $script:service.GetSetting("UI.Theme") | Should -Be "Default"
        }
        
        It "Should reset specific section" {
            # Modify UI section
            $script:service.SetSetting("UI.Theme", "ModifiedTheme")
            $script:service.SetSetting("UI.ShowBorders", $false)
            
            # Reset UI section only
            $script:service.ResetSection("UI")
            
            # Verify UI section reset
            $script:service.GetSetting("UI.Theme") | Should -Be "Default"
            $script:service.GetSetting("UI.ShowBorders") | Should -Be $true
        }
    }
    
    Context "Import/Export Functionality" {
        It "Should export configuration" {
            $script:service.SetSetting("Test.ExportSetting", "ExportValue")
            
            $exportData = $script:service.ExportConfiguration()
            
            $exportData | Should -BeOfType [hashtable]
            $exportData.ContainsKey("Version") | Should -Be $true
            $exportData.ContainsKey("ExportDate") | Should -Be $true
            $exportData.ContainsKey("Settings") | Should -Be $true
            $exportData.Settings.Test.ExportSetting | Should -Be "ExportValue"
        }
        
        It "Should import configuration" {
            $importData = @{
                Settings = @{
                    Application = @{
                        Name = "ImportedApp"
                    }
                    Test = @{
                        ImportSetting = "ImportValue"
                    }
                }
            }
            
            $script:service.ImportConfiguration($importData)
            
            $script:service.GetSetting("Application.Name") | Should -Be "ImportedApp"
            $script:service.GetSetting("Test.ImportSetting") | Should -Be "ImportValue"
            
            # Should retain defaults for unspecified settings
            $script:service.GetSetting("Application.AutoSave") | Should -Be $true
        }
        
        It "Should backup configuration" {
            $script:service.SetSetting("Test.BackupSetting", "BackupValue")
            $script:service.BackupConfiguration()
            
            # Check that backup file was created (pattern: config_backup_*)
            $backupFiles = Get-ChildItem -Path $script:TestDataPath -Filter "config_backup_*.json"
            $backupFiles.Count | Should -BeGreaterThan 0
        }
    }
    
    Context "Utility Methods" {
        It "Should get all settings" {
            $allSettings = $script:service.GetAllSettings()
            $allSettings | Should -BeOfType [hashtable]
            $allSettings.ContainsKey("Application") | Should -Be $true
            $allSettings.ContainsKey("UI") | Should -Be $true
        }
        
        It "Should generate configuration summary" {
            $summary = $script:service.GetConfigurationSummary()
            $summary | Should -Not -BeNullOrEmpty
            $summary | Should -Match "SpeedTUI Configuration Summary"
            $summary | Should -Match "Version: 1.0"
            $summary | Should -Match "Theme: Default"
        }
        
        It "Should enable debug mode" {
            $script:service.EnableDebugMode()
            
            $script:service.GetSetting("Advanced.EnableDebugMode") | Should -Be $true
            $script:service.GetSetting("Application.LogLevel") | Should -Be "Debug"
        }
        
        It "Should disable debug mode" {
            $script:service.EnableDebugMode()  # Enable first
            $script:service.DisableDebugMode()
            
            $script:service.GetSetting("Advanced.EnableDebugMode") | Should -Be $false
            $script:service.GetSetting("Application.LogLevel") | Should -Be "Info"
        }
        
        It "Should check debug mode status" {
            $script:service.IsDebugMode() | Should -Be $false
            
            $script:service.EnableDebugMode()
            $script:service.IsDebugMode() | Should -Be $true
        }
        
        It "Should toggle auto save" {
            $originalAutoSave = $script:service.GetSetting("Application.AutoSave")
            $script:service.ToggleAutoSave()
            
            $newAutoSave = $script:service.GetSetting("Application.AutoSave")
            $newAutoSave | Should -Be (-not $originalAutoSave)
        }
    }
    
    Context "Configuration Presets" {
        It "Should load developer preset" {
            $script:service.LoadDeveloperPreset()
            
            $script:service.GetSetting("Advanced.EnableDebugMode") | Should -Be $true
            $script:service.GetSetting("Application.LogLevel") | Should -Be "Debug"
            $script:service.GetSetting("UI.ShowLineNumbers") | Should -Be $true
            $script:service.GetSetting("Advanced.ShowPerformanceMetrics") | Should -Be $true
        }
        
        It "Should load production preset" {
            $script:service.LoadProductionPreset()
            
            $script:service.GetSetting("Advanced.EnableDebugMode") | Should -Be $false
            $script:service.GetSetting("Application.LogLevel") | Should -Be "Warning"
            $script:service.GetSetting("Network.EnableUpdates") | Should -Be $false
            $script:service.GetSetting("Files.AutoBackup") | Should -Be $true
        }
        
        It "Should load minimal preset" {
            $script:service.LoadMinimalPreset()
            
            $script:service.GetSetting("UI.ShowBorders") | Should -Be $false
            $script:service.GetSetting("UI.ShowStatusBar") | Should -Be $false
            $script:service.GetSetting("UI.ShowToolbar") | Should -Be $false
            $script:service.GetSetting("Commands.ShowUsageCount") | Should -Be $false
        }
    }
    
    Context "Error Handling and Edge Cases" {
        It "Should handle invalid section in reset" {
            # Should not throw error for invalid section
            { $script:service.ResetSection("NonExistentSection") } | Should -Not -Throw
        }
        
        It "Should handle malformed import data" {
            $malformedData = @{
                # Missing Settings key
                Version = "1.0"
            }
            
            { $script:service.ImportConfiguration($malformedData) } | Should -Not -Throw
            
            # Settings should remain unchanged
            $script:service.GetSetting("Application.Name") | Should -Be "SpeedTUI"
        }
        
        It "Should handle deep nested path creation" {
            $script:service.SetSetting("Deep.Nested.Path.Setting", "DeepValue")
            $result = $script:service.GetSetting("Deep.Nested.Path.Setting")
            $result | Should -Be "DeepValue"
        }
        
        It "Should handle removal of non-existent setting" {
            { $script:service.RemoveSetting("NonExistent.Setting") } | Should -Not -Throw
        }
        
        It "Should handle empty path in GetSetting" {
            $result = $script:service.GetSetting("")
            $result | Should -BeNull
        }
        
        It "Should handle null values in settings" {
            $script:service.SetSetting("Test.NullSetting", $null)
            $result = $script:service.GetSetting("Test.NullSetting")
            $result | Should -BeNull
        }
    }
    
    Context "AutoSave Behavior" {
        It "Should auto-save when enabled" {
            $script:service.AutoSave = $true
            $script:service.SetSetting("Test.AutoSaveSetting", "AutoSaveValue")
            
            # Check file was created
            $testFile = Join-Path $script:TestDataPath "test_config.json"
            Test-Path $testFile | Should -Be $true
        }
        
        It "Should not auto-save when disabled" {
            $script:service.AutoSave = $false
            $script:service.SetSetting("Test.NoAutoSaveSetting", "NoAutoSaveValue")
            
            # File should not exist yet
            $testFile = Join-Path $script:TestDataPath "test_config.json"
            Test-Path $testFile | Should -Be $false
        }
    }
    
    Context "Settings Merge Logic" {
        It "Should properly merge nested hashtables" {
            $defaults = @{
                Section1 = @{
                    Setting1 = "Default1"
                    Setting2 = "Default2"
                }
                Section2 = @{
                    Setting3 = "Default3"
                }
            }
            
            $current = @{
                Section1 = @{
                    Setting1 = "Override1"  # Override existing
                    Setting4 = "New4"       # Add new
                }
                Section3 = @{              # New section
                    Setting5 = "New5"
                }
            }
            
            $merged = $script:service.MergeSettings($defaults, $current)
            
            # Check overrides
            $merged.Section1.Setting1 | Should -Be "Override1"
            # Check defaults preserved
            $merged.Section1.Setting2 | Should -Be "Default2"
            # Check new settings added
            $merged.Section1.Setting4 | Should -Be "New4"
            $merged.Section3.Setting5 | Should -Be "New5"
            # Check default sections preserved
            $merged.Section2.Setting3 | Should -Be "Default3"
        }
    }
}