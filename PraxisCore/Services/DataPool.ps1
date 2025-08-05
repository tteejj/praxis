# DataPool.ps1 - Common data pool for all Praxis apps

class DataPool {
    static [string]$DataPath = "$env:HOME/.praxis/data"
    static [hashtable]$Cache = @{}
    
    # Initialize data directories
    static [void] Initialize() {
        $paths = @(
            [DataPool]::DataPath,
            (Join-Path [DataPool]::DataPath "tasks"),
            (Join-Path [DataPool]::DataPath "timeentries"),
            (Join-Path [DataPool]::DataPath "commands"),
            (Join-Path [DataPool]::DataPath "macros"),
            (Join-Path [DataPool]::DataPath "excel"),
            (Join-Path [DataPool]::DataPath "exchange")
        )
        
        foreach ($path in $paths) {
            if (-not (Test-Path $path)) {
                New-Item -ItemType Directory -Path $path -Force | Out-Null
            }
        }
    }
    
    # Get data file path for an app
    static [string] GetDataFile([string]$app, [string]$type) {
        $filename = switch ($app) {
            "TaskPro" { "tasks.json" }
            "TimeTracker" { "timeentries.json" }
            "CommandLibrary" { "commands.json" }
            "MacroFactory" { "macros.json" }
            "ExcelDataFlow" { "mappings.json" }
            default { "$type.json" }
        }
        
        return Join-Path ([DataPool]::DataPath) $type $filename
    }
    
    # Read data from pool
    static [object] Read([string]$app, [string]$type) {
        $file = [DataPool]::GetDataFile($app, $type)
        
        # Check cache first
        $cacheKey = "$app-$type"
        if ([DataPool]::Cache.ContainsKey($cacheKey)) {
            $cached = [DataPool]::Cache[$cacheKey]
            if ($cached.Timestamp -gt (Get-Item $file -ErrorAction SilentlyContinue).LastWriteTime) {
                return $cached.Data
            }
        }
        
        if (Test-Path $file) {
            try {
                $data = Get-Content $file -Raw | ConvertFrom-Json
                [DataPool]::Cache[$cacheKey] = @{
                    Data = $data
                    Timestamp = Get-Date
                }
                return $data
            } catch {
                return $null
            }
        }
        
        return $null
    }
    
    # Write data to pool
    static [void] Write([string]$app, [string]$type, [object]$data) {
        $file = [DataPool]::GetDataFile($app, $type)
        
        # Ensure directory exists
        $dir = Split-Path $file -Parent
        if (-not (Test-Path $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }
        
        # Create backup
        if (Test-Path $file) {
            $backup = Join-Path $dir "backup" ("${type}_" + (Get-Date -Format "yyyyMMdd_HHmmss") + ".json")
            $backupDir = Split-Path $backup -Parent
            if (-not (Test-Path $backupDir)) {
                New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
            }
            Copy-Item $file $backup
        }
        
        # Write data
        $data | ConvertTo-Json -Depth 10 | Set-Content $file -Encoding UTF8
        
        # Update cache
        $cacheKey = "$app-$type"
        [DataPool]::Cache[$cacheKey] = @{
            Data = $data
            Timestamp = Get-Date
        }
    }
    
    # Exchange data between apps
    static [void] Exchange([string]$fromApp, [string]$toApp, [string]$dataType, [object]$data) {
        $exchangeData = @{
            From = $fromApp
            To = $toApp
            Type = $dataType
            Timestamp = Get-Date -Format "o"
            Data = $data
        }
        
        $file = Join-Path ([DataPool]::DataPath) "exchange" "$toApp-pending.json"
        
        # Read existing pending items
        $pending = @()
        if (Test-Path $file) {
            $existing = Get-Content $file -Raw | ConvertFrom-Json
            if ($existing -is [array]) {
                $pending = $existing
            } else {
                $pending = @($existing)
            }
        }
        
        # Add new exchange
        $pending += $exchangeData
        
        # Save
        $pending | ConvertTo-Json -Depth 10 | Set-Content $file -Encoding UTF8
    }
    
    # Check for pending exchanges
    static [object[]] GetPendingExchanges([string]$app) {
        $file = Join-Path ([DataPool]::DataPath) "exchange" "$app-pending.json"
        
        if (Test-Path $file) {
            $data = Get-Content $file -Raw | ConvertFrom-Json
            # Clear the file after reading
            Remove-Item $file -Force
            return $data
        }
        
        return @()
    }
    
    # Get recent items across all apps
    static [object[]] GetRecentItems([int]$count = 10) {
        $recentFile = Join-Path ([DataPool]::DataPath) "recent.json"
        
        if (Test-Path $recentFile) {
            $items = Get-Content $recentFile -Raw | ConvertFrom-Json
            return $items | Select-Object -First $count
        }
        
        return @()
    }
    
    # Add to recent items
    static [void] AddRecentItem([string]$app, [string]$type, [string]$name, [string]$id) {
        $recentFile = Join-Path ([DataPool]::DataPath) "recent.json"
        
        $recent = @()
        if (Test-Path $recentFile) {
            $recent = Get-Content $recentFile -Raw | ConvertFrom-Json
        }
        
        # Add new item at top
        $newItem = @{
            App = $app
            Type = $type
            Name = $name
            Id = $id
            Timestamp = Get-Date -Format "o"
        }
        
        # Remove duplicates and limit to 50 items
        $recent = @($newItem) + ($recent | Where-Object { $_.Id -ne $id }) | Select-Object -First 50
        
        # Save
        $recent | ConvertTo-Json -Depth 10 | Set-Content $recentFile -Encoding UTF8
    }
}