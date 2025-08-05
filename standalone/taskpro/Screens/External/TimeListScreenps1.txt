# TimeListScreen.ps1 - Time entry list with inline editing (based on TaskListScreen)

class TimeListScreen {
    [TimeTrackingService]$TimeService
    [SimpleTimeEntry[]]$TimeEntries
    [System.Collections.Generic.List[object]]$FlatList  # Flattened list for navigation
    [int]$SelectedIndex = 0
    [int]$ScrollTop = 0
    [int]$Width
    [int]$Height
    
    # Inline editing state
    [int]$EditingIndex = -1
    [string]$EditingField = ""  # "project", "description", "monday", "tuesday", "wednesday", "thursday", "friday"
    [string]$EditingValue = ""
    [SimpleTimeEntry]$EditingEntry = $null
    [bool]$IsNewEntry = $false
    
    # Modern RGB Colors
    [string]$HeaderColor = "`e[38;2;100;150;255m"     # Modern blue
    [string]$HighColor = "`e[38;2;255;100;100m"       # Coral red
    [string]$MediumColor = "`e[38;2;255;165;0m"       # Orange
    [string]$LowColor = "`e[38;2;80;200;120m"         # Green
    [string]$ProjectColor = "`e[38;2;160;160;160m"    # Medium gray
    [string]$SelectedBg = "`e[48;2;45;45;55m"         # Dark background highlight
    [string]$EvenRowBg = "`e[48;2;25;25;30m"          # Subtle dark background
    [string]$TimeCodeColor = "`e[38;2;120;120;120m"   # Medium gray
    [string]$TagColor = "`e[38;2;180;180;180m"        # Light gray
    [string]$NormalColor = "`e[0m"                     # Reset
    [string]$EditHighlight = "`e[48;2;255;255;255;38;2;0;0;0m"  # White background, black text
    
    # Current day highlighting
    [string]$TodayColor = "`e[38;2;255;255;100m"       # Yellow for current day
    
    # Column widths for time entry layout
    [int]$ProjectCol = 15    # Project/Time Code
    [int]$DescCol = 30       # Description  
    [int]$MonCol = 8         # Monday
    [int]$TueCol = 8         # Tuesday
    [int]$WedCol = 8         # Wednesday
    [int]$ThuCol = 8         # Thursday
    [int]$FriCol = 8         # Friday
    [int]$TotalCol = 8       # Total
    
    # Pillbox characters
    [string]$PillboxTopLeft = "╭"
    [string]$PillboxTopRight = "╮"
    [string]$PillboxBottomLeft = "╰"
    [string]$PillboxBottomRight = "╯"
    [string]$PillboxHorizontal = "─"
    [string]$PillboxVertical = "│"
    
    TimeListScreen() {
        $this.TimeService = [TimeTrackingService]::new()
        $this.FlatList = [System.Collections.Generic.List[object]]::new()
        $this.LoadTimeEntries()
    }
    
    [void] Initialize([int]$width, [int]$height) {
        $this.Width = $width
        $this.Height = $height
    }
    
    [void] LoadTimeEntries() {
        $this.TimeEntries = $this.TimeService.GetCurrentWeekEntries()
        $this.BuildFlatList()
        
        if ($this.SelectedIndex -ge $this.FlatList.Count) {
            $this.SelectedIndex = [Math]::Max(0, $this.FlatList.Count - 1)
        }
    }
    
    [void] BuildFlatList() {
        $this.FlatList.Clear()
        
        foreach ($entry in $this.TimeEntries) {
            $this.FlatList.Add(@{
                Entry = $entry
                IsLast = $false
            })
        }
    }
    
    [int] GetItemHeight([int]$itemIndex) {
        # Dynamic height calculation for selected item based on content
        if ($itemIndex -eq $this.SelectedIndex) {
            $item = $this.FlatList[$itemIndex]
            return $this.CalculateDynamicHeight($item.Entry)
        } else {
            return 2  # Normal items: content line + empty line for spacing
        }
    }
    
    [int] CalculateDynamicHeight([SimpleTimeEntry]$entry) {
        $requiredLines = 2  # Base: top border + bottom border
        
        # Content analysis for TimeTracker
        if ($this.HasMainContent($entry)) { $requiredLines++ }
        if ($this.HasWeekDetails($entry)) { $requiredLines++ }
        if ($this.HasMetadata($entry)) { $requiredLines++ }
        
        # Spacer line only if we have content (efficiency)
        if ($requiredLines -gt 2) { $requiredLines++ }  # Add spacer
        
        return $requiredLines
    }
    
    [bool] HasMainContent([SimpleTimeEntry]$entry) {
        return -not [string]::IsNullOrWhiteSpace($entry.ProjectCode) -or -not [string]::IsNullOrWhiteSpace($entry.Description)
    }
    
