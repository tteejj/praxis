# VisualMacroFactoryScreen.ps1 - Visual macro builder for IDEA scripts
# Three-pane interface: Component Library | Macro Sequence | Context Panel

class VisualMacroFactoryScreen : Screen {
    # UI Components - Three panes
    [SearchableListBox]$ComponentLibrary      # Left pane
    [MinimalDataGrid]$MacroSequence           # Center pane
    [MinimalDataGrid]$ContextPanel            # Right pane
    
    # Services
    [MacroContextManager]$ContextManager
    [FunctionRegistry]$FunctionRegistry
    [CommandService]$CommandService
    [EventBus]$EventBus
    [ShortcutManager]$ShortcutManager
    
    # Available actions
    [System.Collections.ArrayList]$AvailableActions
    [int]$SelectedSequenceIndex = -1
    
    VisualMacroFactoryScreen() : base() {
        $this.Title = "Visual Macro Factory"
        $this.DrawBackground = $true
        $this.AvailableActions = [System.Collections.ArrayList]::new()
    }
    
    [void] OnInitialize() {
        # Get services
        $this.CommandService = $this.ServiceContainer.GetService("CommandService")
        $this.EventBus = $this.ServiceContainer.GetService('EventBus')
        $this.ShortcutManager = $this.ServiceContainer.GetService('ShortcutManager')
        
        # Initialize macro services
        $this.ContextManager = [MacroContextManager]::new()
        $this.FunctionRegistry = [FunctionRegistry]::new()
        $this.FunctionRegistry.SetCommandService($this.CommandService)
        $this.ContextManager.SetFunctionRegistry($this.FunctionRegistry)
        
        # Create UI components
        $this.CreateComponentLibrary()
        $this.CreateMacroSequence()
        $this.CreateContextPanel()
        
        # Register shortcuts
        $this.RegisterShortcuts()
    }
    
    [void] LoadAvailableActions() {
        if ($global:Logger) {
            $global:Logger.Debug("VisualMacroFactoryScreen.LoadAvailableActions: Starting to load actions")
        }
        
        # Load built-in actions
        $this.AvailableActions.Add([SummarizationAction]::new()) | Out-Null
        $this.AvailableActions.Add([AppendFieldAction]::new()) | Out-Null
        $this.AvailableActions.Add([ExportToExcelAction]::new()) | Out-Null
        
        # Add custom IDEA@ command action
        $this.AvailableActions.Add([CustomIdeaCommandAction]::new()) | Out-Null
        
        if ($global:Logger) {
            $global:Logger.Debug("VisualMacroFactoryScreen.LoadAvailableActions: Loaded $($this.AvailableActions.Count) actions")
        }
        
        # Populate the component library with the loaded actions
        $this.ComponentLibrary.SetItems($this.AvailableActions)
        
        # TODO: Load additional actions from Actions/ directory
    }
    
    [void] CreateComponentLibrary() {
        $this.ComponentLibrary = [SearchableListBox]::new()
        $this.ComponentLibrary.Title = "📚 Component Library"
        $this.ComponentLibrary.ShowBorder = $true
        $this.ComponentLibrary.SearchPrompt = "Search actions... (category:core type:export)"
        
        # Custom renderer for actions
        $this.ComponentLibrary.ItemRenderer = {
            param($action)
            if (-not $action) { return "" }
            return $action.GetDisplayText()
        }
        
        # Handle double-click to add action
        $this.ComponentLibrary.OnItemActivated = {
            param($action)
            $this.AddActionToSequence($action)
        }.GetNewClosure()
        
        $this.ComponentLibrary.Initialize($this.ServiceContainer)
        $this.AddChild($this.ComponentLibrary)
        
        # Load available actions
        $this.LoadAvailableActions()
    }
    
