# FilePickerDialog.ps1 - File selection dialog using FastFileTree
# Modal dialog for selecting files or directories

class FilePickerDialog : BaseDialog {
    [FastFileTree]$FileTree
    [MinimalTextBox]$PathBox
    
    # Configuration
    [string]$InitialPath = ""
    [string]$Filter = "*"
    [bool]$AllowDirectories = $false
    [bool]$AllowFiles = $true
    [bool]$MustExist = $true
    [string]$DialogTitle = "Select File"
    
    # Results
    [string]$SelectedPath = ""
    [bool]$DialogResult = $false
    
    # Events
    [scriptblock]$OnFileSelected = {}
    
    FilePickerDialog() : base("File Picker") {
        $this.DialogWidth = 80
        $this.DialogHeight = 25
        $this.PrimaryButtonText = "Select"
        $this.SecondaryButtonText = "Cancel"
        $this.InitialPath = $PWD.Path
    }
    
    FilePickerDialog([string]$initialPath) : base("File Picker") {
        $this.DialogWidth = 80
        $this.DialogHeight = 25
        $this.PrimaryButtonText = "Select"
        $this.SecondaryButtonText = "Cancel"
        $this.InitialPath = $initialPath
    }
    
    [void] InitializeContent() {
        # Path input box at top
        $this.PathBox = [MinimalTextBox]::new()
        $this.PathBox.Placeholder = "Enter path or navigate below"
        $this.PathBox.Text = $this.InitialPath
        $this.PathBox.ShowBorder = $false  # Dialog provides the border
        $this.PathBox.Height = 1
        $this.AddContentControl($this.PathBox, 1)
        
        # File tree in the middle
        $this.FileTree = [FastFileTree]::new($this.InitialPath)
        $this.FileTree.Title = $this.DialogTitle
        $this.FileTree.Filter = $this.Filter
        $this.FileTree.ShowBorder = $false  # Dialog provides the border
        $this.AddContentControl($this.FileTree, 15)  # Most of the dialog height
        
        # Set up events
        $dialogRef = $this
        $this.FileTree.OnSelectionChanged = {
            $selected = $dialogRef.FileTree.GetSelectedNode()
            if ($selected) {
                $dialogRef.PathBox.Text = $selected.FullPath
                $dialogRef.UpdateButtonStates()
            }
        }.GetNewClosure()
        
        $this.FileTree.OnFileSelected = {
            param($node)
            if ($dialogRef.IsValidSelection($node)) {
                $dialogRef.SelectedPath = $node.FullPath
                $dialogRef.DialogResult = $true
                # Dialog will be closed by SelectFile or CloseDialog
            }
        }.GetNewClosure()
        
        # Set up primary action handler
        $dialogRef = $this
        $this.OnPrimary = {
            $dialogRef.SelectFile()
        }.GetNewClosure()
        
        # Update button states
        $this.UpdateButtonStates()
    }
    
    [void] UpdateButtonStates() {
        $selected = $this.FileTree.GetSelectedNode()
        $isValid = $this.IsValidSelection($selected)
        
        # Enable/disable select button based on selection
        # Note: Button doesn't have Enabled property in current implementation
        # This is a placeholder for when we add that functionality
        
        # Update button text to reflect what will happen
        if ($selected) {
            if ($selected.IsDirectory) {
                $this.SelectButton.Text = if ($this.AllowDirectories) { "Select Folder" } else { "Enter" }
            } else {
                $this.SelectButton.Text = "Select File"
            }
        } else {
            $this.SelectButton.Text = "Select"
        }
        $this.SelectButton.Invalidate()
    }
    
    [bool] IsValidSelection([FileSystemNode]$node) {
        if ($node -eq $null) {
            return $false
        }
        
        # Check if selection type is allowed
        if ($node.IsDirectory -and -not $this.AllowDirectories) {
            return $false
        }
        
        if (-not $node.IsDirectory -and -not $this.AllowFiles) {
            return $false
        }
        
        # Check if file exists (if required)
        if ($this.MustExist -and -not (Test-Path $node.FullPath)) {
            return $false
        }
        
        return $true
    }
    
    [void] SelectFile() {
        $selected = $this.FileTree.GetSelectedNode()
        
        if ($selected -and $this.IsValidSelection($selected)) {
            $this.SelectedPath = $selected.FullPath
            $this.DialogResult = $true
            
            # Fire event
            if ($this.OnFileSelected) {
                & $this.OnFileSelected $selected.FullPath
            }
            
            $this.Active = $false
        } elseif ($selected -and $selected.IsDirectory -and -not $this.AllowDirectories) {
            # Navigate into directory instead of selecting it
            $this.FileTree.NavigateToSelected()
            $this.PathBox.Text = $this.FileTree.RootPath
        } else {
            # Try to use path from text box
            $pathFromBox = $this.PathBox.Text.Trim()
            if ($pathFromBox -and (Test-Path $pathFromBox)) {
                $this.SelectedPath = $pathFromBox
                $this.DialogResult = $true
                
                if ($this.OnFileSelected) {
                    & $this.OnFileSelected $pathFromBox
                }
                
                $this.CloseDialog()
            }
        }
    }
    
    [void] PositionContentControls([int]$dialogX, [int]$dialogY) {
        # Position the path box at the top
        $this.PathBox.SetBounds(
            $dialogX + $this.DialogPadding,
            $dialogY + 2,
            $this.DialogWidth - ($this.DialogPadding * 2),
            1
        )
        
        # Position the file tree below with some spacing
        $this.FileTree.SetBounds(
            $dialogX + $this.DialogPadding,
            $dialogY + 4,
            $this.DialogWidth - ($this.DialogPadding * 2),
            15  # Most of the dialog height
        )
    }
    
    [string] OnRender() {
        $sb = Get-PooledStringBuilder 2048
        
        # First render the base dialog
        $baseRender = ([BaseDialog]$this).OnRender()
        $sb.Append($baseRender)
        
        # Add label for path box
        $labelColor = $this.Theme.GetColor("dialog.title")
        $sb.Append([VT]::MoveTo($this._dialogBounds.X + $this.DialogPadding, $this.PathBox.Y - 1))
        $sb.Append($labelColor)
        $sb.Append("Path:")
        $sb.Append([VT]::Reset())
        
        $result = $sb.ToString()
        Return-PooledStringBuilder $sb
        return $result
    }
    
    # Override HandleScreenInput to handle path box Enter key
    [bool] HandleScreenInput([System.ConsoleKeyInfo]$key) {
        # Let base class handle standard dialog shortcuts first
        if (([BaseDialog]$this).HandleScreenInput($key)) {
            return $true
        }
        
        # Handle Enter in path box
        if ($key.Key -eq [System.ConsoleKey]::Enter -and $this.PathBox.IsFocused) {
            # Try to navigate to path in text box
            $path = $this.PathBox.Text.Trim()
            if ($path -and (Test-Path $path)) {
                if (Test-Path $path -PathType Container) {
                    $this.FileTree.LoadDirectory($path)
                    $this.FileTree.Focus()
                } else {
                    # It's a file, select it
                    $this.SelectedPath = $path
                    $this.DialogResult = $true
                    $this.CloseDialog()
                }
            }
            return $true
        }
        
        return $false
    }
}