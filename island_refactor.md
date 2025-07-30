Of course. You are absolutely right to push for pragmatism. The goal is to get a robust, fast, and maintainable application, not to win an award for architectural purity. A plan that's too complex is a plan that won't get finished.

This new plan is built on that principle. It's a direct, high-impact strategy that focuses only on the changes necessary to make the application stable and fast. We will fix the broken parts and simplify the architecture without adding unnecessary layers.

---

### The Complete Pragmatic & Robust Refactoring Plan

### Part 1: The Guiding Philosophy - A PowerShell-Centric TUI

This plan is guided by principles that feel natural in PowerShell and prioritize immediate results:

1.  **Directness Over Abstraction:** We will use direct method calls and `[scriptblock]` callbacks. This is easier to debug than a complex event bus. A screen will call a service directly and then refresh itself. Simple.
2.  **Services are the State:** `ProjectService`, `TaskService`, etc., are the **single source of truth** for your data. Screens and components will always ask the service for the latest data instead of keeping their own copies. This eliminates the primary cause of data inconsistency bugs.
3.  **Performance is a Feature, Not an Afterthought:** We will only focus on the two biggest performance killers: rendering large lists and excessive string/memory allocation. We will ignore micro-optimizations.
4.  **Lean Components are Better:** We will choose the best, simplest component for each job and discard the complex, buggy alternatives. This reduces the amount of code to maintain and makes the system easier to understand.

---

### Part 2: The Action Plan

#### **Phase 1: Fix the Foundation (The Non-Negotiable Core)**

**Objective:** Implement the robust, focus-driven input model and the service-based state model. This phase solves the critical stability and input bugs.

1.  **Establish the `FocusManager`:**
    *   **Action:** Copy `Services/FocusManager.ps1` from the provided files into your `Services/` directory. It is a lightweight service that simply keeps track of the single active component.
    *   **Action:** In `Start.ps1`, load `Services/FocusManager.ps1` and register it with the `$global:ServiceContainer`.

2.  **Implement the Focus-Driven Input Model:**
    *   **Action:** Modify `Core/ScreenManager.ps1`. The main `Run` loop's input handling should be brutally simple: if a key is available, pass it directly to the active screen's `HandleInput` method. The `ScreenManager` no longer tries to be smart; it just delegates.
    *   **Action:** Modify `Base/Screen.ps1`. This is the most important change. The `HandleInput` method will now orchestrate all input for a screen.

    *   **Pseudocode for `Base/Screen.ps1`'s `HandleInput` method:**
        ```powershell
        # This is the pragmatic input dispatcher.
        [bool] HandleInput([System.ConsoleKeyInfo]$keyInfo) {
            # Priority 1: The single focused component gets the first chance to handle the key.
            # This is the core of the fix. It stops input from "leaking" to other controls.
            $focused = $this.ServiceContainer.GetService('FocusManager').GetFocused()
            if ($focused -and $this.ContainsElement($focused) -and $focused.HandleInput($keyInfo)) {
                return $true # The focused component handled it. We are done.
            }

            # Priority 2: If the component ignored it, check for screen-level shortcuts.
            # This is a new, overridable method where you'll put shortcuts like 'n' for New Project.
            if ($this.HandleScreenInput($keyInfo)) {
                return $true # The screen's shortcut handled it. We are done.
            }

            # Priority 3: As a last resort, handle universal Tab navigation.
            if ($keyInfo.Key -eq [System.ConsoleKey]::Tab) {
                $focusManager = $this.ServiceContainer.GetService('FocusManager')
                if ($keyInfo.Modifiers -band [System.ConsoleModifiers]::Shift) {
                    return $focusManager.FocusPrevious($this)
                } else {
                    return $focusManager.FocusNext($this)
                }
            }

            return $false # Nobody handled this key.
        }
        ```

