# SelectionDialog.ps1 - Dialog for selecting from a list of items

class SelectionDialog : BaseDialog {
    [string]$Prompt
    [MinimalListBox]$ListBox
    [array]$Items = @()
    [scriptblock]$ItemRenderer
    [scriptblock]$OnSelect
    
    SelectionDialog() : base("Select Item") {
        $this.Prompt = "Select an item:"
        $this.DialogWidth = 60
        $this.DialogHeight = 20
        $this.PrimaryButtonText = "Select"
        $this.SecondaryButtonText = "Cancel"
    }
    
    [void] SetItems([array]$items) {
        $this.Items = $items
        if ($this.ListBox) {
            $this.ListBox.SetItems($items)
        }
    }
    
    [void] InitializeContent() {
        # Create list box
        $this.ListBox = [MinimalListBox]::new()
        $this.ListBox.ShowBorder = $true
        $this.ListBox.BorderType = [BorderType]::Rounded
        
        if ($this.ItemRenderer) {
            $this.ListBox.ItemRenderer = $this.ItemRenderer
        }
        
        $this.ListBox.SetItems($this.Items)
        $this.AddContentControl($this.ListBox)
        
        # Configure primary button action
        $dialog = $this
        $this.OnPrimary = {
            $selectedItem = $dialog.ListBox.GetSelectedItem()
            if ($selectedItem -and $dialog.OnSelect) {
                & $dialog.OnSelect $selectedItem
            }
        }.GetNewClosure()
    }
    
    [void] PositionContentControls([int]$dialogX, [int]$dialogY) {
        # Position prompt and list box
        $padding = 2
        $controlWidth = $this.DialogWidth - ($padding * 2)
        $promptHeight = 2
        $listHeight = $this.DialogHeight - $promptHeight - 6  # Leave room for buttons
        
        # Position list box
        $this.ListBox.SetBounds(
            $dialogX + $padding,
            $dialogY + $promptHeight,
            $controlWidth,
            $listHeight
        )
    }
    
    [string] OnRender() {
        $sb = Get-PooledStringBuilder 1024
        
        # First render the base dialog
        $baseRender = ([BaseDialog]$this).OnRender()
        $sb.Append($baseRender)
        
        # Render prompt
        $promptX = $this._dialogBounds.X + 2
        $promptY = $this._dialogBounds.Y + 1
        
        $sb.Append([VT]::MoveTo($promptX, $promptY))
        $sb.Append($this.Theme.GetColor("normal"))
        $sb.Append($this.Prompt)
        
        $sb.Append([VT]::Reset())
        
        $result = $sb.ToString()
        Return-PooledStringBuilder $sb
        return $result
    }
}