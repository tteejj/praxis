# AppendFieldAction.ps1 - Adds a calculated field to the database
# Core data cleaning action for Phase 0

class AppendFieldAction : BaseAction {
    AppendFieldAction() : base() {
        $this.Name = "Append Calculated Field"
        $this.Description = "Adds a new field based on a calculation or equation"
        $this.Category = "Data Cleaning"
        $this.Icon = "➕"
        
        $this.Consumes = @(
            @{
                Name = "fieldName"
                Label = "Field Name"
                Type = "String"
                Description = "Name for the new field"
                Required = $true
                Default = "NEW_FIELD"
            },
            @{
                Name = "fieldEquation"
                Label = "Field Equation"
                Type = "String"
                Description = "IDEA equation for the field calculation"
                Required = $true
                Default = ""
            },
            @{
                Name = "fieldType"
                Label = "Field Type"
                Type = "Choice"
                Description = "Data type for the new field"
                Options = @("Character", "Numeric", "Date", "Logical")
                Required = $true
                Default = "Character"
            },
            @{
                Name = "fieldLength"
                Label = "Field Length"
                Type = "String"
                Description = "Field length (optional, for Character fields)"
                Required = $false
                Default = "50"
            }
        )
        
        $this.Produces = @(
            @{
                Name = "newField"
                Type = "Field"
                Description = "The newly created field"
            }
        )
    }
    
    [string] RenderScript([hashtable]$macroContext) {
        $fieldName = $this.Parameters["fieldName"] ?? "NEW_FIELD"
        $equation = $this.Parameters["fieldEquation"] ?? ""
        $fieldType = $this.Parameters["fieldType"] ?? "Character"
        $fieldLength = $this.Parameters["fieldLength"] ?? "50"
        
        $sb = [System.Text.StringBuilder]::new()
        
        # Build the append field script
        $sb.AppendLine("' Append Field: $fieldName = $equation")
        $sb.AppendLine("Set db = Client.CurrentDatabase()")
        $sb.AppendLine("Set task = db.TableManagement")
        $sb.AppendLine("Set field = task.NewField")
        $sb.AppendLine("")
        
        # Set field properties
        $sb.AppendLine("field.Name = ""$fieldName""")
        $sb.AppendLine("field.Equation = ""$equation""")
        
        # Set field type
        switch ($fieldType.ToUpper()) {
            "CHARACTER" { 
                $length = if ($fieldLength) { $fieldLength } else { "50" }
                $sb.AppendLine("field.Type = WI_VIRT_CHAR")
                $sb.AppendLine("field.Length = $length")
            }
            "NUMERIC" { 
                $sb.AppendLine("field.Type = WI_VIRT_NUM")
                $sb.AppendLine("field.Decimals = 2")
            }
            "DATE" { 
                $sb.AppendLine("field.Type = WI_VIRT_DATE")
            }
            "LOGICAL" { 
                $sb.AppendLine("field.Type = WI_VIRT_LOG")
            }
        }
        
        $sb.AppendLine("")
        $sb.AppendLine("' Add the field to the database")
        $sb.AppendLine("task.AppendField field")
        $sb.AppendLine("task.PerformTask")
        $sb.AppendLine("")
        $sb.AppendLine("Set field = Nothing")
        $sb.AppendLine("Set task = Nothing")
        $sb.AppendLine("Set db = Nothing")
        
        return $sb.ToString()
    }
}