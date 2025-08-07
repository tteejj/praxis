# ProjectSettingsDialog.ps1 - Advanced project configuration with integrated file browser

class ProjectSettingsDialog {
    [SimpleTask]$Task
    [string]$OriginalTitle
    
    # Form fields
    [string]$ProjectFolder = ""
    [string]$T2020File = ""
    [string]$ExportFile = ""
    [string]$ActionLogName = ""
    [string]$ID1 = ""
    [string]$ID2 = ""
    
    # Navigation and display
    [int]$SelectedField = 0
    [string[]]$FieldNames = @("ProjectFolder", "T2020File", "ExportFile", "ActionLogName", "ID1", "ID2", "Save", "Cancel")
    [string[]]$FieldLabels = @("Project Folder", "T2020 Call Log", "Export Data File", "Action Log Name", "Project Code (3)", "Project ID (12)", "Save", "Cancel")
    
    # File browser state
    [bool]$ShowingBrowser = $false
    [string]$BrowserMode = ""  # "folder", "file"
    [string]$CurrentPath = ""
    [string[]]$DirectoryListing = @()
    [int]$BrowserSelectedIndex = 0
    [int]$BrowserScrollTop = 0
    [int]$BrowserOriginField = -1  # Track which field started the browser
    
    # Colors - same approach as TaskListScreen
    [string]$HeaderColor = "`e[38;2;100;150;255m"    # Modern blue
    [string]$FieldColor = "`e[38;2;255;215;0m"      # Yellow
    [string]$ValueColor = "`e[38;2;250;248;240m"     # White
    [string]$ButtonColor = "`e[38;2;80;200;120m"     # Green
    [string]$SelectedBg = "`e[48;2;255;215;0;30m"    # Yellow bg, black text
    [string]$BrowserColor = "`e[38;2;180;180;180m"   # Gray
    [string]$BrowserSelectedBg = "`e[48;2;45;45;55;37m" # Blue bg, white text
    [string]$NormalColor = "`e[0m"                   # Reset
    
    [bool] Show([SimpleTask]$task) {
        $this.Task = $task
        $this.OriginalTitle = $task.Title
        
        # Initialize fields from task
        $this.ProjectFolder = $task.ProjectFolderPath
        $this.T2020File = $task.T2020CallLogFile
        $this.ExportFile = $task.ExportDataFile
        $this.ActionLogName = if ($task.ActionLogName) { $task.ActionLogName } else { "action-log" }
        $this.ID1 = $task.ID1
        $this.ID2 = $task.ID2
        
        # Set initial browser path - don't override existing paths
        if (-not $this.CurrentPath -or $this.CurrentPath -eq "") {
            $this.CurrentPath = if ($this.ProjectFolder -and (Test-Path $this.ProjectFolder)) { 
                $this.ProjectFolder 
            } else { 
                [System.IO.Directory]::GetCurrentDirectory() 
            }
        }
        
        try {
            [Console]::CursorVisible = $false
            
            # Set up Ctrl+C handler for auto-save
            $previousHandler = $null
            try {
                $previousHandler = [Console]::TreatControlCAsInput
                [Console]::TreatControlCAsInput = $true
            } catch {
                # If we can't set it, continue anyway
            }
            
            while ($true) {
                # Render without flicker using StringBuilder approach
                if ($this.ShowingBrowser) {
                    Write-Host -NoNewline $this.RenderBrowser()
                } else {
                    Write-Host -NoNewline $this.RenderSettings()
                }
                
                $key = [Console]::ReadKey($true)
                $result = $this.HandleInput($key)
                
                if ($result -eq "SAVE") {
                    if ($this.ValidateAndSave()) {
                        return $true
                    }
                } elseif ($result -eq "CANCEL") {
                    # Auto-save before cancel
                    $this.ValidateAndSave()
                    return $false
                } elseif ($result -eq "FORCE_EXIT") {
                    # Auto-save and exit immediately
                    $this.ValidateAndSave()
                    return $false
                }
            }
            return $false  # Should never reach here due to infinite loop
        } catch {
            # Auto-save on any exception before showing error
            try {
                $this.ValidateAndSave()
            } catch {
                # If save fails, at least we tried
            }
            
            # Use VT100 for error display to avoid flicker
            Write-Host -NoNewline ([VT]::Clear())
            Write-Host -NoNewline ([VT]::MoveTo(0, 0))
            Write-Host "Dialog error: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host "Press any key to continue..." -ForegroundColor Yellow
            [Console]::ReadKey($true) | Out-Null
            return $false
        } finally {
            # Auto-save before exit
            try {
                $this.ValidateAndSave()
            } catch {
                # If save fails, at least we tried
            }
            
            [Console]::CursorVisible = $true
            
            # Restore previous Ctrl+C handling
            try {
                if ($previousHandler -ne $null) {
                    [Console]::TreatControlCAsInput = $previousHandler
                }
            } catch {
                # Continue if we can't restore
            }
        }
    }
    