    [void] CreateMacroSequence() {
        $this.MacroSequence = [MinimalDataGrid]::new()
        $this.MacroSequence.Title = "🔧 Macro Sequence"
        $this.MacroSequence.ShowBorder = $true
        
        # Define columns for macro sequence
        $columns = @(
            @{ Name = "Step"; Width = 6; Alignment = "Center" },
            @{ Name = "Action"; Width = 20; Alignment = "Left" },
            @{ Name = "Description"; Width = 30; Alignment = "Left" },
            @{ Name = "Status"; Width = 10; Alignment = "Center" }
        )
        $this.MacroSequence.SetColumns($columns)
        
        # Note: MinimalDataGrid doesn't have OnSelectionChanged callback
        # Selection tracking will be handled in HandleInput method
        
        $this.MacroSequence.Initialize($this.ServiceContainer)
        $this.AddChild($this.MacroSequence)
    }
    
    [void] CreateContextPanel() {
        $this.ContextPanel = [MinimalDataGrid]::new()
        $this.ContextPanel.Title = "🎯 Macro Context"
        $this.ContextPanel.ShowBorder = $true
        
        # Define columns for context variables
        $columns = @(
            @{ Name = "Variable"; Width = 15; Alignment = "Left" },
            @{ Name = "Type"; Width = 10; Alignment = "Left" },
            @{ Name = "Value"; Width = 25; Alignment = "Left" },
            @{ Name = "Source"; Width = 15; Alignment = "Left" }
        )
        $this.ContextPanel.SetColumns($columns)
        
        $this.ContextPanel.Initialize($this.ServiceContainer)
        $this.AddChild($this.ContextPanel)
        
        # Initial context update
        $this.UpdateContextPanel()
        
        # Set initial focus to component library
        if ($this.ComponentLibrary) {
            $this.ComponentLibrary.Focus()
        }
    }
    
    [void] RegisterShortcuts() {
        if (-not $this.ShortcutManager) { return }
        
        # Delete: Remove selected action from sequence
        $this.ShortcutManager.RegisterShortcut(@{
            Id = "macro_factory_delete"
            Name = "Delete Action"
            Description = "Remove selected action from macro sequence"
            Key = [System.ConsoleKey]::Delete
            Scope = [ShortcutScope]::Screen
            ScreenType = "VisualMacroFactoryScreen"
            Action = {
                if ($this.MacroSequence.IsFocused -and $this.SelectedSequenceIndex -ge 0) {
                    $this.RemoveActionFromSequence($this.SelectedSequenceIndex)
                }
            }.GetNewClosure()
        })
        
        # Ctrl+Up: Move action up in sequence
        $this.ShortcutManager.RegisterShortcut(@{
            Id = "macro_factory_move_up"
            Name = "Move Action Up"
            Description = "Move selected action up in sequence"
            Key = [System.ConsoleKey]::UpArrow
            Modifiers = [System.ConsoleModifiers]::Control
            Scope = [ShortcutScope]::Screen
            ScreenType = "VisualMacroFactoryScreen"
            Action = {
                if ($this.MacroSequence.IsFocused -and $this.SelectedSequenceIndex -gt 0) {
                    $this.ContextManager.MoveAction($this.SelectedSequenceIndex, $this.SelectedSequenceIndex - 1)
                    $this.SelectedSequenceIndex--
                    $this.UpdateMacroSequence()
                    $this.UpdateContextPanel()
                }
            }.GetNewClosure()
        })
        
        # Ctrl+Down: Move action down in sequence
        $this.ShortcutManager.RegisterShortcut(@{
            Id = "macro_factory_move_down"
            Name = "Move Action Down"
            Description = "Move selected action down in sequence"
            Key = [System.ConsoleKey]::DownArrow
            Modifiers = [System.ConsoleModifiers]::Control
            Scope = [ShortcutScope]::Screen
            ScreenType = "VisualMacroFactoryScreen"
            Action = {
                if ($this.MacroSequence.IsFocused -and 
                    $this.SelectedSequenceIndex -ge 0 -and 
                    $this.SelectedSequenceIndex -lt $this.ContextManager.Actions.Count - 1) {
                    $this.ContextManager.MoveAction($this.SelectedSequenceIndex, $this.SelectedSequenceIndex + 1)
                    $this.SelectedSequenceIndex++
                    $this.UpdateMacroSequence()
                    $this.UpdateContextPanel()
                }
            }.GetNewClosure()
        })
        
        # F5: Generate and preview script
        $this.ShortcutManager.RegisterShortcut(@{
            Id = "macro_factory_preview"
            Name = "Preview Script"
            Description = "Generate and preview the IDEAScript"
            Key = [System.ConsoleKey]::F5
            Scope = [ShortcutScope]::Screen
            ScreenType = "VisualMacroFactoryScreen"
            Action = {
                $this.PreviewGeneratedScript()
            }.GetNewClosure()
        })
        
        # Ctrl+S: Save macro
        $this.ShortcutManager.RegisterShortcut(@{
            Id = "macro_factory_save"
            Name = "Save Macro"
            Description = "Save the current macro"
            Key = [System.ConsoleKey]::S
            Modifiers = [System.ConsoleModifiers]::Control
            Scope = [ShortcutScope]::Screen
            ScreenType = "VisualMacroFactoryScreen"
            Action = {
                $this.SaveMacro()
            }.GetNewClosure()
        })
        
        # Ctrl+O: Open macro
        $this.ShortcutManager.RegisterShortcut(@{
            Id = "macro_factory_open"
            Name = "Open Macro"
            Description = "Open an existing macro"
            Key = [System.ConsoleKey]::O
            Modifiers = [System.ConsoleModifiers]::Control
            Scope = [ShortcutScope]::Screen
            ScreenType = "VisualMacroFactoryScreen"
            Action = {
                $this.OpenMacro()
            }.GetNewClosure()
        })
        
        # Ctrl+N: New macro (clear)
        $this.ShortcutManager.RegisterShortcut(@{
            Id = "macro_factory_new"
            Name = "New Macro"
            Description = "Start a new macro (clear current)"
            Key = [System.ConsoleKey]::N
            Modifiers = [System.ConsoleModifiers]::Control
            Scope = [ShortcutScope]::Screen
            ScreenType = "VisualMacroFactoryScreen"
            Action = {
                $this.NewMacro()
            }.GetNewClosure()
        })
    }
    