    [bool] HasWeekDetails([SimpleTimeEntry]$entry) {
        # TimeTracker shows week breakdown if any day has hours
        return $entry.Monday -gt 0 -or $entry.Tuesday -gt 0 -or $entry.Wednesday -gt 0 -or $entry.Thursday -gt 0 -or $entry.Friday -gt 0
    }
    
    [bool] HasMetadata([SimpleTimeEntry]$entry) {
        # TimeTracker considers total hours and entry type as metadata
        return $entry.Total -gt 0 -or $entry.IsProjectEntry
    }
    
    [int] CalculatePillboxWidth([SimpleTimeEntry]$entry) {
        # Calculate minimum width needed for content
        $line1Length = $this.GetContentLength($entry)
        
        # Use content width plus borders and padding
        $contentWidth = $line1Length
        $pillboxWidth = $contentWidth + 3  # "│" + content + "│"
        
        # Ensure minimum width and don't exceed screen
        $minWidth = 60
        $maxWidth = $this.Width - 4
        
        return [Math]::Min($maxWidth, [Math]::Max($minWidth, $pillboxWidth))
    }
    
    [int] GetContentLength([SimpleTimeEntry]$entry) {
        $length = $this.ProjectCol + $this.DescCol + $this.MonCol + $this.TueCol + $this.WedCol + $this.ThuCol + $this.FriCol + $this.TotalCol
        return $length
    }
    
    [string] GetCurrentDayOfWeek() {
        $today = [DateTime]::Today.DayOfWeek
        $isCurrentWeek = $this.TimeService.IsCurrentWeek()
        
        if (-not $isCurrentWeek) {
            return ""
        }
        
        switch ($today) {
            ([DayOfWeek]::Monday) { return "monday" }
            ([DayOfWeek]::Tuesday) { return "tuesday" }
            ([DayOfWeek]::Wednesday) { return "wednesday" }
            ([DayOfWeek]::Thursday) { return "thursday" }
            ([DayOfWeek]::Friday) { return "friday" }
        }
        return ""
    }
    
    [string] Render() {
        $sb = [System.Text.StringBuilder]::new()
        
        # Clear screen
        [void]$sb.Append([VT]::Clear())
        
        # Header
        [void]$sb.Append([VT]::MoveTo(0, 0))
        [void]$sb.Append($this.HeaderColor)
        [void]$sb.Append("TIMETRACKER - Time Entry Manager")
        [void]$sb.Append($this.NormalColor)
        
        # Week display
        [void]$sb.Append([VT]::MoveTo(0, 1))
        [void]$sb.Append($this.TagColor)
        $weekText = $this.TimeService.GetWeekDisplayString()
        if ($this.TimeService.IsCurrentWeek()) {
            $weekText += " (Current Week)"
        }
        [void]$sb.Append($weekText)
        [void]$sb.Append($this.NormalColor)
        
        # Column headers
        [void]$sb.Append([VT]::MoveTo(0, 2))
        [void]$sb.Append($this.TagColor)
        
        $currentDay = $this.GetCurrentDayOfWeek()
        $monHeader = if ($currentDay -eq "monday") { "▸Mon" } else { "Mon" }
        $tueHeader = if ($currentDay -eq "tuesday") { "▸Tue" } else { "Tue" }
        $wedHeader = if ($currentDay -eq "wednesday") { "▸Wed" } else { "Wed" }
        $thuHeader = if ($currentDay -eq "thursday") { "▸Thu" } else { "Thu" }
        $friHeader = if ($currentDay -eq "friday") { "▸Fri" } else { "Fri" }
        
        [void]$sb.Append("Project".PadRight($this.ProjectCol))
        [void]$sb.Append("Description".PadRight($this.DescCol))
        [void]$sb.Append($monHeader.PadRight($this.MonCol))
        [void]$sb.Append($tueHeader.PadRight($this.TueCol))
        [void]$sb.Append($wedHeader.PadRight($this.WedCol))
        [void]$sb.Append($thuHeader.PadRight($this.ThuCol))
        [void]$sb.Append($friHeader.PadRight($this.FriCol))
        [void]$sb.Append("Total")
        [void]$sb.Append($this.NormalColor)
        
        [void]$sb.Append([VT]::MoveTo(0, 3))
        [void]$sb.Append("═" * $this.Width)
        
        # Time entry list
        $this.RenderTimeList($sb)
        
        # Week total and cumulative display
        $this.RenderTotals($sb)
        
        # Status bar
        [void]$sb.Append([VT]::MoveTo(0, $this.Height - 2))
        [void]$sb.Append("═" * $this.Width)
        
        [void]$sb.Append([VT]::MoveTo(0, $this.Height - 1))
        [void]$sb.Append($this.TagColor)
        if ($this.EditingIndex -ge 0) {
            [void]$sb.Append("EDITING [$($this.EditingField.ToUpper())]: Tab:Next Field  Enter:Save  Escape:Cancel")
        } else {
            [void]$sb.Append("↑↓:Navigate  E:Edit  A:Add  D:Delete  C:Current Week  ←→:Week Nav  Q:Quit")
        }
        [void]$sb.Append($this.NormalColor)
        
        # Show/hide cursor based on editing state and position it correctly
        if ($this.EditingIndex -ge 0) {
            [void]$sb.Append([VT]::ShowCursor())
            # Position cursor at the end of the editing field
            $this.PositionCursorForEditing($sb)
        } else {
            [void]$sb.Append([VT]::HideCursor())
        }
        
        return $sb.ToString()
    }
    
