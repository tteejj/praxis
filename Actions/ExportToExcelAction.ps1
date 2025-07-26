# ExportToExcelAction.ps1 - Exports current database to Excel
# Data I/O action for Phase 0

class ExportToExcelAction : BaseAction {
    ExportToExcelAction() : base() {
        $this.Name = "Export to Excel"
        $this.Description = "Exports the current database to an Excel file"
        $this.Category = "Data I/O"
        $this.Icon = "📈"
        
        $this.Consumes = @(
            @{
                Name = "outputPath"
                Type = "String"
                Description = "Full path for the output Excel file"
            },
            @{
                Name = "includeAllRecords"
                Type = "Boolean"
                Description = "Include all records or only extracted ones"
            }
        )
        
        $this.Produces = @(
            @{
                Name = "excelFile"
                Type = "File"
                Description = "The created Excel file"
            }
        )
    }
    
    [string] RenderScript([hashtable]$macroContext) {
        $outputPath = $macroContext["outputPath"]
        $includeAll = $macroContext["includeAllRecords"]
        
        $sb = [System.Text.StringBuilder]::new()
        
        # Build the export script
        $sb.AppendLine("Set db = Client.OpenDatabase(""$($macroContext['ActiveDatabase'])"")")
        $sb.AppendLine("Set task = db.ExternalFiles.ExcelFiles.NewExport")
        
        # Set output file
        $sb.AppendLine("task.OutputFileName = ""$outputPath""")
        
        # Set record selection
        if ($includeAll -eq "True" -or $includeAll -eq $true) {
            $sb.AppendLine("task.UseAllRecords")
        } else {
            $sb.AppendLine("task.UseExtractedRecords")
        }
        
        # Export all fields
        $sb.AppendLine("task.UseAllFields")
        
        # Execute the export
        $sb.AppendLine("task.PerformTask")
        $sb.AppendLine("Set db = Nothing")
        $sb.AppendLine("Set task = Nothing")
        
        return $sb.ToString()
    }
}