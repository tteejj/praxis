# Core/SettingsService.ps1 - Manages all application configuration.

class SettingsService {
    hidden [string]$_settingsPath
    hidden [hashtable]$_settings
    hidden [hashtable]$_defaults

    SettingsService([string]$configPath) {
        $this._settingsPath = Join-Path $configPath "settings.json"
        $this._defaults = @{
            "Logging.Path" = "Logs"
            "Logging.Level" = "Info"
            "Data.TasksFile" = "Data/tasks.json"
            "Data.TimeFile" = "Data/timeentries.json"
            "UI.AnimationEnabled" = $true
            "UI.AnimationDurationMS" = 150
            "UI.DefaultTheme" = "Default"
        }
        $this.Load()
    }

    [void] Load() {
        if (-not (Test-Path $this._settingsPath)) {
            $this._settings = $this._defaults.Clone()
            $this.Save()
        } else {
            try {
                $json = Get-Content $this._settingsPath -Raw -Encoding UTF8
                $this._settings = ConvertFrom-Json $json -AsHashtable
                # Ensure all default keys exist
                foreach ($key in $this._defaults.Keys) {
                    if (-not $this._settings.ContainsKey($key)) {
                        $this._settings[$key] = $this._defaults[$key]
                    }
                }
            } catch {
                Write-Warning "Could not load settings file. Using defaults. Error: $_"
                $this._settings = $this._defaults.Clone()
            }
        }
    }

    [void] Save() {
        try {
            $configDir = Split-Path -Parent $this._settingsPath
            if (-not (Test-Path $configDir)) {
                New-Item -ItemType Directory -Path $configDir -Force | Out-Null
            }
            $json = ConvertTo-Json $this._settings -Depth 10
            [System.IO.File]::WriteAllText($this._settingsPath, $json)
        } catch {
            [Logger]::Error("Failed to save settings to $($this._settingsPath)", $_)
        }
    }

    [object] Get([string]$key) {
        if ($this._settings.ContainsKey($key)) {
            return $this._settings[$key]
        }
        [Logger]::Warn("Tried to access non-existent setting '$key'. Returning null.")
        return $null
    }

    [void] Set([string]$key, [object]$value) {
        $this._settings[$key] = $value
        $this.Save()
    }
}