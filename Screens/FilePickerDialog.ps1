# FilePickerDialog.ps1 - File selection dialog using FastFileTree
# Modal dialog for selecting files or directories

class FilePickerDialog : Screen {
    [FastFileTree]$FileTree
    [MinimalButton]$SelectButton
    [MinimalButton]$CancelButton
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
    
    # Layout
    hidden [int]$_treeHeight = 20
    hidden [int]$_dialogWidth = 80
    hidden [int]$_dialogHeight = 25
    
    FilePickerDialog() : base() {
        $this.Title = "File Picker"
        $this.DrawBackground = $true
        $this.InitialPath = $PWD.Path
    }
    
    FilePickerDialog([string]$initialPath) : base() {
        $this.Title = "File Picker"
        $this.DrawBackground = $true
        $this.InitialPath = $initialPath
    }
    
    [void] OnInitialize() {
        # Calculate dialog position (centered)
        $centerX = ([Console]::WindowWidth - $this._dialogWidth) / 2
        $centerY = ([Console]::WindowHeight - $this._dialogHeight) / 2
        
        # Path input box at top
        $this.PathBox = [MinimalTextBox]::new()
        $this.PathBox.Placeholder = "Enter path or navigate below"
        $this.PathBox.Text = $this.InitialPath
        $this.PathBox.SetBounds([int]$centerX + 2, [int]$centerY + 2, $this._dialogWidth - 4, 3)
        $this.PathBox.Initialize($global:ServiceContainer)
        $this.AddChild($this.PathBox)
        
        # File tree in the middle
        $this.FileTree = [FastFileTree]::new($this.InitialPath)
        $this.FileTree.Title = $this.DialogTitle
        $this.FileTree.Filter = $this.Filter
        $this.FileTree.ShowBorder = $true
        $this.FileTree.SetBounds([int]$centerX + 2, [int]$centerY + 6, $this._dialogWidth - 4, $this._treeHeight)
        $this.FileTree.Initialize($global:ServiceContainer)
        
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
                $dialogRef.Active = $false
            }
        }.GetNewClosure()
        
        $this.AddChild($this.FileTree)
        
        # Buttons at bottom
        $buttonY = [int]$centerY + 6 + $this._treeHeight + 1
        $buttonWidth = 15
        $buttonSpacing = 2
        $totalButtonWidth = ($buttonWidth * 2) + $buttonSpacing
        $buttonStartX = [int]$centerX + (($this._dialogWidth - $totalButtonWidth) / 2)
        
        $this.SelectButton = [MinimalButton]::new("Select")
        $this.SelectButton.IsDefault = $true
        $this.SelectButton.SetBounds($buttonStartX, $buttonY, $buttonWidth, 3)
        $this.SelectButton.OnClick = {
            $dialogRef.SelectFile()
        }.GetNewClosure()
        $this.SelectButton.Initialize($global:ServiceContainer)
        $this.AddChild($this.SelectButton)
        
        $this.CancelButton = [MinimalButton]::new("Cancel")
        $this.CancelButton.SetBounds($buttonStartX + $buttonWidth + $buttonSpacing, $buttonY, $buttonWidth, 3)
        $this.CancelButton.OnClick = {
            $dialogRef.SelectedPath = ""
            $dialogRef.DialogResult = $false
            $dialogRef.Active = $false
        }.GetNewClosure()
        $this.CancelButton.Initialize($global:ServiceContainer)
        $this.AddChild($this.CancelButton)
        
        # Set initial focus
        $this.FileTree.Focus()
        
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
                
                $this.Active = $false
            }
        }
    }
    
    [void] OnBoundsChanged() {
        # Dialog is positioned manually in OnInitialize
        # This could be enhanced to support resizing
    }
    
    [string] OnRender() {
        # Draw dark overlay background
        $sb = Get-PooledStringBuilder 2048
        
        # Semi-transparent background overlay
        $overlayColor = if ($this.Theme) { $this.Theme.GetBgColor("dialog.overlay") } else { "`e[48;2;0;0;0m" }
        
        for ($y = 0; $y -lt [Console]::WindowHeight; $y++) {
            $sb.Append([VT]::MoveTo(0, $y))
            $sb.Append($overlayColor)
            $sb.Append([StringCache]::GetSpaces([Console]::WindowWidth))
        }
        
        # Dialog border
        $centerX = ([Console]::WindowWidth - $this._dialogWidth) / 2
        $centerY = ([Console]::WindowHeight - $this._dialogHeight) / 2
        
        $borderColor = if ($this.Theme) { $this.Theme.GetColor("dialog.border") } else { "`e[38;2;100;100;100m" }
        $bgColor = if ($this.Theme) { $this.Theme.GetBgColor("dialog.background") } else { "`e[48;2;40;40;40m" }
        
        # Draw dialog background
        for ($y = 0; $y -lt $this._dialogHeight; $y++) {
            $sb.Append([VT]::MoveTo([int]$centerX, [int]$centerY + $y))
            $sb.Append($bgColor)
            $sb.Append([StringCache]::GetSpaces($this._dialogWidth))
        }
        
        # Draw border
        $sb.Append([VT]::MoveTo([int]$centerX, [int]$centerY))
        $sb.Append($borderColor)
        $sb.Append([VT]::TL() + ([VT]::H() * ($this._dialogWidth - 2)) + [VT]::TR())
        
        for ($y = 1; $y -lt $this._dialogHeight - 1; $y++) {
            $sb.Append([VT]::MoveTo([int]$centerX, [int]$centerY + $y))
            $sb.Append($borderColor)
            $sb.Append([VT]::V())
            
            $sb.Append([VT]::MoveTo([int]$centerX + $this._dialogWidth - 1, [int]$centerY + $y))
            $sb.Append($borderColor)
            $sb.Append([VT]::V())
        }
        
        $sb.Append([VT]::MoveTo([int]$centerX, [int]$centerY + $this._dialogHeight - 1))
        $sb.Append($borderColor)
        $sb.Append([VT]::BL() + ([VT]::H() * ($this._dialogWidth - 2)) + [VT]::BR())
        
        # Title
        if ($this.DialogTitle) {
            $sb.Append([VT]::MoveTo([int]$centerX + 2, [int]$centerY))
            $titleColor = if ($this.Theme) { $this.Theme.GetColor("dialog.title") } else { "`e[38;2;255;255;255m" }
            $sb.Append($titleColor)
            $sb.Append(" $($this.DialogTitle) ")
        }
        
        $sb.Append([VT]::Reset())
        
        # Render children on top
        foreach ($child in $this.Children) {
            if ($child.Visible) {
                $sb.Append($child.Render())
            }
        }
        
        $result = $sb.ToString()
        Return-PooledStringBuilder $sb
        return $result
    }
    
    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        switch ($key.Key) {
            ([System.ConsoleKey]::Escape) {
                $this.SelectedPath = ""
                $this.DialogResult = $false
                $this.Active = $false
                return $true
            }
            ([System.ConsoleKey]::Enter) {
                if ($this.PathBox.IsFocused) {
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
                            $this.Active = $false
                        }
                    }
                    return $true
                }
                # Let other controls handle Enter
                break
            }
            ([System.ConsoleKey]::Tab) {
                # Cycle focus between controls
                if ($this.PathBox.IsFocused) {
                    $this.FileTree.Focus()
                } elseif ($this.FileTree.IsFocused) {
                    $this.SelectButton.Focus()
                } elseif ($this.SelectButton.IsFocused) {
                    $this.CancelButton.Focus()
                } else {
                    $this.PathBox.Focus()
                }
                return $true
            }
        }
        
        # Let base Screen handle other input
        return ([Screen]$this).HandleInput($key)
    }
}