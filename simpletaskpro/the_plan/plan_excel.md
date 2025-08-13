Understood. My apologies for the previous misinterpretation. Your clarification is exactly what was needed. You've outlined a far superior, TUI-native design that is elegant, efficient, and perfectly suited to the `ListScreen` architecture we've built.

We will discard the complex component-based approach for this screen entirely. The screen will be a single, flat, editable list. This is the correct path.

Here is the actual, detailed plan for implementing the `ExcelMappingScreen` based on your precise specifications.

---

### **Revised Plan: The `ExcelMappingScreen`**

#### **1.0 Guiding Philosophy**

The screen is not a form; it is a **database view**. The user interacts with it like a spreadsheet or a database table. Each row represents a complete record (a field mapping), and the columns represent the attributes of that record. Navigation is vertical (between records) and horizontal (between fields *during* inline editing). All actions operate on the currently selected row.

This design leverages the full power of the `ListScreen` base class and results in a clean, consistent, and highly efficient user experience.

---

#### **2.0 Data Model (`Models/ExcelFieldMapping.ps1`)**

The foundation of the screen is its data model. We need to ensure the `ExcelFieldMapping` class contains all the necessary properties to support your design.

*   **File:** `Models/ExcelFieldMapping.ps1`
*   **Action:** Verify or create this class with the following properties:

```powershell
class ExcelFieldMapping {
    [string]$Id              # Unique identifier
    [string]$DisplayName     # User-friendly name (editable)
    [string]$SourceCell      # Excel source, e.g., "W23" (editable)
    [string]$DestinationCell # Excel destination, e.g., "A1" (editable)
    [string]$T2020Name       # Name for the text export (editable)
    [bool]$IncludeInT2020    # Toggled by 'X' key
    [int]$SortOrder         # For T2020 export, modified by Ctrl+Arrows
    [string]$Category        # (Optional, but good for future grouping if needed)
    # ... (CreatedDate, ModifiedDate for tracking)
}```

---

#### **3.0 Service Layer (`Services/ExcelMappingService.ps1`)**

The screen will delegate all data persistence and business logic to its service.

*   **File:** `Services/ExcelMappingService.ps1`
*   **Action:** Implement the following methods:
    *   **`GetMappings()`**: Returns an array of `[ExcelFieldMapping]` objects. **Crucially, for the UI, these should be sorted alphabetically by `DisplayName`** to make them easy for the user to find.
    *   **`UpdateMapping([ExcelFieldMapping]$mapping)`**: Saves changes to a single mapping object.
    *   **`AddMapping([ExcelFieldMapping]$mapping)`**: Adds a new mapping to the data file.
    *   **`DeleteMapping([string]$id)`**: Deletes a mapping by its ID.
    *   **`MoveUpForT2020([string]$id)`**: Finds the mapping with the given ID. It then finds the mapping with the next lowest `SortOrder` and **swaps their `SortOrder` values**. This effectively moves the item up in the T2020 export without affecting the alphabetical display order.
    *   **`MoveDownForT2020([string]$id)`**: The inverse of `MoveUpForT2020`. It finds the mapping with the next highest `SortOrder` and swaps their values.
    *   **`GenerateT2020Export()`**: A new method that gets all mappings where `IncludeInT2020` is `$true`, **sorts them by `SortOrder`**, and generates the final text file.

---

#### **4.0 Screen Implementation (`Screens/ExcelMappingScreen.ps1`)**

This is the detailed plan for the screen itself.

##### **4.1 Class Definition & Properties**

*   **File:** `Screens/ExcelMappingScreen.ps1`
*   **Inherits from:** `ListScreen`
*   **Properties:**
    *   `[ExcelMappingService]$MappingService`: The service for data operations.
    *   `[int]$DisplayNameCol`, `$SourceCellCol`, etc.: Integer constants to define the fixed-width columns for rendering, ensuring a clean, table-like layout.

##### **4.2 Data Loading (`LoadData`)**

1.  Call `$this.MappingService.GetMappings()`. The service returns the mappings sorted alphabetically by `DisplayName`.
2.  Clear the `$this.FlatList`.
3.  Iterate through the sorted mappings and add each one to `$this.FlatList`. Since there are no groups, the `$FlatList` will be a simple, flat array of the mapping objects themselves.

##### **4.3 Rendering a Row (`RenderItem`)**

This is the core of the visual design. It will be called for each visible row.

1.  **Define Column Widths:**
    ```powershell
    [int]$IncludeCol = 4       # " [X]"
    [int]$DisplayNameCol = 30  # "RequestDate"
    [int]$SourceCellCol = 10   # "W23"
    [int]$DestCellCol = 10     # "A1"
    [int]$T2020NameCol = 30    # "RequestDate"
    ```
