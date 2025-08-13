Excellent. We have built the foundational services and the core engine components. Now we will construct the framework that brings them all together: the **UI Shell** and the **`BaseScreen`**.

This is the phase where we create the reusable "chassis" for all of our application's screens. We are building the stage upon which all the actors (lists, dialogs, forms) will perform. This phase is critical for ensuring a consistent look and feel, a stable rendering loop, and a simple development experience for creating new screens.

---

### **4.0 Phase 3: Construct the UI Shell and Base Screen Framework**

#### **4.1 Goals & Objectives**

The objective is to create the primary UI framework components. This includes the `Shell`, which manages the persistent outer frame of the application, and a new, powerful `BaseScreen` class. This `BaseScreen` will serve as the template for all future screens, providing them with a complete, high-performance rendering pipeline and a direct connection to the application's input and state management systems.

By the end of this phase, we will have a fully functional, empty application shell. We will be able to launch the app, see a header and footer, and have a "No Content" message in the middle. While it won't *do* anything yet, the entire underlying architecture—from logging and settings to input processing and rendering—will be active and working.

#### **4.2 Rationale: Composition and Convention**

*   **The UI Shell (`Shell.ps1`):** A user needs a constant frame of reference. The shell provides this. It owns the absolute top and bottom of the terminal, managing the main application title, global status messages, and notifications. Screens no longer need to worry about drawing at `Y=0` or `Y=[Console]::WindowHeight`; they are given a "content area" inside the shell to draw in. This drastically simplifies screen logic.
*   **The New `BaseScreen.ps1`:** Our previous `BaseListScreen` was a good idea but tried to do too much. It was both a generic "screen" and a specific "list screen." The new `BaseScreen` will be a leaner, more fundamental abstraction. Its only job is to be a "pluggable component" for the `UI Shell`. It will connect to the `EventBus` and `StateManager`, but it will contain almost no rendering logic itself. This is **Composition over Inheritance** in action. Screens will be *composed of* features rather than inheriting a monolithic implementation.

#### **4.3 Patterns to Follow**

*   **View Controller Pattern:** The `SimpleTaskProApp` class will now act as a "View Controller." Its main loop will manage the active screen (the "View") and the `UI Shell`, orchestrating the top-level application flow.
*   **Template Method Pattern:** The `BaseScreen` will define a series of empty virtual methods like `OnLoaded()`, `OnRender()`, `OnHandleCommand()`, and `OnActivated()`. Child screens will override these "template methods" to inject their specific logic. This creates a predictable lifecycle for every screen.
*   **Single Responsibility Principle:** Each component does one job.
    *   `Shell`: Draws the outer frame.
    *   `BaseScreen`: Manages a screen's lifecycle and connection to the core systems.
    *   `TaskListScreen` (in the next phase): Renders a list of tasks.

#### **4.4 Patterns to AVOID**

*   **`[Console]::Clear()` in Screens:** Screens should *never* clear the entire console. That is the sole responsibility of the `Shell`. Screens are only allowed to draw within the content area they are given. This is the key to flicker-free rendering.
*   **Screens Knowing About Other Screens:** A screen should never have a reference like `$this.TimeEntryScreen`. To navigate, it will publish a `"nav.goto"` command to the `EventBus`. This keeps them completely decoupled.

---

#### **Step 4.5: Implementation - The UI Framework**

##### **A. The UI Shell (`Core/Shell.ps1`)**

*   **Purpose:** To manage the persistent outer frame of the application, providing a consistent header and footer, and a designated content area for active screens.
*   **Instructions:** Create the file `Core/Shell.ps1` with the following content.

```powershell
# Core/Shell.ps1 - Manages the persistent application frame.

class Shell {
    hidden [int]$_width
    hidden [int]$_height
    hidden [string]$_statusMessage = ""
    hidden [datetime]$_statusMessageTimestamp

    Shell() {
        $this.UpdateDimensions()
    }

    [void] UpdateDimensions() {
        $this._width = [Console]::WindowWidth
        $this._height = [Console]::WindowHeight
    }

    [void] Render([object]$activeScreenContent) {
        $sb = [ResourcePool]::GetStringBuilder()
        try {
            [void]$sb.Append([VT]::Clear()) # The Shell is the ONLY place this is called.
            [void]$sb.Append([VT]::HideCursor())

            # 1. Render Header
            [void]$sb.Append([VT]::MoveTo(0, 0))
            [void]$sb.Append([AppThemeManager]::GetColor("Header"))
            $title = " SimpleTaskPro v1.0 ".PadRight($this._width)
            [void]$sb.Append($title)

            # 2. Render the Active Screen's Content
            # The screen content is passed in, already rendered.
            # We just need to place it correctly.
            [void]$sb.Append([VT]::MoveTo(0, 2)) # Content starts on row 2
            [void]$sb.Append($activeScreenContent)

            # 3. Render Footer / Status Bar
            [void]$sb.Append([VT]::MoveTo(0, $this._height - 2))
            [void]$sb.Append([AppThemeManager]::GetColor("Muted"))
            [void]$sb.Append(("─" * $this._width))

            [void]$sb.Append([VT]::MoveTo(0, $this._height - 1))
            $this.RenderStatusLine($sb)

            [Console]::Write($sb.ToString())
        }
        finally {
            [ResourcePool]::ReleaseStringBuilder($sb)
        }
    }

    hidden [void] RenderStatusLine([System.Text.StringBuilder]$sb) {
        # Future: Check for a global status message from the EventBus
        $status = " F1: Help | Ctrl+Q: Quit"
        [void]$sb.Append($status.PadRight($this._width))
    }
}
```

