# EventBus Documentation

The EventBus is a central publish-subscribe system in PRAXIS that enables decoupled communication between components. It replaces direct parent-child references and callback patterns with a clean event-driven architecture.

## Overview

The EventBus allows components to:
- **Publish** events when something happens
- **Subscribe** to events they're interested in
- **Communicate** without knowing about each other

## Quick Start

### Publishing an Event

```powershell
$eventBus = $global:ServiceContainer.GetService('EventBus')
$eventBus.Publish([EventNames]::ProjectCreated, @{
    Project = $newProject
})
```

### Subscribing to an Event

```powershell
$eventBus = $global:ServiceContainer.GetService('EventBus')
$subscription = $eventBus.Subscribe([EventNames]::ProjectCreated, {
    param($sender, $eventData)
    Write-Host "New project created: $($eventData.Project.Name)"
})
```

### Unsubscribing

```powershell
$eventBus.Unsubscribe([EventNames]::ProjectCreated, $subscription)
```

## Event Names

All event names are defined in the `EventNames` class for consistency:

### Project Events
- `ProjectCreated` - When a new project is created
- `ProjectUpdated` - When a project is modified
- `ProjectDeleted` - When a project is deleted
- `ProjectSelected` - When a project is selected

### Task Events
- `TaskCreated` - When a new task is created
- `TaskUpdated` - When a task is modified
- `TaskDeleted` - When a task is deleted
- `TaskSelected` - When a task is selected
- `TaskStatusChanged` - When a task's status changes

### Navigation Events
- `TabChanged` - When the active tab changes
- `ScreenChanged` - When the active screen changes
- `DialogOpened` - When a dialog is opened
- `DialogClosed` - When a dialog is closed

### Application Events
- `AppInitialized` - When the application starts
- `AppShutdown` - When the application is closing
- `ThemeChanged` - When the theme changes
- `ConfigChanged` - When configuration changes
- `RefreshRequested` - Request to refresh data
- `DataChanged` - When data changes

### Command Events
- `CommandExecuted` - When a command is executed
- `CommandRegistered` - When a new command is registered

### UI Events
- `FocusChanged` - When focus changes
- `SelectionChanged` - When selection changes

## Common Patterns

### 1. Screen Event Subscription

```powershell
class MyScreen : Screen {
    [EventBus]$EventBus
    hidden [hashtable]$EventSubscriptions = @{}
    
    [void] OnInitialize() {
        $this.EventBus = $global:ServiceContainer.GetService('EventBus')
        
        if ($this.EventBus) {
            # Subscribe to events
            $this.EventSubscriptions['DataChanged'] = $this.EventBus.Subscribe(
                [EventNames]::DataChanged, {
                    param($sender, $eventData)
                    $this.RefreshData()
                }.GetNewClosure()
            )
        }
    }
}
```

### 2. Cross-Screen Communication

```powershell
# In ProjectsScreen - publish when project is deleted
$this.EventBus.Publish([EventNames]::ProjectDeleted, @{
    ProjectId = $projectId
})

# In TaskScreen - subscribe to remove related tasks
$this.EventBus.Subscribe([EventNames]::ProjectDeleted, {
    param($sender, $eventData)
    $this.RemoveTasksForProject($eventData.ProjectId)
})
```

### 3. Dynamic Command Registration

```powershell
# Register a command dynamically
[CommandRegistration]::RegisterCommand(
    "my command",
    "Description of my command",
    {
        Write-Host "Command executed!"
    }
)
```

### 4. Request/Response Pattern

```powershell
# Request a refresh
$eventBus.Publish([EventNames]::RefreshRequested, @{
    Target = 'ProjectsScreen'
})

# Respond to refresh request
$this.EventBus.Subscribe([EventNames]::RefreshRequested, {
    param($sender, $eventData)
    if (-not $eventData.Target -or $eventData.Target -eq 'ProjectsScreen') {
        $this.LoadProjects()
    }
})
```

## Advanced Features

### Event History

Enable event history for debugging:

```powershell
$eventBus.EnableHistory = $true
$eventBus.MaxHistorySize = 100

# Get event history
$history = $eventBus.GetEventHistory()
$recentProjectEvents = $eventBus.GetEventHistory([EventNames]::ProjectCreated)
```

### Debug Logging

Enable debug logging to see all event activity:

```powershell
$eventBus.EnableDebugLogging = $true
```

### Event Monitoring

Use the EventBus Monitor to view real-time event activity:

