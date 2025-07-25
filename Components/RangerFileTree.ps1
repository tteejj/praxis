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
    
    # Events
    [scriptblock]$OnFileSelected = {}
    
    hidden [ThemeManager]$Theme
    
    RangerFileTree() : base() {
        $this.CurrentPath = (Get-Location).Path
        $this.IsFocusable = $true
        $this.CreatePanes()
    }
    
    RangerFileTree([string]$path) : base() {
        $this.CurrentPath = $path
        $this.IsFocusable = $true
        $this.CreatePanes()
    }
    
    [void] CreatePanes() {
        # Create parent pane
        $this.ParentPane = [FastFileTree]::new()
        $this.ParentPane.ShowBorder = $true
        $this.ParentPane.Title = "Parent"
        $this.ParentPane.ShowSize = $false
        $this.AddChild($this.ParentPane)
        
        # Create current pane
        $this.CurrentPane = [FastFileTree]::new()
        $this.CurrentPane.ShowBorder = $true
        $this.CurrentPane.Title = "Current"
        $this.CurrentPane.ShowSize = $true
        $this.AddChild($this.CurrentPane)
        
        # Create preview pane
        $this.PreviewPane = [FastFileTree]::new()
        $this.PreviewPane.ShowBorder = $true
        $this.PreviewPane.Title = "Preview"
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
            $this.ParentPane.Title = "Drives"
            $this.ParentPane._flatView.Clear()
            $this.ParentPane.Invalidate()
        }
        
        # Update current pane
        $this.CurrentPane.LoadDirectory($this.CurrentPath)
        $this.CurrentPane.Title = Split-Path $this.CurrentPath -Leaf
        if ($this.CurrentPane._flatView.Count -gt 0) {
            $this.CurrentPane.SelectIndex(0)
        }
        
        # Update preview pane
        $this.UpdatePreviewPane()
    }
    
    [void] UpdatePreviewPane() {
        $selected = $this.CurrentPane.GetSelectedNode()
        if (-not $selected) {
            $this.PreviewPane.Title = "Preview"
            $this.PreviewPane._flatView.Clear()
            $this.PreviewPane.Invalidate()
            return
        }
        
        if ($selected.IsDirectory) {
            # Show directory contents
            $this.PreviewPane.LoadDirectory($selected.FullPath)
            $this.PreviewPane.Title = $selected.Name
        } else {
            # Show file preview
            $this.PreviewPane.Title = "File: $($selected.Name)"
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
        $leftWidth = [int]($totalWidth * $this.LeftPaneWidth)
        $centerWidth = [int]($totalWidth * $this.CenterPaneWidth)
        $rightWidth = $totalWidth - $leftWidth - $centerWidth
        
        # Position panes
        $this.ParentPane.SetBounds($this.X, $this.Y, $leftWidth, $this.Height)
        $this.CurrentPane.SetBounds($this.X + $leftWidth, $this.Y, $centerWidth, $this.Height)
        $this.PreviewPane.SetBounds($this.X + $leftWidth + $centerWidth, $this.Y, $rightWidth, $this.Height)
    }
    
    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        # Handle navigation keys
        switch ($key.Key) {
            ([System.ConsoleKey]::LeftArrow) {
                # Navigate to parent directory
                $parentPath = Split-Path $this.CurrentPath -Parent
                if ($parentPath) {
                    $this.NavigateToDirectory($parentPath)
                }
                return $true
            }
            ([System.ConsoleKey]::RightArrow) {
                # Navigate into selected directory
                $selected = $this.CurrentPane.GetSelectedNode()
                if ($selected -and $selected.IsDirectory) {
                    $this.NavigateToDirectory($selected.FullPath)
                }
                return $true
            }
            ([System.ConsoleKey]::H) {
                if (-not $key.Modifiers) {
                    # Toggle hidden files
                    # TODO: Implement hidden file toggle
                    return $true
                }
            }
        }
        
        # Let current pane handle other input
        return $this.CurrentPane.HandleInput($key)
    }
    
    [void] OnGotFocus() {
        ([UIElement]$this).OnGotFocus()
        # Focus the current pane
        if ($this.CurrentPane) {
            $this.CurrentPane.Focus()
        }
    }
    
    [void] Focus() {
        ([UIElement]$this).Focus()
        # Also focus the current pane
        if ($this.CurrentPane) {
            $this.CurrentPane.Focus()
        }
    }
}