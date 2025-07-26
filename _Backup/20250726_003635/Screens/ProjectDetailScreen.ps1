# ProjectDetailScreen - Detailed project view with time tracking information
# Redesigned to follow PRAXIS architecture standards using DockPanel and components

class ProjectDetailScreen : Screen {
    [Project]$Project = $null
    [System.Collections.ArrayList]$TimeEntries
    
    # PRAXIS Architecture Components
    [DockPanel]$MainLayout
    [ListBox]$ProjectInfoPanel
    [DataGrid]$WeeklySummaryGrid  
    [DataGrid]$TimeEntriesGrid
    
    # Services
    [ThemeManager]$ThemeManager
    [EventBus]$EventBus
    
    ProjectDetailScreen() : base() {
        $this.Title = "Project Details"
        $this.TimeEntries = [System.Collections.ArrayList]::new()
    }
    
    ProjectDetailScreen([Project]$project) : base() {
        $this.Title = "Project Details - $($project.Nickname)"
        $this.Project = $project
        $this.TimeEntries = [System.Collections.ArrayList]::new()
    }
    
    [void] OnInitialize() {
        # Get services through proper dependency injection
        $this.ThemeManager = $this.ServiceContainer.GetService('ThemeManager')
        $this.EventBus = $this.ServiceContainer.GetService('EventBus')
        
        # Load time entries if we have a project
        if ($this.Project) {
            $this.LoadTimeEntries()
        }
        
        # Create main DockPanel layout
        $this.MainLayout = [DockPanel]::new()
        $this.MainLayout.Initialize($this.ServiceContainer)
        $this.AddChild($this.MainLayout)
        
        # Create project info panel (top section)
        $this.CreateProjectInfoPanel()
        
        # Create weekly summary grid (middle section)
        $this.CreateWeeklySummaryGrid()
        
        # Create time entries grid (fill remaining space)
        $this.CreateTimeEntriesGrid()
        
        # Update title
        if ($this.Project) {
            $this.Title = "Project Details - $($this.Project.Nickname)"
        }
        
        # Populate data
        $this.PopulateProjectInfo()
        $this.PopulateWeeklySummary()
        $this.PopulateTimeEntries()
    }
    
    [void] CreateProjectInfoPanel() {
        $this.ProjectInfoPanel = [ListBox]::new()
        $this.ProjectInfoPanel.Initialize($this.ServiceContainer)
        $this.ProjectInfoPanel.ShowBorder = $true
        $this.ProjectInfoPanel.Title = "Project Information"
        $this.ProjectInfoPanel.IsFocusable = $false  # Read-only display
        
        # Dock to top with a specific height
        $this.MainLayout.SetChildDock($this.ProjectInfoPanel, [DockPosition]::Top)
        $this.MainLayout.SetChildHeight($this.ProjectInfoPanel, 35)  # Allow plenty of space for all fields
        $this.MainLayout.AddChild($this.ProjectInfoPanel)
    }
    
    [void] CreateWeeklySummaryGrid() {
        $this.WeeklySummaryGrid = [DataGrid]::new()
        $this.WeeklySummaryGrid.Initialize($this.ServiceContainer)
        $this.WeeklySummaryGrid.ShowHeader = $true
        $this.WeeklySummaryGrid.ShowBorder = $true
        $this.WeeklySummaryGrid.Title = "Weekly Hours Summary"
        $this.WeeklySummaryGrid.IsFocusable = $false  # Read-only display
        
        # Set up columns for weekly summary
        $columns = @(
            @{ Name = "WeekOf"; Header = "Week of"; Width = 12; Getter = { param($item) $item.WeekOf } }
            @{ Name = "Monday"; Header = "Mon"; Width = 7; Getter = { param($item) $item.Monday.ToString("F1") } }
            @{ Name = "Tuesday"; Header = "Tue"; Width = 7; Getter = { param($item) $item.Tuesday.ToString("F1") } }
            @{ Name = "Wednesday"; Header = "Wed"; Width = 7; Getter = { param($item) $item.Wednesday.ToString("F1") } }
            @{ Name = "Thursday"; Header = "Thu"; Width = 7; Getter = { param($item) $item.Thursday.ToString("F1") } }
            @{ Name = "Friday"; Header = "Fri"; Width = 7; Getter = { param($item) $item.Friday.ToString("F1") } }
            @{ Name = "Total"; Header = "Total"; Width = 8; Getter = { param($item) $item.Total.ToString("F1") } }
        )
        $this.WeeklySummaryGrid.SetColumns($columns)
        
        # Dock to top (after project info) with a specific height
        $this.MainLayout.SetChildDock($this.WeeklySummaryGrid, [DockPosition]::Top)
        $this.MainLayout.SetChildHeight($this.WeeklySummaryGrid, 8)  # Weekly summary doesn't need much space
        $this.MainLayout.AddChild($this.WeeklySummaryGrid)
    }
    
