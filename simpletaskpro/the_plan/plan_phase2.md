Of course. We have established the foundational services. Now we will build the "engine parts"—the modular, high-performance components that will drive the user interface.

This phase is about creating the reusable tools for input, performance, and content generation. We are building the powerful, standardized components that our future screens will use, ensuring they are all fast, consistent, and easy to develop.

---

### **3.0 Phase 2: Build the Core Engine Components**

#### **3.1 Goals & Objectives**

The objective of this phase is to construct the set of modular, reusable components that form the core of the TUI "engine." We will create the systems responsible for handling user input in a configurable way, managing memory to ensure high performance, and translating application data into a renderable format.

By the end of this phase, we will have a complete, testable, non-visual TUI engine. We will be able to process key presses, map them to commands, and generate the data structures for rendering, all without a single line of UI code. This isolates the core logic and allows us to verify its correctness before connecting it to the visual layer.

#### **3.2 Rationale: A Factory for TUI Components**

Just as a car factory builds standardized engines and transmissions before assembling the car, we are building the standardized components for our UI.

*   **`ResourcePool`:** A high-performance TUI requires aggressive memory management. Constant creation of `StringBuilder` objects and strings is the number one cause of UI stutter. The `ResourcePool` solves this by creating a central "parts depot" for these objects, reducing memory allocation in the render loop to near zero.
*   **`CommandRegistry` & `KeyMappingService`:** To make the application's input user-configurable and easy to manage, we must separate the *what* from the *how*. The `CommandRegistry` defines *what* actions are possible (the "what"). The `KeyMappingService` defines *how* they are triggered (the keybinding). This separation is the key to a flexible input system.
*   **`InputProcessor`:** This component is the "transmission" of our input system. It's a generic, reusable module that connects a physical key press to a logical command and publishes that command to the rest of the application. Screens will no longer contain complex `switch` statements; they will simply host an `InputProcessor`.

#### **3.3 Patterns to Follow**

*   **Command Pattern:** We will formalize all user actions as "Commands." A command is a simple object containing a unique name (`task.delete`), a description, and a default keybinding. This decouples the UI from the action logic.
*   **Flyweight Pattern:** The `ResourcePool` is an implementation of the Flyweight pattern. We reuse a small number of `StringBuilder` objects to serve a large number of render requests, saving memory.
*   **Composition over Inheritance:** Instead of building a monolithic base class that does everything, our new `BaseScreen` (to be built in Phase 3) will be *composed* of these smaller, specialized engine components. It will *have an* `InputProcessor`; it won't *be an* input processor.

#### **3.4 Patterns to AVOID**

*   **Hardcoded Key Logic:** No screen or component should ever have code like `if ($key.Key -eq [System.ConsoleKey]::N)`. All such logic will be defined declaratively in the `CommandRegistry` and handled by the `InputProcessor`.
*   **Mixed Responsibilities:** Components must do one thing well. The `ResourcePool` only manages memory. The `InputProcessor` only processes input. They have no knowledge of tasks, time entries, or rendering.

---

#### **Step 3.5: Implementation - The Core Engine Modules**

The following subsections provide the complete implementation for each engine component.

##### **A. The Performance Toolkit (`Core/ResourcePool.ps1`)**

*   **Purpose:** Provides centralized, high-performance memory management utilities, including `StringBuilder` pooling and string caching, to eliminate GC pressure in the render loop.
*   **Instructions:** Create the file `Core/ResourcePool.ps1` with the following content.

