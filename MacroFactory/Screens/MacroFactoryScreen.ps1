# MacroFactoryScreen.ps1 - Main screen for MacroFactory application

class MacroFactoryScreen {
    # UI Components
    [SimpleList]$ComponentLibrary      # Left pane
    [SimpleGrid]$MacroSequence        # Center pane
    [SimpleGrid]$ContextPanel         # Right pane
    
    # Services
    [MacroContextManager]$ContextManager
    [MacroService]$MacroService
    
    # Available actions
    [System.Collections.ArrayList]$AvailableActions
    [bool]$Running = $true
    [int]$FocusedPane = 0  # 0=Library, 1=Sequence, 2=Context
    
    # Screen dimensions
    [int]$Width
    [int]$Height
    
    MacroFactoryScreen() {
        $this.AvailableActions = [System.Collections.ArrayList]::new()
        $this.Width = [Console]::WindowWidth
        $this.Height = [Console]::WindowHeight
        
        # Initialize services
        $this.ContextManager = [MacroContextManager]::new()
        $this.MacroService = [MacroService]::new()
        
        # Create UI components
        $this.CreateComponents()
        
        # Load available actions
        $this.LoadAvailableActions()
    }
    
    [void] CreateComponents() {
        # Calculate layout (30% | 40% | 30%)
        $gap = 1
        $leftWidth = [int]($this.Width * 0.3) - $gap
        $centerWidth = [int]($this.Width * 0.4) - $gap
        $rightWidth = $this.Width - $leftWidth - $centerWidth - ($gap * 2)
        
        # Component Library (left)
        $this.ComponentLibrary = [SimpleList]::new()
        $this.ComponentLibrary.Title = "📚 Component Library"
        $this.ComponentLibrary.SetBounds(0, 0, $leftWidth, $this.Height - 1)
        $this.ComponentLibrary.ItemRenderer = {
            param($action)
            if (-not $action) { return "" }
            return $action.GetDisplayText()
        }
        
        # Macro Sequence (center)
        $this.MacroSequence = [SimpleGrid]::new()
        $this.MacroSequence.Title = "🔧 Macro Sequence"
        $this.MacroSequence.SetBounds($leftWidth + $gap, 0, $centerWidth, $this.Height - 1)
        
        # Define columns
        $columns = @(
            @{ Name = "Step"; Width = 4 },
            @{ Name = "Action"; Width = 15 },
            @{ Name = "Status"; Width = 15 }
        )
        $this.MacroSequence.SetColumns($columns)
        
        # Context Panel (right)
        $this.ContextPanel = [SimpleGrid]::new()
        $this.ContextPanel.Title = "🎯 Macro Context"
        $this.ContextPanel.SetBounds($leftWidth + $centerWidth + ($gap * 2), 0, $rightWidth, $this.Height - 1)
        
        # Define columns
        $contextColumns = @(
            @{ Name = "Variable"; Width = 12 },
            @{ Name = "Type"; Width = 8 },
            @{ Name = "Value"; Width = 10 }
        )
        $this.ContextPanel.SetColumns($contextColumns)
        
        # Initial context update
        $this.UpdateContextPanel()
    }
    
    [void] LoadAvailableActions() {
        # Load action types
        . (Join-Path $PSScriptRoot ".." "Models" "SampleActions.ps1")
        
        # Add available actions
        $this.AvailableActions.Add([SummarizationAction]::new()) | Out-Null
        $this.AvailableActions.Add([AppendFieldAction]::new()) | Out-Null
        $this.AvailableActions.Add([ExportToExcelAction]::new()) | Out-Null
        $this.AvailableActions.Add([CustomIdeaCommandAction]::new()) | Out-Null
        
        # Update component library
        $this.ComponentLibrary.SetItems($this.AvailableActions)
        
        if ($global:Logger) {
            $global:Logger.Debug("Loaded $($this.AvailableActions.Count) actions")
        }
    }
    
    [void] Run() {
        # Hide cursor
        [Console]::CursorVisible = $false
        
        # Initial render
        $this.Render()
        
        # Main loop
        while ($this.Running) {
            if ([Console]::KeyAvailable) {
                $key = [Console]::ReadKey($true)
                $this.HandleInput($key)
                $this.Render()
            }
            
            Start-Sleep -Milliseconds 50
        }
        
        # Cleanup
        [Console]::CursorVisible = $true
        [Console]::Clear()
    }
    
    [void] Render() {
        $sb = [System.Text.StringBuilder]::new()
        
        # Clear screen
        $sb.Append([VT]::Clear())
        
        # Render components
        $sb.Append($this.ComponentLibrary.Render())
        $sb.Append($this.MacroSequence.Render())
        $sb.Append($this.ContextPanel.Render())
        
        # Status bar
        $sb.Append([VT]::MoveTo(0, $this.Height - 1))
        $sb.Append("`e[48;2;40;40;50m" + (" " * $this.Width))
        $sb.Append([VT]::MoveTo(2, $this.Height - 1))
        
        $shortcuts = switch ($this.FocusedPane) {
            0 { "Tab:Switch Pane | Enter:Add Action | Q:Quit" }
            1 { "Tab:Switch Pane | Enter:Edit | D:Delete | ↑↓:Move | F5:Preview | Ctrl+S:Save | Q:Quit" }
            2 { "Tab:Switch Pane | Q:Quit" }
        }
        
        $sb.Append("`e[38;2;200;200;200m$shortcuts`e[0m")
        
        Write-Host -NoNewline $sb.ToString()
    }
    
