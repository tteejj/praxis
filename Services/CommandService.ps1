# CommandService.ps1 - Service for managing command library
# Handles JSON storage, CRUD operations, and clipboard functionality

class CommandService {
    [string]$DataPath
    [System.Collections.ArrayList]$Commands
    [Logger]$Logger
    
    CommandService() {
        $this.DataPath = Join-Path $global:PraxisRoot "_ProjectData/commands.json"
        $this.Commands = [System.Collections.ArrayList]::new()
        $this.Logger = $global:Logger
        $this.LoadCommands()
    }
    
    # Load commands from JSON file
    [void] LoadCommands() {
        try {
            if (Test-Path $this.DataPath) {
                $jsonContent = Get-Content $this.DataPath -Raw | ConvertFrom-Json
                $this.Commands.Clear()
                
                foreach ($commandData in $jsonContent) {
                    # Convert PSCustomObject to hashtable
                    $hashtable = @{}
                    $commandData.PSObject.Properties | ForEach-Object {
                        $hashtable[$_.Name] = $_.Value
                    }
                    $command = [Command]::FromHashtable($hashtable)
                    $this.Commands.Add($command) | Out-Null
                }
                
                if ($this.Logger) {
                    $this.Logger.Info("Loaded $($this.Commands.Count) commands from $($this.DataPath)")
                }
            } else {
                if ($this.Logger) {
                    $this.Logger.Info("No existing commands file found, starting with empty library")
                }
                # Add some default IDEA commands
                $this.CreateDefaultCommands()
            }
        } catch {
            if ($this.Logger) {
                $this.Logger.Error("Failed to load commands: $($_.Exception.Message)")
            }
        }
    }
    
    # Create default IDEA commands for new installations
    [void] CreateDefaultCommands() {
        # Add some common IDEA@ functions and commands
        $defaultCommands = @(
            @{
                Title = "@CurrentDate_YYYYMMDD"
                Description = "Returns current date in YYYYMMDD format"
                Tags = @("function", "date", "idea")
                Group = "Built-in Functions"
                CommandText = "@CurrentDate_YYYYMMDD"
            },
            @{
                Title = "@PromptForField"
                Description = "Prompts user to select a field from the current database"
                Tags = @("function", "field", "input", "idea")
                Group = "Built-in Functions"
                CommandText = "@PromptForField(`"Select field:`")"
            },
            @{
                Title = "Open Database"
                Description = "Opens a database file in IDEA"
                Tags = @("database", "open", "idea")
                Group = "Database Operations"
                CommandText = "Set db = Client.OpenDatabase(`"database.IMD`")"
            },
            @{
                Title = "Summarize by Field"
                Description = "Creates a summarization by specified field"
                Tags = @("summarize", "group", "analysis", "idea")
                Group = "Analysis"
                CommandText = "Set task = db.Summarization`nTask.AddFieldToSummarize `"FIELD_NAME`"`nTask.OutputDBName = `"Summary_Output`"`ndbName = task.Run()"
            },
            @{
                Title = "Export to Excel"
                Description = "Exports current database to Excel format"
                Tags = @("export", "excel", "output", "idea")
                Group = "Export"
                CommandText = "Set task = db.ExportToExcel`nTask.OutputFile = `"output.xlsx`"`nTask.Run()"
            }
        )
        
        foreach ($cmdData in $defaultCommands) {
            $command = $this.AddCommand($cmdData.Title, $cmdData.Description, $cmdData.Tags, $cmdData.Group, $cmdData.CommandText)
        }
        