```powershell
# Core/ResourcePool.ps1 - Manages reusable objects to optimize performance.

class ResourcePool {
    static [System.Collections.Generic.List[System.Text.StringBuilder]]$_sbPool = @()
    static [hashtable]$Spaces = @{}
    static [hashtable]$HLines = @{}
    static [bool]$IsInitialized = $false

    static [void] Initialize($maxCacheLength = 250) {
        if ([ResourcePool]::IsInitialized) { return }
        # Pre-populate caches for common strings to avoid runtime creation
        for ($i = 1; $i -le $maxCacheLength; $i++) {
            [ResourcePool]::Spaces[$i] = " " * $i
            [ResourcePool]::HLines[$i] = "─" * $i
        }
        [ResourcePool]::IsInitialized = $true
    }

    static [System.Text.StringBuilder] GetStringBuilder() {
        if ([ResourcePool]::_sbPool.Count -gt 0) {
            $sb = [ResourcePool]::_sbPool[0]
            [ResourcePool]::_sbPool.RemoveAt(0)
            $sb.Clear() # Ensure the builder is empty before reuse
            return $sb
        }
        # Start with a large buffer to minimize re-allocations
        return [System.Text.StringBuilder]::new(8192) 
    }

    static [void] ReleaseStringBuilder([System.Text.StringBuilder]$sb) {
        # Limit the pool size to prevent holding onto too much memory
        if ([ResourcePool]::_sbPool.Count -lt 10) {
            [ResourcePool]::_sbPool.Add($sb)
        }
    }

    static [string] GetSpaces([int]$width) {
        if ($width -le 0) { return "" }
        if ([ResourcePool]::Spaces.ContainsKey($width)) {
            return [ResourcePool]::Spaces[$width]
        }
        return " " * $width # Fallback for very large widths
    }
}
```

##### **B. The Command Registry (`Core/CommandRegistry.ps1`)**

*   **Purpose:** To define every logical action available in the application. This is the single source of truth for what a user *can do*. It is completely decoupled from how those actions are triggered.
*   **Instructions:** Create the file `Core/CommandRegistry.ps1` with the following content.

```powershell
# Core/CommandRegistry.ps1 - Defines all logical application commands.

class CommandInfo {
    [string]$Name
    [string]$Description
    [string]$DefaultKey
    [string]$DefaultModifiers

    CommandInfo([string]$name, [string]$desc, [string]$key, [string]$mods) {
        $this.Name = $name
        $this.Description = $desc
        $this.DefaultKey = $key
        $this.DefaultModifiers = $mods
    }
}

class CommandRegistry {
    static [hashtable]$Commands = @{}

    static [void] Initialize() {
        if ([CommandRegistry]::Commands.Count -gt 0) { return }

        # --- Universal Commands ---
        [CommandRegistry]::Register("app.quit", "Quit Application", "Q", "None")
        [CommandRegistry]::Register("app.showHelp", "Show Help", "F1", "None")

        # --- Navigation Commands ---
        [CommandRegistry]::Register("nav.tasks", "Go to Task Screen", "F2", "None")
        [CommandRegistry]::Register("nav.time", "Go to Time Entry Screen", "F3", "None")
        [CommandRegistry]::Register("nav.commands", "Go to Command Library", "F4", "None")
        [CommandRegistry]::Register("nav.excel", "Go to Excel Mappings", "F5", "None")

        # --- List Navigation Commands ---
        [CommandRegistry]::Register("list.moveUp", "Move Selection Up", "UpArrow", "None")
        [CommandRegistry]::Register("list.moveDown", "Move Selection Down", "DownArrow", "None")
        
        # --- Task Screen Commands ---
        [CommandRegistry]::Register("task.edit.start", "Edit Selected Task", "E", "None")
        [CommandRegistry]::Register("task.edit.notes", "Edit Task Notes", "Enter", "None")
        [CommandRegistry]::Register("task.add.new", "Add New Task", "N", "None")
        [CommandRegistry]::Register("task.delete", "Delete Selected Task", "Delete", "None")
        [CommandRegistry]::Register("task.toggle.complete", "Toggle Task Completion", "X", "None")
        # ... etc. for all other commands
    }

    static [void] Register([string]$name, [string]$desc, [string]$key, [string]$mods) {
        [CommandRegistry]::Commands[$name] = [CommandInfo]::new($name, $desc, $key, $mods)
    }

    static [CommandInfo] GetCommand([string]$name) {
        return [CommandRegistry]::Commands[$name]
    }

    static [hashtable] GetAllCommands() {
        return [CommandRegistry]::Commands
    }
}
```

##### **C. The Refactored Key Mapping Service (`Services/KeyMappingService.ps1`)**

*   **Purpose:** To manage the mapping between physical keys and logical commands. Its *only* job is to load user customizations and provide the final, active key map to the `InputProcessor`.
*   **Instructions:** **Replace** the content of `Services/KeyMappingService.ps1` with this new, leaner implementation.