2.  **Implementation:** The method receives the mapping object, its index, and whether it's selected. It will use a `StringBuilder` to construct the line.

    ```powershell
    [string] RenderItem([object]$mapping, [int]$index, [bool]$isSelected) {
        $sb = [System.Text.StringBuilder]::new()
        $isEditingThis = ($this.EditingIndex -eq $index)

        # Column 1: IncludeInT2020 Checkbox
        $includeText = if ($mapping.IncludeInT2020) { " [X]" } else { " [ ]" }
        [void]$sb.Append($includeText.PadRight($this->IncludeCol))

        # Column 2: DisplayName (Editable)
        $this.RenderEditableField($sb, "DisplayName", $mapping.DisplayName, $this->DisplayNameCol, $isEditingThis)

        # Column 3: SourceCell (Editable)
        $this.RenderEditableField($sb, "SourceCell", $mapping.SourceCell, $this->SourceCellCol, $isEditingThis)
        
        # Column 4: DestinationCell (Editable)
        $this.RenderEditableField($sb, "DestinationCell", $mapping.DestinationCell, $this->DestCellCol, $isEditingThis)

        # Column 5: T2020Name (Editable)
        $this.RenderEditableField($sb, "T2020Name", $mapping.T2020Name, $this->T2020NameCol, $isEditingThis)

        return $sb.ToString()
    }

    // Helper method for rendering
    [void] RenderEditableField($sb, $fieldName, $value, $width, $isEditing) {
        if ($isEditing -and $this->EditingField -eq $fieldName) {
            // Use EditHighlight color and show the current editing value
            [void]$sb.Append($this->EditHighlight + $this->EditingValue.PadRight($width) + $this->NormalColor)
        } else {
            // Use normal colors
            [void]$sb.Append($this->ValueColor + $value.PadRight($width) + $this->NormalColor)
        }
    }
    ```

##### **4.4 Input Handling (`HandleDerivedCommand`)**

The `ListScreen` base class handles navigation (`UpArrow`, `DownArrow`) and standard editing keys (`Enter`, `Escape`, `Tab`). We only need to add the custom logic.

```powershell
[void] HandleDerivedCommand([string]$command) {
    switch ($command) {
        "action.toggle.include" { # We map the 'X' key to this command
            if ($this.FlatList.Count -gt 0) {
                $mapping = $this.FlatList[$this.SelectedIndex]
                $mapping.IncludeInT2020 = -not $mapping.IncludeInT2020
                $this.MappingService.UpdateMapping($mapping)
                # No need to reload, just invalidate the screen for re-render
            }
        }
        "action.move.up" { # Mapped to Ctrl+Up
            if ($this.FlatList.Count -gt 0) {
                $mapping = $this.FlatList[$this.SelectedIndex]
                $this.MappingService.MoveUpForT2020($mapping.Id)
                $this.SetStatusMessage("T2020 export order for '$($mapping.DisplayName)' moved up.")
            }
        }
        "action.move.down" { # Mapped to Ctrl+Down
            if ($this.FlatList.Count -gt 0) {
                $mapping = $this.FlatList[$this.SelectedIndex]
                $this.MappingService.MoveDownForT2020($mapping.Id)
                $this.SetStatusMessage("T2020 export order for '$($mapping.DisplayName)' moved down.")
            }
        }
        # ... handle F-keys for file picker, saving, etc.
    }
}
```

##### **4.5 Inline Editing**

1.  **`GetEditableFields`**: This method will return the list of editable field names in the desired Tab order: `DisplayName`, `SourceCell`, `DestinationCell`, `T2020Name`.
2.  **`StartEdit`, `SaveInlineEdit`, `CancelInlineEdit`**: These methods are already provided by the `ListScreen` base class and will work perfectly with this new design. The base class will automatically handle cycling through the fields defined in `GetEditableFields`.

---

#### **5.0 Verification Plan**

The implementation is complete when the following criteria are met:

1.  **Display:** The screen launches and displays a flat, alphabetized list of all field mappings. Each row clearly shows the `[X]`, `DisplayName`, `SourceCell`, `DestinationCell`, and `T2020Name` in fixed-width columns.
2.  **Navigation:** `UpArrow` and `DownArrow` move the selection pillbox correctly.
3.  **Inline Editing:** Pressing `Enter` on a row starts editing the `DisplayName`. `Tab` cycles focus to `SourceCell`, then `DestinationCell`, then `T2020Name`, and then wraps back to `DisplayName`. `Shift+Tab` cycles in reverse. `Escape` cancels the edit. `Enter` (while editing) saves the changes for the entire row.
4.  **T2020 Toggle:** Pressing `X` on a selected row toggles the `[ ]` and `[X]` state and persists the change.
5.  **Reordering:** Pressing `Ctrl+Up` or `Ctrl+Down` does *not* change the visual order of the list but displays a status message confirming the T2020 export order has been changed. A subsequent T2020 export will reflect this new order.
6.  **CRUD:** `N` starts the creation of a new, blank row at the bottom of the list and enters edit mode on its `DisplayName`. `Delete` removes the selected row after a confirmation prompt.

This plan directly implements your design, resulting in a powerful, intuitive, and architecturally clean screen. It eliminates all unnecessary complexity and leverages the existing `ListScreen` framework to its full potential.

