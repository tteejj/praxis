# CustomIdeaCommandAction.ps1 - Allows insertion of custom IDEA@ commands from CommandLibrary
# Integrates with existing CommandService to pull available commands

class CustomIdeaCommandAction : BaseAction {
    [string]$SelectedCommand = ""
    [hashtable]$CommandParameters = @{}
    
    CustomIdeaCommandAction() : base() {
        $this.Name = "Custom IDEA@ Command"
        $this.Description = "Execute a custom IDEA@ command from your command library or type in manually"
        $this.Category = "Custom"
        $this.Icon = "📝"
        $this.AllowsCustomCommands = $true
        
        # This action is flexible - consumes/produces depend on the selected command
        $this.Consumes = @()
        $this.Produces = @()
    }
    
    # Set the command to execute
    [void] SetCommand([string]$commandText) {
        $this.SelectedCommand = $commandText
        $this.UpdateDataContract()
    }
    
    # Update Consumes/Produces based on selected command
    [void] UpdateDataContract() {
        # Clear existing contracts
        $this.Consumes = @()
        $this.Produces = @()
        
        if ([string]::IsNullOrWhiteSpace($this.SelectedCommand)) {
            return
        }
        
        # Parse command for @function references and add as requirements
        $functions = $this.ExtractFunctions($this.SelectedCommand)
        foreach ($func in $functions) {
            $this.Consumes += @{
                Name = $func
                Type = "Variable"
                Description = "Value for $func"
            }
        }
        
        # Most IDEA@ commands produce some kind of output
        # This is generic since we don't know the specific command's output
        $this.Produces += @{
            Name = "commandResult"
            Type = "Unknown"
            Description = "Result of custom IDEA@ command"
        }
    }
    
    # Extract @function references from command text
    [string[]] ExtractFunctions([string]$commandText) {
        $functions = @()
        $pattern = '@(\w+(?:\([^)]*\))?)'
        $matches = [regex]::Matches($commandText, $pattern)
        
        foreach ($match in $matches) {
            $functions += $match.Groups[1].Value
        }
        
        return $functions
    }
    
    [string] RenderScript([hashtable]$macroContext) {
        if ([string]::IsNullOrWhiteSpace($this.SelectedCommand)) {
            return "' No command specified"
        }
        
        $scriptText = $this.SelectedCommand
        
        # Replace @function references with values from macro context
        $functions = $this.ExtractFunctions($scriptText)
        foreach ($func in $functions) {
            if ($macroContext.ContainsKey($func)) {
                $value = $macroContext[$func]
                $scriptText = $scriptText.Replace("@$func", $value)
            }
        }
        
        # Add comment with original command for reference
        $sb = [System.Text.StringBuilder]::new()
        $sb.AppendLine("' Custom IDEA@ Command: $($this.SelectedCommand)")
        $sb.AppendLine($scriptText)
        
        return $sb.ToString()
    }
    
    # Get available commands from CommandService
    [System.Collections.ArrayList] GetAvailableCommands([object]$commandService) {
        if (-not $commandService) {
            return [System.Collections.ArrayList]::new()
        }
        
        # Filter commands that are IDEA@ related
        $ideaCommands = [System.Collections.ArrayList]::new()
        foreach ($command in $commandService.Commands) {
            # Look for commands that contain IDEA@ syntax or are tagged as IDEA commands
            if ($command.Command -match '@\w+' -or 
                $command.Tags -contains "idea" -or 
                $command.Tags -contains "ideascript" -or
                $command.Group -eq "IDEA") {
                $ideaCommands.Add($command) | Out-Null
            }
        }
        
        return $ideaCommands
    }
}