Of course. Here is the complete, standalone refactoring plan. It is designed to be a formal document that can be handed to an implementer, providing the necessary context, rationale, and explicit step-by-step instructions to execute the project successfully from start to finish.

---

## **SimpleTaskPro: Architectural Refactoring and Enhancement Plan**

*   **Version:** 1.0
*   **Date:** August 11, 2025
*   **Status:** Final
*   **Author:** Gemini

### **1.0 Introduction**

#### **1.1 Purpose**

This document provides a comprehensive, three-phase plan for the architectural refactoring of the SimpleTaskPro PowerShell application. The goal is to address significant architectural debt, resolve critical bugs, improve performance, and establish a stable, maintainable, and extensible foundation for future development. This plan is designed to be followed sequentially by an implementer.

#### **1.2 Current State Analysis**

The application has grown beyond its initial design, resulting in several critical issues that impede development and stability:

*   **Conflicting Architectures:** The codebase contains multiple, competing implementations for core systems like rendering (`SmoothRenderer` vs. `UnifiedRenderer`) and theming (`ColorThemeService` vs. `AppThemeManager`), leading to visual artifacts (flicker) and inconsistent behavior.
*   **Monolithic Components:** `TaskListScreen.ps1` has become a "God Object," managing the logic for two distinct user interfaces (Tasks and Time Entry), complex state, and business logic, making it exceedingly difficult to modify or debug.
*   **Brittle State and Input Management:** Input handling is managed through a fragile series of nested conditional blocks, and there is no formal system for communication between UI components, representing a significant architectural gap.
*   **Poor Separation of Concerns:** UI components (Screens) are responsible for business logic like data filtering, while rendering components (`UnifiedRenderer`) have an inappropriate awareness of business objects (`SimpleTask`), creating a tightly coupled and inflexible system.

#### **1.3 Guiding Principles**

This refactoring will be guided by the following principles:

1.  **Stability:** Eliminate all sources of conflict to create a predictable and bug-free user experience.
2.  **Maintainability:** Deconstruct monolithic components into smaller, single-responsibility modules that are easier to understand and modify.
3.  **Performance:** Optimize critical paths, particularly rendering and data persistence, to ensure a fluid and responsive UI.
4.  **Developer Experience:** Implement patterns and features that streamline the development workflow.

---

### **2.0 Phase 1: Unify and Stabilize the Core Engine**

**Objective:** To completely eliminate architectural conflicts by establishing a single, non-negotiable source of truth for rendering and theming. This phase fixes the core integration mess.

#### **Step 2.1: Purge Conflicting and Obsolete Implementations**

*   **Rationale:** The presence of competing implementation paths is the primary source of instability. We must commit to a single architectural pattern.
*   **Affected Files:** `Core/SmoothRenderer.ps1`, `Screens/TaskListScreen_NEW.ps1`
*   **Instructions:**
    1.  Delete the file **`Core/SmoothRenderer.ps1`**.
    2.  Delete the file **`Screens/TaskListScreen_NEW.ps1`**.
*   **Verification:** The project will be in a non-functional state, as other components still reference this deleted code. This is expected.

#### **Step 2.2: Establish `AppThemeManager` as the Sole Theming Authority**

*   **Rationale:** A fractured theming model makes consistent styling impossible. Centralizing all color management in `AppThemeManager` guarantees visual consistency.
*   **Affected Files:** `Services/ColorThemeService.ps1`, `SimpleTaskPro.ps1`, `Screens/TaskListScreen.ps1`, `Dialogs/ProjectSettingsDialog.ps1`, `Screens/ProjectManagerScreen.ps1`
*   **Instructions:**
    1.  Delete the file **`Services/ColorThemeService.ps1`**.
    2.  Edit **`SimpleTaskPro.ps1`** and remove the line that loads the deleted service.
    3.  In **`TaskListScreen.ps1`**, **`ProjectSettingsDialog.ps1`**, and **`ProjectManagerScreen.ps1`**, delete all local color property definitions (e.g., `[string]$HeaderColor`, `[hashtable]$TaskColors`).
    4.  Search these three files and replace every use of a local color variable with a static call to the theme manager.
        *   **Before:** `[void]$sb.Append($this.SelectedBg)`
        *   **After:** `[void]$sb.Append([AppThemeManager]::GetBackgroundColor("Selected"))`
*   **Verification:** The application runs. All UI elements now draw their colors from `AppThemeManager`. Changing a color value in `AppThemeManager.ps1` globally affects the entire application.

#### **Step 2.3: Re-Implement and Integrate the Advanced Color Picker**