    [void] RenderTimeList([System.Text.StringBuilder]$sb) {
        $startY = 4
        $currentY = $startY
        $availableHeight = $this.Height - 6  # Header + status bar
        
        # Calculate how many items we can show with dynamic heights
        $visibleItems = @()
        $totalHeight = 0
        
        for ($i = $this.ScrollTop; $i -lt $this.FlatList.Count; $i++) {
            $itemHeight = $this.GetItemHeight($i)
            if ($totalHeight + $itemHeight -le $availableHeight) {
                $visibleItems += $i
                $totalHeight += $itemHeight
            } else {
                break
            }
        }
        
        # Render each visible item
        foreach ($i in $visibleItems) {
            $item = $this.FlatList[$i]
            $entry = $item.Entry
            $isSelected = ($i -eq $this.SelectedIndex)
            
            if ($isSelected) {
                # === SELECTED ITEM WITH DYNAMIC PILLBOX ===
                
                # Calculate optimal pillbox width and dynamic height
                $pillboxWidth = $this.CalculatePillboxWidth($entry)
                $pillboxHeight = $this.CalculateDynamicHeight($entry)
                $contentLines = $pillboxHeight - 2  # Subtract top and bottom borders
                
                # Calculate the fixed right border position
                $rightBorderColumn = $pillboxWidth
                
                # Spacer line above (only if we have content)
                if ($contentLines -gt 0) {
                    [void]$sb.Append([VT]::MoveTo(0, $currentY))
                    [void]$sb.Append(" " * $this.Width)
                    $currentY++
                }
                
                # Pillbox top
                $this.RenderPillboxTop($sb, $pillboxWidth, $currentY)
                $currentY++
                
                # Content-aware rendering - only render lines that have content
                $lineCount = 0
                
                # Main content line (project/description)
                if ($this.HasMainContent($entry)) {
                    [void]$sb.Append([VT]::MoveTo(0, $currentY))
                    [void]$sb.Append($this.HeaderColor + $this.PillboxVertical + $this.NormalColor)
                    # Add background highlighting within pillbox
                    [void]$sb.Append($this.SelectedBg)
                    $this.RenderTimeContent($sb, $entry, $false, $false)
                    [void]$sb.Append($this.NormalColor)
                    
                    # Move cursor to right border position
                    [void]$sb.Append([VT]::MoveTo($rightBorderColumn - 1, $currentY))
                    [void]$sb.Append($this.HeaderColor + $this.PillboxVertical + $this.NormalColor)
                    $currentY++
                    $lineCount++
                }
                
                # Week details line (daily breakdown)
                if ($this.HasWeekDetails($entry)) {
                    [void]$sb.Append([VT]::MoveTo(0, $currentY))
                    [void]$sb.Append($this.HeaderColor + $this.PillboxVertical + $this.NormalColor)
                    # Add background highlighting within pillbox
                    [void]$sb.Append($this.SelectedBg)
                    
                    # Render daily breakdown summary
                    [void]$sb.Append(" Details: ")
                    $dayDetails = @()
                    if ($entry.Monday -gt 0) { $dayDetails += "Mon: $($entry.Monday.ToString('F1'))" }
                    if ($entry.Tuesday -gt 0) { $dayDetails += "Tue: $($entry.Tuesday.ToString('F1'))" }
                    if ($entry.Wednesday -gt 0) { $dayDetails += "Wed: $($entry.Wednesday.ToString('F1'))" }
                    if ($entry.Thursday -gt 0) { $dayDetails += "Thu: $($entry.Thursday.ToString('F1'))" }
                    if ($entry.Friday -gt 0) { $dayDetails += "Fri: $($entry.Friday.ToString('F1'))" }
                    
                    [void]$sb.Append($this.LowColor + ($dayDetails -join ", ") + $this.NormalColor)
                    [void]$sb.Append($this.NormalColor)
                    
                    # Move cursor to right border position
                    [void]$sb.Append([VT]::MoveTo($rightBorderColumn - 1, $currentY))
                    [void]$sb.Append($this.HeaderColor + $this.PillboxVertical + $this.NormalColor)
                    $currentY++
                    $lineCount++
                }
                
                # Metadata line (entry type and cumulative info)
                if ($this.HasMetadata($entry)) {
                    [void]$sb.Append([VT]::MoveTo(0, $currentY))
                    [void]$sb.Append($this.HeaderColor + $this.PillboxVertical + $this.NormalColor)
                    # Add background highlighting within pillbox
                    [void]$sb.Append($this.SelectedBg)
                    
                    # Render metadata information
                    [void]$sb.Append(" Type: ")
                    if ($entry.IsProjectEntry) {
                        [void]$sb.Append($this.ProjectColor + "Project" + $this.NormalColor)
                        
                        # Show cumulative hours for project entries
                        if ($entry.ProjectCode -match '^\d{3}\s*/\s*\d+$') {
                            $cumulative = $this.TimeService.GetCumulativeHours($entry.ProjectCode)
                            if ($cumulative -gt 0) {
                                [void]$sb.Append(" | Cumulative: " + $this.HighColor + $cumulative.ToString('F1') + $this.NormalColor)
                            }
                        }
                    } else {
                        [void]$sb.Append($this.TimeCodeColor + "Time Code" + $this.NormalColor)
                    }
                    
                    if ($entry.Total -gt 0) {
                        [void]$sb.Append(" | Total: " + $this.HighColor + $entry.Total.ToString('F1') + "h" + $this.NormalColor)
                    }
                    [void]$sb.Append($this.NormalColor)
                    
                    # Move cursor to right border position
                    [void]$sb.Append([VT]::MoveTo($rightBorderColumn - 1, $currentY))
                    [void]$sb.Append($this.HeaderColor + $this.PillboxVertical + $this.NormalColor)
                    $currentY++
                    $lineCount++
                }
                
                # Pillbox bottom
                $this.RenderPillboxBottom($sb, $pillboxWidth, $currentY)
                $currentY++
                
            } else {
                # === NORMAL ITEM (1 line only) ===
                
                # Content line 1
                [void]$sb.Append([VT]::MoveTo(0, $currentY))
                $this.RenderTimeContent($sb, $entry, $true, $false)  # Don't skip description for normal entries
                $currentY++
                
                # Add empty line between entries for better readability
                [void]$sb.Append([VT]::MoveTo(0, $currentY))
                [void]$sb.Append([VT]::ClearLine())
                $currentY++
            }
        }
        
        # Clear remaining lines properly
        while ($currentY -lt ($this.Height - 2)) {
            [void]$sb.Append([VT]::MoveTo(0, $currentY))
            [void]$sb.Append([VT]::ClearLine())
            $currentY++
        }
    }
    