    [void] CreateTimeEntriesGrid() {
        $this.TimeEntriesGrid = [DataGrid]::new()
        $this.TimeEntriesGrid.Initialize($this.ServiceContainer)
        $this.TimeEntriesGrid.ShowHeader = $true
        $this.TimeEntriesGrid.ShowBorder = $true
        $this.TimeEntriesGrid.Title = "Time Entries - [A]dd [E]dit [D]elete [R]efresh"
        $this.TimeEntriesGrid.IsFocusable = $true  # Interactive
        
        # Set up columns for time entries
        $screen = $this  # Capture reference for closure
        $columns = @(
            @{ Name = "Date"; Header = "Date"; Width = 12; Getter = { param($item) $screen.FormatDate($item.Date) }.GetNewClosure() }
            @{ Name = "Hours"; Header = "Hours"; Width = 8; Getter = { param($item) [double]::Parse($item.Total).ToString("F2") } }
            @{ Name = "Description"; Header = "Description"; Width = 40; Getter = { param($item) if ($item.Description) { $item.Description } else { "No description" } } }
        )
        $this.TimeEntriesGrid.SetColumns($columns)
        
        # Set up selection changed handler
        $screen = $this  # Capture reference for closure
        $this.TimeEntriesGrid.OnSelectionChanged = {
            # Handle selection changes if needed
        }.GetNewClosure()
        
        # Fill remaining space
        $this.MainLayout.SetChildDock($this.TimeEntriesGrid, [DockPosition]::Fill)
        $this.MainLayout.AddChild($this.TimeEntriesGrid)
    }
    
    [void] OnActivated() {
        ([Screen]$this).OnActivated()
        # Focus the time entries grid which is the main interactive component
        if ($this.TimeEntriesGrid) {
            $this.TimeEntriesGrid.Focus()
        }
    }
    
    [void] OnBoundsChanged() {
        # DockPanel handles layout automatically
        if ($this.MainLayout) {
            $this.MainLayout.SetBounds($this.X, $this.Y, $this.Width, $this.Height)
        }
    }
    
    [void] LoadTimeEntries() {
        # This would load time entries from the tracker system
        # For now, creating sample data based on the tracker.txt structure
        $this.TimeEntries.Clear()
        
        # Sample time entries (in production, this would load from actual data)
        $sampleEntries = @(
            @{
                Date = "20241201"
                Nickname = $this.Project.Nickname
                ID1 = "CLIENT1"
                ID2 = "V000123456S"
                MonHours = "8.00"
                TueHours = ""
                WedHours = ""
                ThuHours = ""
                FriHours = ""
                Total = "8.00"
                Description = "Initial project setup and requirements gathering"
            },
            @{
                Date = "20241202"
                Nickname = $this.Project.Nickname
                ID1 = "CLIENT1"
                ID2 = "V000123456S"
                MonHours = ""
                TueHours = "6.50"
                WedHours = ""
                ThuHours = ""
                FriHours = ""
                Total = "6.50"
                Description = "Development work on core features"
            },
            @{
                Date = "20241203"
                Nickname = $this.Project.Nickname
                ID1 = "CLIENT1"
                ID2 = "V000123456S"
                MonHours = ""
                TueHours = ""
                WedHours = "7.25"
                ThuHours = ""
                FriHours = ""
                Total = "7.25"
                Description = "Testing and bug fixes"
            }
        )
        
        foreach ($entry in $sampleEntries) {
            $this.TimeEntries.Add([PSCustomObject]$entry) | Out-Null
        }
    }
    
