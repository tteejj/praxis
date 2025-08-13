# Core/StateManager.ps1 - Single source of truth for all application data and UI state.
# Based on Redux/Flux pattern but simplified for PowerShell TUI needs

class StateManager {
    # Application State - the single source of truth
    hidden [hashtable]$_state = @{
        # UI State
        UI = @{
            CurrentScreen = "Tasks"
            ScreenStack = @()
            WindowDimensions = @{ Width = 80; Height = 25 }
            Theme = "Default"
            
            # Task Screen UI State (what Phase 4 expects)
            Tasks = @{
                FlatList = @()
                SelectedTaskId = ""
                SelectedIndex = -1
                ScrollTop = 0
                FilterMode = "All"
                TagFilter = ""
                InputState = "Browsing"  # "Browsing", "Filtering", "TimeEntry"
                CollapseSubtasks = $false
            }
            
            # Time Entry Screen UI State
            TimeEntry = @{
                FlatList = @()
                SelectedIndex = -1
                ScrollTop = 0
                FilterActive = $true
            }
            
            # Command Library Screen UI State
            Commands = @{
                FlatList = @()
                SelectedIndex = -1
                ScrollTop = 0
                FilterMode = "All"
                TagFilter = ""
                FilterInputActive = $false
            }
            
            # Excel Mapping Screen UI State
            Excel = @{
                FlatList = @()
                SelectedIndex = -1
                ScrollTop = 0
            }
        }
        
        # Data State  
        Data = @{
            Tasks = @()
            TimeEntries = @()
            Projects = @()
            LastSyncTime = $null
        }
        
        # User Preferences
        Preferences = @{
            DefaultView = "Tasks"
            AutoSave = $true
            LogLevel = "Info"
        }
    }
    
    # Event Bus reference for state change notifications
    hidden [EventBus]$_eventBus = $null
    
    # State change listeners
    hidden [System.Collections.Generic.List[scriptblock]]$_listeners = [System.Collections.Generic.List[scriptblock]]::new()
    
    StateManager([EventBus]$eventBus) {
        $this._eventBus = $eventBus
        # Note: Logger now singleton, will be passed in when StateManager becomes simpler
    }
    
    # Get current application state (read-only)
    [hashtable] GetState() {
        return $this._state.Clone()
    }
    
    # Get a specific part of the state
    [object] GetState([string]$path) {
        $parts = $path.Split('.')
        $current = $this._state
        
        foreach ($part in $parts) {
            if ($current -is [hashtable] -and $current.ContainsKey($part)) {
                $current = $current[$part]
            } else {
                [Logger]::Warn("StateManager: Invalid state path '$path'")
                return $null
            }
        }
        
        return $current
    }
    
    # Dispatch an action to modify state
    [void] Dispatch([hashtable]$action) {
        if (-not $action.ContainsKey('Type')) {
            [Logger]::Error("StateManager: Action must have 'Type' property")
            return
        }
        
        $actionType = $action.Type
        [Logger]::Debug("StateManager: Dispatching action '$actionType'")
        
        # Store previous state for comparison
        $previousState = $this._state.Clone()
        
        # Apply the action using reducers
        $this._state = $this.Reduce($this._state, $action)
        
        # Notify listeners if state changed
        if ($this.StateChanged($previousState, $this._state)) {
            [Logger]::Debug("StateManager: State changed, notifying listeners")
            $this.NotifyListeners($previousState, $this._state, $action)
            
            # Publish global state change event (both formats for compatibility)
            if ($this._eventBus) {
                $stateChangeData = @{
                    PreviousState = $previousState
                    NewState = $this._state.Clone()
                    Action = $action
                }
                $this._eventBus.Publish("state.changed", $stateChangeData)
                $this._eventBus.Publish("notification:state.changed", $stateChangeData)  # Phase 4 compatibility
            }
        }
    }
    
