Excellent. We have successfully refactored the most complex screen (`TaskListScreen`) onto our new, robust architecture. The blueprint is now proven.

The next phase is about **replication and standardization**. We will leverage the patterns and successes from the `TaskListScreen` migration to rapidly refactor the remaining list-based screens: `TimeEntryScreen`, `CommandLibraryScreen`, and `ExcelMappingScreen`. The goal here is speed and consistency. Because the hard architectural work is done, this phase will be much faster.

Finally, we will complete the application's core functionality by building out the `StateManager`, which is the final piece of the puzzle for a truly stable and predictable application.

---

### **6.0 Phase 5: Standardize All Screens and Implement the State Manager**

#### **6.1 Goals & Objectives**

The primary objective is to bring all remaining screens into the new architectural standard, ensuring the entire application operates under a single, cohesive set of patterns. We will then implement the `StateManager`, the central authority for all application data, which will complete our transition to a unidirectional data flow architecture.

By the end of this phase, the application will be architecturally complete. All screens will be lean, modular components, all input will be handled through the command system, and all state changes will be managed predictably by the `StateManager`. The application will be fully functional, stable, and ready for future feature development.

#### **6.2 Rationale: Consistency and Predictability**

*   **Consistency:** By making all screens follow the same pattern (`BaseScreen` inheritance, `OnRender`/`OnCommand` implementation), we create a consistent developer experience. Anyone (including an AI) familiar with `TaskListScreen` will immediately understand how to work with `TimeEntryScreen`. This drastically reduces the learning curve and maintenance overhead.
*   **Predictability:** The `StateManager` is the ultimate solution to the "state synchronization" bugs that plague complex TUIs. By ensuring there is only one source of truth and a single, predictable way to change it (via Actions), we eliminate an entire class of difficult-to-diagnose bugs. The application's behavior becomes completely deterministic and easy to reason about.

---

#### **Step 6.3: Implementation - Screen Standardization**

This process will be repeated for `TimeEntryScreen`, `CommandLibraryScreen`, and `ExcelMappingScreen`. We will use `TimeEntryScreen` as the detailed example.

##### **A. Refactor `TimeEntryScreen` (`Screens/TimeEntryScreen.ps1`)**

*   **Purpose:** To migrate the `TimeEntryScreen` to the new `BaseScreen` framework, following the `TaskListScreen` blueprint.
*   **Instructions:**
    1.  **Change Inheritance:** Modify the class definition to `class TimeEntryScreen : BaseScreen`.
    2.  **Purge Legacy Code:** Delete all redundant properties (e.g., `$Width`, `$Height`, `$SelectedIndex`) and all monolithic rendering and input methods (`Render`, `HandleInput`, `RenderTimeEntryMode`, etc.).
    3.  **Update Constructor:** The constructor will now call the base constructor and subscribe to the `state.changed` event.
        ```powershell
        TimeEntryScreen([ServiceContainer]$services) : base($services) {
            $this._timeService = $services.GetService("TimeTrackingService")
            $this.EventBus.Subscribe("notification:state.changed", $this.OnStateChanged.GetNewClosure())
            # ... Register command handlers ...
        }
        ```
    4.  **Implement `OnRender`:** This method will now be responsible for drawing the time entry grid within the content area provided by the Shell. It will retrieve the list of time entries from its local state (which is synced from the `StateManager`).
    5.  **Implement `OnCommand`:** This method will be a `switch` statement that routes time-entry-specific commands (`time.edit.hours`, `time.nav.nextWeek`, etc.) to private handler methods.
    6.  **Implement `GetFieldScreenPosition`:** This is crucial. Just as with `TaskListScreen`, this method will contain the logic to calculate the exact X,Y coordinates for the cursor when editing a specific day's hours (e.g., "Monday" is at `X=30`, "Tuesday" is at `X=38`, etc.). This will fix all inline editing bugs.

##### **B. Refactor `CommandLibraryScreen` and `ExcelMappingScreen`**

*   **Purpose:** To apply the same refactoring pattern to the remaining screens.
*   **Instructions:** Repeat the exact same process as for `TimeEntryScreen`.
    *   Change inheritance to `BaseScreen`.
    *   Purge redundant properties and methods.
    *   Implement `OnActivated`, `OnStateChanged`, `OnRender`, and `OnCommand`.
    *   For `ExcelMappingScreen`, the `GetFieldScreenPosition` method will be essential for fixing its inline editing cursor bugs.

---

#### **Step 6.4: Implementation - The State Manager and Final Integration**

##### **A. The State Manager (`Core/StateManager.ps1`)**