    [void] PopulateProjectInfo() {
        if (-not $this.Project -or -not $this.ProjectInfoPanel) {
            return
        }
        
        if ($global:Logger) {
            $global:Logger.Debug("ProjectDetailScreen.PopulateProjectInfo: Project type = $($this.Project.GetType().Name)")
            $global:Logger.Debug("ProjectDetailScreen.PopulateProjectInfo: AuditType = '$($this.Project.AuditType)'")
            $global:Logger.Debug("ProjectDetailScreen.PopulateProjectInfo: ClientID = '$($this.Project.ClientID)'")
        }
        
        $infoItems = [System.Collections.ArrayList]::new()
        
        # === BASIC PROJECT INFORMATION ===
        $infoItems.Add("=== PROJECT IDENTIFICATION ===") | Out-Null
        $infoItems.Add("Nickname: $($this.Project.Nickname)") | Out-Null
        $infoItems.Add("Full Name: $($this.Project.FullProjectName)") | Out-Null
        
        if ($global:Logger) {
            $global:Logger.Debug("ProjectDetailScreen: Showing $($infoItems.Count) items so far")
        }
        
        # IDs
        if ($this.Project.ID1) {
            $infoItems.Add("Client Code (ID1): $($this.Project.ID1)") | Out-Null
        }
        if ($this.Project.ID2) {
            $infoItems.Add("CAS Case# (ID2): $($this.Project.ID2)") | Out-Null
        }
        if ($this.Project.ClientID) {
            $infoItems.Add("Client ID: $($this.Project.ClientID)") | Out-Null
        }
        
        # === AUDIT INFORMATION ===
        $infoItems.Add("") | Out-Null
        $infoItems.Add("=== AUDIT INFORMATION ===") | Out-Null
        if ($this.Project.AuditType) {
            $infoItems.Add("Audit Type: $($this.Project.AuditType)") | Out-Null
        }
        if ($this.Project.AuditProgram) {
            $infoItems.Add("Audit Program: $($this.Project.AuditProgram)") | Out-Null
        }
        if ($this.Project.AuditCase) {
            $infoItems.Add("Audit Case: $($this.Project.AuditCase)") | Out-Null
        }
        
        # Audit Dates
        if ($this.Project.AuditStartDate -and $this.Project.AuditStartDate -ne [DateTime]::MinValue) {
            $infoItems.Add("Audit Start Date: $($this.FormatDate($this.Project.AuditStartDate))") | Out-Null
        }
        if ($this.Project.AuditPeriodFrom -and $this.Project.AuditPeriodFrom -ne [DateTime]::MinValue) {
            $infoItems.Add("Audit Period From: $($this.FormatDate($this.Project.AuditPeriodFrom))") | Out-Null
        }
        if ($this.Project.AuditPeriodTo -and $this.Project.AuditPeriodTo -ne [DateTime]::MinValue) {
            $infoItems.Add("Audit Period To: $($this.FormatDate($this.Project.AuditPeriodTo))") | Out-Null
        }
        
        # Additional Audit Periods
        $hasAuditPeriods = $false
        for ($i = 1; $i -le 5; $i++) {
            $startProp = "AuditPeriod${i}Start"
            $endProp = "AuditPeriod${i}End"
            if ($this.Project.$startProp -ne [DateTime]::MinValue -or $this.Project.$endProp -ne [DateTime]::MinValue) {
                if (-not $hasAuditPeriods) {
                    $infoItems.Add("Additional Audit Periods:") | Out-Null
                    $hasAuditPeriods = $true
                }
                $start = if ($this.Project.$startProp -ne [DateTime]::MinValue) { $this.FormatDate($this.Project.$startProp) } else { "N/A" }
                $end = if ($this.Project.$endProp -ne [DateTime]::MinValue) { $this.FormatDate($this.Project.$endProp) } else { "N/A" }
                $infoItems.Add("  Period ${i}: $start to $end") | Out-Null
            }
        }
        
        # === PROJECT DATES ===
        $infoItems.Add("") | Out-Null
        $infoItems.Add("=== PROJECT DATES ===") | Out-Null
        if ($this.Project.RequestDate -and $this.Project.RequestDate -ne [DateTime]::MinValue) {
            $infoItems.Add("Data Requested: $($this.FormatDate($this.Project.RequestDate))") | Out-Null
        }
        if ($this.Project.DateAssigned) {
            $infoItems.Add("Date Assigned: $($this.FormatDate($this.Project.DateAssigned))") | Out-Null
        }
        if ($this.Project.BFDate -and $this.Project.BFDate -ne [DateTime]::MinValue) {
            $infoItems.Add("BF Date: $($this.FormatDate($this.Project.BFDate))") | Out-Null
        }
        if ($this.Project.DateDue) {
            $infoItems.Add("Due Date: $($this.FormatDate($this.Project.DateDue))") | Out-Null
        }
        if ($this.Project.ClosedDate -and $this.Project.ClosedDate -ne [DateTime]::MinValue) {
            $infoItems.Add("Completed: $($this.FormatDate($this.Project.ClosedDate))") | Out-Null
        }
        
        # === CLIENT LOCATION ===
        $infoItems.Add("") | Out-Null
        $infoItems.Add("=== CLIENT LOCATION ===") | Out-Null
        if ($this.Project.Address) {
            $infoItems.Add("Address: $($this.Project.Address)") | Out-Null
        }
        if ($this.Project.City -or $this.Project.Province -or $this.Project.PostalCode) {
            $location = @()
            if ($this.Project.City) { $location += $this.Project.City }
            if ($this.Project.Province) { $location += $this.Project.Province }
            if ($this.Project.PostalCode) { $location += $this.Project.PostalCode }
            $infoItems.Add("City/Prov/Postal: $($location -join ', ')") | Out-Null
        }
        if ($this.Project.Country) {
            $infoItems.Add("Country: $($this.Project.Country)") | Out-Null
        }
        if ($this.Project.ShipToAddress) {
            $infoItems.Add("Ship To Address: $($this.Project.ShipToAddress)") | Out-Null
        }
        
        # === AUDITOR INFORMATION ===
        $infoItems.Add("") | Out-Null
        $infoItems.Add("=== AUDITOR INFORMATION ===") | Out-Null
        if ($this.Project.AuditorName) {
            $infoItems.Add("Auditor: $($this.Project.AuditorName)") | Out-Null
        }
        if ($this.Project.AuditorPhone) {
            $infoItems.Add("Auditor Phone: $($this.Project.AuditorPhone)") | Out-Null
        }
        if ($this.Project.AuditorTL) {
            $infoItems.Add("Team Lead: $($this.Project.AuditorTL)") | Out-Null
        }
        if ($this.Project.AuditorTLPhone) {
            $infoItems.Add("Team Lead Phone: $($this.Project.AuditorTLPhone)") | Out-Null
        }
        
        # === CONTACT INFORMATION ===
        $infoItems.Add("") | Out-Null
        $infoItems.Add("=== CONTACT INFORMATION ===") | Out-Null
        # Contact 1
        if ($this.Project.Contact1Name) {
            $infoItems.Add("Contact 1:") | Out-Null
            $infoItems.Add("  Name: $($this.Project.Contact1Name)") | Out-Null
            if ($this.Project.Contact1Title) { $infoItems.Add("  Title: $($this.Project.Contact1Title)") | Out-Null }
            if ($this.Project.Contact1Phone) { 
                $phone = $this.Project.Contact1Phone
                if ($this.Project.Contact1Ext) { $phone += " x$($this.Project.Contact1Ext)" }
                $infoItems.Add("  Phone: $phone") | Out-Null 
            }
            if ($this.Project.Contact1Address) { $infoItems.Add("  Address: $($this.Project.Contact1Address)") | Out-Null }
        }
        # Contact 2
        if ($this.Project.Contact2Name) {
            $infoItems.Add("Contact 2:") | Out-Null
            $infoItems.Add("  Name: $($this.Project.Contact2Name)") | Out-Null
            if ($this.Project.Contact2Title) { $infoItems.Add("  Title: $($this.Project.Contact2Title)") | Out-Null }
            if ($this.Project.Contact2Phone) { 
                $phone = $this.Project.Contact2Phone
                if ($this.Project.Contact2Ext) { $phone += " x$($this.Project.Contact2Ext)" }
                $infoItems.Add("  Phone: $phone") | Out-Null 
            }
            if ($this.Project.Contact2Address) { $infoItems.Add("  Address: $($this.Project.Contact2Address)") | Out-Null }
        }
        
        # === SYSTEM INFORMATION ===
        $infoItems.Add("") | Out-Null
        $infoItems.Add("=== SYSTEM INFORMATION ===") | Out-Null
        if ($this.Project.AccountingSoftware1) {
            $sw1 = $this.Project.AccountingSoftware1
            if ($this.Project.AccountingSoftware1Other) { $sw1 += " ($($this.Project.AccountingSoftware1Other))" }
            if ($this.Project.AccountingSoftware1Type) { $sw1 += " - $($this.Project.AccountingSoftware1Type)" }
            $infoItems.Add("Accounting Software 1: $sw1") | Out-Null
        }
        if ($this.Project.AccountingSoftware2) {
            $sw2 = $this.Project.AccountingSoftware2
            if ($this.Project.AccountingSoftware2Other) { $sw2 += " ($($this.Project.AccountingSoftware2Other))" }
            if ($this.Project.AccountingSoftware2Type) { $sw2 += " - $($this.Project.AccountingSoftware2Type)" }
            $infoItems.Add("Accounting Software 2: $sw2") | Out-Null
        }
        
        # === STATUS AND TOTALS ===
        $infoItems.Add("") | Out-Null
        $infoItems.Add("=== STATUS AND HOURS ===") | Out-Null
        $status = if ($this.Project.Status) { $this.Project.Status } else { "Active" }
        $infoItems.Add("Status: $status") | Out-Null
        
        # Show cumulative hours from Excel import
        if ($this.Project.CumulativeHrs -gt 0) {
            $infoItems.Add("Cumulative Hours (from import): $($this.Project.CumulativeHrs.ToString('F2'))") | Out-Null
        }
        
        $totalHours = $this.CalculateTotalHours()
        $infoItems.Add("Total Hours (tracked): $($totalHours.ToString('F2'))") | Out-Null
        
        # === FILE PATHS ===
        $infoItems.Add("") | Out-Null
        $infoItems.Add("=== FILE PATHS ===") | Out-Null
        if ($this.Project.CAAPath) {
            $infoItems.Add("CAA Path: $($this.Project.CAAPath)") | Out-Null
        }
        if ($this.Project.RequestPath) {
            $infoItems.Add("Request Path: $($this.Project.RequestPath)") | Out-Null
        }
        if ($this.Project.T2020Path) {
            $infoItems.Add("T2020 Path: $($this.Project.T2020Path)") | Out-Null
        }
        
        # === ADDITIONAL INFORMATION ===
        if ($this.Project.FXInfo -or $this.Project.Comments -or $this.Project.Note) {
            $infoItems.Add("") | Out-Null
            $infoItems.Add("=== ADDITIONAL INFORMATION ===") | Out-Null
            
            if ($this.Project.FXInfo) {
                $infoItems.Add("FX Info: $($this.Project.FXInfo)") | Out-Null
            }
            if ($this.Project.Comments) {
                $infoItems.Add("Comments: $($this.Project.Comments)") | Out-Null
            }
            if ($this.Project.Note) {
                $infoItems.Add("Notes: $($this.Project.Note)") | Out-Null
            }
        }
        
        $this.ProjectInfoPanel.SetItems($infoItems)
    }
    