    [string] RenderSettings() {
        $sb = [System.Text.StringBuilder]::new()
        
        # Clear screen and position cursor
        [void]$sb.Append([VT]::Clear())
        [void]$sb.Append([VT]::MoveTo(0, 0))
        
        # Header
        [void]$sb.Append($this.HeaderColor)
        [void]$sb.Append("PROJECT SETTINGS - $($this.OriginalTitle)")
        [void]$sb.Append($this.NormalColor)
        [void]$sb.Append([VT]::MoveTo(0, 1))
        [void]$sb.Append("─" * [Console]::WindowWidth)
        
        # Settings fields
        $y = 3
        for ($i = 0; $i -lt 6; $i++) {
            [void]$sb.Append([VT]::MoveTo(2, $y))
            
            $fieldValue = $this.GetFieldValue($i)
            $displayValue = if ($fieldValue.Length -gt 60) { $fieldValue.Substring(0, 57) + "..." } else { $fieldValue }
            
            if ($this.SelectedField -eq $i) {
                [void]$sb.Append($this.SelectedBg)
                [void]$sb.Append("■ $($this.FieldLabels[$i])")
                [void]$sb.Append((" " * (30 - $this.FieldLabels[$i].Length)))
                [void]$sb.Append($displayValue)
                [void]$sb.Append($this.NormalColor)
            } else {
                [void]$sb.Append($this.FieldColor)
                [void]$sb.Append("  $($this.FieldLabels[$i])")
                [void]$sb.Append($this.ValueColor)
                [void]$sb.Append((" " * (30 - $this.FieldLabels[$i].Length)))
                [void]$sb.Append($displayValue)
                [void]$sb.Append($this.NormalColor)
            }
            $y += 2
        }
        
        # Buttons
        $y += 2
        [void]$sb.Append([VT]::MoveTo(2, $y))
        if ($this.SelectedField -eq 6) {
            [void]$sb.Append($this.SelectedBg)
            [void]$sb.Append("■ [Save]")
            [void]$sb.Append($this.NormalColor)
        } else {
            [void]$sb.Append($this.ButtonColor)
            [void]$sb.Append("  [Save]")
            [void]$sb.Append($this.NormalColor)
        }
        
        [void]$sb.Append([VT]::MoveTo(20, $y))
        if ($this.SelectedField -eq 7) {
            [void]$sb.Append($this.SelectedBg)
            [void]$sb.Append("■ [Cancel]")
            [void]$sb.Append($this.NormalColor)
        } else {
            [void]$sb.Append($this.ButtonColor)
            [void]$sb.Append("  [Cancel]")
            [void]$sb.Append($this.NormalColor)
        }
        
        # Instructions
        [void]$sb.Append([VT]::MoveTo(0, [Console]::WindowHeight - 2))
        [void]$sb.Append($this.BrowserColor)
        [void]$sb.Append("↑↓:Navigate  B:Browse  ENTER:Edit  F2:Save  ESC:Cancel")
        [void]$sb.Append($this.NormalColor)
        
        return $sb.ToString()
    }
    