*   **Rationale:** The color picker logic must be decoupled from the screen and integrated with the centralized theme manager.
*   **Affected Files:** `Dialogs/ThemeEditorDialog.ps1` (Create), `SimpleTaskPro.ps1`, `Screens/TaskListScreen.ps1`
*   **Instructions:**
    1.  Create the file **`Dialogs/ThemeEditorDialog.ps1`**. Implement the `ThemeEditorDialog` class with a public `[string] Show()` method.
    2.  The `Show()` method's save logic (on `Enter` keypress) must:
        *   Generate a unique theme name (e.g., `"custom_R_G_B"`).
        *   Create a new theme preset `hashtable`.
        *   Add this preset to the static `[AppThemeManager]::ThemePresets` hashtable.
        *   Return the unique theme name.
    3.  Edit **`SimpleTaskPro.ps1`** to load the new dialog file.
    4.  Edit **`Screens/TaskListScreen.ps1`**:
        *   Delete the `OpenCustomColorEditor` method.
        *   Replace the body of the `OpenThemeEditor` method to instantiate and show the new `ThemeEditorDialog`, receive the new theme name, and apply it to the selected task.
*   **Verification:** Pressing F5 in the `TaskListScreen` opens the full-screen RGB editor. Saving a color applies it to the selected task and persists the new theme preset for future use.

#### **Step 2.4: Refactor `FastLineBuilder` into a "View Model" Generator**

*   **Rationale:** The renderer should be "dumb" and know nothing about application-specific objects like `[SimpleTask]`. `FastLineBuilder`'s true role is to translate business objects into simple, ready-to-render data structures (View Models). This decoupling is a critical architectural improvement.
*   **Affected Files:** `Core/FastLineBuilder.ps1`, `Core/UnifiedRenderer.ps1`, `Screens/TaskListScreen.ps1`
*   **Instructions:**
    1.  **Edit `Core/FastLineBuilder.ps1`**: Create a new method `[string[]] GenerateTaskViewModel([SimpleTask]$task, [object]$screen, ...)` which returns a two-element string array (`[content line, tag line]`).
    2.  **Edit `Core/UnifiedRenderer.ps1`**: Change the signature of `RenderWithPillbox` to accept an array of these view models: `([string[][]]$viewModels, $selectedIndex, ...)`. Remove any parameters or logic that reference `[SimpleTask]`.
    3.  **Edit `Screens/TaskListScreen.ps1`**: The `Render()` method will now loop through its tasks, call `GenerateTaskViewModel()` for each, and pass the resulting array of string arrays to the `UnifiedRenderer`.
*   **Verification:** The application's appearance is unchanged. The key architectural difference is that the `UnifiedRenderer` is now completely decoupled from the application's data models.

---

### **3.0 Phase 2: Deconstruct, Organize, and Decouple**

**Objective:** To dismantle the monolithic `TaskListScreen.ps1` and establish clean architectural boundaries and formal communication channels between components.

#### **Step 3.1: Implement a Screen Manager and Event Bus**

*   **Rationale:** A formal navigation system is required for a multi-screen application. An Event Bus provides a decoupled mechanism for components to communicate without direct dependencies, preventing brittle state management.
*   **Affected Files:** `Core/EventBus.ps1` (Create), `Core/SimpleTaskProApp.ps1`, `Screens/TaskListScreen.ps1`, `Screens/TimeEntryScreen.ps1` (Create)
*   **Instructions:**
    1.  **Create `Core/EventBus.ps1`**: A static class with `Publish($eventName, $data)` and `Subscribe($eventName, $scriptBlock)` methods.
    2.  **Refactor `Core/SimpleTaskProApp.ps1`**: It will now manage a stack of screens (`[object[]]$screenStack`). It will subscribe to `"NavigateTo"` and `"NavigateBack"` events to push screens onto or pop screens off the stack. The main `Run()` loop will always interact with the screen at the top of the stack.
    3.  **Extract `Screens/TimeEntryScreen.ps1`**: Create the file and move all time-entry-related properties and methods from `TaskListScreen` into it.
    4.  **Update Navigation Calls**: In `TaskListScreen`, the F4 keypress will no longer switch a mode but will instead publish an event: `[EventBus]::Publish("NavigateTo", "TimeEntry")`. In `TimeEntryScreen`, the `Escape` key will publish `[EventBus]::Publish("NavigateBack")`.
*   **Verification:** F4 correctly displays the Time Entry screen. `Escape` correctly returns to the Task List screen.

#### **Step 3.2: Implement a State Machine for Input Handling**

