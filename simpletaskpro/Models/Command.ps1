# Command.ps1 - Command model with groups (like SimpleTask with subtasks)

class Command {
    [string]$Id
    [string]$Title
    [string]$CommandText
    [string]$Description
    [string]$GroupId  # null for groups, set for commands
    [bool]$CommandsCollapsed = $false  # Only groups use this
    [int]$SortOrder = 0               # Manual ordering
    [string[]]$Tags = @()             # Filter/search tags
    [System.Collections.Generic.List[Command]]$Commands  # For groups
    [datetime]$CreatedDate
    [datetime]$ModifiedDate
    
    Command() {
        $this.Id = [Guid]::NewGuid().ToString()
        $this.CreatedDate = Get-Date
        $this.ModifiedDate = Get-Date
        $this.CommandText = ""
        $this.Description = ""
        $this.Commands = [System.Collections.Generic.List[Command]]::new()
    }
    
    Command([string]$title) {
        $this.Id = [Guid]::NewGuid().ToString()
        $this.Title = $title
        $this.CreatedDate = Get-Date
        $this.ModifiedDate = Get-Date
        $this.CommandText = ""
        $this.Description = ""
        $this.Commands = [System.Collections.Generic.List[Command]]::new()
    }
    
    [void] AddCommand([Command]$command) {
        $command.GroupId = $this.Id
        $this.Commands.Add($command)
        $this.ModifiedDate = Get-Date
    }
    
    [void] RemoveCommand([Command]$command) {
        $this.Commands.Remove($command)
        $this.ModifiedDate = Get-Date
    }
    
    [bool] IsGroup() {
        return [string]::IsNullOrWhiteSpace($this.GroupId)
    }
    
    [bool] IsCommand() {
        return -not [string]::IsNullOrWhiteSpace($this.GroupId)
    }
    
    [bool] HasCommands() {
        return $this.Commands.Count -gt 0
    }
    
    [string] GetDisplayText() {
        if ($this.IsGroup()) {
            $commandCount = $this.Commands.Count
            return "$($this.Title) ($commandCount commands)"
        } else {
            # Show title and description snippet
            if (-not [string]::IsNullOrWhiteSpace($this.Description)) {
                $desc = $this.Description
                if ($desc.Length -gt 40) {
                    $desc = $desc.Substring(0, 37) + "..."
                }
                return "$($this.Title) - $desc"
            }
            return $this.Title
        }
    }
    
    [string] GetFullDisplayText() {
        if ($this.IsGroup()) {
            return $this.GetDisplayText()
        } else {
            $text = $this.Title
            if (-not [string]::IsNullOrWhiteSpace($this.Description)) {
                $text += "`n  " + $this.Description
            }
            if (-not [string]::IsNullOrWhiteSpace($this.CommandText)) {
                $text += "`n  Command: " + $this.CommandText
            }
            return $text
        }
    }
    
    # Validation
    [bool] IsValid() {
        if ([string]::IsNullOrWhiteSpace($this.Title)) {
            return $false
        }
        
        # Commands must have command text
        if ($this.IsCommand() -and [string]::IsNullOrWhiteSpace($this.CommandText)) {
            return $false
        }
        
        return $true
    }
    
    # Search helper
    [bool] MatchesSearch([string]$query) {
        if ([string]::IsNullOrWhiteSpace($query)) {
            return $true
        }
        
        $query = $query.ToLower()
        
        # Check title
        if ($this.Title.ToLower().Contains($query)) {
            return $true
        }
        
        # Check description
        if (-not [string]::IsNullOrWhiteSpace($this.Description) -and $this.Description.ToLower().Contains($query)) {
            return $true
        }
        
        # Check command text (for commands only)
        if ($this.IsCommand() -and -not [string]::IsNullOrWhiteSpace($this.CommandText) -and $this.CommandText.ToLower().Contains($query)) {
            return $true
        }
        
        # Check tags
        foreach ($tag in $this.Tags) {
            if ($tag.ToLower().Contains($query)) {
                return $true
            }
        }
        
        return $false
    }
}