3.  **Refactor State Management:**
    *   **Action:** Go to your screens (`ProjectsScreen.ps1`, `TaskScreen.ps1`, etc.). If they store their own lists of data (e.g., `[ArrayList]$Projects`), delete those properties. The screen should be stateless regarding core data.
    *   **Action:** In each screen, implement a `LoadData()` or `Refresh()` method that clears its grid and re-populates it by calling the appropriate service (e.g., `$projects = $this.ProjectService.GetAllProjects()`). Call this method in `OnActivated()` to ensure the screen always shows fresh data.
    *   **Action:** Refactor all button clicks and dialogs to follow a simple callback pattern.

    *   **Practical Example: The "New Project" Flow:**
        ```powershell
        # In Screens/ProjectsScreen.ps1
        
        # This method is called by the 'n' key shortcut in HandleScreenInput
        [void] NewProject() {
            $dialog = [NewProjectDialog]::new()
            
            # Use a scriptblock for the callback. This is clean and PowerShell-idiomatic.
            $dialog.OnCreate = {
                param($projectData) # The dialog gives us the data from its text boxes.
                
                # The Screen is responsible for calling the Service to update the master state.
                $this.ProjectService.AddProject($projectData.Name) # Assuming a simple AddProject method.
                
                # Now that the master state is updated, the Screen refreshes its own view.
                $this.LoadProjects() 
            }.GetNewClosure()
            
            $global:ScreenManager.Push($dialog)
        }
        ```

#### **Phase 2: Targeted Optimization and Component Cleanup**

**Objective:** Fix real performance issues and simplify the codebase by removing unused components.

1.  **Virtualize Rendering in `MinimalDataGrid`:**
    *   **Action:** Open `Components/MinimalDataGrid.ps1`. Find the main `for` loop in its `OnRender` (or equivalent) method that draws the rows.
    *   **Action:** Change the loop's logic. It must not iterate over all items. Instead, it should calculate a start and end index based on the grid's height and scroll offset.
    *   **Pseudocode for the `MinimalDataGrid` render loop:**
        ```powershell
        # Inside OnRender()
        $viewportHeight = $this.Height - 4 # Approximate height for content
        $startIndex = $this._scrollOffset
        $endIndex = [Math]::Min($this._scrollOffset + $viewportHeight, $this.Items.Count)

        # The loop ONLY draws what is visible on screen.
        for ($i = $startIndex; $i -lt $endIndex; $i++) {
            $item = $this.Items[$i]
            $screenY = $this.Y + 2 + ($i - $startIndex) # Calculate screen position
            # ... rendering logic for the single row ...
        }
        ```
    *   **Explanation:** This is the most critical performance fix. The grid will now be just as fast with 100,000 items as it is with 10.

2.  **Optimize `SearchableListBox` Filtering:**
    *   **Action:** Open `Components/SearchableListBox.ps1`.
    *   **Action:** Ensure that the `ApplyFilter()` method saves its output to a separate `[System.Collections.ArrayList]$_filteredItems`. The `OnRender()` method must loop over this `_filteredItems` list, **not** the main `$Items` list.
    *   **Explanation:** This prevents the component from re-filtering thousands of items on every single keypress or screen refresh, which is a major source of lag.

3.  **Decommission Unused Components:**
    *   **Action:** You are primarily using the `Minimal*` and `Enhanced*` components. Identify the old, unused components in the `_Backup` folder (e.g., the original `Button.ps1`, `ListBox.ps1`, `DataGrid.ps1`).
    *   **Action:** Delete these unused files.
    *   **Action:** Update `Start.ps1`'s `$loadOrder` array to remove the deleted files.
    *   **Explanation:** This is a simple cleanup that reduces complexity and makes it clear which components are the "correct" ones to use moving forward.

---

### Acceptance Criteria (Definition of Done)

This pragmatic refactor is complete when:

*   [ ] **Stability:** The application no longer freezes. Input is responsive and goes to the correct component (e.g., typing text only affects the focused `TextBox`).
*   [ ] **Performance:** The `ProjectsScreen` and `TaskScreen` are able to load and scroll through a test file of 1,000+ items without noticeable lag.
*   [ ] **Functionality:** All existing CRUD (Create, Read, Update, Delete) operations for projects and tasks work correctly using keyboard shortcuts (`n`, `e`, `d`, `Enter`).
*   [ ] **State Consistency:** Creating a new project and then immediately switching to the `TaskScreen` allows you to assign a task to that new project, proving the service is correctly acting as the single source of truth.
*   [ ] **Simplicity:** The `EventBus.ps1` and `StateManager.ps1` files have been deleted, and the application functions correctly without them. Unused component files from the `_Backup` directory have been deleted.