    [void] PopulateWeeklySummary() {
        if (-not $this.WeeklySummaryGrid) {
            return
        }
        
        $weeklyData = $this.CalculateWeeklySummary()
        $this.WeeklySummaryGrid.SetItems($weeklyData)
    }
    
    [void] PopulateTimeEntries() {
        if (-not $this.TimeEntriesGrid) {
            return
        }
        
        # Sort entries by date (most recent first)
        $sortedEntries = $this.TimeEntries | Sort-Object { [DateTime]::ParseExact($_.Date, "yyyyMMdd", $null) } -Descending
        $this.TimeEntriesGrid.SetItems($sortedEntries)
    }
    
    [string] FormatDate([string]$dateStr) {
        if ([string]::IsNullOrEmpty($dateStr)) {
            return "Not set"
        }
        
        try {
            if ($dateStr.Length -eq 8) {
                # YYYYMMDD format
                $date = [DateTime]::ParseExact($dateStr, "yyyyMMdd", $null)
                return $date.ToString("MM/dd/yyyy")
            } else {
                # Try parsing as DateTime
                $date = [DateTime]::Parse($dateStr)
                return $date.ToString("MM/dd/yyyy")
            }
        } catch {
            return $dateStr
        }
    }
    
    [string] FormatDate([DateTime]$date) {
        if ($date -eq [DateTime]::MinValue) {
            return "Not set"
        }
        return $date.ToString("MM/dd/yyyy")
    }
    