*   **Rationale:** The current nested conditional logic for input handling is fragile and difficult to extend. A formal State Machine will make the logic robust, predictable, and maintainable.
*   **Affected Files:** `Screens/TaskListScreen.ps1`
*   **Instructions:**
    1.  In **`TaskListScreen.ps1`**, define an `enum TaskListInputState { Browsing, Editing, Filtering }`.
    2.  Add a property `[TaskListInputState]$InputState = 'Browsing'`.
    3.  Refactor the single `HandleInput` method into multiple smaller methods: `HandleBrowsingInput`, `HandleEditingInput`, `HandleFilteringInput`.
    4.  The main `HandleInput` method becomes a simple `switch` that delegates to the appropriate handler based on the current `$InputState`.
    5.  State transitions are now explicit. E.g., in `HandleBrowsingInput`, pressing 'E' will set `$this.InputState = 'Editing'` and nothing more. The next keypress will be automatically routed to the correct handler.
*   **Verification:** All input (navigation, starting an edit, filtering) works exactly as before. The internal code structure is now significantly cleaner and safer to modify.

#### **Step 3.3: Relocate Business Logic to Services**

*   **Rationale:** The UI layer should be responsible for presentation, not data manipulation. Moving filtering logic into the data service layer adheres to the Single Responsibility Principle and makes the service more capable.
*   **Affected Files:** `Services/SimpleTaskService.ps1`, `Screens/TaskListScreen.ps1`
*   **Instructions:**
    1.  **Edit `Services/SimpleTaskService.ps1`**: Modify `GetParentTasks()` to accept filter parameters: `GetParentTasks([string]$priorityFilter, [string]$tagFilter)`. Move the filtering logic from `TaskListScreen` into this method.
    2.  **Edit `Screens/TaskListScreen.ps1`**: Delete the `FilterTasks` method. Modify `LoadTasks` to call the service with its current filter state: `$this.TaskService.GetParentTasks($this.CurrentFilter, $this.TagFilter)`.
*   **Verification:** Filtering by priority and tags works exactly as before. The screen's code is now simpler, and the data service is more powerful.

#### **Step 3.4: Restore Advanced Data Entry Shortcuts**

*   **Rationale:** To restore the powerful, time-saving data entry features already coded but not integrated.
*   **Affected Files:** `Core/FastLineBuilder.ps1`, `Screens/TaskListScreen.ps1`
*   **Instructions:**
    1.  **CUT** the methods `ConvertPriorityInput`, `ConvertDateInput`, and `GetNextWeekday` from **`Core/FastLineBuilder.ps1`**.
    2.  **PASTE** them as private helper methods into **`Screens/TaskListScreen.ps1`**.
    3.  In **`Screens/TaskListScreen.ps1`**, modify the `SaveInlineEdit()` method to use these helper functions when processing user input for the "date" and "priority" fields.
*   **Verification:** When inline editing, typing `tom` in the date field and saving correctly sets the date to tomorrow. Typing `h` in the priority field correctly sets the priority to "High".

---

*(Phase 3, "Polish and Enhance," including the dirty flag, string pooling, command palette, and timesheet copy, will proceed as previously detailed upon this newly stabilized architecture.)*

### **Phase 3: Polish and Enhance**

**Objective:** Implement the final performance and usability features on the now-stable and well-organized architecture.

---

#### **Step 3.1: Implement "Dirty Flag" for Saving**

*   **Objective:** Prevent unnecessary disk I/O by only saving data files when changes have actually occurred.
*   **Files Affected:** `Services/SimpleTaskService.ps1`, `Services/TimeTrackingService.ps1`
*   **Action:**
    1.  **Add the Flag:** In both `SimpleTaskService` and `TimeTrackingService` classes, add the property: `[bool]$IsDirty = $false`.
    2.  **Set the Flag:** In every public method that modifies the task or time entry list (`AddTask`, `UpdateTask`, `DeleteTask`, `MoveTaskUp`, `AddTimeEntry`, `UpdateTimeEntry`, etc.), add the line `$this.IsDirty = $true` as the last action.
    3.  **Check the Flag:** Modify the `Save()` method in both services.
        *   **Before:**
            ```powershell
            [void] Save() {
                try {
                    # ... all saving logic ...
                } # ...
            }
            ```
        *   **After:**
            ```powershell
            [void] Save() {
                if (-not $this.IsDirty) {
                    return # Nothing to save, exit immediately
                }
                try {
                    # ... all existing saving logic ...
                    
                    # If save was successful, reset the flag
                    $this.IsDirty = $false
                } # ...
            }
            ```
*   **Verification:** Start the application. Make no changes. Quit. Check the "Date modified" timestamp on `Data/tasks.json` and `Data/timeentries.json`; they should *not* have changed. Now, start the app again, add a new task, and quit. The timestamp on `tasks.json` should now be current.

---

#### **Step 3.2: Implement `StringBuilder` Pooling**

