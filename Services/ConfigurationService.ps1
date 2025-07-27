# ConfigurationService.ps1 - Configuration management with persistence

class ConfigurationService {
    hidden [string]$ConfigPath
    hidden [hashtable]$Config
    hidden [hashtable]$Defaults
    hidden [bool]$AutoSave = $true
    
    ConfigurationService() {
        $this.ConfigPath = Join-Path $global:PraxisRoot "_Config" "settings.json"
        $this.InitializeDefaults()
        $this.Load()
    }
    
    ConfigurationService([string]$configPath) {
        $this.ConfigPath = $configPath
        $this.InitializeDefaults()
        $this.Load()
    }
    
    hidden [void] InitializeDefaults() {
        $this.Defaults = @{
            Theme = @{
                CurrentTheme = "default"
                AvailableThemes = @("default", "matrix", "amber")
                EditTheme = "[Click to open theme editor]"
                UserCustomizations = @{}
                EnableLiveEdit = $true
                ShowThemePreview = $true
            }
            Editor = @{
                TabSize = 4
                WordWrap = $false
                ShowLineNumbers = $true
                HighlightCurrentLine = $true
                AutoSaveInterval = 0  # 0 = disabled, otherwise minutes
                SyntaxHighlighting = $true
            }
            FileBrowser = @{
                DefaultPath = (Get-Location).Path
                ShowHiddenFiles = $false
                IgnoredExtensions = @(".tmp", ".cache", ".log")
                SortBy = "Name"  # Name, Date, Size
                SortDescending = $false
                ShowFileSize = $true
                ShowModifiedDate = $false
            }
            UI = @{
                AnimationsEnabled = $true
                ShowScrollbars = $true
                CompactMode = $false
                VerticalSpacing = 1  # Lines between UI elements
                UseGradients = $false
                GradientType = "vertical"  # vertical or horizontal
            }
            Projects = @{
                DefaultPath = Join-Path $global:PraxisRoot "_ProjectData"
                AutoSave = $true
                BackupEnabled = $true
                BackupCount = 5
            }
            Tasks = @{
                DefaultPriority = "Medium"
                ShowCompletedTasks = $true
                CompletedTaskRetention = 30  # days
            }
            Performance = @{
                EnableCaching = $true
                MaxCacheSize = 100  # MB
                RenderOptimization = $true
            }
            Logging = @{
                Level = "Info"
                MaxFileSize = 10  # MB
                MaxFiles = 5
            }
        }
    }
    
    [void] Load() {
        # Ensure config directory exists
        $configDir = Split-Path -Parent $this.ConfigPath
        if (-not (Test-Path $configDir)) {
            New-Item -ItemType Directory -Path $configDir -Force | Out-Null
        }
        
        # Load config from file or use defaults
        if (Test-Path $this.ConfigPath) {
            try {
                $json = Get-Content -Path $this.ConfigPath -Raw
                $loaded = $json | ConvertFrom-Json -AsHashtable
                
                # Merge with defaults to ensure all keys exist
                $this.Config = $this.MergeHashtables($this.Defaults, $loaded)
                
                if ($global:Logger) {
                    $global:Logger.Info("Configuration loaded from: $($this.ConfigPath)")
                }
            } catch {
                Write-Warning "Failed to load configuration: $_"
                $this.Config = $this.Defaults.Clone()
            }
        } else {
            # No config file, use defaults and save
            $this.Config = $this.Defaults.Clone()
            $this.Save()
        }
    }
    
    [void] Save() {
        try {
            $json = $this.Config | ConvertTo-Json -Depth 10 -Compress:$false
            Set-Content -Path $this.ConfigPath -Value $json -Encoding UTF8
            
            if ($global:Logger) {
                $global:Logger.Debug("Configuration saved to: $($this.ConfigPath)")
            }
        } catch {
            Write-Warning "Failed to save configuration: $_"
        }
    }
    