    [string] RenderBrowser() {
        $sb = [System.Text.StringBuilder]::new()
        
        # Clear and header
        [void]$sb.Append([VT]::Clear())
        [void]$sb.Append([VT]::MoveTo(0, 0))
        [void]$sb.Append($this.HeaderColor)
        $modeText = if ($this.BrowserMode -eq "folder") { "SELECT FOLDER" } else { "SELECT FILE" }
        [void]$sb.Append("$modeText - $($this.OriginalTitle)")
        [void]$sb.Append($this.NormalColor)
        [void]$sb.Append([VT]::MoveTo(0, 1))
        [void]$sb.Append("─" * [Console]::WindowWidth)
        
        # Current path
        [void]$sb.Append([VT]::MoveTo(0, 2))
        [void]$sb.Append($this.FieldColor)
        [void]$sb.Append("Current: ")
        [void]$sb.Append($this.ValueColor)
        [void]$sb.Append($this.CurrentPath)
        [void]$sb.Append($this.NormalColor)
        
        # Directory listing
        $startY = 4
        $maxVisible = [Console]::WindowHeight - 8
        $endIndex = [Math]::Min($this.BrowserScrollTop + $maxVisible, $this.DirectoryListing.Count)
        
        for ($i = $this.BrowserScrollTop; $i -lt $endIndex; $i++) {
            $y = $startY + ($i - $this.BrowserScrollTop)
            [void]$sb.Append([VT]::MoveTo(2, $y))
            
            $item = $this.DirectoryListing[$i]
            $isSelected = ($i -eq $this.BrowserSelectedIndex)
            
            if ($isSelected) {
                [void]$sb.Append($this.BrowserSelectedBg)
                [void]$sb.Append("■ $item")
                [void]$sb.Append($this.NormalColor)
            } else {
                $color = if ($item.EndsWith("/")) { $this.HeaderColor } else { $this.ValueColor }
                [void]$sb.Append($color)
                [void]$sb.Append("  $item")
                [void]$sb.Append($this.NormalColor)
            }
        }
        
        # Instructions
        [void]$sb.Append([VT]::MoveTo(0, [Console]::WindowHeight - 2))
        [void]$sb.Append($this.BrowserColor)
        if ($this.BrowserMode -eq "folder") {
            [void]$sb.Append("↑↓:Navigate  ENTER:Enter/Select  SPACE:Choose Current  ESC:Cancel")
        } else {
            [void]$sb.Append("↑↓:Navigate  ENTER:Enter/Select  SPACE:Choose Current  ESC:Cancel")
        }
        [void]$sb.Append($this.NormalColor)
        
        return $sb.ToString()
    }
    
    [string] HandleInput([System.ConsoleKeyInfo]$key) {
        if ($this.ShowingBrowser) {
            return $this.HandleBrowserInput($key)
        }
        
        # Handle Ctrl+C for force exit with save
        if ($key.Key -eq [System.ConsoleKey]::C -and $key.Modifiers -band [System.ConsoleModifiers]::Control) {
            return "FORCE_EXIT"
        }
        
        switch ($key.Key) {
            ([System.ConsoleKey]::Escape) { 
                return "CANCEL" 
            }
            ([System.ConsoleKey]::F4) {
                # Alt+F4 or just F4 - force exit with save
                return "FORCE_EXIT"
            }
            ([System.ConsoleKey]::Tab) {
                $this.SelectedField = ($this.SelectedField + 1) % $this.FieldNames.Count
            }
            ([System.ConsoleKey]::UpArrow) {
                $this.SelectedField = ($this.SelectedField - 1 + $this.FieldNames.Count) % $this.FieldNames.Count
            }
            ([System.ConsoleKey]::DownArrow) {
                $this.SelectedField = ($this.SelectedField + 1) % $this.FieldNames.Count
            }
            ([System.ConsoleKey]::Enter) {
                switch ($this.SelectedField) {
                    6 { return "SAVE" }
                    7 { return "CANCEL" }
                    default {
                        # For editable fields, handle text input
                        if ($this.SelectedField -ge 3 -and $this.SelectedField -le 5) {
                            # These are text input fields - don't browse
                        }
                    }
                }
            }
            
            # B key for browsing
            ([System.ConsoleKey]::B) {
                # Store which field we're browsing for BEFORE starting browser
                $this.BrowserOriginField = $this.SelectedField
                switch ($this.SelectedField) {
                    0 { $this.StartBrowseProjectFolder() }
                    1 { $this.StartBrowseT2020File() }
                    2 { $this.StartBrowseExportFile() }
                }
            }
            
            ([System.ConsoleKey]::F2) {
                # Quick save
                return "SAVE"
            }
            default {
                # Handle text input for editable fields
                if ($this.SelectedField -ge 3 -and $this.SelectedField -le 5) {
                    $this.HandleTextInput($key)
                }
            }
        }
        return "CONTINUE"
    }
    
