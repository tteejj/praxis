# IEditorCommand.ps1 - Interface for editor commands
# Separate interface to avoid circular dependencies

# Base interface for all editor commands
class IEditorCommand {
    [void] Execute([DocumentBuffer]$buffer) { 
        throw "Execute method must be implemented by derived classes"
    }
    [void] Undo([DocumentBuffer]$buffer) { 
        throw "Undo method must be implemented by derived classes"
    }
    [string] GetDescription() {
        return $this.GetType().Name
    }
}