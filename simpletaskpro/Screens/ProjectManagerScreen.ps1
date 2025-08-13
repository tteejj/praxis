class ProjectManagerScreen : ListScreen {
    [SimpleTaskService]$TaskService
    [SimpleTask]$ParentTask
    
    # Colors for Write-Host (ConsoleColor enum values)
    [ConsoleColor]$HeaderColor = [ConsoleColor]::Cyan
    [ConsoleColor]$HighColor = [ConsoleColor]::Red  
    [ConsoleColor]$MediumColor = [ConsoleColor]::Yellow
    [ConsoleColor]$LowColor = [ConsoleColor]::Green
    [ConsoleColor]$TodayColor = [ConsoleColor]::Yellow
    [ConsoleColor]$SubtaskColor = [ConsoleColor]::Gray
    [ConsoleColor]$CompletedColor = [ConsoleColor]::DarkGray
    [ConsoleColor]$TagColor = [ConsoleColor]::Gray
    
    # ANSI sequences for direct output
    [string]$HeaderAnsi = "`e[38;2;100;150;255m"     # Modern blue
    [string]$TodayAnsi = "`e[38;2;255;215;0m"        # Bright gold/yellow
    [string]$NormalAnsi = "`e[0m"                     # Reset
    
    # Pillbox drawing characters
    [string]$PillboxTopLeft = "╭"
    [string]$PillboxTopRight = "╮"
    [string]$PillboxBottomLeft = "╰"
    [string]$PillboxBottomRight = "╯"
    [string]$PillboxHorizontal = "─"
    [string]$PillboxVertical = "│"
    
    # Menu items
    [array]$MenuItems
    
    ProjectManagerScreen([ServiceContainer]$services) : base($services) {
        $this.Title = "Project Manager"
        # Initialize menu items as simple objects
        $this.MenuItems = @()
        $this.MenuItems += [PSCustomObject]@{ Key = "S"; Title = "Project Settings"; Description = "Configure project folder, files, and metadata" }
        $this.MenuItems += [PSCustomObject]@{ Key = "T"; Title = "T2020 Call Log"; Description = "Open or create T2020 call log file" }
        $this.MenuItems += [PSCustomObject]@{ Key = "O"; Title = "Open Project Folder"; Description = "Open project folder in file explorer" }
        $this.MenuItems += [PSCustomObject]@{ Key = "F"; Title = "Export Data File"; Description = "View export data file (read-only)" }
        $this.MenuItems += [PSCustomObject]@{ Key = "L"; Title = "Action Log"; Description = "Open or create project action log" }
        $this.MenuItems += [PSCustomObject]@{ Key = "B"; Title = "Browse Files"; Description = "Browse project files and folders" }
    }
    
    [void] SetServices([SimpleTaskService]$taskService) {
        $this.TaskService = $taskService
    }
    
    [void] SetParentTask([SimpleTask]$parentTask) {
        $this.ParentTask = $parentTask
    }
    
    [void] SetBounds([int]$x, [int]$y, [int]$width, [int]$height) {
        $this.X = $x
        $this.Y = $y
        $this.Width = $width
        $this.Height = $height
    }
    
    [void] Show() {
        try {
            [Console]::CursorVisible = $false
            
            while ($true) {
                try {
                    $this.Render()
                    
                    $key = [Console]::ReadKey($true)
                    if (-not $this.HandleInput($key)) {
                        break
                    }
                } catch {
                    # Show render/input error
                    [Console]::Clear()
                    [Console]::SetCursorPosition(0, 0)
                    Write-Host "PROJECT SCREEN ERROR:" -ForegroundColor White -BackgroundColor Red
                    Write-Host "Message: $($_.Exception.Message)" -ForegroundColor Yellow
                    Write-Host "Line: $($_.InvocationInfo.ScriptLineNumber)" -ForegroundColor Yellow
                    Write-Host "Details: $($_.Exception.ToString())" -ForegroundColor Gray
                    Write-Host ""
                    Write-Host "Returning to tasks..." -ForegroundColor White
                    Start-Sleep -Milliseconds 2000
                    break
                }
            }
        } catch {
            # Top level error
            try {
                [Console]::Clear()
                [Console]::SetCursorPosition(0, 0)
                Write-Host "CRITICAL PROJECT SCREEN ERROR:" -ForegroundColor White -BackgroundColor DarkRed
                Write-Host "Message: $($_.Exception.Message)" -ForegroundColor Yellow
                Write-Host "Type: $($_.Exception.GetType().Name)" -ForegroundColor Yellow
                Write-Host "Details: $($_.Exception.ToString())" -ForegroundColor Gray
                Write-Host ""
                Write-Host "Returning to tasks..." -ForegroundColor White
                Start-Sleep -Milliseconds 2000
            } catch {
                # If even error display fails, just exit silently
            }
        } finally {
            try {
                [Console]::CursorVisible = $true
            } catch {}
        }
    }
    
    [void] Render() {
        try {
            [Console]::Clear()
            
            # Header - matching TaskListScreen
            [Console]::SetCursorPosition(0, 0)
            Write-Host "PROJECT MANAGER - $($this.ParentTask.Title)" -ForegroundColor $this.HeaderColor
            
            # Column headers
            [Console]::SetCursorPosition(0, 1)
            Write-Host "Key Action                    Description" -ForegroundColor $this.TagColor
            
            # Separator line
            [Console]::SetCursorPosition(0, 2)
            Write-Host ($this.PillboxHorizontal * $this.Width) -ForegroundColor $this.TagColor
        
            # Render menu items with error-safe pillbox selection
            $currentY = 4
            
            for ($i = 0; $i -lt $this.MenuItems.Count; $i++) {
                try {
                    $item = $this.MenuItems[$i]
                    
                    # Debug: show what we're trying to render
                    if ($item -eq $null) {
                        throw "Menu item $i is null"
                    }
                    if ([string]::IsNullOrEmpty($item.Key)) {
                        throw "Menu item $i has no Key"
                    }
                    if ([string]::IsNullOrEmpty($item.Title)) {
                        throw "Menu item $i has no Title"
                    }
                    
                    if ($i -eq $this.SelectedIndex) {
                        # Selected item with simple pillbox  
                        [Console]::SetCursorPosition(0, $currentY)
                        Write-Host "╭" -NoNewline -ForegroundColor $this.HeaderColor
                        Write-Host ("─" * ([Math]::Max(1, $this.Width - 2))) -NoNewline -ForegroundColor $this.HeaderColor
                        Write-Host "╮" -ForegroundColor $this.HeaderColor
                        
                        [Console]::SetCursorPosition(0, $currentY + 1)
                        Write-Host "│" -NoNewline -ForegroundColor $this.HeaderColor
                        Write-Host "■ " -NoNewline -ForegroundColor $this.TodayColor
                        Write-Host " $($item.Key) " -NoNewline -ForegroundColor $this.HeaderColor  
                        Write-Host " $($item.Title)" -NoNewline -ForegroundColor White
                        
                        # Pad safely
                        $usedLength = 4 + $item.Key.Length + 1 + $item.Title.Length + 1
                        $paddingNeeded = [Math]::Max(0, $this.Width - $usedLength - 1)
                        if ($paddingNeeded -gt 0) {
                            Write-Host (" " * $paddingNeeded) -NoNewline
                        }
                        Write-Host "│" -ForegroundColor $this.HeaderColor
                        
                        [Console]::SetCursorPosition(0, $currentY + 2)  
                        Write-Host "╰" -NoNewline -ForegroundColor $this.HeaderColor
                        Write-Host ("─" * ([Math]::Max(1, $this.Width - 2))) -NoNewline -ForegroundColor $this.HeaderColor
                        Write-Host "╯" -ForegroundColor $this.HeaderColor
                        
                        $currentY += 4  # Space for pillbox only
                        
                    } else {
                        # Non-selected item - simple single line
                        [Console]::SetCursorPosition(0, $currentY)
                        Write-Host "■ " -NoNewline -ForegroundColor $this.CompletedColor
                        Write-Host " $($item.Key) " -NoNewline -ForegroundColor $this.TagColor
                        Write-Host " $($item.Title)" -ForegroundColor White
                        
                        $currentY += 1  # Single line spacing
                    }
                } catch {
                    # Show specific error for debugging
                    [Console]::SetCursorPosition(0, $currentY)
                    Write-Host "■ ERROR: $($_.Exception.Message)" -ForegroundColor Red
                    $currentY += 1
                }
            }
        
            # Instructions at bottom - matching TaskListScreen
            $instructY = $this.Height - 1
            [Console]::SetCursorPosition(0, $instructY - 1)
            Write-Host ($this.PillboxHorizontal * $this.Width) -ForegroundColor $this.TagColor
            [Console]::SetCursorPosition(0, $instructY)
            Write-Host "↑↓:Navigate  ENTER:Select  S:Settings  T:T2020  O:Folder  F:Export  L:Log  B:Browse  Q:Return" -ForegroundColor $this.TagColor
            
        } catch {
            # Render error - show simple fallback menu
            [Console]::Clear()
            [Console]::SetCursorPosition(0, 0)
            Write-Host "PROJECT MANAGER - $($this.ParentTask.Title)" -ForegroundColor $this.HeaderColor
            Write-Host ""
            Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Yellow
            Write-Host ""
            Write-Host "Available Options:" -ForegroundColor Cyan
            Write-Host "  S - Project Settings" -ForegroundColor White
            Write-Host "  T - T2020 Call Log" -ForegroundColor White  
            Write-Host "  O - Open Project Folder" -ForegroundColor White
            Write-Host "  F - Export Data File" -ForegroundColor White
            Write-Host "  L - Action Log" -ForegroundColor White
            Write-Host "  B - Browse Files" -ForegroundColor White
            Write-Host "  Q - Return to Tasks" -ForegroundColor White
        }
    }
    
    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        switch ($key.Key) {
            ([System.ConsoleKey]::Escape) { return $false }
            ([System.ConsoleKey]::Q) { return $false }
            
            ([System.ConsoleKey]::UpArrow) {
                $this.SelectedIndex = ($this.SelectedIndex - 1 + $this.MenuItems.Count) % $this.MenuItems.Count
                return $true
            }
            
            ([System.ConsoleKey]::DownArrow) {
                $this.SelectedIndex = ($this.SelectedIndex + 1) % $this.MenuItems.Count
                return $true
            }
            
            ([System.ConsoleKey]::Enter) {
                $selectedItem = $this.MenuItems[$this.SelectedIndex]
                $this.ExecuteAction($selectedItem.Key)
                return $true
            }
            
            default {
                # Direct key selection
                $keyChar = $key.KeyChar.ToString().ToUpper()
                for ($i = 0; $i -lt $this.MenuItems.Count; $i++) {
                    if ($this.MenuItems[$i].Key -eq $keyChar) {
                        $this.SelectedIndex = $i
                        $this.ExecuteAction($keyChar)
                        break
                    }
                }
                return $true
            }
        }
        return $true  # Explicit return for all code paths
    }
    
    [void] ExecuteAction([string]$action) {
        # Show action feedback
        $feedbackY = $this.Height - 3
        [Console]::SetCursorPosition(0, $feedbackY)
        Write-Host (" " * $this.Width) -NoNewline
        [Console]::SetCursorPosition(0, $feedbackY)
        
        switch ($action) {
            "S" { 
                Write-Host "Opening Project Settings..." -ForegroundColor White -BackgroundColor DarkGreen
                Start-Sleep -Milliseconds 500
                $this.OpenProjectSettings()
            }
            "T" { 
                Write-Host "Opening T2020 Call Log..." -ForegroundColor White -BackgroundColor DarkBlue
                Start-Sleep -Milliseconds 500
                $this.OpenT2020CallLog()
            }
            "O" { 
                Write-Host "Opening Project Folder..." -ForegroundColor White -BackgroundColor DarkMagenta
                Start-Sleep -Milliseconds 500
                $this.OpenProjectFolder()
            }
            "F" { 
                Write-Host "Opening Export Data File..." -ForegroundColor White -BackgroundColor DarkCyan
                Start-Sleep -Milliseconds 500
                $this.OpenExportDataFile()
            }
            "L" { 
                Write-Host "Opening Action Log..." -ForegroundColor White -BackgroundColor DarkYellow
                Start-Sleep -Milliseconds 500
                $this.OpenActionLog()
            }
            "B" { 
                Write-Host "Opening File Browser..." -ForegroundColor White -BackgroundColor DarkRed
                Start-Sleep -Milliseconds 500
                $this.OpenFileBrowser()
            }
        }
        
        # Clear feedback after action
        [Console]::SetCursorPosition(0, $feedbackY)
        Write-Host (" " * $this.Width) -NoNewline
    }
    
    [void] OpenProjectSettings() {
        try {
            $dialog = [ProjectSettingsDialog]::new()
            $result = $dialog.Show($this.ParentTask)
            
            if ($result) {
                # Task was modified, update via service
                $this.TaskService.UpdateTask($this.ParentTask)
                
                # Show success message
                [Console]::SetCursorPosition(0, $this.Height - 3)
                Write-Host "Project settings saved successfully!" -ForegroundColor Green
                Start-Sleep -Milliseconds 1000
            }
        } catch {
            [Console]::SetCursorPosition(0, $this.Height - 3) 
            Write-Host "Error opening project settings: $($_.Exception.Message)" -ForegroundColor Red
            Start-Sleep -Milliseconds 2000
        }
    }
    
    [void] OpenT2020CallLog() {
        if ($this.ParentTask.T2020CallLogFile -and $this.ParentTask.T2020CallLogFile.Trim() -ne "") {
            $this.EditExternalFile($this.ParentTask.T2020CallLogFile, "T2020 CALL LOG", $false)
        } else {
            [Console]::SetCursorPosition(0, $this.Height - 3)
            Write-Host "No T2020 call log file configured. Use Settings (S) to configure." -ForegroundColor Yellow
            Start-Sleep -Milliseconds 2000  # Show message for 2 seconds instead of waiting for key
        }
    }
    
    [void] OpenProjectFolder() {
        if ($this.ParentTask.ProjectFolderPath -and (Test-Path $this.ParentTask.ProjectFolderPath)) {
            try {
                if ($env:OS -eq "Windows_NT" -or [System.Environment]::OSVersion.Platform -eq "Win32NT") {
                    Start-Process explorer.exe -ArgumentList $this.ParentTask.ProjectFolderPath
                    [Console]::SetCursorPosition(0, $this.Height - 3)
                    Write-Host "Project folder opened in Explorer" -ForegroundColor Green
                    Start-Sleep -Milliseconds 1000
                } else {
                    # Linux/Mac
                    if (Get-Command xdg-open -ErrorAction SilentlyContinue) {
                        Start-Process xdg-open -ArgumentList $this.ParentTask.ProjectFolderPath
                        [Console]::SetCursorPosition(0, $this.Height - 3)
                        Write-Host "Project folder opened" -ForegroundColor Green
                        Start-Sleep -Milliseconds 1000
                    } else {
                        [Console]::SetCursorPosition(0, $this.Height - 3)
                        Write-Host "Project folder: $($this.ParentTask.ProjectFolderPath)" -ForegroundColor Yellow
                        Start-Sleep -Milliseconds 2000
                    }
                }
            } catch {
                [Console]::SetCursorPosition(0, $this.Height - 3)
                Write-Host "Error opening folder: $($_.Exception.Message)" -ForegroundColor Red
                Start-Sleep -Milliseconds 2000
            }
        } else {
            [Console]::SetCursorPosition(0, $this.Height - 3)
            Write-Host "No project folder configured. Use Settings to configure." -ForegroundColor Yellow
            Start-Sleep -Milliseconds 2000
        }
    }
    
    [void] OpenExportDataFile() {
        if ($this.ParentTask.ExportDataFile -and (Test-Path $this.ParentTask.ExportDataFile)) {
            $this.EditExternalFile($this.ParentTask.ExportDataFile, "EXPORT DATA (READ-ONLY)", $true)
        } else {
            [Console]::SetCursorPosition(0, $this.Height - 3)
            Write-Host "No export data file configured or file not found" -ForegroundColor Yellow
            Start-Sleep -Milliseconds 2000
        }
    }
    
    [void] OpenActionLog() {
        if ($this.ParentTask.ProjectFolderPath) {
            $actionLogPath = Join-Path $this.ParentTask.ProjectFolderPath "$($this.ParentTask.ActionLogName).txt"
            
            # Create action log if it doesn't exist
            if (-not (Test-Path $actionLogPath)) {
                try {
                    $initialContent = "# Action Log for $($this.ParentTask.Title)`n# Created: $(Get-Date)`n`n"
                    [System.IO.File]::WriteAllText($actionLogPath, $initialContent)
                    [Console]::SetCursorPosition(0, $this.Height - 3)
                    Write-Host "Action log created: $actionLogPath" -ForegroundColor Green
                    Start-Sleep -Milliseconds 1000
                } catch {
                    [Console]::SetCursorPosition(0, $this.Height - 3)
                    Write-Host "Could not create action log file: $($_.Exception.Message)" -ForegroundColor Red
                    Start-Sleep -Milliseconds 2000
                    return
                }
            }
            
            $this.EditExternalFile($actionLogPath, "ACTION LOG", $false)
        } else {
            [Console]::SetCursorPosition(0, $this.Height - 3)
            Write-Host "No project folder configured. Use Settings to configure." -ForegroundColor Yellow
            Start-Sleep -Milliseconds 2000
        }
    }
    
    [void] OpenFileBrowser() {
        $startFolder = if ($this.ParentTask.ProjectFolderPath) { $this.ParentTask.ProjectFolderPath } else { [System.IO.Directory]::GetCurrentDirectory() }
        
        [Console]::SetCursorPosition(0, $this.Height - 3)
        Write-Host "File Browser: $startFolder" -ForegroundColor Yellow
        Start-Sleep -Milliseconds 2000
    }
    
    # External file editor integration
    [void] EditExternalFile([string]$filePath, [string]$title, [bool]$readOnly) {
        try {
            # Validate file path first
            if ([string]::IsNullOrWhiteSpace($filePath)) {
                [Console]::SetCursorPosition(0, $this.Height - 3)
                Write-Host "Error: No file path specified" -ForegroundColor Red
                Start-Sleep -Milliseconds 2000
                return
            }
            
            # Check if file exists and is readable
            if (-not (Test-Path $filePath -PathType Leaf)) {
                [Console]::SetCursorPosition(0, $this.Height - 3)
                Write-Host "Error: File not found: $filePath" -ForegroundColor Red
                Start-Sleep -Milliseconds 2000
                return
            }
            
            # Use the existing FullNotesEditor for external files
            $editor = [FullNotesEditor]::new()
            $editor.SetBounds(0, 2, [Console]::WindowWidth, [Console]::WindowHeight - 3)
            
            # Load file content with better error handling
            $content = ""
            try {
                $content = [System.IO.File]::ReadAllText($filePath)
            } catch {
                [Console]::SetCursorPosition(0, $this.Height - 3)
                Write-Host "Error reading file: $($_.Exception.Message)" -ForegroundColor Red
                Start-Sleep -Milliseconds 2000
                return
            }
            
            $editor.SetText($content)
            
            # Show editor with title
            [Console]::Clear()
            [Console]::SetCursorPosition(0, 0)
            $titleColor = if ($readOnly) { [ConsoleColor]::Red } else { [ConsoleColor]::Cyan }
            Write-Host "$title - $([System.IO.Path]::GetFileName($filePath))" -ForegroundColor $titleColor
            
            if ($readOnly) {
                Write-Host "READ-ONLY MODE - Press 'E' to edit in external editor, ESC to return" -ForegroundColor Yellow
            } else {
                Write-Host "F2:Save  ESC:Return without saving" -ForegroundColor Yellow
            }
            
            # Edit loop
            while ($true) {
                Write-Host -NoNewline $editor.Render()
                
                $key = [Console]::ReadKey($true)
                
                if ($key.Key -eq [System.ConsoleKey]::Escape) {
                    break
                } elseif ($key.Key -eq [System.ConsoleKey]::F2 -and -not $readOnly) {
                    # Save file
                    try {
                        $newContent = $editor.GetText()
                        [System.IO.File]::WriteAllText($filePath, $newContent)
                        [Console]::SetCursorPosition(0, 1)
                        Write-Host "File saved successfully!" -ForegroundColor Green
                        Start-Sleep -Milliseconds 1000
                        break
                    } catch {
                        [Console]::SetCursorPosition(0, 1)
                        Write-Host "Error saving file: $($_.Exception.Message)" -ForegroundColor Red
                        Start-Sleep -Milliseconds 2000
                    }
                } elseif ($key.KeyChar -eq 'E' -or $key.KeyChar -eq 'e') {
                    # Open in external editor (like notepad)
                    try {
                        if ($env:OS -eq "Windows_NT" -or [System.Environment]::OSVersion.Platform -eq "Win32NT") {
                            Start-Process notepad.exe -ArgumentList $filePath
                        } else {
                            # Linux/Mac - try common editors
                            $editors = @("nano", "vim", "gedit", "kate")
                            foreach ($editorCmd in $editors) {
                                if (Get-Command $editorCmd -ErrorAction SilentlyContinue) {
                                    Start-Process $editorCmd -ArgumentList $filePath
                                    break
                                }
                            }
                        }
                        break
                    } catch {
                        [Console]::SetCursorPosition(0, 1)
                        Write-Host "Error opening external editor: $($_.Exception.Message)" -ForegroundColor Red
                        Start-Sleep -Milliseconds 2000
                    }
                } else {
                    # Handle editor input
                    if (-not $readOnly) {
                        $editor.HandleInput($key)
                    }
                }
            }
        } catch {
            [Console]::SetCursorPosition(0, $this.Height - 3)
            Write-Host "Error editing file: $($_.Exception.Message)" -ForegroundColor Red
            Start-Sleep -Milliseconds 2000
        }
    }
}