    [void] HandleTextInput([System.ConsoleKeyInfo]$key) {
        $currentValue = ""
        $maxLength = 50
        
        switch ($this.SelectedField) {
            3 { 
                $currentValue = $this.ActionLogName
                $maxLength = 30
            }
            4 { 
                $currentValue = $this.ID1
                $maxLength = 3
            }
            5 { 
                $currentValue = $this.ID2
                $maxLength = 12
            }
        }
        
        if ($key.Key -eq [System.ConsoleKey]::Backspace) {
            if ($currentValue.Length -gt 0) {
                $currentValue = $currentValue.Substring(0, $currentValue.Length - 1)
            }
        } elseif (-not [char]::IsControl($key.KeyChar) -and $currentValue.Length -lt $maxLength) {
            $currentValue += $key.KeyChar
        }
        
        # Update the appropriate field
        switch ($this.SelectedField) {
            3 { $this.ActionLogName = $currentValue }
            4 { $this.ID1 = $currentValue.ToUpper() }
            5 { $this.ID2 = $currentValue.ToUpper() }
        }
    }
    
    # Integrated browser navigation methods
    [void] StartBrowseProjectFolder() {
        $this.ShowingBrowser = $true
        $this.BrowserMode = "folder"
        $this.LoadDirectoryListing($this.CurrentPath)
        $this.BrowserSelectedIndex = 0
        $this.BrowserScrollTop = 0
    }
    
    [void] StartBrowseT2020File() {
        $this.ShowingBrowser = $true
        $this.BrowserMode = "file"
        # Use existing T2020 path if available, otherwise use ProjectFolder
        $startPath = if ($this.T2020File -and (Test-Path (Split-Path $this.T2020File -Parent) -ErrorAction SilentlyContinue)) { 
            Split-Path $this.T2020File -Parent 
        } elseif ($this.ProjectFolder -and (Test-Path $this.ProjectFolder)) { 
            $this.ProjectFolder 
        } else { 
            $this.CurrentPath 
        }
        $this.LoadDirectoryListing($startPath)
        $this.BrowserSelectedIndex = 0
        $this.BrowserScrollTop = 0
    }
    
    [void] StartBrowseExportFile() {
        $this.ShowingBrowser = $true
        $this.BrowserMode = "file"
        # Use existing Export path if available, otherwise use ProjectFolder
        $startPath = if ($this.ExportFile -and (Test-Path (Split-Path $this.ExportFile -Parent) -ErrorAction SilentlyContinue)) { 
            Split-Path $this.ExportFile -Parent 
        } elseif ($this.ProjectFolder -and (Test-Path $this.ProjectFolder)) { 
            $this.ProjectFolder 
        } else { 
            $this.CurrentPath 
        }
        $this.LoadDirectoryListing($startPath)
        $this.BrowserSelectedIndex = 0
        $this.BrowserScrollTop = 0
    }
    
    [void] LoadDirectoryListing([string]$path) {
        try {
            $this.CurrentPath = $path
            $this.DirectoryListing = @()
            
            # Add parent directory option (unless at root)
            if ($path -ne [System.IO.Path]::GetPathRoot($path)) {
                $this.DirectoryListing += "../"
            }
            
            # Add directories first
            $directories = Get-ChildItem -Path $path -Directory -ErrorAction SilentlyContinue | Sort-Object Name
            foreach ($dir in $directories) {
                $this.DirectoryListing += "$($dir.Name)/"
            }
            
            # Add files if browsing for files
            if ($this.BrowserMode -eq "file") {
                $files = Get-ChildItem -Path $path -File -ErrorAction SilentlyContinue | Where-Object { $_.Extension -eq ".txt" -or $_.Extension -eq "" } | Sort-Object Name
                foreach ($file in $files) {
                    $this.DirectoryListing += $file.Name
                }
            }
        } catch {
            $this.DirectoryListing = @("Error: $($_.Exception.Message)")
        }
    }
    
