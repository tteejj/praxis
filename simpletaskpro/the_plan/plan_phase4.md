Excellent. The foundational services and the UI framework are now in place. We have a running application shell that does nothing, but does it with a robust, modular, and high-performance architecture.

Now, we execute the most critical part of the "Strangler Fig" pattern: migrating our first, most complex component—the **`TaskListScreen`**—onto this new framework. This phase will serve as the blueprint for all subsequent screen migrations. We will surgically move logic from the old, monolithic screen into the new, clean "template methods" provided by our `BaseScreen`, and in doing so, we will fix the longstanding bugs related to rendering, input, and cursor positioning.

---

### **5.0 Phase 4: Migrate `TaskListScreen` to the New Architecture**

#### **5.1 Goals & Objectives**

The objective is to refactor `TaskListScreen` from a monolithic, self-contained component into a lean, specialized child of `BaseScreen`. It will delegate all generic functionality (input processing, render loop management, state access) to the core systems we've just built and will be responsible *only* for logic that is specific to displaying and interacting with tasks.

By the end of this phase, the user will see a fully functional Task List. All core features—navigation, inline editing, adding, deleting, toggling completion, and opening notes—will be working correctly and reliably. The cursor positioning bug will be resolved, and the code for `TaskListScreen` will be dramatically simpler and easier to understand.

#### **5.2 Rationale: From Monolith to Modular Component**

This is the "strangling" part of the pattern. We are replacing the brittle, internal guts of `TaskListScreen` with robust connections to our new core engine.

*   **Simplification:** The old `TaskListScreen` was over 1,000 lines of tangled code. The new version will be a fraction of that size, focusing exclusively on task-specific logic. This dramatically reduces cognitive overhead for developers.
*   **Bug Elimination:** By removing the screen's own state management and input loops, we eliminate the entire class of bugs related to state desynchronization and unreliable key handling. The cursor bug is fixed because the screen now provides precise coordinate information to the `BaseScreen`'s rendering pipeline, fulfilling the architectural contract.
*   **Adopting the Blueprint:** This migration serves as the definitive example. Once `TaskListScreen` is complete, refactoring the other screens (`TimeEntryScreen`, `CommandLibraryScreen`) will be a fast and predictable process of following the same pattern.

#### **5.3 Patterns to Follow**

*   **Template Method Implementation:** The primary pattern is implementing the abstract "template methods" from `BaseScreen` (`OnActivated`, `OnRender`, `OnCommand`).
*   **View Model Generation:** `TaskListScreen` will not render directly. It will use its companion `ContentBuilder` (`FastLineBuilder`) to translate its `[SimpleTask]` models into `string[]` View Models.
*   **Command Handling:** All user actions will be handled by subscribing to command events from the `EventBus`. The `OnCommand` method will be a simple `switch` statement that routes command names to the appropriate handler methods.

#### **5.4 Patterns to AVOID**

*   **Direct State Modification:** The screen must not directly modify its own data (e.g., adding a task to a local list). It must always publish an `action:*` event.
*   **Direct Rendering:** The `OnRender` method must not write to the console. It must only append strings to the provided `StringBuilder`.
*   **Legacy Code:** All old, monolithic methods (`RenderTaskModeEnhanced`, `HandleInput`, etc.) must be completely deleted.

---

#### **Step 5.5: Implementation - The `TaskListScreen` Migration**

##### **A. Refactor the `TaskListScreen` Class Definition (`Screens/TaskListScreen.ps1`)**

*   **Purpose:** To formally make `TaskListScreen` a child of our new `BaseScreen` and connect it to the core services.
*   **Instructions:** **Replace** the existing `TaskListScreen` class definition with the following structure. We will purge the old properties and add the new ones it needs to manage its state via the `StateManager`.

```powershell
# Screens/TaskListScreen.ps1 - A lean, modular screen for displaying tasks.

class TaskListScreen : BaseScreen {
    # Services
    hidden [SimpleTaskService]$_taskService
    
    # Local UI State (retrieved from the StateManager)
    hidden [object[]]$_flatList = @()
    hidden [string]$_selectedTaskId = ""
    hidden [int]$_selectedIndex = -1
    hidden [int]$_scrollTop = 0
    # ... other UI state properties as needed ...

    TaskListScreen([ServiceContainer]$services) : base($services) {
        # Get the specific services this screen needs
        $this._taskService = $services.GetService("SimpleTaskService")

        # Subscribe this screen to relevant notifications from the EventBus
        $this.EventBus.Subscribe("notification:state.changed", $this.OnStateChanged.GetNewClosure())

        # Register the commands this screen can handle
        $this.RegisterCommandHandlers()
    }

    # ... (Implementation of OnActivated, OnRender, OnCommand, etc. will go here) ...
}
```

##### **B. Implement the Screen Lifecycle Methods**

*   **Purpose:** To give the screen its core behavior by implementing the template methods from `BaseScreen`.
*   **Instructions:** Add the following methods inside the `TaskListScreen` class.

