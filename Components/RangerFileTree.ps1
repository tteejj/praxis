# RangerFileTree.ps1 - Ranger-style 3-pane file browser
# Left: Parent directory, Center: Current directory, Right: Preview/child

class RangerFileTree : Container {
    [string]$CurrentPath
    [FileSystemNode]$ParentNode
    [FileSystemNode]$CurrentNode
    [FileSystemNode]$PreviewNode
    
    # Three panes
    [FastFileTree]$ParentPane
    [FastFileTree]$CurrentPane
    [FastFileTree]$PreviewPane
    
    # Layout
    [double]$LeftPaneWidth = 0.25
    [double]$CenterPaneWidth = 0.35
    [double]$RightPaneWidth = 0.40
    
    # File operations
    [System.Collections.ArrayList]$MarkedFiles
    [FileOperationService]$FileOperationService
    [bool]$ShowMarkedIndicator = $true
    
    # Events
    [scriptblock]$OnFileSelected = {}
    
    hidden [ThemeManager]$Theme
    
    RangerFileTree() : base() {
        $this.CurrentPath = (Get-Location).Path
        $this.IsFocusable = $true
        $this.MarkedFiles = [System.Collections.ArrayList]::new()
        $this.CreatePanes()
    }
    
    RangerFileTree([string]$path) : base() {
        $this.CurrentPath = $path
        $this.IsFocusable = $true
        $this.MarkedFiles = [System.Collections.ArrayList]::new()
        $this.CreatePanes()
    }
    
    [void] CreatePanes() {
        # Create parent pane
        $this.ParentPane = [FastFileTree]::new()
        $this.ParentPane.ShowBorder = $false  # MainScreen draws the outer border
        $this.ParentPane.Title = ""  # Title will be set dynamically
        $this.ParentPane.ShowSize = $false
        $this.AddChild($this.ParentPane)
        
        # Create current pane
        $this.CurrentPane = [FastFileTree]::new()
        $this.CurrentPane.ShowBorder = $false  # MainScreen draws the outer border
        $this.CurrentPane.Title = ""  # Title will be set dynamically
        $this.CurrentPane.ShowSize = $true
        $this.AddChild($this.CurrentPane)
        
        # Create preview pane
        $this.PreviewPane = [FastFileTree]::new()
        $this.PreviewPane.ShowBorder = $false  # MainScreen draws the outer border
        $this.PreviewPane.Title = ""  # Title will be set dynamically
        $this.PreviewPane.ShowSize = $true
        $this.AddChild($this.PreviewPane)
        
        # Set up event handlers
        $ranger = $this
        $this.CurrentPane.OnSelectionChanged = {
            $ranger.UpdatePreviewPane()
        }.GetNewClosure()
        
        $this.CurrentPane.OnFileSelected = {
            param($node)
            if ($node.IsDirectory) {
                $ranger.NavigateToDirectory($node.FullPath)
            } else {
                if ($ranger.OnFileSelected) {
                    & $ranger.OnFileSelected $node
                }
            }
        }.GetNewClosure()
    }
    
    [void] OnInitialize() {
        # Initialize theme
        $this.Theme = $this.ServiceContainer.GetService('ThemeManager')
        
        # Get file operation service
        $this.FileOperationService = $this.ServiceContainer.GetService('FileOperationService')
        
        # Initialize child panes
        $this.ParentPane.ServiceContainer = $this.ServiceContainer
        $this.ParentPane.OnInitialize()
        $this.CurrentPane.ServiceContainer = $this.ServiceContainer
        $this.CurrentPane.OnInitialize()
        $this.PreviewPane.ServiceContainer = $this.ServiceContainer
        $this.PreviewPane.OnInitialize()
        # Load initial directory
        $this.NavigateToDirectory($this.CurrentPath)
    }
    
    [void] NavigateToDirectory([string]$path) {
        if (-not (Test-Path $path -PathType Container)) {
            return
        }
        
        $this.CurrentPath = Resolve-Path $path
        
        # Update parent pane
        $parentPath = Split-Path $this.CurrentPath -Parent
        if ($parentPath) {
            $this.ParentPane.LoadDirectory($parentPath)
            # Select current directory in parent
            $currentName = Split-Path $this.CurrentPath -Leaf
            for ($i = 0; $i -lt $this.ParentPane._flatView.Count; $i++) {
                if ($this.ParentPane._flatView[$i].Name -eq $currentName) {
                    $this.ParentPane.SelectIndex($i)
                    break
                }
            }
        } else {
            # At root, show drives or root
            $this.ParentPane.Title = ""
            $this.ParentPane._flatView.Clear()
            $this.ParentPane.Invalidate()
        }
        
        # Update current pane
        $this.CurrentPane.LoadDirectory($this.CurrentPath)
        $this.CurrentPane.Title = ""  # No title needed - path shows in status
        if ($this.CurrentPane._flatView.Count -gt 0) {
            $this.CurrentPane.SelectIndex(0)
        } else {
            if ($global:Logger) {
                $global:Logger.Warning("RangerFileTree: No items in current directory")
            }
        }
        
        # Update preview pane
        $this.UpdatePreviewPane()
    }
    
