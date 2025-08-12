    # All editing methods removed - BaseListScreen handles ALL editing
    
    [void] OpenProjectTextExport() {
        # ExcelDataFlow export directory
        $excelDataFlowPath = Join-Path (Split-Path $PSScriptRoot -Parent) "ExcelDataFlow"
        
        if (-not (Test-Path $excelDataFlowPath)) {
            [Console]::SetCursorPosition(0, $this.Height)
            Write-Host -NoNewline "ExcelDataFlow directory not found at: $excelDataFlowPath " -ForegroundColor Red
            Write-Host -NoNewline "Press any key to continue..." -ForegroundColor Gray
            [Console]::ReadKey($true) | Out-Null
            return
        }
        
        # Look for the most recent text export file anywhere in ExcelDataFlow
        $exportFiles = @()
        $searchPatterns = @("*.txt", "*.csv", "*.json", "*.tsv", "*.xml")
        
        # Search root directory and Projects subdirectory recursively
        $searchPaths = @($excelDataFlowPath)
        $projectsDir = Join-Path $excelDataFlowPath "Projects"
        if (Test-Path $projectsDir) {
            $searchPaths += $projectsDir
        }
        
        foreach ($searchPath in $searchPaths) {
            foreach ($pattern in $searchPatterns) {
                $files = Get-ChildItem -Path $searchPath -Filter $pattern -File -Recurse | Where-Object { 
                    $_.Name -like "*Export*" -or $_.Name -like "*export*" 
                }
                $exportFiles += $files
            }
        }
        
        if ($exportFiles.Count -eq 0) {
            [Console]::SetCursorPosition(0, $this.Height)
            Write-Host -NoNewline "No ExcelDataFlow export files found " -ForegroundColor Yellow
            Write-Host -NoNewline "Press any key to continue..." -ForegroundColor Gray
            [Console]::ReadKey($true) | Out-Null
            return
        }
        
        # Get the most recent export file
        $mostRecentFile = $exportFiles | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        
        [Console]::SetCursorPosition(0, $this.Height)
        Write-Host -NoNewline "Opening most recent export: $($mostRecentFile.Name) " -ForegroundColor Green
        Write-Host -NoNewline "Press any key to continue..." -ForegroundColor Gray
        [Console]::ReadKey($true) | Out-Null
        
        # Open the file with default system editor
        try {
            if ($IsLinux -or $IsMacOS) {
                # Unix-like systems - try common text editors
                $editors = @("nano", "vim", "vi", "gedit")
                $foundEditor = $false
                foreach ($editor in $editors) {
                    if (Get-Command $editor -ErrorAction SilentlyContinue) {
                        Start-Process $editor -ArgumentList "`"$($mostRecentFile.FullName)`""
                        $foundEditor = $true
                        break
                    }
                }
                if (-not $foundEditor) {
                    throw "No suitable text editor found"
                }
            } else {
                # Windows
                Start-Process -FilePath $mostRecentFile.FullName
            }
        } catch {
            [Console]::SetCursorPosition(0, $this.Height)
            Write-Host -NoNewline "Failed to open file: $_ " -ForegroundColor Red
            Write-Host -NoNewline "Press any key to continue..." -ForegroundColor Gray
            [Console]::ReadKey($true) | Out-Null
        }
    }