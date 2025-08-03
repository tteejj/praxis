# EventNames.ps1 - Event name constants for EventBus system

# Static class to hold event name constants
class EventNames {
    # Theme events
    static [string] $ThemeChanged = 'theme.changed'
    
    # Project events
    static [string] $ProjectCreated = 'project.created'
    static [string] $ProjectUpdated = 'project.updated'
    static [string] $ProjectDeleted = 'project.deleted'
    
    # Task events
    static [string] $TaskCreated = 'task.created'
    static [string] $TaskUpdated = 'task.updated'
    static [string] $TaskDeleted = 'task.deleted'
    static [string] $TaskStatusChanged = 'task.status.changed'
    
    # Time entry events
    static [string] $TimeEntryUpdated = 'time.entry.updated'
    static [string] $TimeEntryDeleted = 'time.entry.deleted'
    
    # Dialog events
    static [string] $DialogOpened = 'dialog.opened'
    static [string] $DialogClosed = 'dialog.closed'
    
    # Command events
    static [string] $CommandExecuted = 'command.executed'
    static [string] $CommandRegistered = 'command.registered'
    
    # Configuration events
    static [string] $ConfigChanged = 'config.changed'
    
    # Tab events
    static [string] $TabChanged = 'tab.changed'
}