    [void] HandleInput([System.ConsoleKeyInfo]$key) {
        # Global shortcuts
        if ($key.KeyChar -eq 'q' -or $key.KeyChar -eq 'Q') {
            $this.Running = $false
            return
        }
        
        if ($key.Key -eq [System.ConsoleKey]::Tab) {
            $this.FocusedPane = ($this.FocusedPane + 1) % 3
            $this.UpdateFocusHighlight()
            return
        }
        
        # Pane-specific input
        switch ($this.FocusedPane) {
            0 { $this.HandleLibraryInput($key) }
            1 { $this.HandleSequenceInput($key) }
            2 { $this.HandleContextInput($key) }
        }
    }
    
    [void] HandleLibraryInput([System.ConsoleKeyInfo]$key) {
        switch ($key.Key) {
            ([System.ConsoleKey]::UpArrow) { $this.ComponentLibrary.MoveUp() }
            ([System.ConsoleKey]::DownArrow) { $this.ComponentLibrary.MoveDown() }
            ([System.ConsoleKey]::Enter) { $this.AddActionToSequence() }
        }
    }
    
    [void] HandleSequenceInput([System.ConsoleKeyInfo]$key) {
        switch ($key.Key) {
            ([System.ConsoleKey]::UpArrow) { 
                if ($key.Modifiers -band [System.ConsoleModifiers]::Control) {
                    $this.MoveActionUp()
                } else {
                    $this.MacroSequence.MoveUp()
                }
            }
            ([System.ConsoleKey]::DownArrow) { 
                if ($key.Modifiers -band [System.ConsoleModifiers]::Control) {
                    $this.MoveActionDown()
                } else {
                    $this.MacroSequence.MoveDown()
                }
            }
            ([System.ConsoleKey]::Enter) { $this.EditSelectedAction() }
            ([System.ConsoleKey]::D) { 
                if ($key.Modifiers -eq 0) {
                    $this.RemoveSelectedAction()
                }
            }
            ([System.ConsoleKey]::F5) { $this.PreviewScript() }
            ([System.ConsoleKey]::S) {
                if ($key.Modifiers -band [System.ConsoleModifiers]::Control) {
                    $this.SaveMacro()
                }
            }
            ([System.ConsoleKey]::O) {
                if ($key.Modifiers -band [System.ConsoleModifiers]::Control) {
                    $this.OpenMacro()
                }
            }
        }
    }
    
    [void] HandleContextInput([System.ConsoleKeyInfo]$key) {
        switch ($key.Key) {
            ([System.ConsoleKey]::UpArrow) { $this.ContextPanel.MoveUp() }
            ([System.ConsoleKey]::DownArrow) { $this.ContextPanel.MoveDown() }
        }
    }
    
    [void] UpdateFocusHighlight() {
        # Update border colors based on focus
        $focusedColor = "`e[38;2;255;200;100m"
        $normalColor = "`e[38;2;100;150;255m"
        
        $this.ComponentLibrary.BorderColor = if ($this.FocusedPane -eq 0) { $focusedColor } else { $normalColor }
        $this.MacroSequence.BorderColor = if ($this.FocusedPane -eq 1) { $focusedColor } else { $normalColor }
        $this.ContextPanel.BorderColor = if ($this.FocusedPane -eq 2) { $focusedColor } else { $normalColor }
    }
    
    [void] AddActionToSequence() {
        $selectedAction = $this.ComponentLibrary.GetSelectedItem()
        if (-not $selectedAction) { return }
        
        # Clone the action for the sequence
        $actionInstance = $selectedAction.Clone()
        
        # Add to context manager
        $this.ContextManager.AddAction($actionInstance)
        
        # Update displays
        $this.UpdateMacroSequence()
        $this.UpdateContextPanel()
        
        # Show properties dialog if action needs configuration
        if ($actionInstance.Consumes.Count -gt 0) {
            $this.EditAction($this.ContextManager.Actions.Count - 1)
        }
    }
    
    [void] RemoveSelectedAction() {
        if ($this.MacroSequence.SelectedIndex -ge 0 -and 
            $this.MacroSequence.SelectedIndex -lt $this.ContextManager.Actions.Count) {
            
            $this.ContextManager.RemoveAction($this.MacroSequence.SelectedIndex)
            $this.UpdateMacroSequence()
            $this.UpdateContextPanel()
        }
    }
    
    [void] MoveActionUp() {
        $idx = $this.MacroSequence.SelectedIndex
        if ($idx -gt 0) {
            $this.ContextManager.MoveAction($idx, $idx - 1)
            $this.UpdateMacroSequence()
            $this.MacroSequence.SelectedIndex = $idx - 1
        }
    }
    