    [void] AddActionToSequence([BaseAction]$action) {
        # Clone the action to avoid modifying the template
        $newAction = $action.GetType()::new()
        
        $this.ContextManager.AddAction($newAction)
        $this.UpdateMacroSequence()
        $this.UpdateContextPanel()
        
        # Focus the macro sequence and select the new item
        $this.MacroSequence.Focus()
        $this.MacroSequence.SelectedIndex = $this.ContextManager.Actions.Count - 1
        $this.SelectedSequenceIndex = $this.MacroSequence.SelectedIndex
    }
    
    [void] RemoveActionFromSequence([int]$index) {
        $this.ContextManager.RemoveAction($index)
        $this.UpdateMacroSequence()
        $this.UpdateContextPanel()
        
        # Adjust selection
        if ($this.SelectedSequenceIndex -ge $this.ContextManager.Actions.Count) {
            $this.SelectedSequenceIndex = $this.ContextManager.Actions.Count - 1
        }
        $this.MacroSequence.SelectedIndex = $this.SelectedSequenceIndex
    }
    
    [void] UpdateMacroSequence() {
        $rows = @()
        
        for ($i = 0; $i -lt $this.ContextManager.Actions.Count; $i++) {
            $action = $this.ContextManager.Actions[$i]
            $context = $this.ContextManager.GetContextAtStep($i)
            
            # Check if action requirements are met
            $isValid = $action.ValidateContext($context)
            $status = if ($isValid) { "✅ Ready" } else { "⚠️ Issues" }
            
            $rows += @{
                Step = ($i + 1).ToString()
                Action = $action.Name
                Description = $action.Description
                Status = $status
            }
        }
        
        $this.MacroSequence.SetItems($rows)
    }
    
