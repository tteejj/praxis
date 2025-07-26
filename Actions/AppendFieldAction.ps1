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
                Type = "String"
                Description = "Name for the new field"
            },
            @{
                Name = "fieldEquation"
                Type = "String"
                Description = "IDEA equation for the field calculation"
            },
            @{
                Name = "fieldType"
                Type = "String"
                Description = "Data type: Character, Numeric, Date, Logical"
            },
            @{
                Name = "fieldLength"
                Type = "String"
                Description = "Field length (optional, for Character fields)"
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
        $fieldName = $macroContext["fieldName"]
        $equation = $macroContext["fieldEquation"]
        $fieldType = $macroContext["fieldType"]
        $fieldLength = $macroContext["fieldLength"]
        
        $sb = [System.Text.StringBuilder]::new()
        
        # Build the append field script
        $sb.AppendLine("Set db = Client.OpenDatabase(""$($macroContext['ActiveDatabase'])"")")
        $sb.AppendLine("Set task = db.TableManagement.AppendDatabase")
        
        # Set field properties
        $sb.AppendLine("task.AddFieldToAppend ""$fieldName"", ""$equation""")
        
        # Set field type
        switch ($fieldType.ToUpper()) {
            "CHARACTER" { 
                $length = if ($fieldLength) { $fieldLength } else { "50" }
                $sb.AppendLine("task.SetFieldType ""$fieldName"", WI_CHAR_FIELD, $length")
            }
            "NUMERIC" { 
                $sb.AppendLine("task.SetFieldType ""$fieldName"", WI_VIRT_NUM_FIELD")
            }
            "DATE" { 
                $sb.AppendLine("task.SetFieldType ""$fieldName"", WI_VIRT_DATE_FIELD")
            }
            "LOGICAL" { 
                $sb.AppendLine("task.SetFieldType ""$fieldName"", WI_VIRT_BOOL_FIELD")
            }
        }
        
        # Execute the task
        $sb.AppendLine("task.PerformTask")
        $sb.AppendLine("Set db = Nothing")
        $sb.AppendLine("Set task = Nothing")
        
        return $sb.ToString()
    }
}