    # Deep merge hashtables, preserving structure
    hidden [hashtable] MergeHashtables([hashtable]$base, [hashtable]$overlay) {
        $result = $base.Clone()
        
        foreach ($key in $overlay.Keys) {
            if ($base.ContainsKey($key) -and $base[$key] -is [hashtable] -and $overlay[$key] -is [hashtable]) {
                # Recursively merge nested hashtables
                $result[$key] = $this.MergeHashtables($base[$key], $overlay[$key])
            } else {
                # Overlay value takes precedence
                $result[$key] = $overlay[$key]
            }
        }
        
        return $result
    }
    
    # Get configuration value with dot notation support
    [object] Get([string]$path) {
        return $this.Get($path, $null)
    }
    
    [object] Get([string]$path, $default) {
        $parts = $path -split '\.'
        $current = $this.Config
        
        foreach ($part in $parts) {
            if ($current -is [hashtable] -and $current.ContainsKey($part)) {
                $current = $current[$part]
            } else {
                return $default
            }
        }
        
        return $current
    }
    
    # Set configuration value with dot notation support
    [void] Set([string]$path, $value) {
        $parts = $path -split '\.'
        $current = $this.Config
        
        # Navigate to the parent of the target
        for ($i = 0; $i -lt $parts.Count - 1; $i++) {
            $part = $parts[$i]
            
            if (-not $current.ContainsKey($part)) {
                $current[$part] = @{}
            } elseif ($current[$part] -isnot [hashtable]) {
                # Path conflict - convert to hashtable
                $current[$part] = @{}
            }
            
            $current = $current[$part]
        }
        
        # Set the final value
        $lastPart = $parts[-1]
        $current[$lastPart] = $value
        
        # Auto-save if enabled
        if ($this.AutoSave) {
            $this.Save()
        }
    }
    
    # Check if configuration key exists
    [bool] Has([string]$path) {
        $parts = $path -split '\.'
        $current = $this.Config
        
        foreach ($part in $parts) {
            if ($current -is [hashtable] -and $current.ContainsKey($part)) {
                $current = $current[$part]
            } else {
                return $false
            }
        }
        
        return $true
    }
    
    # Remove configuration key
    [void] Remove([string]$path) {
        $parts = $path -split '\.'
        $current = $this.Config
        
        # Navigate to the parent of the target
        for ($i = 0; $i -lt $parts.Count - 1; $i++) {
            $part = $parts[$i]
            
            if ($current -is [hashtable] -and $current.ContainsKey($part)) {
                $current = $current[$part]
            } else {
                # Path doesn't exist
                return
            }
        }
        
        # Remove the final key
        $lastPart = $parts[-1]
        if ($current -is [hashtable] -and $current.ContainsKey($lastPart)) {
            $current.Remove($lastPart)
            
            # Auto-save if enabled
            if ($this.AutoSave) {
                $this.Save()
            }
        }
    }
    
    # Reset to defaults
    [void] Reset() {
        $this.Config = $this.Defaults.Clone()
        $this.Save()
    }
    
    # Reset specific section to defaults
    [void] ResetSection([string]$section) {
        if ($this.Defaults.ContainsKey($section)) {
            $this.Config[$section] = $this.Defaults[$section].Clone()
            
            if ($this.AutoSave) {
                $this.Save()
            }
        }
    }
    
    # Get all configuration as hashtable
    [hashtable] GetAll() {
        return $this.Config.Clone()
    }
    
    # Import configuration from hashtable
    [void] Import([hashtable]$config) {
        $this.Config = $this.MergeHashtables($this.Defaults, $config)
        
        if ($this.AutoSave) {
            $this.Save()
        }
    }
    
    # Export configuration to file
    [void] Export([string]$path) {
        try {
            $json = $this.Config | ConvertTo-Json -Depth 10 -Compress:$false
            Set-Content -Path $path -Value $json -Encoding UTF8
        } catch {
            throw "Failed to export configuration: $_"
        }
    }
}