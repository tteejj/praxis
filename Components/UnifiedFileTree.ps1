# UnifiedFileTree.ps1 - The ONE file tree component with consistent theming and behavior
# Enhances RangerFileTree with unified theme integration and improved API

class UnifiedFileTree : FocusableComponent {
    # FILE TREE MODES
    [UnifiedFileTreeMode]$Mode = [UnifiedFileTreeMode]::Ranger  # Ranger (3-pane), Simple (1-pane), Dual (2-pane)
    
    # CORE PROPERTIES
    [string]$CurrentPath = ""
    [scriptblock]$OnFileSelected = {}
    [scriptblock]$OnDirectoryChanged = {}
    
    # RANGER MODE PROPERTIES (3-pane layout)
    [FileSystemNode]$ParentNode
    [FileSystemNode]$CurrentNode
    [FileSystemNode]$PreviewNode
    [double]$LeftPaneWidth = 0.25
    [double]$CenterPaneWidth = 0.35
    [double]$RightPaneWidth = 0.40
    
    # FILE OPERATIONS
    [System.Collections.ArrayList]$MarkedFiles
    [FileOperationService]$FileOperationService
    [bool]$ShowMarkedIndicator = $true
    [bool]$ShowHiddenFiles = $false
    [bool]$ShowFileSize = $true
    [bool]$ShowFileDate = $true
    
    # VISUAL PROPERTIES
    [bool]$ShowBorder = $true
    [BorderType]$BorderType = [BorderType]::Rounded
    [string]$Title = "Files"
    
    # INTERNAL PANES - UnifiedList components for consistency
    hidden [UnifiedList]$_leftPane = $null
    hidden [UnifiedList]$_centerPane = $null
    hidden [UnifiedList]$_rightPane = $null
    
    # LAYOUT CACHE
    hidden [int]$_leftPaneX = 0
    hidden [int]$_leftPaneWidth = 0
    hidden [int]$_centerPaneX = 0
    hidden [int]$_centerPaneWidth = 0
    hidden [int]$_rightPaneX = 0
    hidden [int]$_rightPaneWidth = 0
    hidden [int]$_paneY = 0
    hidden [int]$_paneHeight = 0
    
    # THEME COLORS - Cached once, consistent everywhere
    hidden [hashtable]$_colors = @{}
    hidden [ThemeManager]$Theme
    
    # CURRENT DIRECTORY CONTENTS
    hidden [System.Collections.Generic.List[FileSystemNode]]$_currentItems
    hidden [System.Collections.Generic.List[FileSystemNode]]$_parentItems
    hidden [System.Collections.Generic.List[FileSystemNode]]$_previewItems
    
    UnifiedFileTree() : base() {
        $this.CurrentPath = (Get-Location).Path
        $this.MarkedFiles = [System.Collections.ArrayList]::new()
        $this._currentItems = [System.Collections.Generic.List[FileSystemNode]]::new()
        $this._parentItems = [System.Collections.Generic.List[FileSystemNode]]::new()
        $this._previewItems = [System.Collections.Generic.List[FileSystemNode]]::new()
        $this.IsFocusable = $true
        $this.FocusStyle = 'minimal'
    }
    
    UnifiedFileTree([string]$path) : base() {
        $this.CurrentPath = $path
        $this.MarkedFiles = [System.Collections.ArrayList]::new()
        $this._currentItems = [System.Collections.Generic.List[FileSystemNode]]::new()
        $this._parentItems = [System.Collections.Generic.List[FileSystemNode]]::new()
        $this._previewItems = [System.Collections.Generic.List[FileSystemNode]]::new()
        $this.IsFocusable = $true
        $this.FocusStyle = 'minimal'
    }
    
    UnifiedFileTree([UnifiedFileTreeMode]$mode, [string]$path) : base() {
        $this.Mode = $mode
        $this.CurrentPath = $path
        $this.MarkedFiles = [System.Collections.ArrayList]::new()
        $this._currentItems = [System.Collections.Generic.List[FileSystemNode]]::new()
        $this._parentItems = [System.Collections.Generic.List[FileSystemNode]]::new()
        $this._previewItems = [System.Collections.Generic.List[FileSystemNode]]::new()
        $this.IsFocusable = $true
        $this.FocusStyle = 'minimal'
    }
    