    [void] RenderPillboxTop([System.Text.StringBuilder]$sb, [int]$width, [int]$y) {
        [void]$sb.Append([VT]::MoveTo(0, $y))
        # Multi-color highlighting: corners use HeaderColor, horizontal uses TagColor
        [void]$sb.Append($this.HeaderColor + $this.PillboxTopLeft + $this.NormalColor)
        [void]$sb.Append($this.TagColor + ($this.PillboxHorizontal * ($width - 2)) + $this.NormalColor)
        [void]$sb.Append($this.HeaderColor + $this.PillboxTopRight + $this.NormalColor)
    }
    
    [void] RenderPillboxBottom([System.Text.StringBuilder]$sb, [int]$width, [int]$y) {
        [void]$sb.Append([VT]::MoveTo(0, $y))
        # Multi-color highlighting: corners use HeaderColor, horizontal uses TagColor
        [void]$sb.Append($this.HeaderColor + $this.PillboxBottomLeft + $this.NormalColor)
        [void]$sb.Append($this.TagColor + ($this.PillboxHorizontal * ($width - 2)) + $this.NormalColor)
        [void]$sb.Append($this.HeaderColor + $this.PillboxBottomRight + $this.NormalColor)
    }
    
    [void] RenderTimeContent([System.Text.StringBuilder]$sb, [SimpleTimeEntry]$entry, [bool]$clearToEnd, [bool]$skipDescription = $false) {
        $isEditingThis = ($this.EditingEntry -and $this.EditingEntry.Id -eq $entry.Id)
        
        # COLUMN 1: PROJECT/TIME CODE
        if ($isEditingThis -and $this.EditingField -eq "project") {
            [void]$sb.Append($this.EditHighlight + $this.EditingValue.PadRight($this.ProjectCol) + $this.NormalColor)
        } else {
            if ($entry.IsTimeCode()) {
                $color = $this.TimeCodeColor
            } else {
                $color = $this.ProjectColor
            }
            $projectCode = if ($entry.ProjectCode) { $entry.ProjectCode } else { "" }
            [void]$sb.Append($color + $projectCode.PadRight($this.ProjectCol) + $this.NormalColor)
        }
        
        # COLUMN 2: DESCRIPTION (skip if requested)
        if (-not $skipDescription) {
            if ($isEditingThis -and $this.EditingField -eq "description") {
                [void]$sb.Append($this.EditHighlight + $this.EditingValue.PadRight($this.DescCol) + $this.NormalColor)
            } else {
                $description = if ($entry.Description) { $entry.Description } else { "" }
                [void]$sb.Append($this.TagColor + $description.PadRight($this.DescCol) + $this.NormalColor)
            }
        } else {
            # Skip description column, add spaces to maintain alignment
            [void]$sb.Append(" " * $this.DescCol)
        }
        
        # COLUMN 3-7: DAY HOURS
        $this.RenderDayColumn($sb, $entry, "monday", $entry.Monday, $this.MonCol, $isEditingThis)
        $this.RenderDayColumn($sb, $entry, "tuesday", $entry.Tuesday, $this.TueCol, $isEditingThis)
        $this.RenderDayColumn($sb, $entry, "wednesday", $entry.Wednesday, $this.WedCol, $isEditingThis)
        $this.RenderDayColumn($sb, $entry, "thursday", $entry.Thursday, $this.ThuCol, $isEditingThis)
        $this.RenderDayColumn($sb, $entry, "friday", $entry.Friday, $this.FriCol, $isEditingThis)
        
        # COLUMN 8: TOTAL
        $totalText = if ($entry.Total -gt 0) { $entry.Total.ToString("F1") } else { "" }
        [void]$sb.Append($this.HighColor + $totalText.PadRight($this.TotalCol) + $this.NormalColor)
        
        # Clear to end of line if requested
        if ($clearToEnd) {
            [void]$sb.Append([VT]::ClearLine())
        }
    }
    