    [void] UpdatePreviewPane() {
        $selected = $this.CurrentPane.GetSelectedNode()
        if (-not $selected) {
            $this.PreviewPane.Title = ""
            $this.PreviewPane._flatView.Clear()
            $this.PreviewPane.Invalidate()
            return
        }
        
        if ($selected.IsDirectory) {
            # Show directory contents
            $this.PreviewPane.LoadDirectory($selected.FullPath)
            $this.PreviewPane.Title = ""
        } else {
            # Show file preview
            $this.PreviewPane.Title = ""
            $this.PreviewPane._flatView.Clear()
            
            # Could add file preview logic here (first N lines, file info, etc.)
            # For now, just show file info
            $info = [FileSystemNode]::new($selected.FullPath)
            $info.Name = "Size: $($selected.GetSizeString())"
            $this.PreviewPane._flatView.Add($info) | Out-Null
            
            $info2 = [FileSystemNode]::new($selected.FullPath)
            $info2.Name = "Modified: $($selected.LastModified.ToString('yyyy-MM-dd HH:mm'))"
            $this.PreviewPane._flatView.Add($info2) | Out-Null
            
            $this.PreviewPane.Invalidate()
        }
    }
    
    [void] OnBoundsChanged() {
        # Calculate pane widths
        $totalWidth = $this.Width
        if ($totalWidth -le 0) {
            if ($global:Logger) {
                $global:Logger.Warning("RangerFileTree: Invalid width $totalWidth")
            }
            return
        }
        
        $leftWidth = [int]($totalWidth * $this.LeftPaneWidth)
        $centerWidth = [int]($totalWidth * $this.CenterPaneWidth)
        $rightWidth = $totalWidth - $leftWidth - $centerWidth
        # Position panes
        $this.ParentPane.SetBounds($this.X, $this.Y, $leftWidth, $this.Height)
        $this.CurrentPane.SetBounds($this.X + $leftWidth, $this.Y, $centerWidth, $this.Height)
        $this.PreviewPane.SetBounds($this.X + $leftWidth + $centerWidth, $this.Y, $rightWidth, $this.Height)
    }
    