*   **Purpose:** To manage the entire application state and process all state changes through a predictable, centralized pipeline.
*   **Instructions:** Create the file `Core/StateManager.ps1` with the following content.

```powershell
# Core/StateManager.ps1 - The single source of truth for the application.

class StateManager {
    hidden [hashtable]$_state
    hidden [EventBus]$_eventBus

    StateManager([EventBus]$eventBus) {
        $this._eventBus = $eventBus
        $this._state = @{
            # Application-level state
            ActiveScreen = "Tasks"
            # Task-related state
            Tasks = @{
                AllTasks = @()
                FlatList = @()
                Filter = "All"
                SelectedTaskId = $null
                SelectedIndex = -1
                ScrollTop = 0
            }
            # Time Entry-related state
            Time = @{
                AllEntries = @()
                FlatList = @()
                CurrentWeek = "" # yyyyMMdd format
                SelectedIndex = -1
                ScrollTop = 0
            }
            # ... etc. for other screens
        }
        $this._eventBus.Subscribe("action:command.execute", $this.OnAction.GetNewClosure())
    }

    [hashtable] GetState() {
        return $this._state
    }

    hidden [void] OnAction([hashtable]$commandData) {
        $command = $commandData.Command
        $data = $commandData.Data

        # This is the central reducer. It's a giant switch that holds all business logic.
        # It takes the current state and an action, and produces the NEW state.
        [Logger]::Info("StateManager received action: $command")

        # --- Create a deep copy to ensure state is immutable ---
        $newState = $this.DeepCopy($this._state)

        # --- Route to the correct reducer logic ---
        switch -Wildcard ($command) {
            "task.delete" {
                # Business logic for deleting a task goes here...
                # It modifies the $newState.Tasks hashtable.
            }
            "list.moveDown" {
                # Business logic for moving selection down...
                # It modifies the $newState.Tasks.SelectedIndex.
            }
            "nav.goto" {
                # Business logic for changing the screen...
                $newState.ActiveScreen = $data.ScreenName
            }
            # ... one case for EVERY command in the CommandRegistry
        }

        # --- If the state has changed, update and notify ---
        # (A real implementation would do a deep compare here)
        $this._state = $newState
        $this._eventBus.Publish("notification:state.changed")
    }

    hidden [object] DeepCopy([object]$object) {
        # A simple mechanism for deep copying the state hashtable
        $json = ConvertTo-Json $object -Depth 10
        return ConvertFrom-Json $json -AsHashtable
    }
}
```

##### **B. Final Integration into the Bootstrapper (`Core/Bootstrapper.ps1`)**

*   **Purpose:** To wire the `StateManager` into the application's startup sequence.
*   **Instructions:** Modify the `Bootstrapper`'s initialization logic.

```powershell
# In Core/Bootstrapper.ps1

class Bootstrapper {
    static [void] Run() {
        # ... global try/catch ...
        
        # 1. Initialize core services
        $services = [ServiceContainer]::new()
        $services.Initialize($PSScriptRoot)

        # 2. Initialize the State Manager (depends on EventBus)
        $eventBus = $services.GetService("EventBus")
        $stateManager = [StateManager]::new($eventBus)
        $services.Register("StateManager", $stateManager)

        # 3. Initialize all Data Services (they may need the StateManager or EventBus)
        $taskService = [SimpleTaskService]::new(...)
        $services.Register("SimpleTaskService", $taskService)
        # ... initialize and register all other services

        # 4. Create and run the main application controller
        $app = [SimpleTaskProApp]::new($services)
        $app.Run()

        # ...
    }
}
```

#### **6.5 Verification for Phase 5**

1.  **Run the Application:** Execute `SimpleTaskPro.ps1`.
2.  **Expected Outcome:**
    *   The application launches and all screens (`TaskListScreen`, `TimeEntryScreen`, `CommandLibraryScreen`, `ExcelMappingScreen`) are fully functional.
    *   **Consistent Behavior:** All screens exhibit the same smooth, flicker-free rendering and pillbox selection.
    *   **Input Works Everywhere:** Inline editing, navigation, and command-based actions work correctly on every screen.
    *   **State is Predictable:** Actions performed on one screen (e.g., changing a task title) are correctly reflected when navigating away and back.
    *   **Log File Analysis:** The log file clearly shows the unidirectional data flow: Key Press -> `InputProcessor` -> `EventBus` (`action:*`) -> `StateManager` -> State Change -> `EventBus` (`notification:state.changed`) -> Screen Re-renders.

With this phase complete, the refactoring is finished. You now have a professional-grade TUI application with a robust, modular, and high-performance architecture. It is stable, easy to maintain, and provides a solid foundation for adding any new features you envision in the future.
