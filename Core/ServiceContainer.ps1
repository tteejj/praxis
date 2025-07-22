# ServiceContainer.ps1 - Lightweight dependency injection
# Simplified from AxiomPhoenix for PRAXIS

class ServiceContainer {
    hidden [hashtable]$_services = @{}
    hidden [hashtable]$_factories = @{}
    
    # Register a service instance
    [void] Register([string]$name, [object]$instance) {
        if ([string]::IsNullOrWhiteSpace($name)) {
            throw "Service name cannot be empty"
        }
        if ($null -eq $instance) {
            throw "Service instance cannot be null"
        }
        if ($this._services.ContainsKey($name) -or $this._factories.ContainsKey($name)) {
            throw "Service '$name' is already registered"
        }
        
        $this._services[$name] = $instance
    }
    
    # Register a factory for lazy initialization
    [void] RegisterFactory([string]$name, [scriptblock]$factory, [bool]$singleton = $true) {
        if ([string]::IsNullOrWhiteSpace($name)) {
            throw "Service name cannot be empty"
        }
        if ($null -eq $factory) {
            throw "Factory cannot be null"
        }
        if ($this._services.ContainsKey($name) -or $this._factories.ContainsKey($name)) {
            throw "Service '$name' is already registered"
        }
        
        $this._factories[$name] = @{
            Factory = $factory
            Singleton = $singleton
            Instance = $null
        }
    }
    
    # Get a service by name
    [object] GetService([string]$name) {
        if ([string]::IsNullOrWhiteSpace($name)) {
            throw "Service name cannot be empty"
        }
        
        # Check eager instances first
        if ($this._services.ContainsKey($name)) {
            return $this._services[$name]
        }
        
        # Check factories
        if ($this._factories.ContainsKey($name)) {
            $factory = $this._factories[$name]
            
            # Return cached singleton if available
            if ($factory.Singleton -and $null -ne $factory.Instance) {
                return $factory.Instance
            }
            
            # Create new instance
            $instance = & $factory.Factory $this
            
            # Cache if singleton
            if ($factory.Singleton) {
                $factory.Instance = $instance
            }
            
            return $instance
        }
        
        throw "Service '$name' not found. Available: $($this.GetServiceNames() -join ', ')"
    }
    
    # Get all registered service names
    [string[]] GetServiceNames() {
        $names = @()
        $names += $this._services.Keys
        $names += $this._factories.Keys
        return $names | Sort-Object
    }
    
    # Cleanup all services
    [void] Cleanup() {
        # Dispose any IDisposable services
        $allInstances = @()
        $allInstances += $this._services.Values
        $allInstances += $this._factories.Values | Where-Object { $_.Instance } | ForEach-Object { $_.Instance }
        
        foreach ($instance in $allInstances) {
            if ($instance -is [System.IDisposable]) {
                try {
                    $instance.Dispose()
                } catch {
                    # Ignore disposal errors
                }
            }
        }
        
        $this._services.Clear()
        $this._factories.Clear()
    }
}

# Global service container instance
$global:ServiceContainer = [ServiceContainer]::new()