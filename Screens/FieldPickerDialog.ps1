# FieldPickerDialog.ps1 - Dialog for selecting database fields

class FieldPickerDialog : BaseDialog {
    [MinimalListBox]$FieldList
    [array]$Fields = @()
    [bool]$AllowMultiple = $false
    [scriptblock]$OnFieldSelected
    
    FieldPickerDialog() : base("Select Field") {
        $this.DialogWidth = 50
        $this.DialogHeight = 20
        $this.PrimaryButtonText = "Select"
        $this.SecondaryButtonText = "Cancel"
    }
    
    [void] SetFields([array]$fields) {
        $this.Fields = $fields
        if ($this.FieldList) {
            $this.FieldList.SetItems($fields)
        }
    }
    
    [void] InitializeContent() {
        # For now, use sample fields until we can get actual database fields
        if ($this.Fields.Count -eq 0) {
            $this.Fields = @(
                @{ Name = "ACCOUNT_NO"; Type = "Character"; Length = 10 }
                @{ Name = "AMOUNT"; Type = "Numeric"; Length = 12 }
                @{ Name = "DATE"; Type = "Date"; Length = 8 }
                @{ Name = "DESCRIPTION"; Type = "Character"; Length = 50 }
                @{ Name = "CATEGORY"; Type = "Character"; Length = 20 }
                @{ Name = "STATUS"; Type = "Character"; Length = 10 }
                @{ Name = "TAX_AMOUNT"; Type = "Numeric"; Length = 10 }
                @{ Name = "VENDOR_ID"; Type = "Character"; Length = 15 }
            )
        }
        
        # Create field list
        $listType = if ($this.AllowMultiple) { [MultiSelectListBox] } else { [MinimalListBox] }
        $this.FieldList = $listType::new()
        $this.FieldList.ShowBorder = $true
        $this.FieldList.BorderType = [BorderType]::Rounded
        $this.FieldList.ItemRenderer = {
            param($field)
            if ($field -is [hashtable]) {
                return "$($field.Name) ($($field.Type))"
            } else {
                return $field.ToString()
            }
        }
        
        $this.FieldList.SetItems($this.Fields)
        $this.AddContentControl($this.FieldList)
        
        # Configure primary button action
        $dialog = $this
        $this.OnPrimary = {
            if ($dialog.AllowMultiple -and $dialog.FieldList -is [MultiSelectListBox]) {
                $selectedFields = $dialog.FieldList.GetSelectedItems()
                if ($selectedFields.Count -gt 0 -and $dialog.OnFieldSelected) {
                    # Join field names with comma
                    $fieldNames = ($selectedFields | ForEach-Object { $_.Name }) -join ","
                    & $dialog.OnFieldSelected $fieldNames
                }
            } else {
                $selectedField = $dialog.FieldList.GetSelectedItem()
                if ($selectedField -and $dialog.OnFieldSelected) {
                    $fieldName = if ($selectedField -is [hashtable]) { $selectedField.Name } else { $selectedField }
                    & $dialog.OnFieldSelected $fieldName
                }
            }
        }.GetNewClosure()
    }
    
    [void] PositionContentControls([int]$dialogX, [int]$dialogY) {
        # Position field list
        $padding = 2
        $controlWidth = $this.DialogWidth - ($padding * 2)
        $titleHeight = 2
        $listHeight = $this.DialogHeight - $titleHeight - 5  # Leave room for buttons
        
        $this.FieldList.SetBounds(
            $dialogX + $padding,
            $dialogY + $titleHeight,
            $controlWidth,
            $listHeight
        )
    }
    
    [string] OnRender() {
        $sb = Get-PooledStringBuilder 1024
        
        # First render the base dialog
        $baseRender = ([BaseDialog]$this).OnRender()
        $sb.Append($baseRender)
        
        # Render field type legend
        $legendX = $this._dialogBounds.X + 2
        $legendY = $this._dialogBounds.Y + $this.DialogHeight - 3
        
        $sb.Append([VT]::MoveTo($legendX, $legendY))
        $sb.Append($this.Theme.GetColor("disabled"))
        
        if ($this.AllowMultiple) {
            $sb.Append("Use Space to select multiple fields")
        } else {
            $sb.Append("Select a field and press Enter")
        }
        
        $sb.Append([VT]::Reset())
        
        $result = $sb.ToString()
        Return-PooledStringBuilder $sb
        return $result
    }
}