    [string] HandleBrowserInput([System.ConsoleKeyInfo]$key) {
        switch ($key.Key) {
            ([System.ConsoleKey]::Escape) {
                $this.ShowingBrowser = $false
                return "CONTINUE"
            }
            
            ([System.ConsoleKey]::UpArrow) {
                if ($this.BrowserSelectedIndex -gt 0) {
                    $this.BrowserSelectedIndex--
                    # Adjust scroll if needed
                    if ($this.BrowserSelectedIndex -lt $this.BrowserScrollTop) {
                        $this.BrowserScrollTop = $this.BrowserSelectedIndex
                    }
                }
                return "CONTINUE"
            }
            
            ([System.ConsoleKey]::DownArrow) {
                if ($this.BrowserSelectedIndex -lt ($this.DirectoryListing.Count - 1)) {
                    $this.BrowserSelectedIndex++
                    # Adjust scroll if needed
                    $maxVisible = [Console]::WindowHeight - 8
                    if ($this.BrowserSelectedIndex -ge ($this.BrowserScrollTop + $maxVisible)) {
                        $this.BrowserScrollTop = $this.BrowserSelectedIndex - $maxVisible + 1
                    }
                }
                return "CONTINUE"
            }
            
            ([System.ConsoleKey]::Enter) {
                if ($this.DirectoryListing.Count -gt 0 -and $this.BrowserSelectedIndex -lt $this.DirectoryListing.Count) {
                    $selectedItem = $this.DirectoryListing[$this.BrowserSelectedIndex]
                    
                    if ($selectedItem -eq "../") {
                        # Go to parent directory
                        $parent = Split-Path -Parent $this.CurrentPath
                        if ($parent) {
                            $this.LoadDirectoryListing($parent)
                            $this.BrowserSelectedIndex = 0
                            $this.BrowserScrollTop = 0
                        }
                    } elseif ($selectedItem.EndsWith("/")) {
                        # Always enter directory for browsing - NEVER select with ENTER
                        $newPath = Join-Path $this.CurrentPath $selectedItem.TrimEnd("/")
                        $this.LoadDirectoryListing($newPath)
                        $this.BrowserSelectedIndex = 0
                        $this.BrowserScrollTop = 0
                    } else {
                        # Files can't be "entered" - do nothing, user must use SPACEBAR to select
                    }
                }
                return "CONTINUE"
            }
            
            ([System.ConsoleKey]::Spacebar) {
                # Select currently highlighted item (file or folder)
                if ($this.DirectoryListing.Count -gt 0 -and $this.BrowserSelectedIndex -lt $this.DirectoryListing.Count) {
                    $selectedItem = $this.DirectoryListing[$this.BrowserSelectedIndex]
                    if ($selectedItem -eq "../") {
                        # Select current folder if on parent directory option
                        $this.SelectBrowserItem("")
                    } elseif ($selectedItem.EndsWith("/")) {
                        # Select folder
                        $this.SelectBrowserItem($selectedItem.TrimEnd("/"))
                    } else {
                        # Select file
                        $this.SelectBrowserItem($selectedItem)
                    }
                } else {
                    # Fallback - select current path
                    $this.SelectBrowserItem("")
                }
                return "CONTINUE"
            }
        }
        return "CONTINUE"
    }
    
    [void] SelectBrowserItem([string]$item) {
        $fullPath = if ($item -ne "") { Join-Path $this.CurrentPath $item } else { $this.CurrentPath }
        
        # Set the value based on which field we started browsing from
        switch ($this.BrowserOriginField) {
            0 { $this.ProjectFolder = $fullPath }
            1 { $this.T2020File = $fullPath }
            2 { $this.ExportFile = $fullPath }
        }
        
        $this.ShowingBrowser = $false
    }
    
    [bool] ValidateAndSave() {
        # Keep ALL paths exactly as the user set them - don't clear anything!
        # The user knows what they want - just save it
        
        # Only validate Action Log Name for invalid characters
        if ($this.ActionLogName -ne "" -and ($this.ActionLogName.IndexOfAny([System.IO.Path]::GetInvalidFileNameChars()) -ge 0)) {
            # Clear invalid action log name
            $this.ActionLogName = "action-log"
        }
        
        # Save to task
        $this.Task.ProjectFolderPath = $this.ProjectFolder
        $this.Task.T2020CallLogFile = $this.T2020File
        $this.Task.ExportDataFile = $this.ExportFile
        $this.Task.ActionLogName = if ($this.ActionLogName -ne "") { $this.ActionLogName } else { "action-log" }
        $this.Task.ID1 = $this.ID1
        $this.Task.ID2 = $this.ID2
        
        return $true
    }
    
    [string] GetFieldValue([int]$fieldIndex) {
        switch ($fieldIndex) {
            0 { return $this.ProjectFolder }
            1 { return $this.T2020File }
            2 { return $this.ExportFile }
            3 { return $this.ActionLogName }
            4 { return $this.ID1 }
            5 { return $this.ID2 }
            default { return "" }
        }
        return ""  # Explicit return for all code paths
    }
}