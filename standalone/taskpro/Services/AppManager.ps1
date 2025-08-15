# AppManager.ps1 - Orchestrates multiple apps within TaskPro
# Handles lazy loading, service management, and app switching

# Module-level variables for reliable state management
$script:AppManagerBasePath = ""
$script:AppManagerInitialized = $false

class AppManager {
    # Static properties for global app management
    static [hashtable]$Services = @{}
    static [hashtable]$Screens = @{}
    static [hashtable]$LoadedApps = @{}
    
    # App definitions
    static [hashtable]$AppDefinitions = @{
        "CommandLibrary" = @{
            ServiceClass = "CommandService"
            ScreenClass = "CommandLibraryScreen"
            RequiredFiles = @(
                "Models/External/Command.ps1",
                "Services/External/CommandService.ps1",
                "Screens/External/CommandEditDialog.ps1",
                "Screens/External/CommandListScreen.ps1",
                "Screens/External/CommandLibraryScreen.ps1"
            )
            Dependencies = @(
                "Core/StringCache.ps1",
                "Services/PraxisDataService.ps1",
                "Services/UnifiedThemeService.ps1",
                "Components/Shared/VT100.ps1",
                "Components/Shared/ColorThemeService.ps1",
                "Components/Shared/PillboxRenderer.ps1",
                "Components/Shared/SimpleListBox.ps1",
                "Components/Shared/SimpleDialog.ps1"
            )
        }
        "TimeTracker" = @{
            ServiceClass = "TimeTrackingService"
            ScreenClass = "TimeListScreen"
            RequiredFiles = @(
                "Models/External/SimpleTimeEntry.ps1",
                "Services/External/TimeTrackingService.ps1",
                "Screens/External/TimeListScreen.ps1"
            )
            Dependencies = @(
                "Core/StringCache.ps1",
                "Services/PraxisDataService.ps1",
                "Components/Shared/VT100.ps1"
            )
        }
    }
    
    # Initialize the AppManager
    static [void] Initialize([string]$basePath) {
        if ($script:AppManagerInitialized) { return }
        
        $script:AppManagerBasePath = $basePath
        $script:AppManagerInitialized = $true
        
        Write-Host "AppManager initialized from: $basePath" -ForegroundColor DarkGray
        Write-Host "BasePath set to: $script:AppManagerBasePath" -ForegroundColor DarkGray
    }
    
    # Check if an app is available (all required files exist)
    static [bool] IsAppAvailable([string]$appName) {
        if (-not [AppManager]::AppDefinitions.ContainsKey($appName)) {
            return $false
        }
        
        $appDef = [AppManager]::AppDefinitions[$appName]
        
        # Check if all required files exist
        foreach ($file in $appDef.RequiredFiles) {
            $fullPath = Join-Path $script:AppManagerBasePath $file
            Write-Host "  Checking: $fullPath" -ForegroundColor DarkGray
            if (-not (Test-Path $fullPath)) {
                Write-Host "Missing required file for ${appName}: $file" -ForegroundColor Yellow
                Write-Host "  Full path checked: $fullPath" -ForegroundColor DarkGray
                return $false
            } else {
                Write-Host "  ✓ Found: $file" -ForegroundColor DarkGreen
            }
        }
        
        return $true
    }
    
    # Load an app's service (lazy loading)
    static [object] GetService([string]$appName) {
        # Return cached service if already loaded
        if ([AppManager]::Services.ContainsKey($appName)) {
            return [AppManager]::Services[$appName]
        }
        
        # Check if app is available
        if (-not [AppManager]::IsAppAvailable($appName)) {
            Write-Host "App $appName is not available" -ForegroundColor Yellow
            [AppManager]::Services[$appName] = $null
            return $null
        }
        
        # Load the service
        try {
            [AppManager]::LoadService($appName)
            return [AppManager]::Services[$appName]
        } catch {
            Write-Host "Failed to load $appName service: $_" -ForegroundColor Red
            [AppManager]::Services[$appName] = $null
            return $null
        }
    }
    
