# MacroService.ps1 - Service for saving and loading macro sequences

class MacroService {
    [string]$MacrosPath
    [Logger]$Logger
    
    MacroService() {
        $this.MacrosPath = Join-Path $global:PraxisRoot "_ProjectData/macros"
        $this.Logger = $global:Logger
        
        # Ensure macros directory exists
        if (-not (Test-Path $this.MacrosPath)) {
            New-Item -ItemType Directory -Path $this.MacrosPath -Force | Out-Null
        }
    }
    
    # Save a macro sequence to file
    [void] SaveMacro([string]$name, [MacroContextManager]$contextManager, [string]$description = "") {
        try {
            $macroData = @{
                Name = $name
                Description = $description
                CreatedDate = Get-Date -Format "o"
                ModifiedDate = Get-Date -Format "o"
                Version = "1.0"
                Actions = @()
            }
            
            # Serialize each action
            foreach ($action in $contextManager.Actions) {
                $actionData = @{
                    Type = $action.GetType().Name
                    Name = $action.Name
                    Parameters = $action.Parameters.Clone()
                }
                $macroData.Actions += $actionData
            }
            
            # Save to JSON file
            $filename = $this.SanitizeFilename($name) + ".json"
            $filepath = Join-Path $this.MacrosPath $filename
            
            $json = $macroData | ConvertTo-Json -Depth 10
            $json | Set-Content -Path $filepath -Encoding UTF8
            
            if ($this.Logger) {
                $this.Logger.Info("Saved macro '$name' to $filepath")
            }
        } catch {
            if ($this.Logger) {
                $this.Logger.Error("Failed to save macro: $_")
            }
            throw
        }
    }
    
    # Load a macro sequence from file
    [MacroContextManager] LoadMacro([string]$filename) {
        try {
            $filepath = Join-Path $this.MacrosPath $filename
            
            if (-not (Test-Path $filepath)) {
                throw "Macro file not found: $filename"
            }
            
            $json = Get-Content -Path $filepath -Raw
            $macroData = $json | ConvertFrom-Json
            
            # Create new context manager
            $contextManager = [MacroContextManager]::new()
            
            # Recreate actions
            foreach ($actionData in $macroData.Actions) {
                $action = $null
                
                # Create action instance based on type
                switch ($actionData.Type) {
                    "SummarizationAction" { $action = [SummarizationAction]::new() }
                    "AppendFieldAction" { $action = [AppendFieldAction]::new() }
                    "ExportToExcelAction" { $action = [ExportToExcelAction]::new() }
                    "CustomIdeaCommandAction" { $action = [CustomIdeaCommandAction]::new() }
                    default {
                        if ($this.Logger) {
                            $this.Logger.Warning("Unknown action type: $($actionData.Type)")
                        }
                        continue
                    }
                }
                
                if ($action) {
                    # Restore parameters
                    $parameters = @{}
                    $actionData.Parameters.PSObject.Properties | ForEach-Object {
                        $parameters[$_.Name] = $_.Value
                    }
                    $action.Parameters = $parameters
                    
                    # Add to context manager
                    $contextManager.AddAction($action)
                }
            }
            
            if ($this.Logger) {
                $this.Logger.Info("Loaded macro from $filepath with $($contextManager.Actions.Count) actions")
            }
            
            return $contextManager
        } catch {
            if ($this.Logger) {
                $this.Logger.Error("Failed to load macro: $_")
            }
            throw
        }
    }
    
    # Get list of available macros
    [hashtable[]] GetAvailableMacros() {
        $macros = @()
        
        try {
            $files = Get-ChildItem -Path $this.MacrosPath -Filter "*.json" -File
            
            foreach ($file in $files) {
                try {
                    $json = Get-Content -Path $file.FullName -Raw
                    $macroData = $json | ConvertFrom-Json
                    
                    $macros += @{
                        Filename = $file.Name
                        Name = $macroData.Name
                        Description = $macroData.Description
                        CreatedDate = $macroData.CreatedDate
                        ModifiedDate = $macroData.ModifiedDate
                        ActionCount = $macroData.Actions.Count
                    }
                } catch {
                    # Skip corrupted files
                    if ($this.Logger) {
                        $this.Logger.Warning("Failed to read macro file: $($file.Name)")
                    }
                }
            }
        } catch {
            if ($this.Logger) {
                $this.Logger.Error("Failed to list macros: $_")
            }
        }
        
        return $macros | Sort-Object ModifiedDate -Descending
    }
    
    # Delete a macro
    [void] DeleteMacro([string]$filename) {
        try {
            $filepath = Join-Path $this.MacrosPath $filename
            
            if (Test-Path $filepath) {
                Remove-Item -Path $filepath -Force
                
                if ($this.Logger) {
                    $this.Logger.Info("Deleted macro: $filename")
                }
            }
        } catch {
            if ($this.Logger) {
                $this.Logger.Error("Failed to delete macro: $_")
            }
            throw
        }
    }
    
    # Sanitize filename
    hidden [string] SanitizeFilename([string]$name) {
        # Replace invalid filename characters
        $invalidChars = [System.IO.Path]::GetInvalidFileNameChars()
        $sanitized = $name
        
        foreach ($char in $invalidChars) {
            $sanitized = $sanitized.Replace($char.ToString(), "_")
        }
        
        # Limit length
        if ($sanitized.Length -gt 50) {
            $sanitized = $sanitized.Substring(0, 50)
        }
        
        return $sanitized
    }
}