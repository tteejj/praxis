# Core/SimpleStateManager.ps1 - PowerShell-centric simple state management
# Replaces complex Redux-style StateManager with YAGNI approach

class SimpleStateManager {
    # Simple hashtable state - PowerShell native
    hidden [hashtable]$_state = @{}
    
    # Event bus for notifications
    hidden [EventBus]$_eventBus = $null
    hidden [Logger]$_logger = $null
    
    SimpleStateManager([EventBus]$eventBus, [Logger]$logger) {
        $this._eventBus = $eventBus
        $this._logger = $logger
        
        # Initialize with simple defaults
        $this._state = @{
            # Current screen
            CurrentScreen = "Tasks"
            
            # Window dimensions
            WindowWidth = 80
            WindowHeight = 25
            
            # Task screen state (what TaskListScreen needs)
            TaskList = @()
            SelectedTaskIndex = -1
            TaskScrollTop = 0
            TaskFilter = "All"
            
            # Time entries
            TimeEntries = @()
            
            # Projects  
            Projects = @()
        }
        
        $this._logger.Debug("SimpleStateManager initialized with PowerShell-native state")
    }
    
    # Get entire state (read-only copy)
    [hashtable] GetState() {
        return $this._state.Clone()
    }
    
    # Get specific state value
    [object] Get([string]$key) {
        if ($this._state.ContainsKey($key)) {
            return $this._state[$key]
        }
        return $null
    }
    
    # Set state value and notify
    [void] Set([string]$key, [object]$value) {
        $oldValue = $this._state[$key]
        $this._state[$key] = $value
        
        $this._logger.Debug("State changed: $key = $($value.GetType().Name)")
        
        # Notify via EventBus
        $this._eventBus.Publish("state.changed", @{
            Key = $key
            OldValue = $oldValue
            NewValue = $value
            State = $this._state.Clone()
        })
    }
    
    # Batch update multiple values
    [void] Update([hashtable]$updates) {
        $changes = @{}
        
        foreach ($key in $updates.Keys) {
            $oldValue = $this._state[$key]
            $this._state[$key] = $updates[$key]
            $changes[$key] = @{
                OldValue = $oldValue
                NewValue = $updates[$key]
            }
        }
        
        $this._logger.Debug("State batch update: $($updates.Keys -join ', ')")
        
        # Single notification for all changes
        $this._eventBus.Publish("state.changed", @{
            Changes = $changes
            State = $this._state.Clone()
        })
    }
    
    # Task-specific convenience methods
    [void] SetTaskList([array]$tasks) {
        $this.Set("TaskList", $tasks)
    }
    
    [void] SetSelectedTask([int]$index) {
        $this.Set("SelectedTaskIndex", $index)
    }
    
    [void] SetTaskScroll([int]$scrollTop) {
        $this.Set("TaskScrollTop", $scrollTop)
    }
    
    [void] SetTaskFilter([string]$filter) {
        $this.Set("TaskFilter", $filter)
    }
    
    # Screen navigation
    [void] SetCurrentScreen([string]$screenName) {
        $this.Set("CurrentScreen", $screenName)
    }
    
    # Window management
    [void] SetWindowDimensions([int]$width, [int]$height) {
        $this.Update(@{
            WindowWidth = $width
            WindowHeight = $height
        })
    }
    
    # Data management
    [void] SetProjects([array]$projects) {
        $this.Set("Projects", $projects)
    }
    
    [void] SetTimeEntries([array]$timeEntries) {
        $this.Set("TimeEntries", $timeEntries)
    }
}