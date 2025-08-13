# Core/Bootstrapper.ps1 - The SINGLE entry point for creating the application and its services.

class Bootstrapper {
    static [object] $ServiceContainer = $null
    static [bool] $IsInitialized = $false

    static [object] Initialize([string]$appRootPath) {
        if ([Bootstrapper]::IsInitialized) { throw "Bootstrapper: Application already initialized" }

        $logger = $null
        try {
            # Step 1: Create Service Container and Core Singletons
            [Bootstrapper]::ServiceContainer = [ServiceContainer]::new()
            $eventBus = [EventBus]::new()
            [Bootstrapper]::ServiceContainer.Register("EventBus", $eventBus)
            $logger = [Logger]::new()
            $logger.Initialize($appRootPath, [LogLevel]::Debug)
            [Bootstrapper]::ServiceContainer.Register("Logger", $logger)

            # Step 2: Create and Register ALL Services (BEFORE the app)
            $logger.Debug("Registering all application services...")
            [StringCache]::Initialize()
            $stateManager = [SimpleStateManager]::new($eventBus, $logger)
            [Bootstrapper]::ServiceContainer.Register("StateManager", $stateManager)
            $inputProcessor = [InputProcessor]::new($eventBus, $stateManager, $logger, $appRootPath)
            [Bootstrapper]::ServiceContainer.Register("InputProcessor", $inputProcessor)
            $renderEngine = [RenderEngine]::new($logger)
            [Bootstrapper]::ServiceContainer.Register("RenderEngine", $renderEngine)
            $contentBuilder = [FastLineBuilder]::new()
            [Bootstrapper]::ServiceContainer.Register("ContentBuilder", $contentBuilder)
            $taskService = [SimpleTaskService]::new()
            [Bootstrapper]::ServiceContainer.Register("SimpleTaskService", $taskService)
            $timeTrackingService = [TimeTrackingService]::new()
            [Bootstrapper]::ServiceContainer.Register("TimeTrackingService", $timeTrackingService)
            $commandService = [CommandService]::new()
            [Bootstrapper]::ServiceContainer.Register("CommandService", $commandService)
            $excelMappingService = [ExcelMappingService]::new()
            [Bootstrapper]::ServiceContainer.Register("ExcelMappingService", $excelMappingService)
            $keyMappingService = [KeyMappingService]::new()
            [Bootstrapper]::ServiceContainer.Register("KeyMappingService", $keyMappingService)

            # Step 3: Initialize Static Managers
            [AppThemeManager]::ApplyTheme("amber")

            # Step 4: Create the Main Application Launcher
            $app = [SimpleTaskProApp]::new([Bootstrapper]::ServiceContainer)
            
            [Bootstrapper]::IsInitialized = $true
            $logger.Info("SimpleTaskPro initialization complete.")
            return $app
        } catch {
            if ($logger) { $logger.Error("Bootstrapper: Critical error during initialization", $_) }
            throw
        }
    }

    # Get the global service container
    static [object] GetServiceContainer() {
        if (-not [Bootstrapper]::ServiceContainer) {
            throw "Bootstrapper: Application not initialized. Call Initialize() first."
        }
        return [Bootstrapper]::ServiceContainer
    }

    # Safe application shutdown
    static [void] Cleanup() {
        try {
            # Get logger if available
            $logger = $null
            if ([Bootstrapper]::ServiceContainer) {
                try { $logger = [Bootstrapper]::ServiceContainer.GetService("Logger") } catch { }
            }
            
            if ($logger) {
                $logger.Info("Bootstrapper: Beginning application cleanup")
            }
            
            # Cleanup services in reverse order
            if ([Bootstrapper]::ServiceContainer) {
                $renderEngine = [Bootstrapper]::ServiceContainer.GetService("RenderEngine")
                if ($renderEngine) {
                    $renderEngine.RestoreConsole()
                }
                
                [Bootstrapper]::ServiceContainer.Cleanup()
            }
            
            # Clear static state
            [StringCache]::ClearCaches()
            
            [Bootstrapper]::ServiceContainer = $null
            [Bootstrapper]::IsInitialized = $false
            
            Write-Host "SimpleTaskPro cleanup complete" -ForegroundColor Yellow
            
        } catch {
            Write-Host "Error during cleanup: $_" -ForegroundColor Red
        }
    }
    
    # Emergency cleanup for crash scenarios
    static [void] EmergencyCleanup() {
        try {
            # Try to restore console state
            [Console]::ResetColor()
            [Console]::CursorVisible = $true
            
            if ([Bootstrapper]::ServiceContainer) {
                $renderEngine = [Bootstrapper]::ServiceContainer.GetService("RenderEngine") 
                if ($renderEngine) {
                    $renderEngine.EmergencyClear()
                }
            }
            
        } catch {
            # Last resort - just show cursor
            try { 
                [Console]::Write("`e[?25h`e[0m")
                [Console]::Clear()
            } catch { }
        }
    }
}