# Core/ServiceContainer-Phase4.5.ps1 - Simple service container for Phase 4.5 architecture
# No static dependencies, just pure dependency injection

class ServiceContainer {
    hidden [hashtable]$_services = @{}

    ServiceContainer() {
        # Simple constructor - no automatic initialization
    }

    [void] Register([string]$name, [object]$instance) {
        if ([string]::IsNullOrWhiteSpace($name)) {
            throw "Service name cannot be null or empty"
        }
        
        if ($null -eq $instance) {
            throw "Service instance cannot be null"
        }
        
        if ($this._services.ContainsKey($name)) {
            # Replace existing service (useful for testing)
            $this._services[$name] = $instance
        } else {
            $this._services[$name] = $instance
        }
    }

    [object] GetService([string]$name) {
        if ([string]::IsNullOrWhiteSpace($name)) {
            throw "Service name cannot be null or empty"
        }
        
        if (-not $this._services.ContainsKey($name)) {
            throw "Service '$name' is not registered"
        }
        
        return $this._services[$name]
    }

    [bool] IsRegistered([string]$name) {
        return $this._services.ContainsKey($name)
    }

    [string[]] GetRegisteredServices() {
        return $this._services.Keys
    }

    [void] Cleanup() {
        # Cleanup services that support it
        foreach ($service in $this._services.Values) {
            if ($service -and $service.PSObject.Methods['Cleanup']) {
                try {
                    $service.Cleanup()
                } catch {
                    # Ignore cleanup errors
                }
            }
        }
        
        $this._services.Clear()
    }
}