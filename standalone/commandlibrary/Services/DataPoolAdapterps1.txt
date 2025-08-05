# DataPoolAdapter.ps1 - Adapter to make CommandLibrary use the common data pool

class DataPoolAdapter {
    [string]$AppName = "CommandLibrary"
    [bool]$UseDataPool = $false
    
    DataPoolAdapter() {
        # Check if DataPool is available
        $dataPoolPath = Join-Path $PSScriptRoot "../../PraxisCore/Services/DataPool.ps1"
        if (Test-Path $dataPoolPath) {
            . $dataPoolPath
            [DataPool]::Initialize()
            $this.UseDataPool = $true
        }
    }
    
    # Load commands from either local file or data pool
    [object[]] LoadCommands() {
        if ($this.UseDataPool) {
            # Try data pool first
            $commands = [DataPool]::Read($this.AppName, "commands")
            if ($commands) {
                return $commands
            }
        }
        
        # Fall back to local file
        $localFile = Join-Path $PSScriptRoot "../Data/commands.json"
        if (Test-Path $localFile) {
            return Get-Content $localFile -Raw | ConvertFrom-Json
        }
        
        return @()
    }
    
    # Save commands to both local and data pool
    [void] SaveCommands([object[]]$commands) {
        # Save to local file (for standalone operation)
        $localFile = Join-Path $PSScriptRoot "../Data/commands.json"
        $localDir = Split-Path $localFile -Parent
        if (-not (Test-Path $localDir)) {
            New-Item -ItemType Directory -Path $localDir -Force | Out-Null
        }
        $commands | ConvertTo-Json -Depth 10 | Set-Content $localFile -Encoding UTF8
        
        # Also save to data pool if available
        if ($this.UseDataPool) {
            [DataPool]::Write($this.AppName, "commands", $commands)
        }
    }
    
    # Check for incoming data from other apps
    [object[]] CheckExchanges() {
        if ($this.UseDataPool) {
            return [DataPool]::GetPendingExchanges($this.AppName)
        }
        return @()
    }
    
    # Process time data from TimeTracker to create report macros
    [hashtable] ProcessTimeDataExchange([object]$exchange) {
        if ($exchange.Type -eq "time-data" -and $exchange.Data.Action -eq "CreateReportMacro") {
            # Generate a command to create time reports
            $entries = $exchange.Data.Entries
            
            $commandText = @"
# Generate time report from TimeTracker data
`$entries = @(
$(foreach ($entry in $entries) {
    "    @{ProjectCode='$($entry.ProjectCode)'; Description='$($entry.Description)'; Total=$($entry.Total)}"
})
)

# Create summary
`$total = (`$entries | Measure-Object -Property Total -Sum).Sum
Write-Host "Time Report Summary" -ForegroundColor Cyan
Write-Host "==================" -ForegroundColor DarkGray
foreach (`$entry in `$entries) {
    Write-Host "`$(`$entry.ProjectCode): `$(`$entry.Description) - `$(`$entry.Total) hours"
}
Write-Host "==================" -ForegroundColor DarkGray
Write-Host "Total: `$total hours" -ForegroundColor Green
"@
            
            return @{
                Title = "Time Report - $(Get-Date -Format 'yyyy-MM-dd')"
                CommandText = $commandText
                Description = "Auto-generated time report from TimeTracker"
                Tags = @("timetracker", "report", "auto-generated")
                Group = "Reports"
            }
        }
        return $null
    }
    
    # Send command to MacroFactory for visual editing
    [void] SendToMacroFactory([object]$command) {
        if ($this.UseDataPool) {
            [DataPool]::Exchange($this.AppName, "MacroFactory", "command", @{
                CommandId = $command.Id
                Title = $command.Title
                CommandText = $command.CommandText
                Action = "CreateVisualMacro"
            })
        }
    }
    
    # Export commands to Excel
    [void] ExportToExcel([object[]]$commands) {
        if ($this.UseDataPool) {
            [DataPool]::Exchange($this.AppName, "ExcelDataFlow", "export-request", @{
                Data = $commands
                Template = "CommandLibrary"
                Format = "xlsx"
            })
        }
    }
    
    # Add command to recent items
    [void] AddToRecent([object]$command) {
        if ($this.UseDataPool) {
            [DataPool]::AddRecentItem($this.AppName, "command", $command.Title, $command.Id)
        }
    }
    
    # Import commands from ExcelDataFlow
    [object[]] ImportFromExcel() {
        if ($this.UseDataPool) {
            $exchanges = [DataPool]::GetPendingExchanges($this.AppName)
            $excelImports = $exchanges | Where-Object { 
                $_.Type -eq "import-data" -and 
                $_.From -eq "ExcelDataFlow" 
            }
            
            $importedCommands = @()
            foreach ($import in $excelImports) {
                if ($import.Data.Commands) {
                    $importedCommands += $import.Data.Commands
                }
            }
            
            return $importedCommands
        }
        return @()
    }
}