    [string] OnRender() {
        # Debug rendering to ensure we're actually drawing
        # Get base rendering from Container
        $baseRender = ([Container]$this).OnRender()
        
        # Add vertical separators between panes
        $sb = Get-PooledStringBuilder 1024
        $sb.Append($baseRender)
        
        if ($this.Theme) {
            $borderColor = $this.Theme.GetColor('border.normal')
            $sb.Append($borderColor)
            
            # Draw vertical separator between parent and current panes
            $leftSeparatorX = $this.X + [int]($this.Width * $this.LeftPaneWidth)
            for ($y = $this.Y + 1; $y -lt ($this.Y + $this.Height - 1); $y++) {
                $sb.Append([VT]::MoveTo($leftSeparatorX, $y))
                $sb.Append('│')
            }
            
            # Add T-junctions at top and bottom for left separator
            $sb.Append([VT]::MoveTo($leftSeparatorX, $this.Y))
            $sb.Append('┬')  # Top T-junction
            $sb.Append([VT]::MoveTo($leftSeparatorX, $this.Y + $this.Height - 1))
            $sb.Append('┴')  # Bottom T-junction
            
            # Draw vertical separator between current and preview panes
            $rightSeparatorX = $this.X + [int]($this.Width * $this.LeftPaneWidth) + [int]($this.Width * $this.CenterPaneWidth)
            for ($y = $this.Y + 1; $y -lt ($this.Y + $this.Height - 1); $y++) {
                $sb.Append([VT]::MoveTo($rightSeparatorX, $y))
                $sb.Append('│')
            }
            
            # Add T-junctions at top and bottom for right separator
            $sb.Append([VT]::MoveTo($rightSeparatorX, $this.Y))
            $sb.Append('┬')  # Top T-junction
            $sb.Append([VT]::MoveTo($rightSeparatorX, $this.Y + $this.Height - 1))
            $sb.Append('┴')  # Bottom T-junction

        }
        
        # If we have marked files, show indicator in status area
        if ($this.MarkedFiles.Count -gt 0 -and $this.ShowMarkedIndicator) {
            # Add marked files indicator at bottom-right
            if ($this.Theme) {
                $markColor = $this.Theme.GetColor('warning')
                $x = $this.X + $this.Width - 20
                $y = $this.Y + $this.Height - 1
                
                $sb.Append([VT]::MoveTo($x, $y))
                $sb.Append($markColor)
                $sb.Append(" [$($this.MarkedFiles.Count) marked] ")
                
            }
        }
        
        $result = $sb.ToString()
        Return-PooledStringBuilder $sb
        return $result
    }
    
    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        # Handle vim-style navigation keys
        if (-not $key.Modifiers) {
            switch ($key.KeyChar) {
                'h' {
                    # Navigate to parent directory (left)
                    $parentPath = Split-Path $this.CurrentPath -Parent
                    if ($parentPath) {
                        $this.NavigateToDirectory($parentPath)
                    }
                    return $true
                }
                'l' {
                    # Navigate into selected directory or open file (right)
                    $selected = $this.CurrentPane.GetSelectedNode()
                    if ($selected) {
                        if ($selected.IsDirectory) {
                            $this.NavigateToDirectory($selected.FullPath)
                        } else {
                            # Open file
                            if ($this.OnFileSelected) {
                                & $this.OnFileSelected $selected
                            }
                        }
                    }
                    return $true
                }
                'j' {
                    # Move down - create a synthetic down arrow key
                    $downKey = New-Object System.ConsoleKeyInfo -ArgumentList ([char]0, [System.ConsoleKey]::DownArrow, $false, $false, $false)
                    return $this.CurrentPane.HandleInput($downKey)
                }
                'k' {
                    # Move up - create a synthetic up arrow key
                    $upKey = New-Object System.ConsoleKeyInfo -ArgumentList ([char]0, [System.ConsoleKey]::UpArrow, $false, $false, $false)
                    return $this.CurrentPane.HandleInput($upKey)
                }
                '.' {
                    # Toggle hidden files
                    # TODO: Implement hidden file toggle
                    return $true
                }
                'y' {
                    # Yank (copy) current file/directory
                    $selected = $this.CurrentPane.GetSelectedNode()
                    if ($selected -and $this.FileOperationService) {
                        $paths = if ($this.MarkedFiles.Count -gt 0) { @($this.MarkedFiles) } else { @($selected.FullPath) }
                        $this.FileOperationService.YankItems($paths, $false)
                        $this.ShowOperationFeedback("Yanked $($paths.Count) item(s)")
                    }
                    return $true
                }
                'd' {
                    # Cut current file/directory
                    $selected = $this.CurrentPane.GetSelectedNode()
                    if ($selected -and $this.FileOperationService) {
                        $paths = if ($this.MarkedFiles.Count -gt 0) { @($this.MarkedFiles) } else { @($selected.FullPath) }
                        $this.FileOperationService.YankItems($paths, $true)
                        $this.ShowOperationFeedback("Cut $($paths.Count) item(s)")
                    }
                    return $true
                }
                'p' {
                    # Paste yanked/cut items
                    if ($this.FileOperationService) {
                        $result = $this.FileOperationService.PasteItems($this.CurrentPath)
                        $this.ShowOperationFeedback($result.Message)
                        if ($result.Success) {
                            $this.RefreshCurrentPane()
                        }
                    }
                    return $true
                }
                'r' {
                    # Rename current file/directory
                    $selected = $this.CurrentPane.GetSelectedNode()
                    if ($selected) {
                        $this.ShowRenameDialog($selected)
                    }
                    return $true
                }
                ' ' {
                    # Toggle mark on current file
                    $selected = $this.CurrentPane.GetSelectedNode()
                    if ($selected) {
                        if ($this.MarkedFiles.Contains($selected.FullPath)) {
                            $this.MarkedFiles.Remove($selected.FullPath) | Out-Null
                        } else {
                            $this.MarkedFiles.Add($selected.FullPath) | Out-Null
                        }
                        # Move to next item after marking
                        $downKey = New-Object System.ConsoleKeyInfo -ArgumentList ([char]0, [System.ConsoleKey]::DownArrow, $false, $false, $false)
                        $this.CurrentPane.HandleInput($downKey)
                        $this.Invalidate()
                    }
                    return $true
                }
            }
        }
        
        # Handle uppercase keys with Shift
        if ($key.Modifiers -eq [System.ConsoleModifiers]::Shift) {
            switch ($key.KeyChar) {
                'D' {
                    # Delete with confirmation
                    $selected = $this.CurrentPane.GetSelectedNode()
                    if ($selected) {
                        $paths = if ($this.MarkedFiles.Count -gt 0) { @($this.MarkedFiles) } else { @($selected.FullPath) }
                        $this.ShowDeleteConfirmation($paths)
                    }
                    return $true
                }
            }
        }
        
