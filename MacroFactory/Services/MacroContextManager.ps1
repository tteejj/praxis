# MacroContextManager.ps1 - Manages macro state and variable context
# Simplified version for standalone MacroFactory

class MacroContextManager {
    [System.Collections.ArrayList]$Actions = [System.Collections.ArrayList]::new()
    [hashtable]$GlobalContext = @{}
    
    MacroContextManager() {
        $this.InitializeGlobalContext()
    }
    
    # Initialize with common IDEA context variables
    [void] InitializeGlobalContext() {
        $this.GlobalContext = @{
            # Common IDEA database context
            "ActiveDatabase" = @{
                Type = "Database"
                Description = "Currently active database in IDEA"
                Available = $true
            }
            
            # System variables
            "CurrentUser" = @{
                Type = "String"
                Description = "Current Windows username"
                Available = $true
                Value = $env:USERNAME
            }
            
            "CurrentDate" = @{
                Type = "Date"
                Description = "Current system date"
                Available = $true
                Value = (Get-Date).ToString("yyyy-MM-dd")
            }
        }
    }
    
    # Add an action to the macro sequence
    [void] AddAction([BaseAction]$action) {
        $this.Actions.Add($action) | Out-Null
        if ($global:Logger) {
            $global:Logger.Debug("Added action '$($action.Name)' at position $($this.Actions.Count)")
        }
    }
    
    # Remove an action from the sequence
    [void] RemoveAction([int]$index) {
        if ($index -ge 0 -and $index -lt $this.Actions.Count) {
            $action = $this.Actions[$index]
            $this.Actions.RemoveAt($index)
            
            if ($global:Logger) {
                $global:Logger.Debug("Removed action '$($action.Name)' from position $index")
            }
        }
    }
    
    # Move an action to a different position
    [void] MoveAction([int]$fromIndex, [int]$toIndex) {
        if ($fromIndex -eq $toIndex -or 
            $fromIndex -lt 0 -or $fromIndex -ge $this.Actions.Count -or
            $toIndex -lt 0 -or $toIndex -ge $this.Actions.Count) {
            return
        }
        
        $action = $this.Actions[$fromIndex]
        $this.Actions.RemoveAt($fromIndex)
        
        # Adjust target index if we removed an item before it
        if ($fromIndex -lt $toIndex) {
            $toIndex--
        }
        
        $this.Actions.Insert($toIndex, $action)
        
        if ($global:Logger) {
            $global:Logger.Debug("Moved action '$($action.Name)' from $fromIndex to $toIndex")
        }
    }
    
    # Get the context available at a specific step
    [hashtable] GetContextAtStep([int]$stepIndex) {
        $context = $this.GlobalContext.Clone()
        
        # Add variables produced by all previous actions
        for ($i = 0; $i -lt $stepIndex -and $i -lt $this.Actions.Count; $i++) {
            $action = $this.Actions[$i]
            foreach ($produced in $action.Produces) {
                $varName = $this.ResolveVariableName($produced.Name, $i)
                $context[$varName] = @{
                    Type = $produced.Type
                    Description = $produced.Description
                    ProducedBy = $action.Name
                    StepIndex = $i
                    Available = $true
                }
            }
        }
        
        return $context
    }
    
    # Get all variables available in the macro
    [hashtable] GetFullContext() {
        return $this.GetContextAtStep($this.Actions.Count)
    }
    
    # Resolve variable name with automatic collision handling
    [string] ResolveVariableName([string]$baseName, [int]$actionIndex) {
        # For now, use the parameter value directly
        $action = $this.Actions[$actionIndex]
        if ($action.Parameters.ContainsKey($baseName)) {
            return $action.Parameters[$baseName]
        }
        return $baseName
    }
    
    # Validate that all actions have their required context
    [hashtable] ValidateMacro() {
        $validation = @{
            IsValid = $true
            Errors = @()
            Warnings = @()
        }
        
        for ($i = 0; $i -lt $this.Actions.Count; $i++) {
            $action = $this.Actions[$i]
            $availableContext = $this.GetContextAtStep($i)
            
            # Check if all required variables are available
            foreach ($requirement in $action.Consumes) {
                if ($requirement.Type -eq "Variable" -and $requirement.Required) {
                    $varName = $action.Parameters[$requirement.Name]
                    if ($varName -and $varName.StartsWith('$')) {
                        $varName = $varName.Substring(1)
                        if (-not $availableContext.ContainsKey($varName)) {
                            $validation.IsValid = $false
                            $validation.Errors += "Step $($i + 1) ($($action.Name)): Missing required variable '$varName'"
                        }
                    }
                }
            }
        }
        
        return $validation
    }
    
    # Generate the final IDEAScript
    [string] GenerateScript() {
        # First check if we have any actions
        if ($this.Actions.Count -eq 0) {
            throw "Cannot generate script: No actions in macro sequence"
        }
        
        # Validate that all actions have required parameters configured
        $paramErrors = @()
        for ($i = 0; $i -lt $this.Actions.Count; $i++) {
            $action = $this.Actions[$i]
            foreach ($param in $action.Consumes) {
                if ($param.Required -and 
                    (-not $action.Parameters.ContainsKey($param.Name) -or 
                     [string]::IsNullOrEmpty($action.Parameters[$param.Name]))) {
                    $paramErrors += "Step $($i + 1) ($($action.Name)): Missing required parameter '$($param.Label)'"
                }
            }
        }
        
        if ($paramErrors.Count -gt 0) {
            throw "Cannot generate script: Missing parameters.`n$($paramErrors -join "`n")"
        }
        
        $sb = [System.Text.StringBuilder]::new()
        $sb.AppendLine("' Generated by MacroFactory")
        $sb.AppendLine("' Generated on: $(Get-Date)")
        $sb.AppendLine("' Total steps: $($this.Actions.Count)")
        $sb.AppendLine("")
        $sb.AppendLine("Option Explicit")
        $sb.AppendLine("")
        $sb.AppendLine("Sub Main()")
        $sb.AppendLine("    On Error GoTo ErrorHandler")
        $sb.AppendLine("")
        
        for ($i = 0; $i -lt $this.Actions.Count; $i++) {
            $action = $this.Actions[$i]
            $context = $this.GetContextAtStep($i)
            
            $sb.AppendLine("    ' Step $($i + 1): $($action.Name)")
            if ($action.Description) {
                $sb.AppendLine("    ' $($action.Description)")
            }
            $sb.AppendLine("")
            
            try {
                $actionScript = $action.RenderScript($context)
                # Indent the action script
                $lines = $actionScript -split "`n"
                foreach ($line in $lines) {
                    if ($line.Trim()) {
                        $sb.AppendLine("    $line")
                    } else {
                        $sb.AppendLine("")
                    }
                }
            } catch {
                $sb.AppendLine("    ' ERROR generating script for $($action.Name): $($_.Exception.Message)")
            }
            
            $sb.AppendLine("")
        }
        
        $sb.AppendLine("    Exit Sub")
        $sb.AppendLine("")
        $sb.AppendLine("ErrorHandler:")
        $sb.AppendLine("    MsgBox ""Error: "" & Err.Description")
        $sb.AppendLine("End Sub")
        
        return $sb.ToString()
    }
    
    # Clear all actions and reset context
    [void] Clear() {
        $this.Actions.Clear()
        $this.InitializeGlobalContext()
        
        if ($global:Logger) {
            $global:Logger.Debug("Cleared macro context")
        }
    }
}