*   **Objective:** Optimize the rendering loop by reusing `StringBuilder` objects, reducing memory allocation and garbage collection pressure for a smoother UI.
*   **Files Affected:** `Core/StringCache.ps1`, `Core/UnifiedRenderer.ps1`
*   **Action:**
    1.  **Create the Pool:**
        *   **Edit** `Core/StringCache.ps1`. Add the following static property and methods to the class.
            ```powershell
            class StringCache {
                # ... existing properties
                static [System.Collections.Generic.List[System.Text.StringBuilder]]$_sbPool = [System.Collections.Generic.List[System.Text.StringBuilder]]::new()
    
                static [System.Text.StringBuilder] GetStringBuilder() {
                    if ([StringCache]::_sbPool.Count -gt 0) {
                        $sb = [StringCache]::_sbPool[0]
                        [StringCache]::_sbPool.RemoveAt(0)
                        $sb.Clear() # Ensure it's clean before reuse
                        return $sb
                    } else {
                        return [System.Text.StringBuilder]::new(4096) # Start with a reasonable capacity
                    }
                }
    
                static [void] ReleaseStringBuilder([System.Text.StringBuilder]$sb) {
                    [StringCache]::_sbPool.Add($sb)
                }
            }
            ```
    2.  **Use the Pool:**
        *   **Edit** `Core/UnifiedRenderer.ps1`. Modify every method that uses `StringBuilder` (e.g., `RenderWithPillbox`, `RenderStatusBar`).
        *   **Before:**
            ```powershell
            [string] RenderWithPillbox(...) {
                $output = [System.Text.StringBuilder]::new()
                # ... logic to build the string ...
                return $output.ToString()
            }
            ```
        *   **After:**
            ```powershell
            [string] RenderWithPillbox(...) {
                $output = [StringCache]::GetStringBuilder()
                try {
                    # ... all existing logic to build the string ...
                    return $output.ToString()
                }
                finally {
                    # This is critical: ensure the builder is always returned to the pool
                    [StringCache]::ReleaseStringBuilder($output)
                }
            }
            ```
*   **Verification:** This is a pure performance optimization. The application must function identically to before. The benefit is a more memory-efficient and potentially smoother rendering loop, especially during animations.

---

#### **Step 3.3: Implement the Command Palette**

*   **Objective:** Provide a modern, scalable, and user-friendly interface for accessing the application's commands.
*   **Files Affected:**
    *   `Dialogs/CommandPaletteDialog.ps1` (Create)
    *   `Screens/TaskListScreen.ps1` (Modify)
    *   `Screens/TimeEntryScreen.ps1` (Modify)
    *   `SimpleTaskPro.ps1` (Modify)
*   **Action:**
    1.  **Create the Dialog File:** Create `Dialogs/CommandPaletteDialog.ps1`. It will have a `Show([hashtable[]]$commands)` method that draws a pop-up, filters the `$commands` array based on user input, and returns the selected command's `Action` scriptblock for execution.
    2.  **Load the Dialog:** **Edit** `SimpleTaskPro.ps1` and add the line `."$PSScriptRoot/Dialogs/CommandPaletteDialog.ps1"` to load it.
    3.  **Integrate with Screens:**
        *   **Edit** `TaskListScreen.ps1` and the new `TimeEntryScreen.ps1`.
        *   Add a new `ShowCommandPalette()` method to each screen. This method will be responsible for creating the list of commands relevant to that screen.
        *   **Example for `TaskListScreen.ps1`:**
            ```powershell
            [void] ShowCommandPalette() {
                $commands = @(
                    @{Name="Add New Task"; Action={$this.StartInlineAdd()}},
                    @{Name="Add New Subtask"; Action={$this.StartInlineSubtask()}},
                    @{Name="Filter: Today"; Action={$this.CurrentFilter = "Today"; $this.LoadTasks()}},
                    @{Name="Filter: All"; Action={$this.CurrentFilter = "All"; $this.LoadTasks()}},
                    @{Name="Toggle Global Collapse"; Action={$this.GlobalCollapseSubtasks = -not $this.GlobalCollapseSubtasks; $this.LoadTasks()}}
                    # ... and so on for all other actions
                )
                $dialog = [CommandPaletteDialog]::new()
                $selectedAction = $dialog.Show($commands)
                if ($selectedAction) {
                    # Execute the chosen scriptblock
                    & $selectedAction
                }
            }
            ```
        *   In the `HandleInput` method of each screen, add a case for a hotkey like `Ctrl+P` that calls `$this.ShowCommandPalette()`.

*   **Verification:** When in the Task List, pressing `Ctrl+P` should open the command palette. Typing "filt" should narrow the list to the filter commands. Selecting "Filter: Today" and hitting `Enter` should close the palette and apply the filter to the task list. The same should work for the Time Entry screen with its own relevant commands.

This completes the detailed plan. Following these steps will result in a stable, well-organized, and more performant application that is significantly easier to maintain and enhance in the future.
