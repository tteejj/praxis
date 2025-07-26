Of course. Let's elevate the `VisualMacroFactory` from a functional prototype to a robust and complete system. This involves enhancing the user experience, ensuring data integrity, and providing a full end-to-end workflow from creation to execution.

The core of this enhancement is a shift from a static to a fully dynamic and interactive system. Here is a detailed, multi-phase plan to achieve this.

---

### Phase 1: The Interactive Configuration System (The Core UX)

This phase addresses the most critical missing piece: allowing users to configure each action with the specific data it needs to operate.

#### 1.1. Enhance the `BaseAction` Contract for Dynamic UI

First, we need to make the `Consumes` property in `BaseAction` more descriptive so the UI can build itself dynamically.

**File to Modify:** `Models/BaseAction.ps1`

Expand the `Consumes` hashtable to include more metadata, such as the type of input required and potential options.

```powershell
# In class BaseAction

# Modify this property definition
[hashtable[]]$Consumes = @(
    @{
        Name = "fieldName"
        Label = "Field Name" # User-friendly label for the UI
        Type = "String"      # Input type: String, Field, Database, Boolean, Choice
        Description = "Name for the new field"
        Default = "NEW_FIELD"
    },
    @{
        Name = "fieldToSummarize"
        Label = "Field to Summarize"
        Type = "Field" # A special type indicating the UI should let the user pick a field
        Description = "The database field to group by"
    },
    @{
        Name = "includeHeader"
        Label = "Include Header"
        Type = "Boolean"
        Description = "Include a header row in the output"
        Default = $true
    },
    @{
        Name = "exportFormat"
        Label = "Export Format"
        Type = "Choice"
        Description = "The format to export the file in"
        Options = @("Excel", "CSV", "Text") # Options for a dropdown
    }
)
```

#### 1.2. Create the `ActionPropertiesDialog`

This new, intelligent dialog will read an action's `Consumes` contract and generate the appropriate input controls.

**New File:** `Screens/ActionPropertiesDialog.ps1`

```powershell
class ActionPropertiesDialog : BaseDialog {
    hidden [BaseAction]$_action
    hidden [hashtable]$_controls = @{} # Stores the created UI controls

    ActionPropertiesDialog([BaseAction]$action) : base("Configure: $($action.Name)") {
        $this._action = $action
        $this.DialogWidth = 70
        # Dynamic height based on the number of parameters
        $this.DialogHeight = 8 + ($action.Consumes.Count * 4) 
        $this.PrimaryButtonText = "Apply"
    }

    [void] InitializeContent() {
        foreach ($param in $this._action.Consumes) {
            $control = $null
            $currentValue = $this._action.Parameters[$param.Name] ?? $param.Default

            # Create different controls based on the parameter type
            switch ($param.Type) {
                "Field" {
                    # In a real scenario, this would be a ListBox populated with fields
                    # from the current context database. For now, a TextBox will suffice.
                    $control = [MinimalTextBox]::new()
                    $control.Placeholder = "Enter field name (e.g., AMOUNT)"
                }
                "Boolean" {
                    # A ListBox is a good way to represent a boolean choice
                    $control = [MinimalListBox]::new()
                    $control.SetItems(@("True", "False"))
                    $control.SelectIndex( if ([bool]::Parse($currentValue)) { 0 } else { 1 } )
                    $control.Height = 3 # Smaller listbox
                }
                "Choice" {
                    $control = [MinimalListBox]::new()
                    $control.SetItems($param.Options)
                    if ($currentValue) {
                        $control.SelectIndex([array]::IndexOf($param.Options, $currentValue))
                    }
                    $control.Height = $param.Options.Count + 2
                }
                default { # "String", "Database", etc.
                    $control = [MinimalTextBox]::new()
                    $control.Placeholder = $param.Description
                }
            }
            
            if ($control -is [MinimalTextBox] -and $currentValue) {
                $control.Text = $currentValue.ToString()
            }

            # Add a label for each control
            $control.Title = $param.Label # Using a 'Title' property on controls would be ideal
            
            $this.AddContentControl($control)
            $this._controls[$param.Name] = $control
        }

        # On Save, update the action's parameters
        $this.OnPrimary = {
            foreach ($name in $this._controls.Keys) {
                $control = $this._controls[$name]
                $value = $null
                if ($control -is [MinimalTextBox]) {
                    $value = $control.Text
                } elseif ($control -is [MinimalListBox]) {
                    $value = $control.GetSelectedItem()
                }
                $this._action.Parameters[$name] = $value
            }
        }.GetNewClosure()
    }
}
```