    # Apply action to state using reducer pattern
    [hashtable] Reduce([hashtable]$state, [hashtable]$action) {
        $newState = $state.Clone()
        
        switch ($action.Type) {
            # UI Actions
            "UI.SET_CURRENT_SCREEN" {
                $newState.UI.CurrentScreen = $action.Payload.Screen
            }
            "UI.PUSH_SCREEN" {
                $newState.UI.ScreenStack += $action.Payload.Screen
            }
            "UI.POP_SCREEN" {
                if ($newState.UI.ScreenStack.Count -gt 0) {
                    $newState.UI.ScreenStack = $newState.UI.ScreenStack[0..($newState.UI.ScreenStack.Count - 2)]
                }
            }
            "UI.SET_WINDOW_DIMENSIONS" {
                $newState.UI.WindowDimensions = $action.Payload.Dimensions
            }
            "UI.SET_THEME" {
                $newState.UI.Theme = $action.Payload.Theme
            }
            
            # Task Screen UI Actions (what Phase 4 expects)
            "UI.TASKS.SET_FLAT_LIST" {
                $newState.UI.Tasks.FlatList = $action.Payload.FlatList
            }
            "UI.TASKS.SET_SELECTION" {
                $newState.UI.Tasks.SelectedTaskId = $action.Payload.TaskId
                $newState.UI.Tasks.SelectedIndex = $action.Payload.Index
            }
            "UI.TASKS.SET_SCROLL" {
                $newState.UI.Tasks.ScrollTop = $action.Payload.ScrollTop
            }
            "UI.TASKS.SET_FILTER" {
                $newState.UI.Tasks.FilterMode = $action.Payload.FilterMode
                if ($action.Payload.TagFilter) {
                    $newState.UI.Tasks.TagFilter = $action.Payload.TagFilter
                }
            }
            "UI.TASKS.SET_INPUT_STATE" {
                $newState.UI.Tasks.InputState = $action.Payload.InputState
            }
            "UI.TASKS.SET_COLLAPSE_SUBTASKS" {
                $newState.UI.Tasks.CollapseSubtasks = $action.Payload.CollapseSubtasks
            }
            
            # Time Entry Screen UI Actions
            "UI.TIME_ENTRY.SET_FLAT_LIST" {
                $newState.UI.TimeEntry.FlatList = $action.Payload.FlatList
            }
            "UI.TIME_ENTRY.SET_SELECTION" {
                $newState.UI.TimeEntry.SelectedIndex = $action.Payload.Index
            }
            "UI.TIME_ENTRY.SET_SCROLL" {
                $newState.UI.TimeEntry.ScrollTop = $action.Payload.ScrollTop
            }
            "UI.TIME_ENTRY.SET_FILTER_ACTIVE" {
                $newState.UI.TimeEntry.FilterActive = $action.Payload.FilterActive
            }
            
            # Command Library Screen UI Actions
            "UI.COMMANDS.SET_FLAT_LIST" {
                $newState.UI.Commands.FlatList = $action.Payload.FlatList
            }
            "UI.COMMANDS.SET_SELECTION" {
                $newState.UI.Commands.SelectedIndex = $action.Payload.Index
            }
            "UI.COMMANDS.SET_SCROLL" {
                $newState.UI.Commands.ScrollTop = $action.Payload.ScrollTop
            }
            "UI.COMMANDS.SET_FILTER" {
                $newState.UI.Commands.FilterMode = $action.Payload.FilterMode
                if ($action.Payload.TagFilter) {
                    $newState.UI.Commands.TagFilter = $action.Payload.TagFilter
                }
                if ($action.Payload.ContainsKey('FilterInputActive')) {
                    $newState.UI.Commands.FilterInputActive = $action.Payload.FilterInputActive
                }
            }
            
            # Excel Mapping Screen UI Actions
            "UI.EXCEL.SET_FLAT_LIST" {
                $newState.UI.Excel.FlatList = $action.Payload.FlatList
            }
            "UI.EXCEL.SET_SELECTION" {
                $newState.UI.Excel.SelectedIndex = $action.Payload.Index
            }
            "UI.EXCEL.SET_SCROLL" {
                $newState.UI.Excel.ScrollTop = $action.Payload.ScrollTop
            }
            
            # Data Actions
            "DATA.SET_TASKS" {
                $newState.Data.Tasks = $action.Payload.Tasks
                $newState.Data.LastSyncTime = Get-Date
            }
            "DATA.ADD_TASK" {
                $newState.Data.Tasks += $action.Payload.Task
            }
            "DATA.UPDATE_TASK" {
                $taskId = $action.Payload.TaskId
                $updatedTask = $action.Payload.Task
                for ($i = 0; $i -lt $newState.Data.Tasks.Count; $i++) {
                    if ($newState.Data.Tasks[$i].Id -eq $taskId) {
                        $newState.Data.Tasks[$i] = $updatedTask
                        break
                    }
                }
            }
            "DATA.DELETE_TASK" {
                $taskId = $action.Payload.TaskId
                $newState.Data.Tasks = $newState.Data.Tasks | Where-Object { $_.Id -ne $taskId }
            }
            
            # Time Entry Actions
            "DATA.SET_TIME_ENTRIES" {
                $newState.Data.TimeEntries = $action.Payload.TimeEntries
                $newState.Data.LastSyncTime = Get-Date
            }
            "DATA.ADD_TIME_ENTRY" {
                $newState.Data.TimeEntries += $action.Payload.TimeEntry
            }
            
            # Project Actions
            "DATA.SET_PROJECTS" {
                $newState.Data.Projects = $action.Payload.Projects
                $newState.Data.LastSyncTime = Get-Date
            }
            
            # Preference Actions
            "PREFERENCES.SET_DEFAULT_VIEW" {
                $newState.Preferences.DefaultView = $action.Payload.View
            }
            "PREFERENCES.SET_AUTO_SAVE" {
                $newState.Preferences.AutoSave = $action.Payload.AutoSave
            }
            "PREFERENCES.SET_LOG_LEVEL" {
                $newState.Preferences.LogLevel = $action.Payload.LogLevel
            }
            
            default {
                [Logger]::Warn("StateManager: Unknown action type '$($action.Type)'")
            }
        }
        
        return $newState
    }
    
