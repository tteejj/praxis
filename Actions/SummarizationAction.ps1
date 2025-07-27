# SummarizationAction.ps1 - Performs IDEA summarization operation
# One of the core Phase 0 actions for data analysis

class SummarizationAction : BaseAction {
    SummarizationAction() : base() {
        $this.Name = "Summarization"
        $this.Description = "Summarizes data by grouping fields and calculating totals"
        $this.Category = "Core Analysis"
        $this.Icon = "📊"
        
        $this.Consumes = @(
            @{
                Name = "summaryFields"
                Type = "FieldList"
                Label = "Summary Fields"
                Description = "Fields to group by in the summarization"
                Required = $true
                Default = ""
            },
            @{
                Name = "totalFields"
                Type = "FieldList"
                Label = "Total Fields"
                Description = "Numeric fields to total (optional)"
                Required = $false
                Default = ""
            },
            @{
                Name = "outputDatabase"
                Type = "String"
                Label = "Output Database Name"
                Description = "Name for the output database"
                Required = $true
                Default = "Summary_Result"
            }
        )
        
        $this.Produces = @(
            @{
                Name = "summaryResult"
                Type = "Database"
                Description = "Database containing summarized results"
            }
        )
    }
    
    [string] RenderScript([hashtable]$macroContext) {
        # Get parameters from this action instance
        $summaryFields = $this.Parameters["summaryFields"]
        $totalFields = $this.Parameters["totalFields"]
        $outputDb = $this.Parameters["outputDatabase"]
        
        # Use defaults if not set
        if ([string]::IsNullOrEmpty($outputDb)) {
            $outputDb = "Summary_Result"
        }
        
        $sb = [System.Text.StringBuilder]::new()
        
        # Build the summarization script
        $sb.AppendLine("' Summarization: Group by $summaryFields")
        $sb.AppendLine("Set db = Client.CurrentDatabase()")
        $sb.AppendLine("Set task = db.Summarization")
        $sb.AppendLine("")
        
        # Add grouping fields
        if ($summaryFields) {
            foreach ($field in ($summaryFields -split ',')) {
                $field = $field.Trim()
                if ($field) {
                    $sb.AppendLine("task.AddFieldToSummarize ""$field""")
                }
            }
        }
        
        # Add total fields if specified
        if ($totalFields -and $totalFields -ne "") {
            foreach ($field in ($totalFields -split ',')) {
                $field = $field.Trim()
                if ($field) {
                    $sb.AppendLine("task.AddFieldToTotal ""$field""")
                }
            }
        }
        
        # Set output database
        $sb.AppendLine("")
        $sb.AppendLine("task.OutputDBName = ""$outputDb""")
        $sb.AppendLine("task.CreatePercentage = False")
        $sb.AppendLine("")
        
        # Execute the task
        $sb.AppendLine("' Execute summarization")
        $sb.AppendLine("task.PerformTask")
        $sb.AppendLine("Set db = Nothing")
        $sb.AppendLine("Set task = Nothing")
        
        return $sb.ToString()
    }
}