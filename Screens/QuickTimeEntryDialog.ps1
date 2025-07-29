# QuickTimeEntryDialog - Simple time entry dialog

class QuickTimeEntryDialog : BaseDialog {
    [DateTime]$WeekFriday
    [MinimalTextBox]$ProjectBox
    [MinimalTextBox]$MondayBox
    [MinimalTextBox]$TuesdayBox
    [MinimalTextBox]$WednesdayBox
    [MinimalTextBox]$ThursdayBox
    [MinimalTextBox]$FridayBox
    [TimeTrackingService]$TimeService
    [ProjectService]$ProjectService
    [scriptblock]$OnSave = {}
    
    QuickTimeEntryDialog([DateTime]$weekFriday) : base("Quick Time Entry") {
        $this.WeekFriday = $weekFriday
        $this.PrimaryButtonText = "Save"
        $this.SecondaryButtonText = "Cancel"
        $this.DialogWidth = 60
        $this.DialogHeight = 20
    }
    
    [void] InitializeContent() {
        # Get services
        $this.TimeService = $this.ServiceContainer.GetService("TimeTrackingService")
        $this.ProjectService = $this.ServiceContainer.GetService("ProjectService")
        
        # Create all input fields
        $this.ProjectBox = [MinimalTextBox]::new()
        $this.ProjectBox.ShowBorder = $false
        $this.ProjectBox.Placeholder = "Enter Project ID2 or Non-Project Code..."
        $this.ProjectBox.Height = 1
        $this.AddContentControl($this.ProjectBox, 1)
        
        $this.MondayBox = [MinimalTextBox]::new()
        $this.MondayBox.ShowBorder = $false
        $this.MondayBox.Placeholder = "Monday Hours"
        $this.MondayBox.Height = 1
        $this.AddContentControl($this.MondayBox, 2)
        
        $this.TuesdayBox = [MinimalTextBox]::new()
        $this.TuesdayBox.ShowBorder = $false
        $this.TuesdayBox.Placeholder = "Tuesday Hours"
        $this.TuesdayBox.Height = 1
        $this.AddContentControl($this.TuesdayBox, 3)
        
        $this.WednesdayBox = [MinimalTextBox]::new()
        $this.WednesdayBox.ShowBorder = $false
        $this.WednesdayBox.Placeholder = "Wednesday Hours"
        $this.WednesdayBox.Height = 1
        $this.AddContentControl($this.WednesdayBox, 4)
        
        $this.ThursdayBox = [MinimalTextBox]::new()
        $this.ThursdayBox.ShowBorder = $false
        $this.ThursdayBox.Placeholder = "Thursday Hours"
        $this.ThursdayBox.Height = 1
        $this.AddContentControl($this.ThursdayBox, 5)
        
        $this.FridayBox = [MinimalTextBox]::new()
        $this.FridayBox.ShowBorder = $false
        $this.FridayBox.Placeholder = "Friday Hours"
        $this.FridayBox.Height = 1
        $this.AddContentControl($this.FridayBox, 6)
        
        # Set up save action
        $dialog = $this
        $this.OnPrimary = {
            if ($dialog.ProjectBox.Text.Trim()) {
                # Parse project ID
                $projectId = $dialog.ProjectBox.Text.Trim().ToUpper()
                
                # Create time entry for each day with hours
                $weekStart = $dialog.WeekFriday.AddDays(-4)
                $daysAndHours = @(
                    @{ Day = $weekStart; Hours = $dialog.ParseHours($dialog.MondayBox.Text) },
                    @{ Day = $weekStart.AddDays(1); Hours = $dialog.ParseHours($dialog.TuesdayBox.Text) },
                    @{ Day = $weekStart.AddDays(2); Hours = $dialog.ParseHours($dialog.WednesdayBox.Text) },
                    @{ Day = $weekStart.AddDays(3); Hours = $dialog.ParseHours($dialog.ThursdayBox.Text) },
                    @{ Day = $weekStart.AddDays(4); Hours = $dialog.ParseHours($dialog.FridayBox.Text) }
                )
                
                # Find project details
                $project = $dialog.ProjectService.GetAllProjects() | Where-Object { $_.ID2 -eq $projectId } | Select-Object -First 1
                
                foreach ($dayInfo in $daysAndHours) {
                    if ($dayInfo.Hours -gt 0) {
                        $timeEntry = [PSCustomObject]@{
                            Id = [Guid]::NewGuid().ToString()
                            ProjectId = $projectId
                            ProjectName = if ($project) { $project.FullProjectName } else { $projectId }
                            Date = $dayInfo.Day
                            Hours = $dayInfo.Hours
                            Description = ""
                            CreatedAt = [DateTime]::Now
                            UpdatedAt = [DateTime]::Now
                        }
                        
                        # Add to time service
                        $dialog.TimeService.AddTimeEntry($timeEntry)
                    }
                }
                
                # Call legacy callback if set
                if ($dialog.OnSave) {
                    $data = @{
                        WeekEndingFriday = $dialog.WeekFriday.ToString("yyyyMMdd")
                        ID2 = $projectId
                        Monday = $dialog.ParseHours($dialog.MondayBox.Text)
                        Tuesday = $dialog.ParseHours($dialog.TuesdayBox.Text)
                        Wednesday = $dialog.ParseHours($dialog.WednesdayBox.Text)
                        Thursday = $dialog.ParseHours($dialog.ThursdayBox.Text)
                        Friday = $dialog.ParseHours($dialog.FridayBox.Text)
                    }
                    & $dialog.OnSave $data
                }
            }
        }.GetNewClosure()
    }
    