    [double] CalculateTotalHours() {
        $total = 0.0
        foreach ($entry in $this.TimeEntries) {
            try {
                $hours = [double]::Parse($entry.Total)
                $total += $hours
            } catch {
                # Skip invalid entries
            }
        }
        return $total
    }
    
    [System.Collections.ArrayList] CalculateWeeklySummary() {
        $weeks = @{}
        
        foreach ($entry in $this.TimeEntries) {
            try {
                $entryDate = [DateTime]::ParseExact($entry.Date, "yyyyMMdd", $null)
                $monday = $entryDate.AddDays(-([int]$entryDate.DayOfWeek - 1))
                $weekKey = $monday.ToString("MM/dd/yyyy")
                
                if (-not $weeks.ContainsKey($weekKey)) {
                    $weeks[$weekKey] = @{
                        WeekOf = $weekKey
                        Monday = 0.0
                        Tuesday = 0.0
                        Wednesday = 0.0
                        Thursday = 0.0
                        Friday = 0.0
                        Total = 0.0
                    }
                }
                
                # Add hours to appropriate day
                $dayOfWeek = $entryDate.DayOfWeek.ToString()
                $hours = [double]::Parse($entry.Total)
                
                switch ($dayOfWeek) {
                    "Monday" { $weeks[$weekKey].Monday += $hours }
                    "Tuesday" { $weeks[$weekKey].Tuesday += $hours }
                    "Wednesday" { $weeks[$weekKey].Wednesday += $hours }
                    "Thursday" { $weeks[$weekKey].Thursday += $hours }
                    "Friday" { $weeks[$weekKey].Friday += $hours }
                }
                
                $weeks[$weekKey].Total += $hours
            } catch {
                # Skip invalid entries
            }
        }
        
        $weeklyData = [System.Collections.ArrayList]::new()
        foreach ($week in $weeks.Values) {
            $weeklyData.Add([PSCustomObject]$week) | Out-Null
        }
        
        # Sort by week date (most recent first) and ensure ArrayList type
        $sortedData = $weeklyData | Sort-Object { [DateTime]::Parse($_.WeekOf) } -Descending
        $result = [System.Collections.ArrayList]::new()
        foreach ($item in $sortedData) {
            $result.Add($item) | Out-Null
        }
        return $result
    }
    