##### **B. The New `BaseScreen` (`Base/BaseScreen.ps1`)**

*   **Purpose:** To serve as the foundational class for all screens. It handles the screen lifecycle, provides access to core services, and connects to the `EventBus` and `InputProcessor`. It is an *abstract* base class and contains no rendering logic of its own.
*   **Instructions:** Create the file `Base/BaseScreen.ps1`. **This will eventually replace `BaseListScreen`.**

```powershell
# Base/BaseScreen.ps1 - The foundational abstract class for all UI screens.

class BaseScreen {
    # Core services provided by the container
    [ServiceContainer]$Services
    [SettingsService]$Settings
    [InputProcessor]$InputProcessor
    [EventBus]$EventBus

    # Screen dimensions, provided by the shell
    [int]$Width
    [int]$Height

    # Public constructor
    BaseScreen([ServiceContainer]$services) {
        $this.Services = $services
        $this.Settings = $services.GetService("SettingsService")
        # Note: EventBus is static, but getting it via container is good practice
        $this.EventBus = $services.GetService("EventBus")
        
        # Each screen gets its own InputProcessor
        $keyMapService = [KeyMappingService]::new($services.AppRootPath) # Assuming AppRootPath is on services
        $this.InputProcessor = [InputProcessor]::new($keyMapService)

        # Subscribe to core events
        $this.EventBus.Subscribe("action:command.execute", $this.OnCommand.GetNewClosure())
    }

    # --- Public API for the Shell/App Controller ---

    [void] Activate([int]$width, [int]$height) {
        $this.Width = $width
        $this.Height = $height
        $this.OnActivated() # Call the overrideable hook
    }

    [string] Render() {
        # This is the primary method the Shell will call
        $sb = [ResourcePool]::GetStringBuilder()
        try {
            $this.OnRender($sb) # Delegate rendering to the child class
            return $sb.ToString()
        }
        finally {
            [ResourcePool]::ReleaseStringBuilder($sb)
        }
    }

    [void] HandleKey([System.ConsoleKeyInfo]$key) {
        $this.InputProcessor.ProcessKey($key)
    }

    # --- Template Methods for Child Classes to Override ---

    [void] OnActivated() {
        # Override in child class to load data, etc.
    }

    [void] OnRender([System.Text.StringBuilder]$sb) {
        # OVERRIDE THIS in child classes to draw the UI.
        [void]$sb.Append("This screen ('$($this.GetType().Name)') did not override OnRender().")
    }

    [void] OnCommand([hashtable]$commandData) {
        # OVERRIDE THIS in child classes to handle commands from the InputProcessor.
        $commandName = $commandData.Command
        [Logger]::Warn("Screen '$($this.GetType().Name)' received command '$commandName' but has no handler.")
    }
}```

##### **C. The Application Controller (`Core/SimpleTaskProApp.ps1`)**

*   **Purpose:** To orchestrate the `Shell` and the active screen. Its main loop is now extremely simple.
*   **Instructions:** **Replace** the content of `Core/SimpleTaskProApp.ps1` with this new implementation.

```powershell
# Core/SimpleTaskProApp.ps1 - The main application controller.

class SimpleTaskProApp {
    hidden [ServiceContainer]$_services
    hidden [Shell]$_shell
    hidden [System.Collections.Generic.Stack[BaseScreen]] $_screenStack
    hidden [bool]$_isRunning = $true

    SimpleTaskProApp([ServiceContainer]$services) {
        $this._services = $services
        $this._shell = [Shell]::new()
        $this._screenStack = [System.Collections.Generic.Stack[BaseScreen]]::new()
        
        # Subscribe to application-level events
        [EventBus]::Subscribe("app.quit", { $this._isRunning = $false }.GetNewClosure())
        # Add nav subscriptions later...
    }

    [void] Run() {
        # Push the initial screen (we'll create a placeholder for now)
        # In the next phase, this will be: [TaskListScreen]::new($this._services)
        $initialScreen = [BaseScreen]::new($this._services)
        $this._screenStack.Push($initialScreen)
        $initialScreen.Activate([Console]::WindowWidth, [Console]::WindowHeight)

        while ($this._isRunning) {
            # 1. Get active screen
            $activeScreen = $this._screenStack.Peek()

            # 2. Render the full UI (Shell + Screen)
            $screenContent = $activeScreen.Render()
            $this._shell.Render($screenContent)

            # 3. Wait for and handle input
            $key = [Console]::ReadKey($true)
            $activeScreen.HandleKey($key)
        }
    }
}
```

#### **4.6 Verification for Phase 3**

1.  **Update `test-phase1.ps1` to `test-phase3.ps1`:**
2.  **Execution:**
    *   Initialize the `ServiceContainer` as before.
    *   Create an instance of `SimpleTaskProApp`.
    *   Call `$app.Run()`.
3.  **Expected Outcome:**
    *   The application launches and displays the `UI Shell` (header and footer).
    *   In the content area, the message "This screen ('BaseScreen') did not override OnRender()." is displayed.
    *   Pressing keys will generate debug logs showing that the `InputProcessor` is running and publishing `action:command.execute` events.
    *   The log file will also show warnings that the `BaseScreen` is receiving these commands but has no handler.
    *   Pressing `Ctrl+Q` (or whatever is mapped to `app.quit`) will cleanly exit the application.

This confirms that our entire architectural chassis is working. The application can start, render, and process input through the full, decoupled, high-performance stack. We are now perfectly positioned to start migrating the actual UI screens onto this solid foundation in the next phase.
