# BaseAction.ps1 - Base class for Visual Macro Factory actions
# Defines the contract for all macro actions with explicit data dependencies

class BaseAction {
    [string]$Name
    [string]$Description
    [string]$Category
    [string]$Icon = "⚙️"
    
    # Declares what variables this action NEEDS from the Macro Context
    # Format: @{ Name="fieldName"; Type="Field"; Description="Field to analyze" }
    [hashtable[]]$Consumes = @()
    
    # Declares what variables this action CREATES  
    # Format: @{ Name="outputDb"; Type="Database"; Description="Result database" }
    [hashtable[]]$Produces = @()
    
    # Whether this action can accept custom IDEA@ commands
    [bool]$AllowsCustomCommands = $false
    
    # Stores the configured parameter values for this action instance
    [hashtable]$Parameters = @{}
    
    BaseAction() {
        # Override in derived classes
    }
    
    # Generates the final IDEAScript code using the provided context
    [string] RenderScript([hashtable]$macroContext) {
        throw "RenderScript must be implemented by derived class: $($this.GetType().Name)"
    }
    
    # Get display text for UI lists
    [string] GetDisplayText() {
        return "$($this.Icon) $($this.Name)"
    }
    
    # Get detailed description with requirements
    [string] GetDetailedDescription() {
        $sb = [System.Text.StringBuilder]::new()
        $sb.AppendLine($this.Description)
        
        if ($this.Consumes.Count -gt 0) {
            $sb.AppendLine("`nRequires:")
            foreach ($req in $this.Consumes) {
                $sb.AppendLine("  • $($req.Name) ($($req.Type)): $($req.Description)")
            }
        }
        
        if ($this.Produces.Count -gt 0) {
            $sb.AppendLine("`nProduces:")
            foreach ($prod in $this.Produces) {
                $sb.AppendLine("  • $($prod.Name) ($($prod.Type)): $($prod.Description)")
            }
        }
        
        return $sb.ToString()
    }
    
    # Validate that required context variables are available
    [bool] ValidateContext([hashtable]$macroContext) {
        foreach ($requirement in $this.Consumes) {
            if (-not $macroContext.ContainsKey($requirement.Name)) {
                return $false
            }
        }
        return $true
    }
    
    # Get list of missing context variables
    [string[]] GetMissingContext([hashtable]$macroContext) {
        $missing = @()
        foreach ($requirement in $this.Consumes) {
            if (-not $macroContext.ContainsKey($requirement.Name)) {
                $missing += $requirement.Name
            }
        }
        return $missing
    }
    
    # Get validation status with detailed message
    [hashtable] GetValidationStatus([hashtable]$macroContext) {
        # First check if all parameters are configured
        $unconfigured = @()
        foreach ($param in $this.Consumes) {
            if (-not $this.Parameters.ContainsKey($param.Name) -or 
                [string]::IsNullOrEmpty($this.Parameters[$param.Name])) {
                $unconfigured += $param.Label ?? $param.Name
            }
        }
        
        if ($unconfigured.Count -gt 0) {
            return @{ 
                IsValid = $false
                Message = "⚠️ Configure: $($unconfigured -join ', ')"
            }
        }
        
        # Then check context requirements
        $missing = $this.GetMissingContext($macroContext)
        if ($missing.Count -gt 0) {
            return @{ 
                IsValid = $false
                Message = "⚠️ Missing: $($missing -join ', ')" 
            }
        }
        
        # Add more validation checks here if needed
        
        return @{ 
            IsValid = $true
            Message = "✅ Ready" 
        }
    }
}