    # Load service implementation
    static [void] LoadService([string]$appName) {
        Write-Host "Loading $appName service..." -ForegroundColor DarkGray
        
        $appDef = [AppManager]::AppDefinitions[$appName]
        
        # Load dependencies first
        foreach ($dep in $appDef.Dependencies) {
            $depPath = Join-Path $script:AppManagerBasePath $dep
            if (Test-Path $depPath) {
                . $depPath
            }
        }
        
        # Initialize PraxisDataService if it was loaded and not already initialized
        try {
            $praxisDataType = Get-Command -Name "PraxisDataService" -ErrorAction SilentlyContinue
            if ($praxisDataType) {
                $isInitialized = Invoke-Expression "[PraxisDataService]::IsInitialized"
                if (-not $isInitialized) {
                    $dataPath = "/home/teej/projects/github/praxis/_ProjectData/praxis-unified.json"
                    Invoke-Expression "[PraxisDataService]::Initialize('$dataPath')"
                    Write-Host "  ✓ PraxisDataService initialized for $appName" -ForegroundColor DarkGray
                }
            }
        } catch {
            # PraxisDataService not available or already initialized
        }
        
        # Initialize UnifiedThemeService if it was loaded and not already initialized
        try {
            $unifiedThemeType = Get-Command -Name "UnifiedThemeService" -ErrorAction SilentlyContinue
            if ($unifiedThemeType) {
                $isInitialized = Invoke-Expression "[UnifiedThemeService]::IsInitialized"
                if (-not $isInitialized) {
                    $userDataPath = Join-Path $script:AppManagerBasePath "Data"
                    if (-not (Test-Path $userDataPath)) {
                        New-Item -ItemType Directory -Path $userDataPath -Force | Out-Null
                    }
                    Invoke-Expression "[UnifiedThemeService]::Initialize('$userDataPath')"
                    Write-Host "  ✓ UnifiedThemeService initialized for $appName" -ForegroundColor DarkGray
                }
            }
        } catch {
            # UnifiedThemeService not available or already initialized
        }
        
        # Load required files
        foreach ($file in $appDef.RequiredFiles) {
            $filePath = Join-Path $script:AppManagerBasePath $file
            Write-Host "  Loading: $file" -ForegroundColor DarkGray
            . $filePath
        }
        
        # Verify classes are loaded by attempting instantiation
        Write-Host "  Verifying service class $($appDef.ServiceClass)..." -ForegroundColor DarkGray
        try {
            $testService = New-Object $appDef.ServiceClass
            Write-Host "  ✓ Service class verified" -ForegroundColor DarkGreen
        } catch {
            throw "Service class verification failed: $_"
        }
        
        Write-Host "  Verifying screen class $($appDef.ScreenClass)..." -ForegroundColor DarkGray
        try {
            if ($appName -eq "CommandLibrary") {
                # CommandLibraryScreen requires CommandService parameter
                $testScreen = & { param($cls, $svc) New-Object $cls -ArgumentList $svc } $appDef.ScreenClass $testService
            } else {
                # TimeListScreen and others use parameterless constructor
                $testScreen = New-Object $appDef.ScreenClass
            }
            Write-Host "  ✓ Screen class verified" -ForegroundColor DarkGreen
        } catch {
            throw "Screen class verification failed: $_"
        }
        
        # Create service instance dynamically after classes are loaded
        $serviceClass = $appDef.ServiceClass
        try {
            $service = New-Object $serviceClass
            [AppManager]::Services[$appName] = $service
        } catch {
            throw "Failed to create $serviceClass instance: $_"
        }
        
        # Create screen immediately in the same scope where classes are available
        Write-Host "  Creating screen in LoadService scope..." -ForegroundColor DarkGray
        try {
            if ($appName -eq "CommandLibrary") {
                $screen = & { param($cls, $svc) New-Object $cls -ArgumentList $svc } $appDef.ScreenClass $service
                [AppManager]::Screens[$appName] = $screen
            } elseif ($appName -eq "TimeTracker") {
                $screen = & { param($cls) New-Object $cls } $appDef.ScreenClass
                $screen.TimeService = $service
                [AppManager]::Screens[$appName] = $screen
            }
            Write-Host "  ✓ Screen created in same scope" -ForegroundColor DarkGreen
        } catch {
            Write-Host "  ✗ Screen creation failed: $_" -ForegroundColor Red
            # Continue without screen - we'll try creating it later if needed
        }
        
        [AppManager]::LoadedApps[$appName] = $true
        Write-Host "✓ $appName service loaded successfully" -ForegroundColor Green
    }
    
