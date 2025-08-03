# Command.ps1 - Model for storing reusable command strings
# Used in Command Library for quick access and clipboard copying

class Command {
    [string]$Id = ""
    [string]$Title = ""
    [string]$Description = ""
    [string[]]$Tags = @()
    [string]$Group = ""
    [string]$CommandText = ""  # REQUIRED - the actual command to copy
    [datetime]$Created = [datetime]::Now
    [datetime]$LastUsed = [datetime]::MinValue
    [int]$UseCount = 0
    
    Command() {
        $this.Id = [Guid]::NewGuid().ToString()
    }
    
    Command([string]$commandText) {
        $this.Id = [Guid]::NewGuid().ToString()
        $this.CommandText = $commandText
    }
    
    Command([string]$title, [string]$commandText) {
        $this.Id = [Guid]::NewGuid().ToString()
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
            # Show first 40 chars of command if no title
            $truncated = if ($this.CommandText.Length -gt 40) { 
                $this.CommandText.Substring(0, 37) + "..." 
            } else { 
                $this.CommandText 
            }
            $displayText += $truncated
        }
        
        # Add description if present and not too long
        if (-not [string]::IsNullOrWhiteSpace($this.Description) -and $this.Description.Length -lt 50) {
            $displayText += " - $($this.Description)"
        }
        
        return $displayText
    }
    
    # Get display text with tags
    [string] GetDisplayTextWithTags() {
        $displayText = $this.GetDisplayText()
        
        # Add tags if present
        if ($this.Tags.Count -gt 0) {
            $tagDisplay = "#" + ($this.Tags -join " #")
            $displayText += " " + $tagDisplay
        }
        
        return $displayText
    }
    
    # Get colored display text for terminal
    [string] GetColoredDisplayText() {
        $result = ""
        
        # Group in brackets with color
        if (-not [string]::IsNullOrWhiteSpace($this.Group)) {
            $result += "[VT]::Cyan() + `"[$($this.Group)]`" + [VT]::Reset() + `" `""
        }
        
        # Title or command text
        if (-not [string]::IsNullOrWhiteSpace($this.Title)) {
            $result += "[VT]::White() + `"$($this.Title)`" + [VT]::Reset()"
        } else {
            $truncated = if ($this.CommandText.Length -gt 40) { 
                $this.CommandText.Substring(0, 37) + "..." 
            } else { 
                $this.CommandText 
            }
            $result += "[VT]::Green() + `"$truncated`" + [VT]::Reset()"
        }
        
        # Description
        if (-not [string]::IsNullOrWhiteSpace($this.Description) -and $this.Description.Length -lt 50) {
            $result += " + [VT]::Gray() + `" - $($this.Description)`" + [VT]::Reset()"
        }
        
        # Tags
        if ($this.Tags.Count -gt 0) {
            $tagDisplay = "#" + ($this.Tags -join " #")
            $result += " + [VT]::Magenta() + `" $tagDisplay`" + [VT]::Reset()"
        }
        
        return $result
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
            Created = $this.Created.ToString("o")
            LastUsed = if ($this.LastUsed -eq [datetime]::MinValue) { "" } else { $this.LastUsed.ToString("o") }
            UseCount = $this.UseCount
        }
    }
    
    # Create from hashtable (for JSON deserialization)
    static [Command] FromHashtable([hashtable]$data) {
        $command = [Command]::new()
        $command.Id = $data.Id
        $command.Title = $data.Title
        $command.Description = $data.Description
        $command.Tags = $data.Tags
        $command.Group = $data.Group
        $command.CommandText = $data.CommandText
        $command.Created = if ($data.Created) { [datetime]::Parse($data.Created) } else { [datetime]::Now }
        $command.LastUsed = if ($data.LastUsed) { [datetime]::Parse($data.LastUsed) } else { [datetime]::MinValue }
        $command.UseCount = $data.UseCount
        return $command
    }
}