    [void] AddTimeEntry() {
        if (-not $this.Project) {
            return
        }
        
        # Create time entry dialog
        $dialog = [TimeEntryDialog]::new($this.Project)
        
        # Set up callback for when entry is saved
        $screen = $this  # Capture reference for closure
        $dialog.OnSave = {
            param($timeEntryData)
            
            # Add to local time entries collection
            $screen.TimeEntries.Add($timeEntryData) | Out-Null
            
            # Refresh all displays
            $screen.PopulateTimeEntries()
            $screen.PopulateWeeklySummary()
            $screen.PopulateProjectInfo()  # Update total hours
            
            # Close dialog using proper service access
            $screenManager = $screen.ServiceContainer.GetService("ScreenManager")
            if ($screenManager) {
                $screenManager.Pop()
            }
        }.GetNewClosure()
        
        $dialog.OnCancel = {
            # Close dialog using proper service access
            $screenManager = $screen.ServiceContainer.GetService("ScreenManager")
            if ($screenManager) {
                $screenManager.Pop()
            }
        }.GetNewClosure()
        
        # Show dialog using proper service access
        $screenManager = $this.ServiceContainer.GetService("ScreenManager")
        if ($screenManager) {
            $screenManager.Push($dialog)
        }
    }
    
    [void] EditSelectedTimeEntry() {
        $selected = $this.TimeEntriesGrid.GetSelectedItem()
        if (-not $selected) {
            return
        }
        
        $this.EditTimeEntry($selected)
    }
    