    [void] MoveActionDown() {
        $idx = $this.MacroSequence.SelectedIndex
        if ($idx -ge 0 -and $idx -lt ($this.ContextManager.Actions.Count - 1)) {
            $this.ContextManager.MoveAction($idx, $idx + 1)
            $this.UpdateMacroSequence()
            $this.MacroSequence.SelectedIndex = $idx + 1
        }
    }
    
    [void] EditSelectedAction() {
        if ($this.MacroSequence.SelectedIndex -ge 0) {
            $this.EditAction($this.MacroSequence.SelectedIndex)
        }
    }
    
    [void] EditAction([int]$index) {
        if ($index -lt 0 -or $index -ge $this.ContextManager.Actions.Count) { return }
        
        $action = $this.ContextManager.Actions[$index]
        
        # Create property editor dialog
        . (Join-Path $PSScriptRoot "ActionPropertiesDialog.ps1")
        $dialog = [ActionPropertiesDialog]::new($action)
        $dialog.Show()
        
        # Update displays after editing
        $this.UpdateMacroSequence()
        $this.UpdateContextPanel()
        $this.Render()
    }
    
    [void] UpdateMacroSequence() {
        $rows = @()
        
        for ($i = 0; $i -lt $this.ContextManager.Actions.Count; $i++) {
            $action = $this.ContextManager.Actions[$i]
            $context = $this.ContextManager.GetContextAtStep($i)
            
            # Get validation status
            $statusInfo = $action.GetValidationStatus($context)
            
            $rows += @{
                Step = ($i + 1).ToString()
                Action = $action.Name
                Status = $statusInfo.Message
            }
        }
        
        $this.MacroSequence.SetRows($rows)
    }
    
    [void] UpdateContextPanel() {
        $rows = @()
        
        # Get full context
        $context = $this.ContextManager.GetFullContext()
        
        foreach ($varName in $context.Keys) {
            $varInfo = $context[$varName]
            
            $value = if ($varInfo.ContainsKey('Value')) { 
                $varInfo.Value 
            } else { 
                "<undefined>" 
            }
            
            # Truncate value if too long
            if ($value.Length -gt 10) {
                $value = $value.Substring(0, 7) + "..."
            }
            
            $rows += @{
                Variable = $varName
                Type = $varInfo.Type
                Value = $value
            }
        }
        
        $this.ContextPanel.SetRows($rows)
    }
    
    [void] PreviewScript() {
        try {
            $script = $this.ContextManager.GenerateScript()
            
            # Show script in preview dialog
            . (Join-Path $PSScriptRoot "ScriptPreviewDialog.ps1")
            $preview = [ScriptPreviewDialog]::new($script)
            $preview.Show()
            
            $this.Render()
        } catch {
            $dialog = [SimpleDialog]::new("Error", $_.Exception.Message)
            $dialog.Buttons = @("OK")
            $dialog.Show()
            $this.Render()
        }
    }
    
    [void] SaveMacro() {
        # Get macro name
        . (Join-Path $PSScriptRoot "TextInputDialog.ps1")
        $nameDialog = [TextInputDialog]::new("Save Macro", "Enter macro name:")
        $nameDialog.Show()
        
        if ($nameDialog.Result -and $nameDialog.InputText) {
            $name = $nameDialog.InputText
            
            # Get description
            $descDialog = [TextInputDialog]::new("Macro Description", "Enter description (optional):")
            $descDialog.Show()
            
            $description = if ($descDialog.Result) { $descDialog.InputText } else { "" }
            
            try {
                $this.MacroService.SaveMacro($name, $this.ContextManager, $description)
                
                $dialog = [SimpleDialog]::new("Success", "Macro saved successfully!")
                $dialog.Buttons = @("OK")
                $dialog.Show()
            } catch {
                $dialog = [SimpleDialog]::new("Error", "Failed to save macro: $_")
                $dialog.Buttons = @("OK")
                $dialog.Show()
            }
        }
        
        $this.Render()
    }
    
    [void] OpenMacro() {
        try {
            $macros = $this.MacroService.GetAvailableMacros()
            
            if ($macros.Count -eq 0) {
                $dialog = [SimpleDialog]::new("Open Macro", "No saved macros found.")
                $dialog.Buttons = @("OK")
                $dialog.Show()
                $this.Render()
                return
            }
            
            # Show macro selection dialog
            . (Join-Path $PSScriptRoot "MacroSelectionDialog.ps1")
            $selectDialog = [MacroSelectionDialog]::new($macros)
            $selectDialog.Show()
            
            if ($selectDialog.Result -and $selectDialog.SelectedMacro) {
                # Load the macro
                $newContextManager = $this.MacroService.LoadMacro($selectDialog.SelectedMacro.Filename)
                $this.ContextManager = $newContextManager
                
                # Update UI
                $this.UpdateMacroSequence()
                $this.UpdateContextPanel()
            }
        } catch {
            $dialog = [SimpleDialog]::new("Error", "Failed to open macro: $_")
            $dialog.Buttons = @("OK")
            $dialog.Show()
        }
        
        $this.Render()
    }
}