    # ═══════════════════════════════════════════════════════════════════════════════════════
    # INITIALIZATION & THEME MANAGEMENT - Guaranteed consistent theming
    # ═══════════════════════════════════════════════════════════════════════════════════════
    
    [void] OnInitialize() {
        ([FocusableComponent]$this).OnInitialize()
        $this.Theme = $this.ServiceContainer.GetService("ThemeManager")
        $this.FileOperationService = $this.ServiceContainer.GetService('FileOperationService')
        
        if ($this.Theme) {
            # Subscribe to theme changes
            $eventBus = $this.ServiceContainer.GetService('EventBus')
            if ($eventBus) {
                $eventBus.Subscribe('theme.changed', {
                    param($sender, $eventData)
                    $this.CacheThemeColors()
                    $this.InvalidateAllPanes()
                }.GetNewClosure())
            }
            
            $this.CacheThemeColors()
        }
        
        # Create internal panes based on mode
        $this.CreatePanes()
        
        # Load initial directory
        if ($this.CurrentPath) {
            $this.NavigateToDirectory($this.CurrentPath)
        }
    }
    
    [void] CacheThemeColors() {
        if ($this.Theme) {
            $this._colors = @{
                # Text colors - all amber
                text = $this.Theme.GetColor('text.primary')
                textSecondary = $this.Theme.GetColor('text.secondary')
                textDisabled = $this.Theme.GetColor('text.disabled')
                
                # File type colors
                directory = $this.Theme.GetColor('color.primary')
                file = $this.Theme.GetColor('text.primary')
                executable = $this.Theme.GetColor('status.success')
                hidden = $this.Theme.GetColor('text.disabled')
                
                # Selection colors - unified with other components
                selectedText = $this.Theme.GetColor('focus.reverse.text')
                selectedBg = $this.Theme.GetBgColor('focus.reverse.background')
                
                # Border and structure
                border = $this.Theme.GetColor('border.normal')
                borderFocused = $this.Theme.GetColor('border.focused')
                paneSeparator = $this.Theme.GetColor('border.normal')
                
                # Focus indicator
                focusIndicator = $this.Theme.GetColor('color.primary')
                
                # Status indicators
                marked = $this.Theme.GetColor('status.warning')
                symlink = $this.Theme.GetColor('status.info')
            }
        }
    }
    
    [void] CreatePanes() {
        # Remove existing panes
        if ($this._leftPane) { $this.RemoveChild($this._leftPane) }
        if ($this._centerPane) { $this.RemoveChild($this._centerPane) }
        if ($this._rightPane) { $this.RemoveChild($this._rightPane) }
        
        $tree = $this
        
        switch ($this.Mode) {
            ([UnifiedFileTreeMode]::Ranger) {
                # Create three panes using UnifiedList
                $this._leftPane = [UnifiedList]::new([UnifiedListMode]::SimpleList)
                $this._leftPane.ShowBorder = $false
                $this._leftPane.Title = ""
                $this._leftPane.ItemRenderer = { param($item) return $tree.RenderFileItem($item) }
                $this.AddChild($this._leftPane)
                
                $this._centerPane = [UnifiedList]::new([UnifiedListMode]::SimpleList)
                $this._centerPane.ShowBorder = $false
                $this._centerPane.Title = ""
                $this._centerPane.ItemRenderer = { param($item) return $tree.RenderFileItem($item) }
                $this._centerPane.OnSelectionChanged = { $tree.UpdatePreviewPane() }.GetNewClosure()
                $this._centerPane.OnItemActivated = { param($item) $tree.ActivateItem($item) }.GetNewClosure()
                $this.AddChild($this._centerPane)
                
                $this._rightPane = [UnifiedList]::new([UnifiedListMode]::SimpleList)
                $this._rightPane.ShowBorder = $false
                $this._rightPane.Title = ""
                $this._rightPane.ItemRenderer = { param($item) return $tree.RenderFileItem($item) }
                $this.AddChild($this._rightPane)
            }
            ([UnifiedFileTreeMode]::Simple) {
                # Single pane
                $this._centerPane = [UnifiedList]::new([UnifiedListMode]::SimpleList)
                $this._centerPane.ShowBorder = $false
                $this._centerPane.Title = $this.Title
                $this._centerPane.ItemRenderer = { param($item) return $tree.RenderFileItem($item) }
                $this._centerPane.OnItemActivated = { param($item) $tree.ActivateItem($item) }.GetNewClosure()
                $this.AddChild($this._centerPane)
            }
            ([UnifiedFileTreeMode]::Dual) {
                # Two panes
                $this._centerPane = [UnifiedList]::new([UnifiedListMode]::SimpleList)
                $this._centerPane.ShowBorder = $false
                $this._centerPane.Title = ""
                $this._centerPane.ItemRenderer = { param($item) return $tree.RenderFileItem($item) }
                $this._centerPane.OnSelectionChanged = { $tree.UpdatePreviewPane() }.GetNewClosure()
                $this._centerPane.OnItemActivated = { param($item) $tree.ActivateItem($item) }.GetNewClosure()
                $this.AddChild($this._centerPane)
                
                $this._rightPane = [UnifiedList]::new([UnifiedListMode]::SimpleList)
                $this._rightPane.ShowBorder = $false
                $this._rightPane.Title = ""
                $this._rightPane.ItemRenderer = { param($item) return $tree.RenderFileItem($item) }
                $this.AddChild($this._rightPane)
            }
        }
        
        # Initialize panes
        if ($this._leftPane) { $this._leftPane.Initialize($this.ServiceContainer) }
        if ($this._centerPane) { $this._centerPane.Initialize($this.ServiceContainer) }
        if ($this._rightPane) { $this._rightPane.Initialize($this.ServiceContainer) }
    }
    
