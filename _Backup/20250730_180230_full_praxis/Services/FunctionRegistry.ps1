# FunctionRegistry.ps1 - Registry for @functions used in Visual Macro Factory
# Integrates with CommandService to provide both built-in and custom @functions

class FunctionRegistry {
    [hashtable]$BuiltInFunctions = @{}
    [CommandService]$CommandService
    [Logger]$Logger
    
    FunctionRegistry() {
        $this.Logger = $global:Logger
        $this.RegisterBuiltInFunctions()
    }
    
    # Set the CommandService reference for accessing custom commands
    [void] SetCommandService([CommandService]$commandService) {
        $this.CommandService = $commandService
    }
    
    # Register built-in @functions
    [void] RegisterBuiltInFunctions() {
        # User input functions
        $this.BuiltInFunctions["PromptForField"] = @{
            Name = "PromptForField"
            Description = "Prompts user to select a field from the current database"
            Category = "User Input"
            Usage = "@PromptForField"
            Template = "@PromptForField"
        }
        
        $this.BuiltInFunctions["PromptForValue"] = @{
            Name = "PromptForValue"
            Description = "Prompts user for a text value"
            Category = "User Input"
            Usage = "@PromptForValue(""Enter value:"")"
            Template = "@PromptForValue(""Enter description"")"
        }
        
        $this.BuiltInFunctions["PromptForNumber"] = @{
            Name = "PromptForNumber"
            Description = "Prompts user for a numeric value"
            Category = "User Input"
            Usage = "@PromptForNumber(""Enter amount:"")"
            Template = "@PromptForNumber(""Enter description"")"
        }
        
        # System functions
        $this.BuiltInFunctions["CurrentDate_YYYYMMDD"] = @{
            Name = "CurrentDate_YYYYMMDD"
            Description = "Current date in YYYYMMDD format"
            Category = "System"
            Usage = "@CurrentDate_YYYYMMDD"
            Template = "@CurrentDate_YYYYMMDD"
        }
        
        $this.BuiltInFunctions["CurrentDate_MMDDYYYY"] = @{
            Name = "CurrentDate_MMDDYYYY"
            Description = "Current date in MM/DD/YYYY format"
            Category = "System"
            Usage = "@CurrentDate_MMDDYYYY"
            Template = "@CurrentDate_MMDDYYYY"
        }
        
        $this.BuiltInFunctions["CurrentUser"] = @{
            Name = "CurrentUser"
            Description = "Current Windows username"
            Category = "System"
            Usage = "@CurrentUser"
            Template = "@CurrentUser"
        }
        
        $this.BuiltInFunctions["CurrentTime_HHMMSS"] = @{
            Name = "CurrentTime_HHMMSS"
            Description = "Current time in HHMMSS format"
            Category = "System"
            Usage = "@CurrentTime_HHMMSS"
            Template = "@CurrentTime_HHMMSS"
        }
        
        # File functions
        $this.BuiltInFunctions["TempFile"] = @{
            Name = "TempFile"
            Description = "Generate a temporary file path"
            Category = "File"
            Usage = "@TempFile(.xlsx)"
            Template = "@TempFile(.xlsx)"
        }
    }
    
    # Get all available @functions (built-in + custom from CommandService)
    [hashtable[]] GetAllFunctions() {
        $functions = @()
        
        # Add built-in functions
        foreach ($func in $this.BuiltInFunctions.Values) {
            $functions += $func
        }
        
        # Add custom functions from CommandService if available
        if ($this.CommandService) {
            $customFunctions = $this.GetCustomFunctions()
            $functions += $customFunctions
        }
        
        return $functions
    }
    
    # Get custom @functions from CommandService
    [hashtable[]] GetCustomFunctions() {
        $functions = @()
        
        if (-not $this.CommandService) {
            return $functions
        }
        
        # Look for commands that define @functions
        foreach ($command in $this.CommandService.Commands) {
            # Check if command defines a @function (starts with @)
            if ($command.Command -match '^@(\w+)') {
                $funcName = $matches[1]
                $functions += @{
                    Name = $funcName
                    Description = $command.Description
                    Category = "Custom"
                    Usage = $command.Command
                    Template = $command.Command
                    Source = "CommandLibrary"
                    Tags = $command.Tags
                }
            }
            
            # Also check for commands tagged as functions
            if ($command.Tags -contains "function" -or $command.Tags -contains "@function") {
                $functions += @{
                    Name = $command.Name
                    Description = $command.Description
                    Category = "Custom"
                    Usage = $command.Command
                    Template = $command.Command
                    Source = "CommandLibrary"
                    Tags = $command.Tags
                }
            }
        }
        
        return $functions
    }
    
    # Search functions by name or description
    [hashtable[]] SearchFunctions([string]$query) {
        $allFunctions = $this.GetAllFunctions()
        $results = @()
        
        $query = $query.ToLower()
        
        foreach ($func in $allFunctions) {
            $name = $func.Name.ToLower()
            $desc = $func.Description.ToLower()
            
            if ($name.Contains($query) -or $desc.Contains($query)) {
                $results += $func
            }
        }
        
        return $results
    }
    
    # Get functions by category
    [hashtable[]] GetFunctionsByCategory([string]$category) {
        $allFunctions = $this.GetAllFunctions()
        $results = @()
        
        foreach ($func in $allFunctions) {
            if ($func.Category -eq $category) {
                $results += $func
            }
        }
        
        return $results
    }
    
    # Resolve @function at runtime (for script generation)
    [string] ResolveFunction([string]$functionCall, [hashtable]$context = @{}) {
        # This would be called during macro execution to replace @functions with actual values
        # For now, return the function call as-is for the IDEAScript to handle
        return $functionCall
    }
}