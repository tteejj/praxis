# BaseAction.ps1 - Base class for all macro actions

class BaseAction {
    [string]$Name = "Base Action"
    [string]$Description = "Base action class"
    [string]$Category = "General"
    [hashtable]$Parameters = @{}
    
    # What this action consumes (input requirements)
    [hashtable[]]$Consumes = @()
    
    # What this action produces (output variables)
    [hashtable[]]$Produces = @()
    
    # Constructor
    BaseAction() {
        $this.InitializeAction()
    }
    
    # Override in derived classes to set up action properties
    [void] InitializeAction() {
        # To be overridden
    }
    
    # Get display text for UI
    [string] GetDisplayText() {
        return "$($this.Category): $($this.Name)"
    }
    
    # Clone the action (for adding to sequence)
    [BaseAction] Clone() {
        $newAction = $this.GetType()::new()
        $newAction.Parameters = $this.Parameters.Clone()
        return $newAction
    }
    
    # Validate the action has all required parameters
    [hashtable] GetValidationStatus([hashtable]$context) {
        $missing = @()
        
        foreach ($param in $this.Consumes) {
            if ($param.Required -and 
                (-not $this.Parameters.ContainsKey($param.Name) -or 
                 [string]::IsNullOrEmpty($this.Parameters[$param.Name]))) {
                $missing += $param.Label
            }
        }
        
        if ($missing.Count -gt 0) {
            return @{ 
                IsValid = $false
                Message = "⚠️ Missing: $($missing -join ', ')"
            }
        }
        
        return @{ 
            IsValid = $true
            Message = "✅ Configured"
        }
    }
    
    # Render the IDEAScript code for this action
    [string] RenderScript([hashtable]$context) {
        throw "RenderScript must be implemented by derived class"
    }
    
    # Get missing context variables
    [string[]] GetMissingContext([hashtable]$context) {
        $missing = @()
        foreach ($param in $this.Consumes) {
            if ($param.Type -eq "Variable" -and $param.Required) {
                $varName = $this.Parameters[$param.Name]
                if ($varName -and $varName.StartsWith('$')) {
                    $varName = $varName.Substring(1)
                    if (-not $context.ContainsKey($varName)) {
                        $missing += $varName
                    }
                }
            }
        }
        return $missing
    }
}