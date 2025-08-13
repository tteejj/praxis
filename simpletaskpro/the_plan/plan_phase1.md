Of course. Here is the updated and finalized "reference manual" entry for Phase 1.

This section is now complete, self-contained, and incorporates all of our strategic decisions. It provides the high-level rationale for your understanding and the detailed, explicit implementation steps for an AI or human developer to execute flawlessly.

---

### **2.0 Phase 1: Establish the Core Architectural Foundation**

#### **2.1 Goals & Objectives**

The primary objective of this phase is to construct the foundational, non-UI "scaffolding" for the entire application. We will build the central nervous system (the `EventBus`), the brain (the `StateManager`), the configuration hub (the `SettingsService`), and the diagnostic tools (the `Logger`).

By the end of this phase, we will have a robust, decoupled, and testable set of core services. This will allow us to build the UI components in subsequent phases with confidence, knowing that the underlying infrastructure is sound.

#### **2.2 Rationale: Why These Components First?**

In any complex application, the components that have the fewest dependencies must be built first. These core services are the bedrock:

*   **`EventBus`:** All components will communicate through the Event Bus. It must exist before any components can be wired together.
*   **`Logger`:** During a complex refactor, the ability to log actions and errors from every part of the system is not a luxury; it is a critical diagnostic tool. We build it first so we can use it immediately.
*   **`SettingsService`:** Components need configuration from the moment they are created (e.g., "Where is the log file located?"). The Settings Service provides this configuration, preventing hardcoded values from proliferating through the codebase.
*   **`ServiceContainer`:** This component acts as our "bootstrapper." It ensures that these critical services are initialized correctly, in the right order, and are easily accessible to the rest of the application.

#### **2.3 Patterns to Follow**

*   **Singleton/Static Classes:** These core services will be implemented as static classes or managed as singletons by the `ServiceContainer`. There should only ever be ONE instance of the `EventBus`, `Logger`, and `SettingsService` in the entire application.
*   **Dependency Inversion:** Components should not create their own dependencies. Instead of `new Logger()`, they will request the logger from the `ServiceContainer`. This makes our code decoupled and testable.
*   **Observer Pattern:** The `EventBus` is a classic implementation of the Observer pattern. It allows "Publisher" objects to send messages without knowing who the "Subscriber" objects are, and vice-versa.

#### **2.4 Patterns to AVOID**

*   **Direct Component Communication:** At no point should a component get a direct reference to another component (e.g., `$taskScreen.TimeService`). All communication must go through the `EventBus` or be mediated by the `StateManager`.
*   **Hardcoded Configuration:** Do not place file paths, colors, or behavioral "magic numbers" directly in component code. All such values must be retrieved from the `SettingsService`.

---

#### **Step 2.5: Implementation - The Core Service Modules**

The following subsections provide the complete implementation for each core service. This code should be created in new files within the `Core/` directory.

##### **A. The Logger (`Core/Logger.ps1`)**

*   **Purpose:** Provides a centralized, file-based logging facility for diagnostics and error tracking.
*   **Instructions:** Create the file `Core/Logger.ps1` with the following content.

```powershell
# Core/Logger.ps1 - Centralized, file-based logging service.

enum LogLevel {
    Debug = 0
    Info = 1
    Warn = 2
    Error = 3
    Fatal = 4
}

class Logger {
    static [string]$LogFile
    static [LogLevel]$LogLevel = [LogLevel]::Info
    static [bool]$IsInitialized = $false

    static [void] Initialize([string]$logPath, [LogLevel]$level) {
        if ([Logger]::IsInitialized) { return }
        [Logger]::LogFile = Join-Path $logPath "SimpleTaskPro-$(Get-Date -Format 'yyyy-MM-dd').log"
        [Logger]::LogLevel = $level
        
        try {
            $logDir = Split-Path -Parent [Logger]::LogFile
            if (-not (Test-Path $logDir)) {
                New-Item -ItemType Directory -Path $logDir -Force | Out-Null
            }
            "--- Log Initialized at $(Get-Date) ---" | Out-File -FilePath [Logger]::LogFile -Append -Encoding UTF8
            [Logger]::IsInitialized = $true
        } catch {
            Write-Host "FATAL: Could not initialize logger at $([Logger]::LogFile). Error: $_" -ForegroundColor Red
        }
    }

    static [void] Log([LogLevel]$level, [string]$message) {
        if (-not [Logger]::IsInitialized -or $level -lt [Logger]::LogLevel) { return }

        $timestamp = Get-Date -Format "HH:mm:ss"
        $levelString = $level.ToString().ToUpper().PadRight(5)
        "$timestamp $levelString - $message" | Out-File -FilePath [Logger]::LogFile -Append -Encoding UTF8
    }

    static [void] Debug([string]$message) { [Logger]::Log([LogLevel]::Debug, $message) }
    static [void] Info([string]$message)  { [Logger]::Log([LogLevel]::Info, $message) }
    static [void] Warn([string]$message)  { [Logger]::Log([LogLevel]::Warn, $message) }
    static [void] Error([string]$message, [System.Exception]$exception = $null) {
        $fullMessage = $message
        if ($exception) {
            $fullMessage += "`n$($exception.ToString())"
            if ($exception.ScriptStackTrace) {
                $fullMessage += "`nStack Trace:`n$($exception.ScriptStackTrace)"
            }
        }
        [Logger]::Log([LogLevel]::Error, $fullMessage)
    }
}
```

##### **B. The Settings Service (`Core/SettingsService.ps1`)**

*   **Purpose:** Manages loading and saving of all application configuration from a central `settings.json` file. Provides default values to prevent crashes if the file is missing or malformed.
*   **Instructions:** Create the file `Core/SettingsService.ps1` with the following content.

```powershell
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
```

##### **C. The Event Bus (`Core/EventBus.ps1`)**

*   **Purpose:** Provides the central, decoupled communication channel for the entire application, based on the Observer pattern.
*   **Instructions:** Refine the existing `Core/EventBus.ps1` to be more robust and align with our new conventions.

```powershell
# Core/EventBus.ps1 - Decoupled application-wide communication system.

