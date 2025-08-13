# Core/SimpleTaskProApp.ps1 - A lightweight launcher and screen controller.

class SimpleTaskProApp {
    hidden [ServiceContainer]$_services
    hidden [Logger]$_logger
    hidden [hashtable]$_screens = @{}

    SimpleTaskProApp([ServiceContainer]$services) {
        $this._services = $services
        $this._logger = $services.GetService("Logger")
        $this.InitializeScreens()
    }

    [void] InitializeScreens() {
        # Create instances of all screens the app can show.
        $this._screens["Tasks"] = [TaskListScreen]::new($this._services)
        # $this._screens["TimeEntry"] = [TimeEntryScreen]::new($this._services) # Add other screens here
        $this._logger.Info("All application screens have been instantiated.")
    }

    [void] Run() {
        $this._logger.Info("Application launcher running. Handing control to initial screen.")
        $initialScreen = $this._screens["Tasks"]
        # The screen now runs its own main loop. This is the handoff.
        $initialScreen.Show() 
    }
}