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
                Label = "Output Path"
                Description = "Full path for the output Excel file"
                Required = $true
                Default = "C:\IDEA\Export.xlsx"
            },
            @{
                Name = "includeAllRecords"
                Type = "Boolean"
                Label = "Include All Records"
                Description = "Include all records or only extracted ones"
                Required = $false
                Default = "True"
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
        $outputPath = $this.Parameters["outputPath"]
        $includeAll = $this.Parameters["includeAllRecords"]
        
        $sb = [System.Text.StringBuilder]::new()
        
        # Build the export script
        $sb.AppendLine("' Export to Excel: $outputPath")
        $sb.AppendLine("Set db = Client.CurrentDatabase()")
        $sb.AppendLine("Set task = db.ExportDatabase")
        $sb.AppendLine("")
        
        # Set output file
        $sb.AppendLine("task.OutputFileName = ""$outputPath""")
        $sb.AppendLine("task.FileType = ""Excel 2007/2010 (*.xlsx)""")
        $sb.AppendLine("")
        
        # Set record selection
        if ($includeAll -eq "True" -or $includeAll -eq $true) {
            $sb.AppendLine("task.IncludeAllRecords = True")
        } else {
            $sb.AppendLine("task.IncludeAllRecords = False")
        }
        
        # Execute the export
        $sb.AppendLine("' Execute export")
        $sb.AppendLine("task.PerformTask")
        $sb.AppendLine("Set db = Nothing")
        $sb.AppendLine("Set task = Nothing")
        
        return $sb.ToString()
    }
}