    # Check if state has changed (deep comparison would be expensive, so we use reference check)
    [bool] StateChanged([hashtable]$oldState, [hashtable]$newState) {
        # For now, assume state changed if we got here (since we create new state objects)
        # In a more sophisticated implementation, we could do deep comparison
        return $true
    }
    
    # Subscribe to state changes
    [void] Subscribe([scriptblock]$listener) {
        $this._listeners.Add($listener)
        [Logger]::Debug("StateManager: Added state change listener")
    }
    
    # Unsubscribe from state changes
    [void] Unsubscribe([scriptblock]$listener) {
        $this._listeners.Remove($listener)
        [Logger]::Debug("StateManager: Removed state change listener")
    }
    
    # Notify all listeners of state change
    [void] NotifyListeners([hashtable]$previousState, [hashtable]$newState, [hashtable]$action) {
        foreach ($listener in $this._listeners) {
            try {
                & $listener $previousState $newState $action
            } catch {
                [Logger]::Error("StateManager: Error executing state change listener", $_)
            }
        }
    }
    
    # Action creators for common operations
    static [hashtable] SetCurrentScreen([string]$screen) {
        return @{
            Type = "UI.SET_CURRENT_SCREEN"
            Payload = @{ Screen = $screen }
        }
    }
    
    static [hashtable] SetTasks([array]$tasks) {
        return @{
            Type = "DATA.SET_TASKS" 
            Payload = @{ Tasks = $tasks }
        }
    }
    
    static [hashtable] AddTask([hashtable]$task) {
        return @{
            Type = "DATA.ADD_TASK"
            Payload = @{ Task = $task }
        }
    }
    
    static [hashtable] UpdateTask([string]$taskId, [hashtable]$task) {
        return @{
            Type = "DATA.UPDATE_TASK"
            Payload = @{ TaskId = $taskId; Task = $task }
        }
    }
    
    static [hashtable] DeleteTask([string]$taskId) {
        return @{
            Type = "DATA.DELETE_TASK"
            Payload = @{ TaskId = $taskId }
        }
    }
    
    static [hashtable] SetWindowDimensions([int]$width, [int]$height) {
        return @{
            Type = "UI.SET_WINDOW_DIMENSIONS"
            Payload = @{ Dimensions = @{ Width = $width; Height = $height } }
        }
    }
    
    # Phase 4 Task Screen Action Creators
    static [hashtable] SetTaskSelection([string]$taskId, [int]$index) {
        return @{
            Type = "UI.TASKS.SET_SELECTION"
            Payload = @{ TaskId = $taskId; Index = $index }
        }
    }
    
    static [hashtable] SetTaskScroll([int]$scrollTop) {
        return @{
            Type = "UI.TASKS.SET_SCROLL"
            Payload = @{ ScrollTop = $scrollTop }
        }
    }
    
    static [hashtable] SetTaskFilter([string]$filterMode, [string]$tagFilter = "") {
        return @{
            Type = "UI.TASKS.SET_FILTER"
            Payload = @{ FilterMode = $filterMode; TagFilter = $tagFilter }
        }
    }
    
    static [hashtable] SetTaskInputState([string]$inputState) {
        return @{
            Type = "UI.TASKS.SET_INPUT_STATE"
            Payload = @{ InputState = $inputState }
        }
    }
    
    static [hashtable] SetTaskFlatList([array]$flatList) {
        return @{
            Type = "UI.TASKS.SET_FLAT_LIST"
            Payload = @{ FlatList = $flatList }
        }
    }
}