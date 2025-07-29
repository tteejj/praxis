# CommandParser.ps1 - Parses simplified command syntax with colon parameters

class ParsedCommand {
    [string]$Verb
    [string]$Noun  
    [hashtable]$Parameters
    [string]$PositionalText
    [string]$OriginalCommand
    
    ParsedCommand() {
        $this.Parameters = @{}
    }
}

class CommandParser {
    static [ParsedCommand] Parse([string]$commandText) {
        $result = [ParsedCommand]::new()
        $result.OriginalCommand = $commandText
        
        # Remove leading colon if present
        $text = $commandText.TrimStart(':').Trim()
        if ([string]::IsNullOrEmpty($text)) {
            return $result
        }
        
        # Split into parts
        $parts = $text.Split(' ', [StringSplitOptions]::RemoveEmptyEntries)
        if ($parts.Count -eq 0) {
            return $result
        }
        
        # Extract verb (first part)
        $result.Verb = $parts[0].ToLower()
        
        # Extract noun (second part, if exists)
        if ($parts.Count -gt 1) {
            $result.Noun = $parts[1].ToLower()
        }
        
        # Parse remaining parts for parameters and positional text
        $remainingParts = $parts[2..($parts.Count - 1)]
        $currentParam = $null
        $positionalParts = @()
        
        foreach ($part in $remainingParts) {
            if ($part.Contains(':')) {
                # This is a parameter
                $colonIndex = $part.IndexOf(':')
                $paramName = $part.Substring(0, $colonIndex).ToLower()
                $paramValue = $part.Substring($colonIndex + 1)
                
                # Handle empty parameter values (param: value on next part)
                if ([string]::IsNullOrEmpty($paramValue)) {
                    $currentParam = $paramName
                } else {
                    $result.Parameters[$paramName] = $paramValue
                    $currentParam = $null
                }
            }
            elseif ($currentParam) {
                # This part belongs to the current parameter
                if ($result.Parameters.ContainsKey($currentParam)) {
                    $result.Parameters[$currentParam] += " " + $part
                } else {
                    $result.Parameters[$currentParam] = $part
                }
                # Keep currentParam for multi-word values
            }
            else {
                # This is positional text
                $positionalParts += $part
            }
        }
        
        # Set positional text
        if ($positionalParts.Count -gt 0) {
            $result.PositionalText = $positionalParts -join ' '
        }
        
        return $result
    }
    
    static [bool] ValidateCommand([ParsedCommand]$command, [string[]]$requiredParams = @()) {
        if ([string]::IsNullOrEmpty($command.Verb)) {
            return $false
        }
        
        # Check required parameters
        foreach ($param in $requiredParams) {
            if (-not $command.Parameters.ContainsKey($param.ToLower()) -and 
                [string]::IsNullOrEmpty($command.PositionalText)) {
                return $false
            }
        }
        
        return $true
    }
    
    static [string] GetParameterValue([ParsedCommand]$command, [string]$paramName, [string]$defaultValue = "") {
        $paramName = $paramName.ToLower()
        
        if ($command.Parameters.ContainsKey($paramName)) {
            return $command.Parameters[$paramName]
        }
        
        # For common parameters, try positional text as fallback
        if ($paramName -eq "name" -and -not [string]::IsNullOrEmpty($command.PositionalText)) {
            return $command.PositionalText
        }
        
        return $defaultValue
    }
    
    static [string] FormatCommand([string]$verb, [string]$noun, [hashtable]$parameters = @{}) {
        $parts = @(":" + $verb.ToLower(), $noun.ToLower())
        
        foreach ($key in $parameters.Keys) {
            $value = $parameters[$key]
            if (-not [string]::IsNullOrEmpty($value)) {
                $parts += "$($key.ToLower()): $value"
            }
        }
        
        return $parts -join ' '
    }
    
    # Helper methods for common command patterns
    static [ParsedCommand] ParseProjectCommand([string]$commandText) {
        $command = [CommandParser]::Parse($commandText)
        
        # Add project-specific parameter aliases
        if ($command.Parameters.ContainsKey('n')) {
            $command.Parameters['name'] = $command.Parameters['n']
        }
        if ($command.Parameters.ContainsKey('d')) {
            $command.Parameters['due'] = $command.Parameters['d']  
        }
        if ($command.Parameters.ContainsKey('i1')) {
            $command.Parameters['id1'] = $command.Parameters['i1']
        }
        if ($command.Parameters.ContainsKey('i2')) {
            $command.Parameters['id2'] = $command.Parameters['i2']
        }
        
        return $command
    }
    
    static [string[]] GetSuggestions([string]$partialCommand, [string]$context = "") {
        $suggestions = @()
        
        # Remove leading colon for parsing
        $text = $partialCommand.TrimStart(':').Trim()
        $parts = $text.Split(' ', [StringSplitOptions]::RemoveEmptyEntries)
        
        if ($parts.Count -eq 0 -or ($parts.Count -eq 1 -and -not $text.EndsWith(' '))) {
            # Suggest verbs
            $verbs = @('add', 'edit', 'delete', 'new', 'remove', 'update', 'create', 'filter', 'sort', 'export')
            $suggestions = $verbs | Where-Object { $_.StartsWith($parts[0], [StringComparison]::OrdinalIgnoreCase) }
        }
        elseif ($parts.Count -eq 1 -or ($parts.Count -eq 2 -and -not $text.EndsWith(' '))) {
            # Suggest nouns based on context
            $nouns = switch ($context) {
                'ProjectsScreen' { @('project', 'projects') }
                'TaskScreen' { @('task', 'tasks', 'subtask') }
                'TimeEntryScreen' { @('time', 'entry', 'timeentry') }
                default { @('project', 'task', 'time', 'entry') }
            }
            if ($parts.Count -eq 2) {
                $suggestions = $nouns | Where-Object { $_.StartsWith($parts[1], [StringComparison]::OrdinalIgnoreCase) }
            } else {
                $suggestions = $nouns
            }
        }
        else {
            # Suggest parameters based on noun
            $noun = if ($parts.Count -gt 1) { $parts[1] } else { "" }
            $parameters = switch ($noun) {
                'project' { @('name:', 'due:', 'id1:', 'id2:', 'note:') }
                'task' { @('name:', 'description:', 'status:', 'priority:', 'due:', 'project:') }
                'time' { @('project:', 'task:', 'hours:', 'description:', 'date:') }
                default { @('name:', 'description:', 'date:') }
            }
            $suggestions = $parameters
        }
        
        return $suggestions
    }
}