    [void] EditTimeEntry([PSCustomObject]$timeEntry) {
        if (-not $this.Project -or -not $timeEntry) {
            return
        }
        
        # Create edit time entry dialog
        $dialog = [TimeEntryDialog]::new($this.Project, $timeEntry)
        
        # Set up callback for when entry is updated
        $screen = $this  # Capture reference for closure
        $dialog.OnSave = {
            param($timeEntryData)
            
            # Find and replace in local collection
            for ($i = 0; $i -lt $screen.TimeEntries.Count; $i++) {
                if ($screen.TimeEntries[$i].Date -eq $timeEntry.Date -and
                    $screen.TimeEntries[$i].Description -eq $timeEntry.Description) {
                    $screen.TimeEntries[$i] = $timeEntryData
                    break
                }
            }
            
            # Refresh all displays
            $screen.PopulateTimeEntries()
            $screen.PopulateWeeklySummary()
            $screen.PopulateProjectInfo()  # Update total hours
            
            # Close dialog using proper service access
            $screenManager = $screen.ServiceContainer.GetService("ScreenManager")
            if ($screenManager) {
                $screenManager.Pop()
            }
        }.GetNewClosure()
        
        $dialog.OnCancel = {
            # Close dialog using proper service access
            $screenManager = $screen.ServiceContainer.GetService("ScreenManager")
            if ($screenManager) {
                $screenManager.Pop()
            }
        }.GetNewClosure()
        
        # Show dialog using proper service access
        $screenManager = $this.ServiceContainer.GetService("ScreenManager")
        if ($screenManager) {
            $screenManager.Push($dialog)
        }
    }
    
    [void] DeleteSelectedTimeEntry() {
        $selected = $this.TimeEntriesGrid.GetSelectedItem()
        if (-not $selected) {
            return
        }
        
        $this.DeleteTimeEntry($selected)
    }
    
    [void] DeleteTimeEntry([PSCustomObject]$timeEntry) {
        if (-not $timeEntry) {
            return
        }
        
        # Show confirmation dialog
        $message = "Delete time entry for $($this.FormatDate($timeEntry.Date)) ($($timeEntry.Total) hours)?"
        $dialog = [ConfirmationDialog]::new($message)
        
        $screen = $this  # Capture reference for closure
        $dialog.OnConfirm = {
            # Remove from local collection
            for ($i = $screen.TimeEntries.Count - 1; $i -ge 0; $i--) {
                if ($screen.TimeEntries[$i].Date -eq $timeEntry.Date -and
                    $screen.TimeEntries[$i].Description -eq $timeEntry.Description) {
                    $screen.TimeEntries.RemoveAt($i)
                    break
                }
            }
            
            # Refresh all displays
            $screen.PopulateTimeEntries()
            $screen.PopulateWeeklySummary()
            $screen.PopulateProjectInfo()  # Update total hours
            
            # Close dialog using proper service access
            $screenManager = $screen.ServiceContainer.GetService("ScreenManager")
            if ($screenManager) {
                $screenManager.Pop()
            }
        }.GetNewClosure()
        
        $dialog.OnCancel = {
            # Close dialog using proper service access
            $screenManager = $screen.ServiceContainer.GetService("ScreenManager")
            if ($screenManager) {
                $screenManager.Pop()
            }
        }.GetNewClosure()
        
        # Show dialog using proper service access
        $screenManager = $this.ServiceContainer.GetService("ScreenManager")
        if ($screenManager) {
            $screenManager.Push($dialog)
        }
    }
    
    [void] RefreshData() {
        # Reload time entries
        $this.LoadTimeEntries()
        
        # Refresh all displays
        $this.PopulateProjectInfo()
        $this.PopulateWeeklySummary()
        $this.PopulateTimeEntries()
        
        # Focus the time entries grid
        if ($this.TimeEntriesGrid) {
            $this.TimeEntriesGrid.Focus()
        }
    }
    
    [bool] HandleScreenInput([System.ConsoleKeyInfo]$keyInfo) {
        # Handle character shortcuts
        if ($keyInfo.KeyChar) {
            switch ($keyInfo.KeyChar) {
                'r' {
                    # Refresh/reload data
                    $this.RefreshData()
                    return $true
                }
                'a' {
                    # Add new time entry
                    $this.AddTimeEntry()
                    return $true
                }
                'e' {
                    # Edit selected time entry
                    $this.EditSelectedTimeEntry()
                    return $true
                }
                'd' {
                    # Delete selected time entry
                    $this.DeleteSelectedTimeEntry()
                    return $true
                }
            }
        }
        
        # Handle ESC to go back
        if ($keyInfo.Key -eq [System.ConsoleKey]::Escape) {
            if ($global:ScreenManager) {
                $global:ScreenManager.Pop()
            }
            return $true
        }
        
        # Let base class handle other input (like tab switching and navigation)
        return $false
    }
}