        # Also handle arrow keys for compatibility
        switch ($key.Key) {
            ([System.ConsoleKey]::LeftArrow) {
                # Navigate to parent directory, but let MainScreen handle if no parent
                $parentPath = Split-Path $this.CurrentPath -Parent
                if ($parentPath -and $parentPath -ne $this.CurrentPath) {
                    $this.NavigateToDirectory($parentPath)
                    return $true
                }
                # No parent available - let MainScreen handle (switch focus to menu)
                return $false
            }
            ([System.ConsoleKey]::RightArrow) {
                # Navigate into selected directory
                $selected = $this.CurrentPane.GetSelectedNode()
                if ($selected -and $selected.IsDirectory) {
                    $this.NavigateToDirectory($selected.FullPath)
                }
                return $true
            }
        }
        
        # Let current pane handle other input
        return $this.CurrentPane.HandleInput($key)
    }
    
    [void] OnGotFocus() {
        ([UIElement]$this).OnGotFocus()
        # Don't automatically focus child pane - we'll handle input and delegate as needed
    }
    
    [void] Focus() {
        # Call base Focus to set IsFocused = true
        ([UIElement]$this).Focus()
        
        # Don't focus child panes - we'll handle the input routing ourselves
    }
    
    # Helper methods for file operations
    [void] ShowOperationFeedback([string]$message) {
        # Use toast service if available, otherwise log
        $toastService = $this.ServiceContainer.GetService('ToastService')
        if ($toastService) {
            $toastService.ShowToast($message, 'info', 2000)
        } elseif ($global:Logger) {
            $global:Logger.Info("File operation: $message")
        }
    }
    
    [void] RefreshCurrentPane() {
        # Reload current directory
        $this.CurrentPane.LoadDirectory($this.CurrentPath)
        if ($this.CurrentPane._flatView.Count -gt 0) {
            # Try to maintain selection position
            $currentIndex = $this.CurrentPane.SelectedIndex
            if ($currentIndex -ge $this.CurrentPane._flatView.Count) {
                $currentIndex = $this.CurrentPane._flatView.Count - 1
            }
            $this.CurrentPane.SelectIndex($currentIndex)
        }
        $this.UpdatePreviewPane()
        $this.Invalidate()
    }
    
    [void] ShowRenameDialog([FileSystemNode]$node) {
        # Create and show rename dialog
        # Use late binding to avoid type loading issues
        $dialogType = [type]"TextInputDialog"
        if (-not $dialogType) {
            $this.ShowOperationFeedback("Rename dialog not available")
            return
        }
        
        $dialog = $dialogType::new("Rename", "Enter new name:", $node.Name)
        $screenManager = $this.ServiceContainer.GetService("ScreenManager")
        $screenManager.Push($dialog)
        
        # Handle dialog result
        $ranger = $this
        $dialog.OnSubmit = {
            param($newName)
            if ($newName -and $newName -ne $node.Name) {
                $result = $ranger.FileOperationService.RenameItem($node.FullPath, $newName)
                $ranger.ShowOperationFeedback($result.Message)
                if ($result.Success) {
                    $ranger.RefreshCurrentPane()
                }
            }
        }.GetNewClosure()
    }
    
    [void] ShowDeleteConfirmation([string[]]$paths) {
        # Create simple confirmation dialog with safe late binding
        $message = "Delete $($paths.Count) item(s)? This will move them to recycle bin."
        
        # Use late binding to avoid type loading issues
        $dialogType = $null
        try {
            $dialogType = Get-TypeData -TypeName "ConfirmationDialog" -ErrorAction SilentlyContinue
            if (-not $dialogType) {
                # Try alternative method
                $dialogType = [System.Type]::GetType("ConfirmationDialog")
            }
        } catch {
            # Type not available yet
        }
        
        if (-not $dialogType) {
            $this.ShowOperationFeedback("Delete confirmation dialog not available")
            return
        }
        
        try {
            $dialog = New-Object -TypeName "ConfirmationDialog" -ArgumentList $message
            $screenManager = $this.ServiceContainer.GetService("ScreenManager")
            $screenManager.Push($dialog)
            
            # Handle dialog result
            $ranger = $this
            $dialog.OnConfirm = {
                $result = $ranger.FileOperationService.DeleteItems($paths, $true)
                $ranger.ShowOperationFeedback($result.Message)
                if ($result.Success) {
                    # Clear marked files if any were deleted
                    foreach ($path in $paths) {
                        $ranger.MarkedFiles.Remove($path) | Out-Null
                    }
                    $ranger.RefreshCurrentPane()
                }
            }.GetNewClosure()
            
            $dialog.OnCancel = {
                $ranger.ShowOperationFeedback("Delete cancelled")
            }.GetNewClosure()
            
        } catch {
            $this.ShowOperationFeedback("Failed to create delete confirmation dialog: $($_.Exception.Message)")
        }
    }
    
}