You are absolutely correct. My previous plan was a strategist's overview, not an implementer's guide. To truly be useful, it needs to be a document that can be followed precisely, step-by-step, with no ambiguity.

I have refined the entire plan to meet this higher standard. Each step now includes the specific files to edit, the code to add or change, explicit "before" and "after" examples, and a "Verification" section so you can confirm your progress at each stage.

This is the refined, detailed roadmap.

---

### **Phase 1: Unify and Stabilize the Core Engine**

**Objective:** Eliminate all conflicting implementations to create a single, stable rendering and theming foundation. This will fix the "integration mess."

---

#### **Step 1.1: Purge Obsolete Code**

*   **Objective:** Remove redundant and conflicting files from the project.
*   **Files Affected:**
    *   `Core/SmoothRenderer.ps1` (Delete)
    *   `Screens/TaskListScreen_NEW.ps1` (Delete)
    *   `SimpleTaskPro.ps1` (Modify)
*   **Action:**
    1.  **Delete** the file `Core/SmoothRenderer.ps1`.
    2.  **Delete** the file `Screens/TaskListScreen_NEW.ps1`.
    3.  **Edit** `SimpleTaskPro.ps1`: This file loads all components at startup. We must remove the line that attempts to load the now-deleted `TaskListScreen_NEW.ps1`. (There is no line for `SmoothRenderer` as it was not part of the startup script).
        *   *Note: This step may seem trivial, but ensures the project no longer references deleted components.*

*   **Verification:** The application will fail to run after this step because `TaskListScreen` still has references to the deleted code. This is expected. We will fix this in the following steps.

---

#### **Step 1.2: Centralize Theming with `AppThemeManager`**

*   **Objective:** Make `AppThemeManager` the single source of truth for all colors and styles.
*   **Files Affected:**
    *   `Services/ColorThemeService.ps1` (Delete)
    *   `SimpleTaskPro.ps1` (Modify)
    *   `Screens/TaskListScreen.ps1` (Modify)
    *   `Dialogs/ProjectSettingsDialog.ps1` (Modify)
    *   `Screens/ProjectManagerScreen.ps1` (Modify)
