# EditorCommands.ps1 - Command Pattern implementation for text editor
# Provides robust undo/redo system using Command Pattern design

# Base interface for all editor commands
class IEditorCommand {
    [void] Execute([object]$buffer) { 
        throw "Execute method must be implemented by derived classes"
    }
    [void] Undo([object]$buffer) { 
        throw "Undo method must be implemented by derived classes"
    }
    [string] GetDescription() {
        return $this.GetType().Name
    }
}

# Command for inserting text at a specific position
class InsertTextCommand : IEditorCommand {
    [int]$Line
    [int]$Col
    [string]$Text
    
    InsertTextCommand([int]$line, [int]$col, [string]$text) {
        $this.Line = $line
        $this.Col = $col
        $this.Text = $text
    }
    
    [void] Execute([object]$buffer) {
        $buffer.InsertTextAt($this.Line, $this.Col, $this.Text)
    }
    
    [void] Undo([object]$buffer) {
        $buffer.DeleteTextAt($this.Line, $this.Col, $this.Text.Length)
    }
    
    [string] GetDescription() {
        return "Insert '$($this.Text)' at ($($this.Line),$($this.Col))"
    }
}

# Command for deleting text at a specific position
class DeleteTextCommand : IEditorCommand {
    [int]$Line
    [int]$Col
    [string]$DeletedText  # Stores the text that was deleted for undo
    [int]$Length
    
    DeleteTextCommand([int]$line, [int]$col, [string]$deletedText) {
        $this.Line = $line
        $this.Col = $col
        $this.DeletedText = $deletedText
        $this.Length = $deletedText.Length
    }
    
    [void] Execute([object]$buffer) {
        $buffer.DeleteTextAt($this.Line, $this.Col, $this.Length)
    }
    
    [void] Undo([object]$buffer) {
        $buffer.InsertTextAt($this.Line, $this.Col, $this.DeletedText)
    }
    
    [string] GetDescription() {
        return "Delete '$($this.DeletedText)' at ($($this.Line),$($this.Col))"
    }
}

# Command for inserting a new line
class InsertNewlineCommand : IEditorCommand {
    [int]$Line
    [int]$Col
    [string]$SplitRightText = ""  # Text moved to new line when splitting
    
    InsertNewlineCommand([int]$line, [int]$col, [string]$splitRightText = "") {
        $this.Line = $line
        $this.Col = $col
        $this.SplitRightText = $splitRightText
    }
    
    [void] Execute([object]$buffer) {
        $buffer.InsertNewlineAt($this.Line, $this.Col)
    }
    
    [void] Undo([object]$buffer) {
        $buffer.JoinLinesAt($this.Line, $this.SplitRightText)
    }
    
    [string] GetDescription() {
        return "Insert newline at ($($this.Line),$($this.Col))"
    }
}

# Command for joining two lines (opposite of newline)
class JoinLinesCommand : IEditorCommand {
    [int]$Line
    [string]$JoinedText  # Text from the next line that was joined
    
    JoinLinesCommand([int]$line, [string]$joinedText) {
        $this.Line = $line
        $this.JoinedText = $joinedText
    }
    
    [void] Execute([object]$buffer) {
        $buffer.JoinLinesAt($this.Line, "")
    }
    
    [void] Undo([object]$buffer) {
        # Find the split position and insert newline
        $currentLine = $buffer.GetLine($this.Line)
        $splitPos = $currentLine.Length - $this.JoinedText.Length
        $buffer.InsertNewlineAt($this.Line, $splitPos)
    }
    
    [string] GetDescription() {
        return "Join lines at $($this.Line)"
    }
}

# Composite command for grouping multiple commands into one undo unit
class CompositeCommand : IEditorCommand {
    [System.Collections.ArrayList]$Commands
    [string]$Description
    
    CompositeCommand([string]$description) {
        $this.Commands = [System.Collections.ArrayList]::new()
        $this.Description = $description
    }
    
    [void] AddCommand([object]$command) {
        $this.Commands.Add($command) | Out-Null
    }
    
    [void] Execute([object]$buffer) {
        foreach ($command in $this.Commands) {
            $command.Execute($buffer)
        }
    }
    
    [void] Undo([object]$buffer) {
        # Undo in reverse order
        for ($i = $this.Commands.Count - 1; $i -ge 0; $i--) {
            $this.Commands[$i].Undo($buffer)
        }
    }
    
    [string] GetDescription() {
        return $this.Description
    }
}