```powershell
# --- Screen Lifecycle & State Management ---

[void] OnActivated() {
    # This is called when the screen becomes active.
    # We'll trigger an initial data load by requesting the StateManager to update.
    [Logger]::Info("TaskListScreen activated. Requesting initial state.")
    $this.EventBus.Publish("action:tasks.load")
}

[void] OnStateChanged() {
    # This is our notification from the StateManager that data has changed.
    # We pull the new state we need to render the UI.
    [Logger]::Debug("TaskListScreen received state.changed notification.")
    $state = $this.Services.GetService("StateManager").GetState()

    $this._flatList = $state.Tasks.FlatList
    $this._selectedTaskId = $state.Tasks.SelectedTaskId
    $this._selectedIndex = $state.Tasks.SelectedIndex
    $this._scrollTop = $state.Tasks.ScrollTop
    # ... etc., pull all relevant state
}

# --- Rendering ---

[void] OnRender([System.Text.StringBuilder]$sb) {
    # This is our main rendering hook. It's called by the Shell.
    # Its only job is to render the *content area* of the task list.

    # 1. Render Header
    $this.RenderHeader($sb)

    # 2. Render List Items
    $contentHeight = $this.Height - 4 # Account for Shell header/footer and our own header/footer
    $endIndex = [Math]::Min($this._scrollTop + $contentHeight, $this._flatList.Count)

    for ($i = $this._scrollTop; $i -lt $endIndex; $i++) {
        $item = $this._flatList[$i]
        $isSelected = ($item.Task.Id -eq $this._selectedTaskId)
        
        # Use the ContentBuilder (FastLineBuilder) to get the string[] view model
        $viewModel = $this.Services.GetService("ContentBuilder").GenerateTaskViewModel($item.Task, $this, $item.Level, $item.IsLast)

        # The RenderPipeline is responsible for drawing it with a pillbox if selected
        $this.Services.GetService("RenderPipeline").RenderItem($sb, $viewModel, $isSelected)
    }

    # 3. Render Footer
    $this.RenderFooter($sb)
}

# --- Command Handling ---

[void] RegisterCommandHandlers() {
    # Create a local map of which methods handle which commands.
    $commandMap = @{
        "task.delete" = { $this.HandleDeleteTask() }
        "task.edit.notes" = { $this.HandleEditNotes() }
        # ... etc. for every command this screen cares about
    }
    $this._commandHandlers = $commandMap # Store it on the object
}

[void] OnCommand([hashtable]$commandData) {
    # This method is called by the base class when the InputProcessor publishes a command.
    $commandName = $commandData.Command
    
    if ($this._commandHandlers.ContainsKey($commandName)) {
        # Find and execute the correct handler scriptblock
        & $this._commandHandlers[$commandName]
    }
}
```

##### **C. Implement the Command Handler Methods**

*   **Purpose:** To contain the actual logic for what happens when a command is executed. These methods are clean, simple, and have a single responsibility.
*   **Instructions:** Add these private helper methods to the `TaskListScreen` class. They are called by the `OnCommand` router.

```powershell
# --- Private Command Handlers ---

hidden [void] HandleDeleteTask() {
    [Logger]::Info("Handling command: task.delete")
    if ($this._selectedTaskId) {
        # We don't delete the task directly. We ask the StateManager to do it.
        $this.EventBus.Publish("action:task.delete", @{ TaskId = $this._selectedTaskId })
    }
}

hidden [void] HandleEditNotes() {
    [Logger]::Info("Handling command: task.edit.notes")
    if ($this._selectedTaskId) {
        # Open the notes editor dialog (which will be its own screen in a future phase)
        $task = $this._taskService.GetTask($this._selectedTaskId) # Still need service for this
        # ... logic to show the FullNotesEditor dialog ...
    }
}
# ... and so on for every other action (HandleNewTask, HandleToggleComplete, etc.)
```

#### **5.6 Verification for Phase 4**

1.  **Integrate with the Bootstrapper:** In `Core/Bootstrapper.ps1`, change the line that creates `[BaseScreen]` to create `[TaskListScreen]` instead.
2.  **Run the Application:** Execute `SimpleTaskPro.ps1`.
3.  **Expected Outcome:**
    *   The application launches and displays a fully rendered, functional Task List inside the UI Shell.
    *   **Navigation Works:** Up and down arrow keys correctly move the selection pillbox.
    *   **Input Works:**
        *   Pressing 'E' correctly starts inline editing for the selected task.
        *   Pressing `Enter` correctly opens the full-screen notes editor.
        *   Pressing `Delete` removes the selected task.
    *   **Cursor is Correct:** During inline editing, the physical cursor appears at the correct X,Y coordinate for the field being edited.
    *   **Logging is Active:** The log file is populated with messages from the screen and services as actions are performed.

With the completion of this phase, the most complex part of the refactor is done. We have a stable, high-performance, and maintainable core, with our main screen successfully migrated. The path to refactoring the remaining screens is now clear and simple.