    # Get or create a screen for an app
    static [object] GetScreen([string]$appName) {
        # Return cached screen if already created
        if ([AppManager]::Screens.ContainsKey($appName)) {
            Write-Host "Using cached screen for $appName" -ForegroundColor DarkGray
            return [AppManager]::Screens[$appName]
        }
        
        # Get the service first - this will also try to create the screen
        $service = [AppManager]::GetService($appName)
        if ($service -eq $null) {
            return $null
        }
        
        # Check if screen was created during service loading
        if ([AppManager]::Screens.ContainsKey($appName)) {
            Write-Host "Screen was created during service loading for $appName" -ForegroundColor DarkGray
            return [AppManager]::Screens[$appName]
        }
        
        # If screen creation during loading failed, try the legacy approach
        Write-Host "Attempting legacy screen creation for $appName" -ForegroundColor Yellow
        try {
            [AppManager]::CreateScreen($appName, $service)
            return [AppManager]::Screens[$appName]
        } catch {
            Write-Host "Failed to create $appName screen: $_" -ForegroundColor Red
            return $null
        }
    }
    
    # Create screen implementation
    static [void] CreateScreen([string]$appName, [object]$service) {
        Write-Host "Creating $appName screen..." -ForegroundColor DarkGray
        
        $appDef = [AppManager]::AppDefinitions[$appName]
        $screenClass = $appDef.ScreenClass
        
        try {
            # Create screen instance using the verified class name
            if ($appName -eq "CommandLibrary") {
                # Create CommandLibraryScreen with service parameter
                $screen = & { param($cls, $svc) New-Object $cls -ArgumentList $svc } $screenClass $service
                [AppManager]::Screens[$appName] = $screen
            } elseif ($appName -eq "TimeTracker") {
                # Create TimeListScreen without parameters, then set service
                $screen = & { param($cls) New-Object $cls } $screenClass
                $screen.TimeService = $service
                [AppManager]::Screens[$appName] = $screen
            } else {
                throw "Unknown app screen: $appName"
            }
        } catch {
            throw "Failed to create $screenClass instance: $_"
        }
        
        Write-Host "✓ $appName screen created successfully" -ForegroundColor Green
    }
    
    # Get list of available apps
    static [string[]] GetAvailableApps() {
        $available = @()
        foreach ($appName in [AppManager]::AppDefinitions.Keys) {
            if ([AppManager]::IsAppAvailable($appName)) {
                $available += $appName
            }
        }
        return $available
    }
    
    # Get list of loaded apps
    static [string[]] GetLoadedApps() {
        return [AppManager]::LoadedApps.Keys
    }
    
    # Unload an app (free memory)
    static [void] UnloadApp([string]$appName) {
        if ([AppManager]::Services.ContainsKey($appName)) {
            [AppManager]::Services.Remove($appName)
        }
        if ([AppManager]::Screens.ContainsKey($appName)) {
            [AppManager]::Screens.Remove($appName)
        }
        if ([AppManager]::LoadedApps.ContainsKey($appName)) {
            [AppManager]::LoadedApps.Remove($appName)
        }
        Write-Host "✓ $appName unloaded" -ForegroundColor Yellow
    }
    
    # Get app status information
    static [hashtable] GetAppStatus([string]$appName) {
        return @{
            Name = $appName
            Available = [AppManager]::IsAppAvailable($appName)
            ServiceLoaded = [AppManager]::Services.ContainsKey($appName) -and ([AppManager]::Services[$appName] -ne $null)
            ScreenCreated = [AppManager]::Screens.ContainsKey($appName)
            LoadedAt = if ([AppManager]::LoadedApps.ContainsKey($appName)) { Get-Date } else { $null }
        }
    }
    
    # Get status of all apps
    static [hashtable[]] GetAllAppStatus() {
        $statuses = @()
        foreach ($appName in [AppManager]::AppDefinitions.Keys) {
            $statuses += [AppManager]::GetAppStatus($appName)
        }
        return $statuses
    }
}