```powershell
# Services/KeyMappingService.ps1 - Manages the mapping of keys to commands.

class KeyMappingService {
    hidden [string]$_configFile
    hidden [hashtable]$_activeKeyMap = @{} # Key: "Ctrl+N", Value: "task.add.new"

    KeyMappingService([string]$configPath) {
        $this._configFile = Join-Path $configPath "keymappings.json"
        $this.BuildActiveMap()
    }

    [void] BuildActiveMap() {
        # 1. Start with the defaults from the Command Registry
        $defaultCommands = [CommandRegistry]::GetAllCommands()
        foreach ($command in $defaultCommands.Values) {
            $keyString = if ($command.DefaultModifiers -eq "None") {
                $command.DefaultKey
            } else {
                "$($command.DefaultModifiers)+$($command.DefaultKey)"
            }
            $this._activeKeyMap[$keyString] = $command.Name
        }

        # 2. Load user customizations from file and override defaults
        if (Test-Path $this._configFile) {
            try {
                $userMappings = Get-Content $this._configFile | ConvertFrom-Json -AsHashtable
                foreach ($keyString in $userMappings.Keys) {
                    $commandName = $userMappings[$keyString]
                    # Override the default with the user's preference
                    $this._activeKeyMap[$keyString] = $commandName
                }
                [Logger]::Info("Loaded user key mappings from $($this._configFile)")
            } catch {
                [Logger]::Error("Could not load user key mappings.", $_)
            }
        }
    }

    [string] GetCommandForKey([System.ConsoleKeyInfo]$keyInfo) {
        $modifiers = @()
        if ($keyInfo.Modifiers -band [System.ConsoleModifiers]::Control) { $modifiers += "Control" }
        if ($keyInfo.Modifiers -band [System.ConsoleModifiers]::Alt)     { $modifiers += "Alt" }
        if ($keyInfo.Modifiers -band [System.ConsoleModifiers]::Shift)   { $modifiers += "Shift" }

        $keyString = if ($modifiers.Count -gt 0) {
            "$($modifiers -join '+')+$($keyInfo.Key.ToString())"
        } else {
            $keyInfo.Key.ToString()
        }

        if ($this._activeKeyMap.ContainsKey($keyString)) {
            return $this._activeKeyMap[$keyString]
        }
        return $null
    }
}
```

##### **D. The Input Processor (`Core/InputProcessor.ps1`)**

*   **Purpose:** A modular, reusable component that acts as the "transmission" for input. It takes a raw keypress, uses the `KeyMappingService` to translate it into a command, and publishes that command as an event.
*   **Instructions:** Create the file `Core/InputProcessor.ps1` with the following content.

```powershell
# Core/InputProcessor.ps1 - Translates key presses to command events.

class InputProcessor {
    hidden [KeyMappingService]$_keyMappingService

    InputProcessor([KeyMappingService]$keyService) {
        $this._keyMappingService = $keyService
    }

    [bool] ProcessKey([System.ConsoleKeyInfo]$keyInfo) {
        $commandName = $this._keyMappingService.GetCommandForKey($keyInfo)

        if ($commandName) {
            [Logger]::Debug("InputProcessor: Key '$keyInfo' mapped to command '$commandName'. Publishing event.")
            # Publish the command as a generic action event for the StateManager to handle.
            [EventBus]::Publish("action:command.execute", @{ Command = $commandName })
            return $true # The key was handled.
        }

        [Logger]::Debug("InputProcessor: Key '$keyInfo' has no command mapping.")
        return $false # The key was not handled.
    }
}
```

#### **3.6 Verification for Phase 2**

1.  **Create a Test Script (`test-phase2.ps1`):**
2.  **Execution:**
    *   Perform the same initialization as Phase 1.
    *   Initialize the `CommandRegistry`.
    *   Create an instance of the `KeyMappingService`.
    *   Create an instance of the `InputProcessor`.
    *   Subscribe to the `"action:command.execute"` event on the `EventBus`.
    *   Simulate a keypress (e.g., `N`) by creating a `[System.ConsoleKeyInfo]` object and passing it to `$inputProcessor.ProcessKey()`.
3.  **Expected Outcome:**
    *   The `EventBus` subscriber for `"action:command.execute"` should fire.
    *   The data received by the subscriber should be a hashtable containing `@{ Command = "task.add.new" }`.
    *   The log file should contain debug messages showing the key being processed and the event being published.

With this phase complete, we have a fully decoupled, user-configurable, and high-performance input engine ready to be plugged into our UI screens in the next phase.