    [void] RenderDayColumn([System.Text.StringBuilder]$sb, [SimpleTimeEntry]$entry, [string]$dayName, [decimal]$hours, [int]$colWidth, [bool]$isEditingThis) {
        $currentDay = $this.GetCurrentDayOfWeek()
        $isCurrentDay = ($dayName -eq $currentDay)
        
        if ($isEditingThis -and $this.EditingField -eq $dayName) {
            [void]$sb.Append($this.EditHighlight + $this.EditingValue.PadRight($colWidth) + $this.NormalColor)
        } else {
            $hoursText = if ($hours -gt 0) { $hours.ToString("F1") } else { "" }
            if ($isCurrentDay) {
                $color = $this.TodayColor
            } else {
                $color = $this.LowColor
            }
            [void]$sb.Append($color + $hoursText.PadRight($colWidth) + $this.NormalColor)
        }
    }
    
    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        # Handle editing mode input first
        if ($this.EditingIndex -ge 0) {
            return $this.HandleEditingInput($key)
        }
        
        switch ($key.Key) {
            ([System.ConsoleKey]::UpArrow) {
                if ($this.SelectedIndex -gt 0) {
                    $this.SelectedIndex--
                    $this.EnsureVisible()
                }
                return $true
            }
            ([System.ConsoleKey]::DownArrow) {
                if ($this.SelectedIndex -lt ($this.FlatList.Count - 1)) {
                    $this.SelectedIndex++
                    $this.EnsureVisible()
                }
                return $true
            }
            ([System.ConsoleKey]::LeftArrow) {
                $this.TimeService.NavigateToPreviousWeek()
                $this.LoadTimeEntries()
                return $true
            }
            ([System.ConsoleKey]::RightArrow) {
                $this.TimeService.NavigateToNextWeek()
                $this.LoadTimeEntries()
                return $true
            }
            ([System.ConsoleKey]::E) {
                # Start inline editing of current entry
                if ($this.FlatList.Count -gt 0) {
                    $this.StartInlineEdit()
                }
                return $true
            }
            ([System.ConsoleKey]::A) {
                # Start inline add new entry
                $this.StartInlineAdd()
                return $true
            }
            ([System.ConsoleKey]::D) {
                $this.DeleteEntry()
                return $true
            }
            ([System.ConsoleKey]::C) {
                $this.TimeService.NavigateToCurrentWeek()
                $this.LoadTimeEntries()
                return $true
            }
            ([System.ConsoleKey]::Q) {
                return $false
            }
        }
        
