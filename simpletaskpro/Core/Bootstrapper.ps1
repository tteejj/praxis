# Core/Bootstrapper.ps1 - Application initialization with Phase 1 services
# Safe, predictable startup sequence for SimpleTaskPro

class Bootstrapper {
    static [ServiceContainer]$ServiceContainer = $null
    static [bool]$IsInitialized = $false
    
    # Initialize the entire application with new Phase 1 architecture
    static [SimpleTaskProApp] Initialize([string]$appRootPath) {
        if ([Bootstrapper]::IsInitialized) {
            throw "Bootstrapper: Application already initialized"
        }
        
        try {
            Write-Host "SimpleTaskPro starting..." -ForegroundColor Green
            
            # Step 1: Initialize Service Container
            [Bootstrapper]::ServiceContainer = [ServiceContainer]::new()
            
            # Step 1.5: Create EventBus and Logger singletons and register them
            $eventBus = [EventBus]::new()
            [Bootstrapper]::ServiceContainer.Register("EventBus", $eventBus)
            
            $logger = [Logger]::new()
            # Initialize the logger with proper path and level
            $logger.Initialize($appRootPath, [LogLevel]::Debug)
            [Bootstrapper]::ServiceContainer.Register("Logger", $logger)
            
            # Step 2: Register additional services needed by existing app
            [Bootstrapper]::RegisterExistingServices()
            
            # Step 3: Initialize StringCache for performance
            [StringCache]::Initialize()
            
            # Step 4: Create SimpleStateManager and register it
            $eventBus = [Bootstrapper]::ServiceContainer.GetService("EventBus")
            $logger = [Bootstrapper]::ServiceContainer.GetService("Logger")
            $stateManager = [SimpleStateManager]::new($eventBus, $logger)
            [Bootstrapper]::ServiceContainer.Register("StateManager", $stateManager)
            
            # Step 5: Create InputProcessor with user key mappings and register it  
            $inputProcessor = [InputProcessor]::new($eventBus, $stateManager, $logger, $appRootPath)
            [Bootstrapper]::ServiceContainer.Register("InputProcessor", $inputProcessor)
            
            # Export default key mappings for user reference
            $inputProcessor.ExportDefaultKeyMappings($appRootPath)
            
            # Step 6: Create RenderEngine and register it
            $renderEngine = [RenderEngine]::new($logger)
            [Bootstrapper]::ServiceContainer.Register("RenderEngine", $renderEngine)
            
            # Step 6.5: Create FastLineBuilder (ContentBuilder) and register it
            $fastLineBuilder = [FastLineBuilder]::new()
            [Bootstrapper]::ServiceContainer.Register("ContentBuilder", $fastLineBuilder)
            
            # Step 6.6: Initialize AppThemeManager (static class) with default theme
            [AppThemeManager]::ApplyTheme("Default")
            $logger.Debug("AppThemeManager initialized with Default theme")
            
            # Step 7: Create the main application with service injection
            $logger.Debug("Bootstrapper: About to create SimpleTaskProApp")
            $app = [SimpleTaskProApp]::new([Bootstrapper]::ServiceContainer)
            $logger.Debug("Bootstrapper: SimpleTaskProApp created successfully")
            
            [Bootstrapper]::IsInitialized = $true
            $logger.Info("SimpleTaskPro initialization complete")
            Write-Host "SimpleTaskPro ready!" -ForegroundColor Green
            
            return $app
            
        } catch {
            # Logger may not be available if error happened early
            try {
                $logger = [Bootstrapper]::ServiceContainer.GetService("Logger")
                $logger.Error("Bootstrapper: Critical error during initialization", $_)
            } catch {
                # Fallback if logger not available
            }
            Write-Host "Failed to initialize SimpleTaskPro: $_" -ForegroundColor Red
            
            # Attempt cleanup
            [Bootstrapper]::Cleanup()
            throw
        }
    }
    
    # Register services that existing code expects
    static [void] RegisterExistingServices() {
        # Create actual service instances instead of placeholders
        # For now these will be basic implementations
        
        # Create core services - Phase 5 expects these to exist
        $taskService = [SimpleTaskService]::new()
        [Bootstrapper]::ServiceContainer.Register("TaskService", $taskService)
        
        $timeService = [TimeTrackingService]::new()
        [Bootstrapper]::ServiceContainer.Register("TimeService", $timeService)
        
        $commandService = [CommandService]::new()
        [Bootstrapper]::ServiceContainer.Register("CommandService", $commandService)
    }
    
    # Get the global service container
    static [ServiceContainer] GetServiceContainer() {
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