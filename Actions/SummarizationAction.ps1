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
                Description = "Fields to group by in the summarization"
            },
            @{
                Name = "totalFields"
                Type = "FieldList"
                Description = "Numeric fields to total (optional)"
            },
            @{
                Name = "outputDatabase"
                Type = "String"
                Description = "Name for the output database"
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
        $summaryFields = $macroContext["summaryFields"]
        $totalFields = $macroContext["totalFields"]
        $outputDb = $macroContext["outputDatabase"]
        
        $sb = [System.Text.StringBuilder]::new()
        
        # Build the summarization script
        $sb.AppendLine("Set db = Client.OpenDatabase(""$($macroContext['ActiveDatabase'])"")")
        $sb.AppendLine("Set task = db.Summarization")
        
        # Add grouping fields
        if ($summaryFields) {
            $sb.AppendLine("task.AddFieldToSummarize ""$summaryFields""")
        }
        
        # Add total fields if specified
        if ($totalFields -and $totalFields -ne "") {
            $sb.AppendLine("task.AddFieldToTotal ""$totalFields""")
        }
        
        # Set output database
        $sb.AppendLine("task.OutputDBName = ""$outputDb""")
        
        # Execute the task
        $sb.AppendLine("task.CreatePercentage = False")
        $sb.AppendLine("task.AppendDB = True")
        $sb.AppendLine("dbName = task.Run()")
        $sb.AppendLine("Set db = Nothing")
        $sb.AppendLine("Set task = Nothing")
        
        return $sb.ToString()
    }
}