    # ═══════════════════════════════════════════════════════════════════════════════════════
    # LAYOUT MANAGEMENT - Automatic pane positioning
    # ═══════════════════════════════════════════════════════════════════════════════════════
    
    [void] OnBoundsChanged() {
        ([FocusableComponent]$this).OnBoundsChanged()
        $this.CalculateLayout()
        $this.PositionPanes()
    }
    
    [void] CalculateLayout() {
        # Calculate content area (inside border)
        if ($this.ShowBorder) {
            $contentX = $this.X + 1
            $contentY = $this.Y + 1
            $contentWidth = $this.Width - 2
            $contentHeight = $this.Height - 2
        } else {
            $contentX = $this.X
            $contentY = $this.Y
            $contentWidth = $this.Width
            $contentHeight = $this.Height
        }
        
        $this._paneY = $contentY
        $this._paneHeight = $contentHeight
        
        # Calculate pane positions based on mode
        switch ($this.Mode) {
            ([UnifiedFileTreeMode]::Ranger) {
                # Three panes
                $this._leftPaneX = $contentX
                $this._leftPaneWidth = [int]($contentWidth * $this.LeftPaneWidth)
                
                $this._centerPaneX = $this._leftPaneX + $this._leftPaneWidth
                $this._centerPaneWidth = [int]($contentWidth * $this.CenterPaneWidth)
                
                $this._rightPaneX = $this._centerPaneX + $this._centerPaneWidth
                $this._rightPaneWidth = $contentWidth - $this._leftPaneWidth - $this._centerPaneWidth
            }
            ([UnifiedFileTreeMode]::Simple) {
                # Single pane
                $this._centerPaneX = $contentX
                $this._centerPaneWidth = $contentWidth
            }
            ([UnifiedFileTreeMode]::Dual) {
                # Two panes
                $this._centerPaneX = $contentX
                $this._centerPaneWidth = [int]($contentWidth * 0.5)
                
                $this._rightPaneX = $this._centerPaneX + $this._centerPaneWidth
                $this._rightPaneWidth = $contentWidth - $this._centerPaneWidth
            }
        }
    }
    
    [void] PositionPanes() {
        if ($this._leftPane) {
            $this._leftPane.SetBounds($this._leftPaneX, $this._paneY, $this._leftPaneWidth, $this._paneHeight)
        }
        if ($this._centerPane) {
            $this._centerPane.SetBounds($this._centerPaneX, $this._paneY, $this._centerPaneWidth, $this._paneHeight)
        }
        if ($this._rightPane) {
            $this._rightPane.SetBounds($this._rightPaneX, $this._paneY, $this._rightPaneWidth, $this._paneHeight)
        }
    }
    
    # ═══════════════════════════════════════════════════════════════════════════════════════
    # FILE SYSTEM OPERATIONS - Directory navigation and file handling
    # ═══════════════════════════════════════════════════════════════════════════════════════
    
