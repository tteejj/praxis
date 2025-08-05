# DataPoolAdapter.ps1 - Adapter to make MacroFactory use the common data pool

class DataPoolAdapter {
    [string]$AppName = "MacroFactory"
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
    
    # Load macros from either local file or data pool
    [object[]] LoadMacros() {
        if ($this.UseDataPool) {
            # Try data pool first
            $macros = [DataPool]::Read($this.AppName, "macros")
            if ($macros) {
                return $macros
            }
        }
        
        # Fall back to local files
        $macrosPath = Join-Path $PSScriptRoot ".." "Data" "macros"
        if (Test-Path $macrosPath) {
            $macroList = @()
            $files = Get-ChildItem -Path $macrosPath -Filter "*.json" -File -ErrorAction SilentlyContinue
            
            foreach ($file in $files) {
                try {
                    $json = Get-Content -Path $file.FullName -Raw
                    $macroData = $json | ConvertFrom-Json
                    $macroList += $macroData
                } catch {
                    # Skip corrupted files
                }
            }
            
            return $macroList
        }
        
        return @()
    }
    
    # Save macros to both local and data pool
    [void] SaveMacros([object[]]$macros) {
        # Also save to data pool if available
        if ($this.UseDataPool) {
            [DataPool]::Write($this.AppName, "macros", $macros)
        }
    }
    
    # Save single macro
    [void] SaveMacro([hashtable]$macroData) {
        # Load existing macros
        $macros = $this.LoadMacros()
        
        # Check if macro already exists
        $existing = $macros | Where-Object { $_.Name -eq $macroData.Name }
        if ($existing) {
            # Update existing
            $index = [Array]::IndexOf($macros, $existing)
            $macros[$index] = $macroData
        } else {
            # Add new
            $macros += $macroData
        }
        
        # Save all macros
        $this.SaveMacros($macros)
        
        # Add to recent
        $this.AddToRecent($macroData)
    }
    
    # Check for incoming data from other apps
    [object[]] CheckExchanges() {
        if ($this.UseDataPool) {
            return [DataPool]::GetPendingExchanges($this.AppName)
        }
        return @()
    }
    
    # Process command from CommandLibrary
    [hashtable] ProcessCommandExchange([object]$exchange) {
        if ($exchange.Type -eq "command" -and $exchange.Data.Action -eq "CreateVisualMacro") {
            # Create a new macro template from command
            return @{
                Name = "Macro: $($exchange.Data.Title)"
                Description = "Visual macro created from CommandLibrary command"
                InitialScript = $exchange.Data.CommandText
                CommandId = $exchange.Data.CommandId
            }
        }
        return $null
    }
    
    # Send macro to CommandLibrary as a command
    [void] SendToCommandLibrary([object]$macro, [string]$ideaScript) {
        if ($this.UseDataPool) {
            [DataPool]::Exchange($this.AppName, "CommandLibrary", "macro-command", @{
                Title = $macro.Name
                CommandText = $ideaScript
                Description = $macro.Description
                Tags = @("macro", "ideascript", "auto-generated")
                Group = "Macros"
            })
        }
    }
    
    # Export macros to Excel
    [void] ExportToExcel([object[]]$macros) {
        if ($this.UseDataPool) {
            # Transform macro data for Excel export
            $exportData = @()
            foreach ($macro in $macros) {
                $exportData += @{
                    Name = $macro.Name
                    Description = $macro.Description
                    ActionCount = $macro.Actions.Count
                    Created = $macro.CreatedDate
                    Modified = $macro.ModifiedDate
                }
            }
            
            [DataPool]::Exchange($this.AppName, "ExcelDataFlow", "export-request", @{
                Data = $exportData
                Template = "MacroLibrary"
                Format = "xlsx"
            })
        }
    }
    
    # Add macro to recent items
    [void] AddToRecent([object]$macro) {
        if ($this.UseDataPool) {
            $id = if ($macro.Id) { $macro.Id } else { $macro.Name }
            [DataPool]::AddRecentItem($this.AppName, "macro", $macro.Name, $id)
        }
    }
    
    # Import macros from Excel
    [object[]] ImportFromExcel() {
        if ($this.UseDataPool) {
            $exchanges = [DataPool]::GetPendingExchanges($this.AppName)
            $excelImports = $exchanges | Where-Object { 
                $_.Type -eq "import-data" -and 
                $_.From -eq "ExcelDataFlow" 
            }
            
            $importedMacros = @()
            foreach ($import in $excelImports) {
                if ($import.Data.Macros) {
                    $importedMacros += $import.Data.Macros
                }
            }
            
            return $importedMacros
        }
        return @()
    }
}