    [void] PositionContentControls([int]$dialogX, [int]$dialogY) {
        # Custom positioning for time entry fields
        $controlWidth = $this.DialogWidth - ($this.DialogPadding * 2)
        $currentY = $dialogY + 2
        
        # Week label
        $weekText = "Week of " + $this.WeekFriday.AddDays(-4).ToString("MM/dd/yyyy") + " to " + $this.WeekFriday.ToString("MM/dd/yyyy")
        # We'll render this in OnRender
        
        # Project field
        $this.ProjectBox.SetBounds($dialogX + $this.DialogPadding, $currentY, $controlWidth, 1)
        $currentY += 3
        
        # Day fields - two columns
        $halfWidth = [int](($controlWidth - 2) / 2)
        
        # Monday and Tuesday
        $this.MondayBox.SetBounds($dialogX + $this.DialogPadding, $currentY, $halfWidth, 1)
        $this.TuesdayBox.SetBounds($dialogX + $this.DialogPadding + $halfWidth + 2, $currentY, $halfWidth, 1)
        $currentY += 2
        
        # Wednesday and Thursday
        $this.WednesdayBox.SetBounds($dialogX + $this.DialogPadding, $currentY, $halfWidth, 1)
        $this.ThursdayBox.SetBounds($dialogX + $this.DialogPadding + $halfWidth + 2, $currentY, $halfWidth, 1)
        $currentY += 2
        
        # Friday (full width)
        $this.FridayBox.SetBounds($dialogX + $this.DialogPadding, $currentY, $controlWidth, 1)
    }
    
    [string] OnRender() {
        $result = ([BaseDialog]$this).OnRender()
        
        # Add week label
        $sb = [System.Text.StringBuilder]::new()
        $sb.Append($result)
        
        $weekText = "Week: " + $this.WeekFriday.AddDays(-4).ToString("MM/dd") + " - " + $this.WeekFriday.ToString("MM/dd")
        $labelX = $this._dialogBounds.X + $this.DialogPadding
        $labelY = $this._dialogBounds.Y + 1
        
        $sb.Append([VT]::MoveTo($labelX, $labelY))
        $sb.Append($this.Theme.GetColor('text.secondary'))
        $sb.Append($weekText)
        
        # Add day labels
        $dayY = $labelY + 4
        $halfWidth = [int](($this.DialogWidth - ($this.DialogPadding * 2) - 2) / 2)
        
        # Monday/Tuesday labels
        $sb.Append([VT]::MoveTo($labelX, $dayY - 1))
        $sb.Append("Monday:")
        $sb.Append([VT]::MoveTo($labelX + $halfWidth + 2, $dayY - 1))
        $sb.Append("Tuesday:")
        
        # Wednesday/Thursday labels
        $sb.Append([VT]::MoveTo($labelX, $dayY + 1))
        $sb.Append("Wednesday:")
        $sb.Append([VT]::MoveTo($labelX + $halfWidth + 2, $dayY + 1))
        $sb.Append("Thursday:")
        
        # Friday label
        $sb.Append([VT]::MoveTo($labelX, $dayY + 3))
        $sb.Append("Friday:")
        
        return $sb.ToString()
    }
    
    [decimal] ParseHours([string]$text) {
        if ([string]::IsNullOrWhiteSpace($text)) { return 0 }
        $hours = 0
        if ([decimal]::TryParse($text, [ref]$hours)) {
            return $hours
        }
        return 0
    }
}