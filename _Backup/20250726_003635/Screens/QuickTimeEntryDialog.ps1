# QuickTimeEntryDialog - Simple time entry dialog

class QuickTimeEntryDialog : BaseDialog {
    [DateTime]$WeekFriday
    [TextBox]$ProjectBox
    [TextBox]$MondayBox
    [TextBox]$TuesdayBox
    [TextBox]$WednesdayBox
    [TextBox]$ThursdayBox
    [TextBox]$FridayBox
    [TimeTrackingService]$TimeService
    [scriptblock]$OnSave
    
    QuickTimeEntryDialog([DateTime]$weekFriday) : base("Quick Time Entry") {
        $this.WeekFriday = $weekFriday
        $this.PrimaryButtonText = "Save"
        $this.SecondaryButtonText = "Cancel"
        $this.DialogWidth = 70
        $this.DialogHeight = 30
    }
    
    [void] InitializeContent() {
        # Create all input fields
        $this.ProjectBox = [TextBox]::new()
        $this.ProjectBox.Placeholder = "Enter Project ID2 or Non-Project Code..."
        $this.AddContentControl($this.ProjectBox, 1)
        
        $this.MondayBox = [TextBox]::new()
        $this.MondayBox.Placeholder = "Monday Hours"
        $this.AddContentControl($this.MondayBox, 2)
        
        $this.TuesdayBox = [TextBox]::new()
        $this.TuesdayBox.Placeholder = "Tuesday Hours"
        $this.AddContentControl($this.TuesdayBox, 3)
        
        $this.WednesdayBox = [TextBox]::new()
        $this.WednesdayBox.Placeholder = "Wednesday Hours"
        $this.AddContentControl($this.WednesdayBox, 4)
        
        $this.ThursdayBox = [TextBox]::new()
        $this.ThursdayBox.Placeholder = "Thursday Hours"
        $this.AddContentControl($this.ThursdayBox, 5)
        
        $this.FridayBox = [TextBox]::new()
        $this.FridayBox.Placeholder = "Friday Hours"
        $this.AddContentControl($this.FridayBox, 6)
        
        # Set up save action
        $dialog = $this
        $this.OnPrimary = {
            if ($dialog.ProjectBox.Text.Trim()) {
                $this.TimeService = $this.ServiceContainer.GetService("TimeTrackingService")
                
                $data = @{
                    WeekEndingFriday = $dialog.WeekFriday.ToString("yyyyMMdd")
                    ID2 = $dialog.ProjectBox.Text.Trim().ToUpper()
                    Monday = $dialog.ParseHours($dialog.MondayBox.Text)
                    Tuesday = $dialog.ParseHours($dialog.TuesdayBox.Text)
                    Wednesday = $dialog.ParseHours($dialog.WednesdayBox.Text)
                    Thursday = $dialog.ParseHours($dialog.ThursdayBox.Text)
                    Friday = $dialog.ParseHours($dialog.FridayBox.Text)
                }
                
                if ($dialog.OnSave) {
                    & $dialog.OnSave $data
                }
                
                $dialog.CloseDialog()
            }
        }.GetNewClosure()
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