*   **Action:**
    1.  **Delete** the file `Services/ColorThemeService.ps1`.
    2.  **Edit** `SimpleTaskPro.ps1`: Remove the line that loads the service: `."$PSScriptRoot/Services/ColorThemeService.ps1"`.
    3.  **Edit** `Screens/TaskListScreen.ps1`, `Dialogs/ProjectSettingsDialog.ps1`, and `Screens/ProjectManagerScreen.ps1`:
        *   Find and delete all local color property definitions (e.g., `[string]$HeaderColor`, `[string]$SelectedBg`, `[ConsoleColor]$HeaderColor`, etc.).
        *   Perform a find-and-replace for all usages of these local color variables.

        *   **Example Before (from `TaskListScreen.ps1`):**
            ```powershell
            [string]$HeaderColor = "`e[38;2;100;150;255m" 
            # ... later in code ...
            [void]$sb.Append($this.HeaderColor)
            ```
        *   **Example After:**
            ```powershell
            // The local variable definition is deleted
            # ... later in code ...
            [void]$sb.Append([AppThemeManager]::GetColor("Header"))
            ```
        *   Apply this pattern to *all* color variables in all three files. The color names in `AppThemeManager` (`Header`, `Field`, `Value`, `Button`, `Selected`, etc.) are comprehensive and should cover all existing use cases.

*   **Verification:** After this step, the application should run again. The UI will now draw its colors exclusively from `AppThemeManager`. Changing a color value in `AppThemeManager.ps1` should affect the entire application consistently.

---

#### **Step 1.3: Integrate the Advanced Color Picker**

*   **Objective:** Re-implement the live-preview RGB color picker as a modular dialog that correctly integrates with the new centralized theme manager.
*   **Files Affected:**
    *   `Dialogs/ThemeEditorDialog.ps1` (Create)
    *   `Screens/TaskListScreen.ps1` (Modify)
    *   `SimpleTaskPro.ps1` (Modify)
*   **Action:**
    1.  **Create** the new file `Dialogs/ThemeEditorDialog.ps1` with the following class structure:
        ```powershell
        class ThemeEditorDialog {
            # Method to show the dialog and handle its logic
            [string] Show() {
                # This method will contain the while($true) loop for input,
                # the logic for rendering the R, G, B values, the color preview box,
                # and handling key presses to change values.
            }
        }
        ```
    2.  **Edit** `Dialogs/ThemeEditorDialog.ps1`: Implement the `Show` method. The logic for the `Enter` keypress is critical:
        *   It will create a unique theme name, e.g., `"custom_123_45_210"`.
        *   It will create a new theme entry `hashtable`.
        *   It will add this new entry to the static `[AppThemeManager]::ThemePresets` hashtable.
        *   It will call `[AppThemeManager]::ApplyTheme("custom_123_45_210")` to make the change instant.
        *   It will return the name of the new custom theme.
    3.  **Edit** `SimpleTaskPro.ps1`: Add a line to load the new dialog: `."$PSScriptRoot/Dialogs/ThemeEditorDialog.ps1"`.
    4.  **Edit** `Screens/TaskListScreen.ps1`:
        *   **Delete** the entire `OpenCustomColorEditor` method.
        *   Modify the `OpenThemeEditor` method. Its new, simplified logic will be:
            ```powershell
            [void] OpenThemeEditor() {
                $dialog = [ThemeEditorDialog]::new()
                $newThemeName = $dialog.Show() # Show the dialog and get the result
                if ($newThemeName) {
                    # This task is now using the new custom theme
                    $item = $this.FlatList[$this.SelectedIndex]
                    $item.Task.ColorTheme = $newThemeName
                    $item.Task.SubtaskColorTheme = $newThemeName
                    $this.TaskService.UpdateTask($item.Task)
                    $this.LoadTasks()
                }
            }
            ```

*   **Verification:** Pressing F5 in the `TaskListScreen` should now open the new, full-screen RGB editor. Adjusting values should update the live preview. Pressing `Enter` should save the new custom color, apply it to the selected task, and return to the task list, which should immediately reflect the new color.

---

#### **Step 1.4: Finalize the Rendering Pipeline**

*   **Objective:** Fully consolidate all rendering and animation logic into `UnifiedRenderer`, making `TaskListScreen` a pure controller.
*   **Files Affected:**
    *   `Core/UnifiedRenderer.ps1` (Modify)
    *   `Screens/TaskListScreen.ps1` (Modify)
*   **Action:**
    1.  **Edit** `Core/UnifiedRenderer.ps1`:
        *   The existing `RenderWithAnimation` method is flawed because it tries to write directly to the console. We will change its signature and purpose.
        *   **New Method Signature:** `[void] AnimatePillboxSlide([List[string]]$lines, [int]$fromIndex, [int]$toIndex, [int]$startY)`
        *   **New Logic:** This method will contain the animation loop. Inside the loop, it will calculate the interpolated position and call its *own* `RenderWithPillbox` method to generate the *entire screen content as a single string*. It will then write that single string to the console with `[Console]::Write()`, followed by a `Start-Sleep`. This is a crucial change to eliminate flicker.
    2.  **Edit** `Screens/TaskListScreen.ps1`:
        *   **Delete** the methods: `RenderTaskMode`, `RenderTaskList`, `RenderPillboxTop`, `RenderPillboxBottom`, `RenderPillboxSide`, `RenderTaskContent`, `RenderTagContent`, and `RenderTreeSpacingLine`.
        *   **Rename** the method `RenderTaskModeEnhanced` to just `Render()`.
        *   **Replace the entire body** of the new `Render()` method. It will become very simple:
            ```powershell
            [string] Render() {
                # 1. Build the list of line strings using the line builder
                $lines = $this.LineBuilder.BuildAllLinesFromTemplates($this.FlatList, -1, $this)
                # 2. Let the renderer handle everything else
                return $this.Renderer.RenderWithPillbox($lines, $this.SelectedIndex)
            }
            ```
        *   Modify the main input-handling `switch` statement for `UpArrow` and `DownArrow`:
            *   **Before:** It would just change the index.
            *   **After:** It will now call the renderer's animation method. E.g., `$this.Renderer.AnimatePillboxSlide($lines, $this.PreviousSelectedIndex, $this.SelectedIndex)`. The main loop will no longer call `$this.Screen.Render()` after an up/down keypress, as the animation method handles all rendering.

*   **Verification:** The application should look and function as before, but the code will be vastly simpler. Moving the selection up and down should now trigger a smooth slide animation handled entirely by the `UnifiedRenderer`, and there should be zero flicker.

**At the end of Phase 1, the application's core engine will be stable, unified, and ready for further refactoring.**

Of course. Let's proceed with the same level of explicit detail for the remaining phases.

---

### **Phase 2: Deconstruct and Organize Code**

**Objective:** Break apart the oversized `TaskListScreen.ps1` file into logical, manageable components. This will make future development faster and less error-prone by ensuring each file has a single, clear responsibility.

---

#### **Step 2.1: Extract the Time Entry Screen**

*   **Objective:** Move all logic and state for the "Time Entry" mode into its own dedicated screen file, converting the `TaskListScreen`'s internal "mode" into a proper app-level state change between two distinct screens.
*   **Files Affected:**
    *   `Screens/TimeEntryScreen.ps1` (Create)
    *   `Screens/TaskListScreen.ps1` (Modify)
    *   `Core/SimpleTaskProApp.ps1` (Modify)
    *   `SimpleTaskPro.ps1` (Modify)
*   **Action:**
    1.  **Create New File:** Create the file `Screens/TimeEntryScreen.ps1`. Define the new class structure within it. It will initially be a container for the code we are about to move.
        ```powershell
        # In Screens/TimeEntryScreen.ps1
        class TimeEntryScreen {
            # All Time-Entry-related properties and methods will be pasted here.
        }
        ```
    2.  **Move Time-Related Properties:**
        *   **Edit** `Screens/TaskListScreen.ps1`.
        *   **CUT** (do not copy) the following property definitions from the top of the `TaskListScreen` class and **PASTE** them into the new `TimeEntryScreen` class:
            ```powershell
            # These lines are to be CUT from TaskListScreen.ps1
            [string]$CurrentMode = "Tasks" # This will be removed entirely later
            [TimeTrackingService]$TimeService = $null
            [SimpleTimeEntry[]]$TimeEntries = @()
            [hashtable]$TaskLookup = @{}
            [object]$AppReference = $null
            [System.Collections.Generic.List[object]]$TimeFlatList
            [int]$TimeSelectedIndex = 0
            [int]$TimeScrollTop = 0
            [int]$TimeEditingIndex = -1
            [string]$TimeEditingField = ""
            [string]$TimeEditingValue = ""
            [SimpleTimeEntry]$TimeEditingEntry = $null
            [bool]$IsNewTimeEntry = $false
            [bool]$IsTimeFilterActive = $true
            [int]$NameCol = 25
            [int]$ID1Col = 6
            # ... and all other Time Entry column and color variables.
            ```
    3.  **Move Time-Related Methods:**
        *   **Edit** `Screens/TaskListScreen.ps1`.
        *   **CUT** the following entire methods from `TaskListScreen` and **PASTE** them into the new `TimeEntryScreen` class:
            *   `InitializeTimeService`
            *   `LoadTaskLookup`
            *   `SwitchToTimeEntryMode` (This will be deleted later, but move it for now)
            *   `SwitchToTaskMode` (This will be deleted later, but move it for now)
            *   `LoadTimeEntries`
            *   `BuildTimeFlatList`
            *   `RenderTimeEntryMode`
            *   `GetCurrentDayOfWeek`
            *   `RenderTimeList`
            *   `GetTimeItemHeight`
            *   `RenderTimeContent`
            *   `RenderTimeDayColumn`
            *   `PositionTimeEntryCursor`
            *   `HandleTimeEntryInput`
            *   `HandleTimeEditingInput`
            *   `StartTimeInlineEdit`
            *   `StartTimeInlineAdd`
            *   `NextTimeEditField`
            *   `PreviousTimeEditField`
            *   `SetTimeEntryDayValue`
            *   `SaveTimeInlineEdit`
            *   `CancelTimeInlineEdit`
            *   `EndTimeInlineEdit`
            *   `DeleteTimeEntry`
            *   `EnsureTimeVisible`
    4.  **Update the Main Application Loader:**
        *   **Edit** `SimpleTaskPro.ps1`. Add the line to load our new screen file.
            ```powershell
            # Add this line in SimpleTaskPro.ps1, after ProjectManagerScreen is loaded
            ."$PSScriptRoot/Screens/TimeEntryScreen.ps1"
            ```
    5.  **Refactor the Main App Controller:**
        *   **Edit** `Core/SimpleTaskProApp.ps1`. This is where we change the state management logic.
        *   **Before:**
            ```powershell
            class SimpleTaskProApp {
                [TaskListScreen]$Screen
                // ...
            }
            ```
        *   **After:**
            ```powershell
            class SimpleTaskProApp {
                [TaskListScreen]$TaskScreen
                [TimeEntryScreen]$TimeEntryScreen
                [object]$ActiveScreen
                [bool]$Running = $true
                // ...

                SimpleTaskProApp() {
                    $this.TaskScreen = [TaskListScreen]::new()
                    $this.TimeEntryScreen = [TimeEntryScreen]::new()
                    $this.ActiveScreen = $this.TaskScreen # Start with the Task screen

                    # Give both screens a reference back to the app for switching
                    $this.TaskScreen.SetAppReference($this)
                    $this.TimeEntryScreen.SetAppReference($this)
                }

                [void] SwitchToTimeEntry() {
                    $this.ActiveScreen = $this.TimeEntryScreen
                    $this.ActiveScreen.LoadTimeEntries() # Ensure data is fresh
                }
            
                [void] SwitchToTasks() {
                    $this.ActiveScreen = $this.TaskScreen
                    $this.ActiveScreen.LoadTasks() # Ensure data is fresh
                }
                
                [void] Run() {
                    # ...
                    while ($this.Running) {
                        # Change this line:
                        if (-not $this.ActiveScreen.HandleInput($key)) { ... }
                        # Change this line:
                        Write-Host -NoNewline $this.ActiveScreen.Render()
                        # ...
                    }
                }
            }
            ```
        *   You will also need to add a simple `SetAppReference($app)` method to both `TaskListScreen.ps1` and the new `TimeEntryScreen.ps1` so they can call back to `$this.AppReference.SwitchToTasks()`, etc.

*   **Verification:** The application should start and look identical. Pressing F4 should now switch to the Time Entry UI. All functionality (editing, navigation) in both modes should work as before. The key difference is that the code is now properly separated, making the next steps much easier.

---

#### **Step 2.2: Centralize Layout Constants**

*   **Objective:** Remove all hardcoded column widths and layout "magic numbers" from screen and component files and place them in a single, globally accessible location.
*   **Files Affected:**
    *   `AppThemeManager.ps1` (Modify)
    *   `Core/FastLineBuilder.ps1` (Modify)
    *   `Screens/TaskListScreen.ps1` (Modify)
*   **Action:**
    1.  **Define the New Location:**
        *   **Edit** `AppThemeManager.ps1`. Add a new static hashtable property to the class.
            ```powershell
            class AppThemeManager {
                # ... existing properties ...
                static [hashtable]$Layout = @{
                    # All layout constants will be pasted here
                }
                # ... existing methods ...
            }
            ```
    2.  **Move the Constants:**
        *   Go through `Core/FastLineBuilder.ps1` and `Screens/TaskListScreen.ps1`.
        *   **CUT** all variables related to column widths and indentation (e.g., `$COLUMN_ID1`, `$COLUMN_ID2`, `$COLUMN_CREATED`, `$COLUMN_DATE`, `$COLUMN_ARROW`, `$TREE_INDENT`, `$SUBTASK_INDENT`, etc.).
        *   **PASTE** them into the new `$Layout` hashtable in `AppThemeManager.ps1`.
            ```powershell
            # In AppThemeManager.ps1
            static [hashtable]$Layout = @{
                ID1 = 5
                ID2 = 14
                Created = 12
                Date = 12
                Arrow = 3
                TreeIndent = 7
                SubtaskIndent = 4
                # etc...
            }
            ```
    3.  **Find and Replace:**
        *   In all files (primarily `FastLineBuilder.ps1`), replace every usage of the old variables with a static call to the new location.
        *   **Example Before (from `FastLineBuilder.ps1`):**
            ```powershell
            # Parent task: ID1(5) + ID2(14) + Created(12) + Due(12) + Arrow(3) + Title
            $length = 5 + 14 + 12 + 12 + 3
            ```
        *   **Example After:**
            ```powershell
            # Parent task: ID1 + ID2 + Created + Due + Arrow + Title
            $length = [AppThemeManager]::Layout.ID1 + [AppThemeManager]::Layout.ID2 + [AppThemeManager]::Layout.Created + [AppThemeManager]::Layout.Date + [AppThemeManager]::Layout.Arrow
            ```

*   **Verification:** The application's UI should render with the *exact same layout* as before. The change is purely architectural. To test, temporarily change a value in `AppThemeManager::$Layout` (e.g., set `ID1 = 10`), run the app, and observe that the ID1 column is now wider.

---

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