    [void] UpdateContextPanel() {
        $rows = @()
        
        # Get context for the selected step (or full context if none selected)
        $context = if ($this.SelectedSequenceIndex -ge 0) {
            $this.ContextManager.GetContextAtStep($this.SelectedSequenceIndex)
        } else {
            $this.ContextManager.GetFullContext()
        }
        
        foreach ($varName in $context.Keys) {
            $varInfo = $context[$varName]
            $source = if ($varInfo.ContainsKey('ProducedBy')) { $varInfo.ProducedBy } else { "System" }
            
            $rows += @{
                Variable = $varName
                Type = $varInfo.Type
                Value = if ($varInfo.ContainsKey('Value')) { $varInfo.Value } else { "<undefined>" }
                Source = $source
            }
        }
        
        $this.ContextPanel.SetItems($rows)
        
        # Update title to show context step
        if ($this.SelectedSequenceIndex -ge 0) {
            $this.ContextPanel.Title = "🎯 Context at Step $($this.SelectedSequenceIndex + 1)"
        } else {
            $this.ContextPanel.Title = "🎯 Full Macro Context"
        }
    }
    
    [void] PreviewGeneratedScript() {
        try {
            $script = $this.ContextManager.GenerateScript()
            
            # TODO: Show script in a dialog or new screen
            # For now, just log the script
            if ($global:Logger) {
                $global:Logger.Info("Generated Script: $script")
            }
            
        } catch {
            if ($global:Logger) {
                $global:Logger.Error("Script Generation Error: $($_.Exception.Message)")
            }
        }
    }
    
    [void] SaveMacro() {
        # TODO: Implement macro saving to file
        if ($global:Logger) {
            $global:Logger.Info("Save Macro: Not yet implemented")
        }
    }
    
    [void] OpenMacro() {
        # TODO: Implement macro loading from file
        if ($global:Logger) {
            $global:Logger.Info("Open Macro: Not yet implemented")
        }
    }
    
    [void] NewMacro() {
        $this.ContextManager.Clear()
        $this.SelectedSequenceIndex = -1
        $this.UpdateMacroSequence()
        $this.UpdateContextPanel()
    }
    
    # Note: We could track selection changes here if needed, but for now
    # we'll update context when actions are explicitly performed
    
    [void] OnBoundsChanged() {
        if ($global:Logger) {
            $global:Logger.Debug("VisualMacroFactoryScreen.OnBoundsChanged: Width=$($this.Width) Height=$($this.Height)")
        }
        
        if ($this.Width -le 0 -or $this.Height -le 0) { 
            if ($global:Logger) {
                $global:Logger.Debug("VisualMacroFactoryScreen.OnBoundsChanged: Skipping due to zero bounds")
            }
            return 
        }
        
        # Three-pane layout: 30% | 40% | 30%
        $leftWidth = [int]($this.Width * 0.3)
        $centerWidth = [int]($this.Width * 0.4)
        $rightWidth = $this.Width - $leftWidth - $centerWidth
        
        $contentHeight = $this.Height - 2  # Account for title
        
        if ($global:Logger) {
            $global:Logger.Debug("VisualMacroFactoryScreen.OnBoundsChanged: leftWidth=$leftWidth centerWidth=$centerWidth rightWidth=$rightWidth contentHeight=$contentHeight")
        }
        
        # Position Component Library (left pane)
        if ($this.ComponentLibrary) {
            $this.ComponentLibrary.SetBounds(0, 1, $leftWidth, $contentHeight)
        }
        
        # Position Macro Sequence (center pane)
        if ($this.MacroSequence) {
            $this.MacroSequence.SetBounds($leftWidth, 1, $centerWidth, $contentHeight)
        }
        
        # Position Context Panel (right pane)
        if ($this.ContextPanel) {
            $this.ContextPanel.SetBounds($leftWidth + $centerWidth, 1, $rightWidth, $contentHeight)
        }
    }
}