    [void] NavigateToDirectory([string]$path) {
        if (-not (Test-Path $path -PathType Container)) {
            return
        }
        
        $oldPath = $this.CurrentPath
        $this.CurrentPath = Resolve-Path $path
        
        # Load directory contents
        $this.LoadCurrentDirectory()
        $this.LoadParentDirectory()
        $this.UpdatePreviewPane()
        
        # Fire directory changed event
        if ($this.OnDirectoryChanged -and $oldPath -ne $this.CurrentPath) {
            & $this.OnDirectoryChanged $this.CurrentPath
        }
    }
    
    [void] LoadCurrentDirectory() {
        $this._currentItems.Clear()
        
        try {
            $items = Get-ChildItem -Path $this.CurrentPath -Force:$this.ShowHiddenFiles -ErrorAction SilentlyContinue
            
            foreach ($item in $items) {
                if (-not $this.ShowHiddenFiles -and $item.Name.StartsWith('.')) {
                    continue
                }
                
                $node = $this.CreateFileSystemNode($item)
                $this._currentItems.Add($node)
            }
            
            # Sort: directories first, then files, both alphabetically
            $sortedItems = $this._currentItems | Sort-Object @{Expression={-not $_.IsDirectory}}, Name
            $this._currentItems.Clear()
            foreach ($item in $sortedItems) {
                $this._currentItems.Add($item)
            }
            
        } catch {
            if ($global:Logger) {
                $global:Logger.Error("UnifiedFileTree: Error loading directory '$($this.CurrentPath)': $_")
            }
        }
        
        # Update center pane
        if ($this._centerPane) {
            $this._centerPane.SetItems($this._currentItems)
        }
    }
    
    [void] LoadParentDirectory() {
        $this._parentItems.Clear()
        
        if ($this.Mode -ne [UnifiedFileTreeMode]::Ranger -or -not $this._leftPane) {
            return
        }
        
        $parentPath = Split-Path $this.CurrentPath -Parent
        if (-not $parentPath) {
            return
        }
        
        try {
            $items = Get-ChildItem -Path $parentPath -Directory -Force:$this.ShowHiddenFiles -ErrorAction SilentlyContinue
            
            foreach ($item in $items) {
                if (-not $this.ShowHiddenFiles -and $item.Name.StartsWith('.')) {
                    continue
                }
                
                $node = $this.CreateFileSystemNode($item)
                $this._parentItems.Add($node)
            }
            
            # Sort alphabetically
            $sortedItems = $this._parentItems | Sort-Object Name
            $this._parentItems.Clear()
            foreach ($item in $sortedItems) {
                $this._parentItems.Add($item)
            }
            
        } catch {
            if ($global:Logger) {
                $global:Logger.Error("UnifiedFileTree: Error loading parent directory '$parentPath': $_")
            }
        }
        
        # Update left pane and select current directory
        $this._leftPane.SetItems($this._parentItems)
        $currentName = Split-Path $this.CurrentPath -Leaf
        for ($i = 0; $i -lt $this._parentItems.Count; $i++) {
            if ($this._parentItems[$i].Name -eq $currentName) {
                $this._leftPane.SelectIndex($i)
                break
            }
        }
    }
    
    [void] UpdatePreviewPane() {
        if (-not $this._rightPane) {
            return
        }
        
        $this._previewItems.Clear()
        
        $selectedItem = $this._centerPane.GetSelectedItem()
        if (-not $selectedItem -or -not $selectedItem.IsDirectory) {
            $this._rightPane.SetItems($this._previewItems)
            return
        }
        
        try {
            $items = Get-ChildItem -Path $selectedItem.FullPath -Force:$this.ShowHiddenFiles -ErrorAction SilentlyContinue
            
            foreach ($item in $items) {
                if (-not $this.ShowHiddenFiles -and $item.Name.StartsWith('.')) {
                    continue
                }
                
                $node = $this.CreateFileSystemNode($item)
                $this._previewItems.Add($node)
            }
            
            # Sort: directories first, then files
            $sortedItems = $this._previewItems | Sort-Object @{Expression={-not $_.IsDirectory}}, Name
            $this._previewItems.Clear()
            foreach ($item in $sortedItems) {
                $this._previewItems.Add($item)
            }
            
        } catch {
            # Directory not accessible - clear preview
        }
        
        $this._rightPane.SetItems($this._previewItems)
    }
    
