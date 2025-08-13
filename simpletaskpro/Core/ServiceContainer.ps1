# Core/ServiceContainer.ps1 - Initializes and provides access to all core services.
# Inspired by Praxis but kept simple for buildability

class ServiceContainer {
    hidden [hashtable]$_services = @{}

    [void] Initialize([string]$appRootPath) {
        [Logger]::Info("Initializing ServiceContainer from path: $appRootPath")
        
        # 1. Settings Service (must be first)
        $settings = [SettingsService]::new($appRootPath)
        $this.Register("SettingsService", $settings)
        [Logger]::Info("SettingsService registered")

        # 2. Logger (depends on settings) - already initialized but register for access
        $logPath = Join-Path $appRootPath ($settings.Get("Logging.Path"))
        $logLevelStr = $settings.Get("Logging.Level")
        $logLevel = [LogLevel]::$logLevelStr
        [Logger]::Initialize($logPath, $logLevel)
        [Logger]::Info("Logger initialized with level: $logLevelStr")

        # 3. Event Bus (no dependencies) - register the static class for consistency
        $this.Register("EventBus", [EventBus])
        [Logger]::Info("EventBus registered")

        [Logger]::Info("ServiceContainer initialization complete")
    }

    [void] Register([string]$name, [object]$instance) {
        if ([string]::IsNullOrWhiteSpace($name)) {
            throw "Service name cannot be empty"
        }
        if ($null -eq $instance) {
            throw "Service instance cannot be null"
        }
        if ($this._services.ContainsKey($name)) {
            [Logger]::Warn("Service '$name' already registered, replacing")
        }
        
        $this._services[$name] = $instance
        [Logger]::Debug("Registered service: $name")
    }

    [object] GetService([string]$name) {
        if ([string]::IsNullOrWhiteSpace($name)) {
            [Logger]::Error("GetService called with empty name")
            return $null
        }
        
        if ($this._services.ContainsKey($name)) {
            return $this._services[$name]
        }
        
        [Logger]::Error("Attempted to resolve unregistered service: $name. Available services: $($this.GetServiceNames() -join ', ')")
        return $null
    }

    # Get all registered service names (for debugging)
    [string[]] GetServiceNames() {
        return $this._services.Keys | Sort-Object
    }

    # Cleanup services (for shutdown)
    [void] Cleanup() {
        [Logger]::Info("ServiceContainer cleanup starting")
        
        # Dispose any IDisposable services
        foreach ($serviceName in $this._services.Keys) {
            $service = $this._services[$serviceName]
            if ($service -is [System.IDisposable]) {
                try {
                    $service.Dispose()
                    [Logger]::Debug("Disposed service: $serviceName")
                } catch {
                    [Logger]::Warn("Error disposing service $serviceName : $_")
                }
            }
        }
        
        $this._services.Clear()
        [Logger]::Info("ServiceContainer cleanup complete")
    }
}