        return $true
    }
    
    # === INLINE EDITING METHODS ===
    
    [void] StartInlineEdit() {
        $item = $this.FlatList[$this.SelectedIndex]
        $this.EditingIndex = $this.SelectedIndex
        $this.EditingEntry = $item.Entry
        $this.EditingField = "project"  # Start with project code
        $this.EditingValue = $item.Entry.ProjectCode
        $this.IsNewEntry = $false
    }
    
    [void] StartInlineAdd() {
        try {
            # Create a new entry and add it temporarily to the end
            $newEntry = [SimpleTimeEntry]::new()
            
            # Safely set the week ending friday using the service's current week
            if ($this.TimeService -and $this.TimeService.CurrentWeekFriday) {
                $newEntry.WeekEndingFriday = $this.TimeService.CurrentWeekFriday.ToString("yyyyMMdd")
            } else {
                # Fallback to current week if service isn't available
                $newEntry.WeekEndingFriday = $newEntry.GetCurrentWeekEndingFriday()
            }
            
            $this.FlatList.Add(@{
                Entry = $newEntry
                IsLast = $false
            })
            
            $this.EditingIndex = $this.FlatList.Count - 1
            $this.EditingEntry = $newEntry
            $this.EditingField = "project"
            $this.EditingValue = ""
            $this.SelectedIndex = $this.EditingIndex
            $this.IsNewEntry = $true
            
            $this.EnsureVisible()
        }
        catch {
            # Log the error and reset state to prevent crash
            if ($global:Logger) {
                & $global:Logger.Error "Error in StartInlineAdd: $($_.Exception.Message)"
                & $global:Logger.Error "Stack trace: $($_.ScriptStackTrace)"
            }
            # Reset editing state to safe values
            $this.EditingIndex = -1
            $this.EditingField = ""
            $this.EditingValue = ""
            $this.EditingEntry = $null
            $this.IsNewEntry = $false
        }
    }
    
    [bool] HandleEditingInput([System.ConsoleKeyInfo]$key) {
        switch ($key.Key) {
            ([System.ConsoleKey]::Enter) {
                # For new entries, only save after completing all required fields
                if ($this.IsNewEntry) {
                    if ($this.EditingField -eq "friday") {
                        $this.SaveInlineEdit()
                    } else {
                        $this.NextEditField()
                    }
                } else {
                    # For existing entries, save immediately
                    $this.SaveInlineEdit()
                }
                return $true
            }
            ([System.ConsoleKey]::Escape) {
                # Cancel editing
                $this.CancelInlineEdit()
                return $true
            }
            ([System.ConsoleKey]::Tab) {
                # Check for Shift+Tab (reverse)
                if ($key.Modifiers -band [System.ConsoleModifiers]::Shift) {
                    $this.PreviousEditField()
                } else {
                    $this.NextEditField()
                }
                return $true
            }
            ([System.ConsoleKey]::Backspace) {
                if ($this.EditingValue.Length -gt 0) {
                    $this.EditingValue = $this.EditingValue.Substring(0, $this.EditingValue.Length - 1)
                }
                return $true
            }
            default {
                # Add character to editing value
                if ($key.KeyChar -and [char]::IsControl($key.KeyChar) -eq $false) {
                    $this.EditingValue += $key.KeyChar
                }
                return $true
            }
        }
        return $true
    }
    
    [void] NextEditField() {
        # Cycle through fields: project -> description -> monday -> tuesday -> wednesday -> thursday -> friday
        switch ($this.EditingField) {
            "project" {
                $this.EditingEntry.ProjectCode = $this.EditingValue
                $this.EditingField = "description"
                $this.EditingValue = $this.EditingEntry.Description
            }
            "description" {
                $this.EditingEntry.Description = $this.EditingValue
                $this.EditingField = "monday"
                $this.EditingValue = if ($this.EditingEntry.Monday -gt 0) { $this.EditingEntry.Monday.ToString() } else { "" }
            }
            "monday" {
                $this.SetDayValue("Monday", $this.EditingValue)
                $this.EditingField = "tuesday"
                $this.EditingValue = if ($this.EditingEntry.Tuesday -gt 0) { $this.EditingEntry.Tuesday.ToString() } else { "" }
            }
            "tuesday" {
                $this.SetDayValue("Tuesday", $this.EditingValue)
                $this.EditingField = "wednesday"
                $this.EditingValue = if ($this.EditingEntry.Wednesday -gt 0) { $this.EditingEntry.Wednesday.ToString() } else { "" }
            }
            "wednesday" {
                $this.SetDayValue("Wednesday", $this.EditingValue)
                $this.EditingField = "thursday"
                $this.EditingValue = if ($this.EditingEntry.Thursday -gt 0) { $this.EditingEntry.Thursday.ToString() } else { "" }
            }
            "thursday" {
                $this.SetDayValue("Thursday", $this.EditingValue)
                $this.EditingField = "friday"
                $this.EditingValue = if ($this.EditingEntry.Friday -gt 0) { $this.EditingEntry.Friday.ToString() } else { "" }
            }
            "friday" {
                $this.SetDayValue("Friday", $this.EditingValue)
                if ($this.IsNewEntry) {
                    # For new entries, we're done - will save on next Enter
                    return
                } else {
                    # For existing entries, cycle back to project
                    $this.EditingField = "project"
                    $this.EditingValue = $this.EditingEntry.ProjectCode
                }
            }
        }
    }
    
    [void] PreviousEditField() {
        # Cycle backwards: project <- description <- monday <- ... <- friday
        switch ($this.EditingField) {
            "project" {
                $this.EditingEntry.ProjectCode = $this.EditingValue
                $this.EditingField = "friday"
                $this.EditingValue = if ($this.EditingEntry.Friday -gt 0) { $this.EditingEntry.Friday.ToString() } else { "" }
            }
            "description" {
                $this.EditingEntry.Description = $this.EditingValue
                $this.EditingField = "project"
                $this.EditingValue = $this.EditingEntry.ProjectCode
            }
            "monday" {
                $this.SetDayValue("Monday", $this.EditingValue)
                $this.EditingField = "description"
                $this.EditingValue = $this.EditingEntry.Description
            }
            "tuesday" {
                $this.SetDayValue("Tuesday", $this.EditingValue)
                $this.EditingField = "monday"
                $this.EditingValue = if ($this.EditingEntry.Monday -gt 0) { $this.EditingEntry.Monday.ToString() } else { "" }
            }
            "wednesday" {
                $this.SetDayValue("Wednesday", $this.EditingValue)
                $this.EditingField = "tuesday"
                $this.EditingValue = if ($this.EditingEntry.Tuesday -gt 0) { $this.EditingEntry.Tuesday.ToString() } else { "" }
            }
            "thursday" {
                $this.SetDayValue("Thursday", $this.EditingValue)
                $this.EditingField = "wednesday"
                $this.EditingValue = if ($this.EditingEntry.Wednesday -gt 0) { $this.EditingEntry.Wednesday.ToString() } else { "" }
            }
            "friday" {
                $this.SetDayValue("Friday", $this.EditingValue)
                $this.EditingField = "thursday"
                $this.EditingValue = if ($this.EditingEntry.Thursday -gt 0) { $this.EditingEntry.Thursday.ToString() } else { "" }
            }
        }
    }
    
    [void] SetDayValue([string]$dayName, [string]$value) {
        $hours = 0
        if ($value -and [decimal]::TryParse($value, [ref]$hours)) {
            $this.EditingEntry.SetDayHours($dayName, $hours)
        } else {
            $this.EditingEntry.SetDayHours($dayName, 0)
        }
    }
    
    [void] SaveInlineEdit() {
        # Apply final field value
        switch ($this.EditingField) {
            "project" { $this.EditingEntry.ProjectCode = $this.EditingValue }
            "description" { $this.EditingEntry.Description = $this.EditingValue }
            "monday" { $this.SetDayValue("Monday", $this.EditingValue) }
            "tuesday" { $this.SetDayValue("Tuesday", $this.EditingValue) }
            "wednesday" { $this.SetDayValue("Wednesday", $this.EditingValue) }
            "thursday" { $this.SetDayValue("Thursday", $this.EditingValue) }
            "friday" { $this.SetDayValue("Friday", $this.EditingValue) }
        }
        
        # Determine if it's a time code or project
        if ($this.EditingEntry.ProjectCode.Length -le 5 -and $this.EditingEntry.ProjectCode.Length -ge 3) {
            $this.EditingEntry.IsProjectEntry = $false
        } else {
            $this.EditingEntry.IsProjectEntry = $true
        }
        
        # Recalculate total
        $this.EditingEntry.CalculateTotal()
        
        # Save to service
        if ($this.EditingEntry.ProjectCode) {
            if ($this.EditingEntry.Id -eq [guid]::Empty -or $this.IsNewEntry) {
                # New entry
                $this.TimeService.AddTimeEntry($this.EditingEntry)
            } else {
                # Existing entry
                $this.TimeService.UpdateTimeEntry($this.EditingEntry)
            }
        } else {
            # Empty project code, remove if it was a new entry
            if ($this.IsNewEntry) {
                $this.FlatList.RemoveAt($this.EditingIndex)
            }
        }
        
        $this.EndInlineEdit()
    }
    
    [void] CancelInlineEdit() {
        # Remove new entry if it was being added
        if ($this.IsNewEntry) {
            $this.FlatList.RemoveAt($this.EditingIndex)
            if ($this.SelectedIndex -ge $this.FlatList.Count) {
                $this.SelectedIndex = [Math]::Max(0, $this.FlatList.Count - 1)
            }
        }
        $this.EndInlineEdit()
    }
    
    [void] EndInlineEdit() {
        $this.EditingIndex = -1
        $this.EditingField = ""
        $this.EditingValue = ""
        $this.EditingEntry = $null
        $this.IsNewEntry = $false
        $this.LoadTimeEntries()  # Refresh the list
    }
    
    [void] DeleteEntry() {
        if ($this.FlatList.Count -eq 0) { return }
        
        $item = $this.FlatList[$this.SelectedIndex]
        $this.TimeService.DeleteTimeEntry($item.Entry.Id)
        $this.LoadTimeEntries()
    }
    
    [void] ShowStatus([string]$message, [int]$durationMs = 2000) {
        # Save cursor position
        [Console]::SetCursorPosition(2, $this.Height - 1)
        Write-Host $message -ForegroundColor Green -NoNewline
        
        # Set a flag to clear the status after duration
        $this.StatusMessage = $message
        $this.StatusClearTime = [DateTime]::Now.AddMilliseconds($durationMs)
    }
    
    [void] RenderTotals([System.Text.StringBuilder]$sb) {
        # Calculate week total
        $weekTotal = 0
        foreach ($entry in $this.TimeEntries) {
            $weekTotal += $entry.Total
        }
        
        # Get cumulative for selected entry if it's a project entry
        $cumulative = 0
        $selectedProjectCode = ""
        if ($this.SelectedIndex -ge 0 -and $this.SelectedIndex -lt $this.FlatList.Count) {
            $selectedEntry = $this.FlatList[$this.SelectedIndex].Entry
            if ($selectedEntry.ProjectCode -match '^\d{3}\s*/\s*\d+$') {
                $selectedProjectCode = $selectedEntry.ProjectCode
                $cumulative = $this.TimeService.GetCumulativeHours($selectedProjectCode)
            }
        }
        
        # Display totals line
        [void]$sb.Append([VT]::MoveTo(0, $this.Height - 3))
        [void]$sb.Append($this.HighColor)
        $totalsText = "Week Total: $($weekTotal.ToString('F1'))"
        if ($selectedProjectCode) {
            $totalsText += "  |  Cumulative for $selectedProjectCode`: $($cumulative.ToString('F1'))"
        }
        [void]$sb.Append($totalsText.PadRight($this.Width))
        [void]$sb.Append($this.NormalColor)
    }
    
    [void] EnsureVisible() {
        # Ensure selected item is visible with dynamic heights
        if ($this.SelectedIndex -lt $this.ScrollTop) {
            $this.ScrollTop = $this.SelectedIndex
        } else {
            # Check if selected item fits in current view
            $availableHeight = $this.Height - 6
            $totalHeight = 0
            $needsScroll = $true
            
            for ($i = $this.ScrollTop; $i -le $this.SelectedIndex -and $i -lt $this.FlatList.Count; $i++) {
                $itemHeight = $this.GetItemHeight($i)
                $totalHeight += $itemHeight
                
                if ($i -eq $this.SelectedIndex) {
                    if ($totalHeight -le $availableHeight) {
                        $needsScroll = $false
                    }
                    break
                }
            }
            
            if ($needsScroll) {
                # Scroll to show selected item
                $this.ScrollTop = [Math]::Max(0, $this.SelectedIndex - 1)
            }
        }
    }
    
    [void] PositionCursorForEditing([System.Text.StringBuilder]$sb) {
        if ($this.EditingIndex -lt 0) { return }
        
        # Calculate the Y position of the editing item
        $startY = 4
        $currentY = $startY
        $foundY = -1
        
        # Calculate how many items we can show with dynamic heights
        for ($i = $this.ScrollTop; $i -lt $this.FlatList.Count; $i++) {
            $itemHeight = $this.GetItemHeight($i)
            if ($i -eq $this.EditingIndex) {
                # Found our editing item, it will be in pillbox mode (4 lines)
                # All editing happens on the content line (2nd line of pillbox)
                $foundY = $currentY + 2  # Content line is 2nd line of pillbox
                break
            }
            $currentY += $itemHeight
            if ($currentY -ge ($this.Height - 6)) { break }
        }
        
        if ($foundY -ge 0) {
            # Calculate X position based on field being edited
            $x = 1  # Start after the left border "│"
            
            switch ($this.EditingField) {
                "project" {
                    $x += $this.EditingValue.Length
                }
                "description" {
                    # Description is now in the main content line, not a separate line
                    $x += $this.ProjectCol + $this.EditingValue.Length
                }
                "monday" {
                    $x += $this.ProjectCol + $this.DescCol + $this.EditingValue.Length
                }
                "tuesday" {
                    $x += $this.ProjectCol + $this.DescCol + $this.MonCol + $this.EditingValue.Length
                }
                "wednesday" {
                    $x += $this.ProjectCol + $this.DescCol + $this.MonCol + $this.TueCol + $this.EditingValue.Length
                }
                "thursday" {
                    $x += $this.ProjectCol + $this.DescCol + $this.MonCol + $this.TueCol + $this.WedCol + $this.EditingValue.Length
                }
                "friday" {
                    $x += $this.ProjectCol + $this.DescCol + $this.MonCol + $this.TueCol + $this.WedCol + $this.ThuCol + $this.EditingValue.Length
                }
            }
            
            [void]$sb.Append([VT]::MoveTo($x, $foundY))
        }
    }
}