# SampleActions.ps1 - Sample actions for MacroFactory

# Summarization Action
class SummarizationAction : BaseAction {
    [void] InitializeAction() {
        $this.Name = "Summarize Data"
        $this.Description = "Summarize database by field with statistics"
        $this.Category = "Analysis"
        
        $this.Consumes = @(
            @{
                Name = "database"
                Label = "Database"
                Type = "Database"
                Description = "Database to summarize"
                Required = $true
            },
            @{
                Name = "fieldToSummarize"
                Label = "Field to Summarize"
                Type = "Field"
                Description = "Field to group by"
                Required = $true
            },
            @{
                Name = "outputName"
                Label = "Output Variable"
                Type = "String"
                Description = "Name for result variable"
                Default = "summaryResult"
                Required = $true
            }
        )
        
        $this.Produces = @(
            @{
                Name = "outputName"
                Type = "Database"
                Description = "Summarized database"
            }
        )
    }
    
    [string] RenderScript([hashtable]$context) {
        $db = $this.Parameters["database"]
        $field = $this.Parameters["fieldToSummarize"]
        $output = $this.Parameters["outputName"]
        
        return @"
' Summarize $db by $field
Set $output = db.$db.Summarization
$output.AddFieldToSummarize "$field"
$output.AddFieldToTotal "AMOUNT"
$output.AddFieldToTotal "COUNT"
$output.PerformTask()
"@
    }
}

# Append Field Action
class AppendFieldAction : BaseAction {
    [void] InitializeAction() {
        $this.Name = "Append Field"
        $this.Description = "Add a new field to database"
        $this.Category = "Data"
        
        $this.Consumes = @(
            @{
                Name = "database"
                Label = "Database"
                Type = "Database"
                Description = "Target database"
                Required = $true
            },
            @{
                Name = "fieldName"
                Label = "Field Name"
                Type = "String"
                Description = "Name for new field"
                Default = "NEW_FIELD"
                Required = $true
            },
            @{
                Name = "fieldType"
                Label = "Field Type"
                Type = "Choice"
                Description = "Data type for field"
                Options = @("Character", "Numeric", "Date", "Logical")
                Default = "Character"
                Required = $true
            },
            @{
                Name = "fieldLength"
                Label = "Field Length"
                Type = "Number"
                Description = "Length of field (for Character)"
                Default = "50"
                Required = $false
            }
        )
        
        $this.Produces = @()
    }
    
    [string] RenderScript([hashtable]$context) {
        $db = $this.Parameters["database"]
        $name = $this.Parameters["fieldName"]
        $type = $this.Parameters["fieldType"]
        $length = $this.Parameters["fieldLength"]
        
        $typeCode = switch ($type) {
            "Character" { "WI_CHAR_FIELD" }
            "Numeric" { "WI_NUM_FIELD" }
            "Date" { "WI_DATE_FIELD" }
            "Logical" { "WI_BOOL_FIELD" }
            default { "WI_CHAR_FIELD" }
        }
        
        $script = "' Append field $name to $db`n"
        $script += "db.$db.AppendField `"$name`", $typeCode"
        
        if ($type -eq "Character" -and $length) {
            $script += ", $length"
        }
        
        return $script
    }
}

# Export to Excel Action
class ExportToExcelAction : BaseAction {
    [void] InitializeAction() {
        $this.Name = "Export to Excel"
        $this.Description = "Export database to Excel file"
        $this.Category = "Export"
        
        $this.Consumes = @(
            @{
                Name = "database"
                Label = "Database"
                Type = "Database"
                Description = "Database to export"
                Required = $true
            },
            @{
                Name = "filename"
                Label = "Filename"
                Type = "String"
                Description = "Output filename"
                Default = "export.xlsx"
                Required = $true
            },
            @{
                Name = "includeHeader"
                Label = "Include Headers"
                Type = "Boolean"
                Description = "Include column headers"
                Default = "True"
                Required = $false
            }
        )
        
        $this.Produces = @()
    }
    
    [string] RenderScript([hashtable]$context) {
        $db = $this.Parameters["database"]
        $filename = $this.Parameters["filename"]
        $headers = $this.Parameters["includeHeader"]
        
        $script = "' Export $db to Excel`n"
        $script += "Set export = db.$db.ExportToXLSX`n"
        $script += "export.FileName = `"$filename`"`n"
        
        if ($headers -eq "False") {
            $script += "export.IncludeHeaders = False`n"
        }
        
        $script += "export.PerformTask()"
        
        return $script
    }
}

# Custom IDEA Command Action
class CustomIdeaCommandAction : BaseAction {
    [void] InitializeAction() {
        $this.Name = "Custom IDEA Command"
        $this.Description = "Execute custom IDEAScript code"
        $this.Category = "Advanced"
        
        $this.Consumes = @(
            @{
                Name = "customCode"
                Label = "IDEAScript Code"
                Type = "Multiline"
                Description = "Custom IDEAScript code to execute"
                Required = $true
            }
        )
        
        $this.Produces = @()
    }
    
    [string] RenderScript([hashtable]$context) {
        $code = $this.Parameters["customCode"]
        
        return @"
' Custom IDEAScript
$code
"@
    }
}