1. Press `/` or `:` to open Command Palette
2. Type "eventbus monitor"
3. Press Enter

Or programmatically:

```powershell
$monitor = [EventBusMonitor]::new()
$global:ScreenManager.Push($monitor)
```

### Getting Event Information

```powershell
$info = $eventBus.GetEventInfo()
Write-Host "Total handlers: $($info.TotalHandlers)"
Write-Host "Events published: $($info.TotalEventsPublished)"

# Get detailed debug report
$report = $eventBus.GetDebugReport()
Write-Host $report
```

## Best Practices

### 1. Use EventNames Constants
Always use the predefined constants instead of strings:
```powershell
# Good
$eventBus.Publish([EventNames]::ProjectCreated, @{})

# Bad
$eventBus.Publish('project.created', @{})
```

### 2. Include Relevant Data
Provide all necessary information in event data:
```powershell
$eventBus.Publish([EventNames]::TaskStatusChanged, @{
    TaskId = $task.Id
    OldStatus = $oldStatus
    NewStatus = $newStatus
    Task = $task  # Include full object if useful
})
```

### 3. Clean Up Subscriptions
Unsubscribe when components are disposed:
```powershell
[void] Dispose() {
    if ($this.EventBus) {
        foreach ($key in $this.EventSubscriptions.Keys) {
            $this.EventBus.Unsubscribe($key, $this.EventSubscriptions[$key])
        }
    }
}
```

### 4. Handle Errors Gracefully
EventBus catches handler errors to prevent cascading failures:
```powershell
$this.EventBus.Subscribe([EventNames]::DataChanged, {
    param($sender, $eventData)
    try {
        # Your code here
    } catch {
        $logger = $global:ServiceContainer.GetService('Logger')
        $logger.Log("Error handling event: $_", "Error")
    }
})
```

### 5. Use Weak References for UI Components
Prevent memory leaks with weak references:
```powershell
$this.EventBus.SubscribeWeak([EventNames]::ThemeChanged, $this, {
    param($sender, $eventData)
    $this.OnThemeChanged()
})
```

## Migration Guide

### From Direct Parent References

Before:
```powershell
# In CommandPalette
$palette.Parent.TabContainer.ActivateTab(0)
$projectsScreen = $palette.Parent.TabContainer.Tabs[0].Content
$projectsScreen.RefreshProjects()
```

After:
```powershell
# In CommandPalette
$palette.EventBus.Publish([EventNames]::TabChanged, @{ TabIndex = 0 })
$palette.EventBus.Publish([EventNames]::RefreshRequested, @{ 
    Target = 'ProjectsScreen' 
})
```

### From Callbacks

Before:
```powershell
$dialog.OnCreate = {
    param($project)
    $screen.LoadProjects()
}
```

After:
```powershell
# Dialog publishes event
$this.EventBus.Publish([EventNames]::ProjectCreated, @{ 
    Project = $project 
})

# Screen subscribes to event
$this.EventBus.Subscribe([EventNames]::ProjectCreated, {
    param($sender, $eventData)
    $this.LoadProjects()
})
```

## Troubleshooting

### Events Not Being Received

1. Check that EventBus is initialized:
```powershell
$eventBus = $global:ServiceContainer.GetService('EventBus')
if (-not $eventBus) {
    Write-Host "EventBus not found!"
}
```

2. Verify subscription is active:
```powershell
$info = $eventBus.GetEventInfo()
$handlers = $info.RegisteredEvents[[EventNames]::YourEvent]
Write-Host "Handlers for event: $($handlers.HandlerCount)"
```

3. Enable debug logging:
```powershell
$eventBus.EnableDebugLogging = $true
```

### Memory Leaks

Use weak references for UI components or ensure proper cleanup:
```powershell
# Option 1: Weak reference
$eventBus.SubscribeWeak($eventName, $uiComponent, $handler)

# Option 2: Manual cleanup
[void] Dispose() {
    $this.EventBus.UnsubscribeAll($eventName)
}
```

### Performance Issues

1. Disable history if not needed:
```powershell
$eventBus.EnableHistory = $false
```

2. Avoid publishing events in tight loops
3. Keep event handlers lightweight

## Examples

See the test files for complete examples:
- `test-eventbus.ps1` - Basic functionality
- `test-eventbus-integration.ps1` - Integration scenarios
- `test-cross-screen-events.ps1` - Cross-screen communication
- `test-eventbus-complete.ps1` - Full feature demonstration