#### 1.3. Trigger the Dialog from the `VisualMacroFactoryScreen`

The user needs a way to open this dialog. Double-clicking or pressing Enter on an action in the `MacroSequence` is the standard UX for this.

**File to Modify:** `Screens/VisualMacroFactoryScreen.ps1`

```powershell
# In CreateMacroSequence() method
$this.MacroSequence.Initialize($this.ServiceContainer)
$this.AddChild($this.MacroSequence)

# ---> ADD THIS <---
# This scriptblock will be executed when Enter is pressed on a grid item.
$this.MacroSequence.OnItemActivated = {
    $this.EditSelectedAction()
}.GetNewClosure()

# ... also in RegisterShortcuts()
$shortcutManager.RegisterShortcut(@{
    Id = "macro_factory_edit_action"
    Key = [System.ConsoleKey]::Enter
    Scope = [ShortcutScope]::Context
    Context = "MacroSequenceFocus" # Hypothetical context
    Action = { if ($this.MacroSequence.IsFocused) { $this.EditSelectedAction() } }
})

# ... then add the new method to the class
[void] EditSelectedAction() {
    $index = $this.MacroSequence.SelectedIndex
    if ($index -lt 0) { return }

    $action = $this.ContextManager.Actions[$index]
    $dialog = [ActionPropertiesDialog]::new($action)
    
    # After the dialog closes, refresh the UI to reflect changes.
    $dialog.OnPrimary = {
        $this.UpdateMacroSequence()
        $this.UpdateContextPanel()
    }.GetNewClosure()

    $global:ScreenManager.Push($dialog)
}
```

---

### Phase 2: Advanced Context Management and Validation

Make the macro factory "smart" by providing real-time validation and feedback.

#### 2.1. Dynamic Context Resolution

The context manager should resolve variables. When an action has a parameter like `"@PromptForField"` or refers to the output of a previous step like `"$summaryResult"`, the context manager needs to understand and validate this.

**File to Modify:** `Services/MacroContextManager.ps1`

```powershell
# In MacroContextManager class

[hashtable] GetContextAtStep([int]$stepIndex) {
    $context = $this.GlobalContext.Clone()
    
    for ($i = 0; $i -lt $stepIndex; $i++) {
        $action = $this.Actions[$i]
        
        # ---> NEW: Resolve parameters before adding produced variables <---
        # This allows an action to use variables from a step right before it.
        $resolvedParams = @{}
        foreach($paramName in $action.Parameters.Keys){
            $value = $action.Parameters[$paramName]
            if($value -is [string] -and $value.StartsWith('$')){
                # This is a variable reference, check if it exists in the current context
                $varName = $value.Substring(1)
                if($context.ContainsKey($varName)){
                    $resolvedParams[$paramName] = $context[$varName]
                }
            } else {
                $resolvedParams[$paramName] = $value
            }
        }

        foreach ($produced in $action.Produces) {
            # Use the resolved output name from the action's parameters
            $outputVarName = $resolvedParams[$produced.Name] ?? $produced.Name
            
            $context[$outputVarName] = @{
                Type = $produced.Type
                Description = $produced.Description
                ProducedBy = "$($action.Name) (Step $($i+1))"
            }
        }
    }
    return $context
}
```

#### 2.2. Richer Validation Feedback