    [FileSystemNode] CreateFileSystemNode([System.IO.FileSystemInfo]$item) {
        $node = [FileSystemNode]::new()
        $node.Name = $item.Name
        $node.FullPath = $item.FullName
        $node.IsDirectory = $item.PSIsContainer
        $node.Size = if ($item.PSIsContainer) { 0 } else { $item.Length }
        $node.LastModified = $item.LastWriteTime
        $node.IsHidden = $item.Attributes -band [System.IO.FileAttributes]::Hidden
        $node.IsSymlink = $item.Attributes -band [System.IO.FileAttributes]::ReparsePoint
        $node.IsMarked = $this.MarkedFiles.Contains($item.FullName)
        return $node
    }
    
    [void] ActivateItem([FileSystemNode]$item) {
        if (-not $item) {
            return
        }
        
        if ($item.IsDirectory) {
            $this.NavigateToDirectory($item.FullPath)
        } else {
            if ($this.OnFileSelected) {
                & $this.OnFileSelected $item
            }
        }
    }
    
    # ═══════════════════════════════════════════════════════════════════════════════════════
    # RENDERING SYSTEM - File item display with consistent theming
    # ═══════════════════════════════════════════════════════════════════════════════════════
    
    [string] RenderContent() {
        $sb = Get-PooledStringBuilder 1024
        
        try {
            # Render border
            if ($this.ShowBorder) {
                $borderColor = if ($this.IsFocused) { $this._colors.borderFocused } else { $this._colors.border }
                $borderStr = [BorderStyle]::RenderBorder(
                    $this.X, $this.Y, $this.Width, $this.Height,
                    $this.BorderType, $borderColor
                )
                [void]$sb.Append($borderStr)
                
                # Title
                if ($this.Title) {
                    $titleText = " $($this.Title) "
                    $titleX = $this.X + 2
                    [void]$sb.Append([VT]::MoveTo($titleX, $this.Y))
                    [void]$sb.Append($this._colors.focusIndicator)
                    [void]$sb.Append($titleText)
                }
            }
            
            # Render pane separators for multi-pane modes
            if ($this.Mode -eq [UnifiedFileTreeMode]::Ranger) {
                $this.RenderPaneSeparators($sb)
            } elseif ($this.Mode -eq [UnifiedFileTreeMode]::Dual) {
                $this.RenderDualPaneSeparator($sb)
            }
            
            # Child panes render themselves
            return $sb.ToString()
        }
        finally {
            Return-PooledStringBuilder $sb
        }
    }
    
    [void] RenderPaneSeparators([System.Text.StringBuilder]$sb) {
        # Vertical separators between panes
        $sep1X = $this._centerPaneX - 1
        $sep2X = $this._rightPaneX - 1
        
        for ($y = $this._paneY; $y -lt ($this._paneY + $this._paneHeight); $y++) {
            [void]$sb.Append([VT]::MoveTo($sep1X, $y))
            [void]$sb.Append($this._colors.paneSeparator)
            [void]$sb.Append("│")
            
            [void]$sb.Append([VT]::MoveTo($sep2X, $y))
            [void]$sb.Append($this._colors.paneSeparator)
            [void]$sb.Append("│")
        }
    }
    
    [void] RenderDualPaneSeparator([System.Text.StringBuilder]$sb) {
        # Vertical separator between panes
        $sepX = $this._rightPaneX - 1
        
        for ($y = $this._paneY; $y -lt ($this._paneY + $this._paneHeight); $y++) {
            [void]$sb.Append([VT]::MoveTo($sepX, $y))
            [void]$sb.Append($this._colors.paneSeparator)
            [void]$sb.Append("│")
        }
    }
    