        if ($this.Logger) {
            $this.Logger.Info("Created $($defaultCommands.Count) default IDEA commands")
        }
    }
    
    # Save commands to JSON file
    [void] SaveCommands() {
        try {
            $commandsData = @()
            foreach ($command in $this.Commands) {
                $commandsData += $command.ToHashtable()
            }
            
            $json = $commandsData | ConvertTo-Json -Depth 10
            $json | Set-Content $this.DataPath -Encoding UTF8
            
            if ($this.Logger) {
                $this.Logger.Info("Saved $($this.Commands.Count) commands to $($this.DataPath)")
            }
        } catch {
            if ($this.Logger) {
                $this.Logger.Error("Failed to save commands: $($_.Exception.Message)")
            }
        }
    }
    
    # Get all commands
    [System.Collections.ArrayList] GetAllCommands() {
        return $this.Commands
    }
    
    # Get command by ID
    [Command] GetCommand([string]$id) {
        foreach ($command in $this.Commands) {
            if ($command.Id -eq $id) {
                return $command
            }
        }
        return $null
    }
    
    # Add new command
    [Command] AddCommand([string]$commandText) {
        if ([string]::IsNullOrWhiteSpace($commandText)) {
            throw "Command text is required"
        }
        
        $command = [Command]::new($commandText)
        $this.Commands.Add($command) | Out-Null
        $this.SaveCommands()
        
        if ($this.Logger) {
            $this.Logger.Info("Added new command: $($command.Id)")
        }
        
        return $command
    }
    
    # Add command with full details
    [Command] AddCommand([string]$title, [string]$description, [string[]]$tags, [string]$group, [string]$commandText) {
        if ([string]::IsNullOrWhiteSpace($commandText)) {
            throw "Command text is required"
        }
        
        $command = [Command]::new()
        $command.Title = $title ?? ""
        $command.Description = $description ?? ""
        $command.Tags = $tags ?? @()
        $command.Group = $group ?? ""
        $command.CommandText = $commandText
        
        $this.Commands.Add($command) | Out-Null
        $this.SaveCommands()
        
        if ($this.Logger) {
            $this.Logger.Info("Added new command: $($command.GetDisplayText())")
        }
        
        return $command
    }
    
    # Update existing command
    [bool] UpdateCommand([Command]$command) {
        if (-not $command.IsValid()) {
            throw "Command text is required"
        }
        
        $existingIndex = -1
        for ($i = 0; $i -lt $this.Commands.Count; $i++) {
            if ($this.Commands[$i].Id -eq $command.Id) {
                $existingIndex = $i
                break
            }
        }
        
        if ($existingIndex -ge 0) {
            $this.Commands[$existingIndex] = $command
            $this.SaveCommands()
            
            if ($this.Logger) {
                $this.Logger.Info("Updated command: $($command.GetDisplayText())")
            }
            return $true
        }
        
        return $false
    }
    
    # Delete command
    [bool] DeleteCommand([string]$id) {
        for ($i = 0; $i -lt $this.Commands.Count; $i++) {
            if ($this.Commands[$i].Id -eq $id) {
                $command = $this.Commands[$i]
                $this.Commands.RemoveAt($i)
                $this.SaveCommands()
                
                if ($this.Logger) {
                    $this.Logger.Info("Deleted command: $($command.GetDisplayText())")
                }
                return $true
            }
        }
        
        return $false
    }
    
    # Copy command to clipboard and record usage
    [void] CopyToClipboard([string]$id) {
        $command = $this.GetCommand($id)
        if ($command) {
            try {
                Set-Clipboard -Value $command.CommandText
                $command.RecordUsage()
                $this.SaveCommands()
                
                if ($this.Logger) {
                    $this.Logger.Info("Copied command to clipboard: $($command.GetDisplayText())")
                }
            } catch {
                if ($this.Logger) {
                    $this.Logger.Error("Failed to copy to clipboard: $($_.Exception.Message)")
                }
                throw "Failed to copy to clipboard: $($_.Exception.Message)"
            }
        } else {
            throw "Command not found: $id"
        }
    }
    
    # Search commands with enhanced syntax
    [System.Collections.ArrayList] SearchCommands([string]$query) {
        $results = [System.Collections.ArrayList]::new()
        
        if ([string]::IsNullOrWhiteSpace($query)) {
            # Return all commands if no query
            foreach ($command in $this.Commands) {
                $results.Add($command) | Out-Null
            }
            return $results
        }
        
        # Parse search query
        $searchCriteria = $this.ParseSearchQuery($query)
        
        foreach ($command in $this.Commands) {
            if ($this.MatchesSearchCriteria($command, $searchCriteria)) {
                $results.Add($command) | Out-Null
            }
        }
        
        return $results
    }
    
    # Parse search query into criteria
    hidden [hashtable] ParseSearchQuery([string]$query) {
        $criteria = @{
            DefaultSearch = @()
            TitleSearch = @()
            DescriptionSearch = @()
            TagSearch = @()
            GroupSearch = @()
            AndMode = $false
        }
        
        # Check for AND mode (+)
        if ($query -match '\+') {
            $criteria.AndMode = $true
        }
        
        # Split by spaces and process each term
        $terms = $query -split '\s+' | Where-Object { $_ -ne '' }
        
        foreach ($term in $terms) {
            if ($term -match '^(\+?)([tdg]):(.+)$') {
                $isAnd = $matches[1] -eq '+'
                $type = $matches[2]
                $searchTerm = $matches[3]
                
                # Handle OR within the search term (|)
                $searchValues = $searchTerm -split '\|'
                
                switch ($type) {
                    't' { $criteria.TagSearch += $searchValues }
                    'd' { $criteria.DescriptionSearch += $searchValues }
                    'g' { $criteria.GroupSearch += $searchValues }
                }
            } else {
                # Default search (title and general)
                $cleanTerm = $term -replace '^\+', ''
                $criteria.DefaultSearch += $cleanTerm
            }
        }
        
        return $criteria
    }
    
    # Check if command matches search criteria
    hidden [bool] MatchesSearchCriteria([Command]$command, [hashtable]$criteria) {
        $matches = @()
        
        # Default search (title and general text)
        if ($criteria.DefaultSearch.Count -gt 0) {
            $titleMatch = $false
            $generalMatch = $false
            
            foreach ($term in $criteria.DefaultSearch) {
                if ($command.Title -and $command.Title -match [regex]::Escape($term)) {
                    $titleMatch = $true
                }
                if ($command.GetSearchableText() -match [regex]::Escape($term)) {
                    $generalMatch = $true
                }
            }
            
            $matches += ($titleMatch -or $generalMatch)
        }
        
        # Tag search
        if ($criteria.TagSearch.Count -gt 0) {
            $tagMatch = $false
            $tagText = ($command.Tags -join ' ')
            
            foreach ($term in $criteria.TagSearch) {
                if ($tagText -match [regex]::Escape($term)) {
                    $tagMatch = $true
                    break
                }
            }
            
            $matches += $tagMatch
        }
        
        # Description search
        if ($criteria.DescriptionSearch.Count -gt 0) {
            $descMatch = $false
            
            foreach ($term in $criteria.DescriptionSearch) {
                if ($command.Description -and $command.Description -match [regex]::Escape($term)) {
                    $descMatch = $true
                    break
                }
            }
            
            $matches += $descMatch
        }
        
        # Group search
        if ($criteria.GroupSearch.Count -gt 0) {
            $groupMatch = $false
            
            foreach ($term in $criteria.GroupSearch) {
                if ($command.Group -and $command.Group -match [regex]::Escape($term)) {
                    $groupMatch = $true
                    break
                }
            }
            
            $matches += $groupMatch
        }
        
        # Return based on AND/OR logic
        if ($matches.Count -eq 0) {
            return $true  # No specific criteria, match all
        }
        
        if ($criteria.AndMode) {
            # AND: all criteria must match
            return ($matches | Where-Object { $_ -eq $false }).Count -eq 0
        } else {
            # OR: any criteria can match
            return ($matches | Where-Object { $_ -eq $true }).Count -gt 0
        }
    }
    
    # Get all unique groups
    [string[]] GetGroups() {
        $groups = @()
        foreach ($command in $this.Commands) {
            if (-not [string]::IsNullOrWhiteSpace($command.Group) -and $groups -notcontains $command.Group) {
                $groups += $command.Group
            }
        }
        return $groups | Sort-Object
    }
    
    # Get all unique tags
    [string[]] GetTags() {
        $tags = @()
        foreach ($command in $this.Commands) {
            foreach ($tag in $command.Tags) {
                if (-not [string]::IsNullOrWhiteSpace($tag) -and $tags -notcontains $tag) {
                    $tags += $tag
                }
            }
        }
        return $tags | Sort-Object
    }
}