Instead of a simple "Ready" or "Issues" status, provide detailed error messages.

**File to Modify:** `Screens/VisualMacroFactoryScreen.ps1`

```powershell
# In UpdateMacroSequence() method

$statusInfo = $action.GetValidationStatus($context) # New method on BaseAction
$rows += @{
    # ... other properties ...
    Status = $statusInfo.Message
    # You could even store the status color here
}

# ... and in the DataGrid column definition ...
@{ Name = "Status"; Header = "Status"; Width = 15;
    Formatter = { param($value)
        if ($value -match "✅") {
            return "`e[32m$value`e[0m" # Green
        } elseif ($value -match "⚠️") {
            return "`e[33m$value`e[0m" # Yellow
        }
        return $value
    }
}
```

**File to Modify:** `Models/BaseAction.ps1`

```powershell
# New method in BaseAction class

[hashtable] GetValidationStatus([hashtable]$macroContext) {
    $missing = $this.GetMissingContext($macroContext)
    if ($missing.Count -gt 0) {
        return @{ IsValid = $false; Message = "⚠️ Missing: $($missing -join ', ')" }
    }
    
    # Add more checks here, e.g., type validation
    
    return @{ IsValid = $true; Message = "✅ Ready" }
}
```

---

### Phase 3: Full Lifecycle and Integration

Enable users to save, load, and use their created macros.

#### 3.1. Robust Save/Load

Improve the persistence logic to be more resilient.

**File to Modify:** `Screens/VisualMacroFactoryScreen.ps1`

```powershell
# In OpenMacro() method

# ... inside the loop ...
$actionType = [type]$actionData.ActionType
if (-not $actionType) {
    # ---> ADD THIS ROBUSTNESS LOGIC <---
    Write-Warning "Action type '$($actionData.ActionType)' not found. Skipping."
    # Optionally, create a placeholder action to preserve the sequence
    $actionInstance = [MissingAction]::new($actionData.ActionType) 
    continue
}
$actionInstance = $actionType::new()
# ...
```

#### 3.2. Script Preview and Export

Instead of logging the script to the console, show it in a proper text editor screen.

**File to Modify:** `Screens/VisualMacroFactoryScreen.ps1`

```powershell
# In PreviewGeneratedScript() method

[void] PreviewGeneratedScript() {
    try {
        $script = $this.ContextManager.GenerateScript()
        
        # ---> REPLACE CONSOLE LOGGING WITH THIS <---
        # Create a read-only text editor screen to display the script
        $previewScreen = [TextEditorScreenNew]::new()
        $previewScreen.Title = "IDEAScript Preview (Read-Only)"
        
        # Load the script content into the buffer
        $previewScreen._buffer.Lines.Clear()
        $script.Split("`n") | ForEach-Object { $previewScreen._buffer.Lines.Add($_) }
        $previewScreen._buffer.IsModified = $false # Mark as not modified
        
        # In a full implementation, you'd make the buffer read-only
        
        $global:ScreenManager.Push($previewScreen)

    } catch {
        # Show an error modal
        $errorDialog = [MessageModal]::new("Script Generation Error", $_.Exception.Message)
        $global:ScreenManager.Push($errorDialog)
    }
}
```

---

### Final Polish and Recommendations

-   **Status Bar:** Add a `MinimalStatusBar` to the `VisualMacroFactoryScreen` to display shortcut hints and status messages (e.g., "Macro Saved").
-   **Context-Aware `ActionPropertiesDialog`:** The dialog for an action should be able to query the `MacroContextManager` for available variables. For example, when configuring an `ExportToExcelAction`, the "Database" field should present a dropdown of all `Database` type variables created in previous steps.
-   **Undo/Redo for Macro Building:** Wrap actions like `AddAction`, `RemoveAction`, and parameter changes in a command pattern so the user can undo mistakes while building the macro itself.

By implementing these three phases, your Visual Macro Factory will be a complete, robust, and intuitive tool for automating IDEA tasks.
