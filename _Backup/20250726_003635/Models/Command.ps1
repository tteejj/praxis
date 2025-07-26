# Command.ps1 - Model for storing reusable command strings
# Used in Command Library for quick access and clipboard copying

class Command : BaseModel {
    [string]$Title = ""
    [string]$Description = ""
    [string[]]$Tags = @()
    [string]$Group = ""
    [string]$CommandText = ""  # REQUIRED - the actual command to copy
    [datetime]$Created = [datetime]::Now
    [datetime]$LastUsed = [datetime]::MinValue
    [int]$UseCount = 0
    
    Command() : base() {
        # Base constructor handles Id generation
    }
    
    Command([string]$commandText) : base() {
        $this.CommandText = $commandText
    }
    
    Command([string]$title, [string]$commandText) : base() {
        $this.Title = $title
        $this.CommandText = $commandText
    }
    
    # Validation - CommandText is required
    [bool] IsValid() {
        return -not [string]::IsNullOrWhiteSpace($this.CommandText)
    }
    
    # Update usage statistics when command is used
    [void] RecordUsage() {
        $this.LastUsed = [datetime]::Now
        $this.UseCount++
    }
    
    # Get display text for lists
    [string] GetDisplayText() {
        $displayText = ""
        
        # Add group prefix if present
        if (-not [string]::IsNullOrWhiteSpace($this.Group)) {
            $displayText += "[$($this.Group)] "
        }
        
        # Add title or truncated command text
        if (-not [string]::IsNullOrWhiteSpace($this.Title)) {
            $displayText += $this.Title
        } else {
            # Use first 50 chars of command text as fallback
            $commandPreview = $this.CommandText
            if ($commandPreview.Length -gt 50) {
                $commandPreview = $commandPreview.Substring(0, 47) + "..."
            }
            $displayText += $commandPreview
        }
        
        return $displayText
    }
    
    # Get searchable text for filtering
    [string] GetSearchableText() {
        $searchText = @()
        
        if (-not [string]::IsNullOrWhiteSpace($this.Title)) {
            $searchText += $this.Title
        }
        
        if (-not [string]::IsNullOrWhiteSpace($this.Description)) {
            $searchText += $this.Description
        }
        
        if (-not [string]::IsNullOrWhiteSpace($this.Group)) {
            $searchText += $this.Group
        }
        
        if ($this.Tags -and $this.Tags.Count -gt 0) {
            $searchText += ($this.Tags -join " ")
        }
        
        # Always include command text in search
        $searchText += $this.CommandText
        
        return ($searchText -join " ")
    }
    
    # Get detailed text for display in dialogs
    [string] GetDetailText() {
        $details = @()
        
        if (-not [string]::IsNullOrWhiteSpace($this.Title)) {
            $details += "Title: $($this.Title)"
        }
        
        if (-not [string]::IsNullOrWhiteSpace($this.Description)) {
            $details += "Description: $($this.Description)"
        }
        
        if (-not [string]::IsNullOrWhiteSpace($this.Group)) {
            $details += "Group: $($this.Group)"
        }
        
        if ($this.Tags -and $this.Tags.Count -gt 0) {
            $details += "Tags: $($this.Tags -join ', ')"
        }
        
        $details += "Command: $($this.CommandText)"
        
        if ($this.UseCount -gt 0) {
            $details += "Used: $($this.UseCount) times, last: $($this.LastUsed.ToString('yyyy-MM-dd HH:mm'))"
        }
        
        return ($details -join "`n")
    }
    
    # Convert to hashtable for JSON serialization
    [hashtable] ToHashtable() {
        return @{
            Id = $this.Id
            Title = $this.Title
            Description = $this.Description
            Tags = $this.Tags
            Group = $this.Group
            CommandText = $this.CommandText
            Created = $this.Created.ToString("yyyy-MM-ddTHH:mm:ss.fffffffK")
            LastUsed = if ($this.LastUsed -eq [datetime]::MinValue) { $null } else { $this.LastUsed.ToString("yyyy-MM-ddTHH:mm:ss.fffffffK") }
            UseCount = $this.UseCount
        }
    }
    
    # Create from hashtable (for JSON deserialization)
    static [Command] FromHashtable([hashtable]$data) {
        $command = [Command]::new()
        
        $command.Id = $data.Id
        $command.Title = $data.Title ?? ""
        $command.Description = $data.Description ?? ""
        $command.Tags = $data.Tags ?? @()
        $command.Group = $data.Group ?? ""  
        $command.CommandText = $data.CommandText ?? ""
        $command.UseCount = $data.UseCount ?? 0
        
        if ($data.Created) {
            $command.Created = [datetime]::Parse($data.Created)
        }
        
        if ($data.LastUsed) {
            $command.LastUsed = [datetime]::Parse($data.LastUsed)
        } else {
            $command.LastUsed = [datetime]::MinValue
        }
        
        return $command
    }
}