class EventBus {
    static [hashtable]$Subscriptions = @{}

    static [void] Subscribe([string]$eventName, [scriptblock]$callback) {
        if (-not [EventBus]::Subscriptions.ContainsKey($eventName)) {
            [EventBus]::Subscriptions[$eventName] = [System.Collections.Generic.List[scriptblock]]::new()
        }
        [EventBus]::Subscriptions[$eventName].Add($callback)
        [Logger]::Debug("New subscription to event '$eventName'.")
    }

    static [void] Unsubscribe([string]$eventName, [scriptblock]$callback) {
        if ([EventBus]::Subscriptions.ContainsKey($eventName)) {
            [EventBus]::Subscriptions[$eventName].Remove($callback)
            [Logger]::Debug("Unsubscribed from event '$eventName'.")
        }
    }

    static [void] Publish([string]$eventName, [object]$data = $null) {
        if (-not [EventBus]::Subscriptions.ContainsKey($eventName)) {
            [Logger]::Debug("Published event '$eventName' with no subscribers.")
            return
        }

        [Logger]::Debug("Publishing event '$eventName' to $([EventBus]::Subscriptions[$eventName].Count) subscribers.")
        
        # Create a copy of the subscribers list in case a callback modifies the original list.
        $subscribers = [EventBus]::Subscriptions[$eventName].ToArray()

        foreach ($callback in $subscribers) {
            try {
                if ($data -ne $null) {
                    & $callback $data
                } else {
                    & $callback
                }
            } catch {
                [Logger]::Error("Error executing subscriber for event '$eventName'.", $_)
            }
        }
    }
}
```

##### **D. The Service Container (`Core/ServiceContainer.ps1`)**

*   **Purpose:** Acts as the application's "bootstrapper," responsible for initializing all core services in the correct order and making them available.
*   **Instructions:** Refine the existing `Core/ServiceContainer.ps1` to initialize and manage our new core services.

```powershell
# Core/ServiceContainer.ps1 - Initializes and provides access to all core services.

class ServiceContainer {
    hidden [hashtable]$_services = @{}

    [void] Initialize([string]$appRootPath) {
        # 1. Settings Service (must be first)
        $settings = [SettingsService]::new($appRootPath)
        $this.Register("SettingsService", $settings)

        # 2. Logger (depends on settings)
        $logPath = Join-Path $appRootPath ($settings.Get("Logging.Path"))
        $logLevel = [LogLevel]::($settings.Get("Logging.Level"))
        [Logger]::Initialize($logPath, $logLevel)

        # 3. Event Bus (no dependencies)
        $this.Register("EventBus", [EventBus]) # Register the static class itself for access

        [Logger]::Info("Service Container initialized successfully.")
    }

    [void] Register([string]$name, [object]$instance) {
        $this._services[$name] = $instance
    }

    [object] GetService([string]$name) {
        if ($this._services.ContainsKey($name)) {
            return $this._services[$name]
        }
        [Logger]::Error("Attempted to resolve unregistered service: $name")
        return $null
    }
}
```

#### **2.6 Verification for Phase 1**

To confirm this phase is complete and successful, we will perform the following steps:

1.  **Create a Test Script (`test-phase1.ps1`):** This script will not launch the main application but will test the core services directly.
2.  **Execution:**
    *   Create an instance of `ServiceContainer` and call `Initialize()`.
    *   Retrieve the `SettingsService` and read a default value.
    *   Use the `Logger` to write an Info and an Error message.
    *   Use the `EventBus` to publish a test event and confirm a subscribed scriptblock fires.
3.  **Expected Outcome:**
    *   The script runs without errors.
    *   A `settings.json` file is created in the project root if it didn't exist.
    *   A log file is created in the `Logs/` directory and contains the correct timestamped messages.
    *   The test event subscription successfully receives the published event.

With the successful completion of this phase, we have a stable, configurable, and diagnosable foundation upon which we can confidently build the rest of the application.