    [string] RenderFileItem([FileSystemNode]$item) {
        if (-not $item) {
            return ""
        }
        
        $sb = [System.Text.StringBuilder]::new()
        
        # File type indicator and color
        if ($item.IsDirectory) {
            [void]$sb.Append("📁 ")
        } elseif ($item.IsSymlink) {
            [void]$sb.Append("🔗 ")
        } elseif ($this.IsExecutable($item)) {
            [void]$sb.Append("⚡ ")
        } else {
            [void]$sb.Append("📄 ")
        }
        
        # File name
        [void]$sb.Append($item.Name)
        
        # Marked indicator
        if ($item.IsMarked -and $this.ShowMarkedIndicator) {
            [void]$sb.Append(" ★")
        }
        
        # Size and date (if enabled and space allows)
        if (-not $item.IsDirectory -and $this.ShowFileSize) {
            $sizeStr = $this.FormatFileSize($item.Size)
            [void]$sb.Append(" ($sizeStr)")
        }
        
        return $sb.ToString()
    }
    
    [bool] IsExecutable([FileSystemNode]$item) {
        $ext = [System.IO.Path]::GetExtension($item.Name).ToLower()
        return $ext -in @('.exe', '.bat', '.cmd', '.ps1', '.sh', '.py', '.rb', '.pl')
    }
    
    [string] FormatFileSize([long]$bytes) {
        if ($bytes -lt 1024) { return "$bytes B" }
        if ($bytes -lt 1MB) { return "{0:N1} KB" -f ($bytes / 1KB) }
        if ($bytes -lt 1GB) { return "{0:N1} MB" -f ($bytes / 1MB) }
        return "{0:N1} GB" -f ($bytes / 1GB)
    }
    
    # ═══════════════════════════════════════════════════════════════════════════════════════
    # INPUT HANDLING - File browser navigation
    # ═══════════════════════════════════════════════════════════════════════════════════════
    
    [bool] OnHandleInput([System.ConsoleKeyInfo]$key) {
        # Focus the center pane for navigation
        if ($this._centerPane -and -not $this._centerPane.IsFocused) {
            $focusManager = $this.ServiceContainer.GetService('FocusManager')
            if ($focusManager) {
                $focusManager.SetFocus($this._centerPane)
            }
        }
        
        switch ($key.Key) {
            ([System.ConsoleKey]::Backspace) {
                # Navigate to parent directory
                $parentPath = Split-Path $this.CurrentPath -Parent
                if ($parentPath) {
                    $this.NavigateToDirectory($parentPath)
                }
                return $true
            }
        }
        
        # Let the focused pane handle other input
        return $false
    }
    
    # ═══════════════════════════════════════════════════════════════════════════════════════
    # PUBLIC API - Simple, consistent methods
    # ═══════════════════════════════════════════════════════════════════════════════════════
    
    [void] Refresh() {
        $this.LoadCurrentDirectory()
        $this.LoadParentDirectory()
        $this.UpdatePreviewPane()
    }
    
    [void] NavigateUp() {
        $parentPath = Split-Path $this.CurrentPath -Parent
        if ($parentPath) {
            $this.NavigateToDirectory($parentPath)
        }
    }
    
    [FileSystemNode] GetSelectedItem() {
        if ($this._centerPane) {
            return $this._centerPane.GetSelectedItem()
        }
        return $null
    }
    
    [void] ToggleHiddenFiles() {
        $this.ShowHiddenFiles = -not $this.ShowHiddenFiles
        $this.Refresh()
    }
    
    [void] MarkCurrentItem() {
        $selected = $this.GetSelectedItem()
        if ($selected) {
            if ($selected.IsMarked) {
                $this.MarkedFiles.Remove($selected.FullPath)
                $selected.IsMarked = $false
            } else {
                $this.MarkedFiles.Add($selected.FullPath) | Out-Null
                $selected.IsMarked = $true
            }
            $this.InvalidateAllPanes()
        }
    }
    
    [void] InvalidateAllPanes() {
        if ($this._leftPane) { $this._leftPane.Invalidate() }
        if ($this._centerPane) { $this._centerPane.Invalidate() }
        if ($this._rightPane) { $this._rightPane.Invalidate() }
        $this.Invalidate()
    }
}

# Supporting enums and classes
enum UnifiedFileTreeMode {
    Ranger = 0  # 3-pane ranger-style (parent | current | preview)
    Simple = 1  # Single pane file list
    Dual = 2    # 2-pane (current | preview)
}

class FileSystemNode {
    [string]$Name = ""
    [string]$FullPath = ""
    [bool]$IsDirectory = $false
    [long]$Size = 0
    [DateTime]$LastModified = [DateTime]::MinValue
    [bool]$IsHidden = $false
    [bool]$IsSymlink = $false
    [bool]$IsMarked = $false
}