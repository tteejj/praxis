# FastFileTree.ps1 - High-performance file system browser based on ALCAR patterns
# Fast string-based rendering with directory caching and lazy loading

class FileSystemNode {
    [string]$Name
    [string]$FullPath
    [bool]$IsDirectory
    [long]$Size
    [datetime]$LastModified
    [bool]$IsExpanded = $false
    [System.Collections.ArrayList]$Children
    [FileSystemNode]$Parent
    [int]$Level = 0
    [bool]$IsLoaded = $false
    [bool]$HasChildren = $false
    
    FileSystemNode([string]$fullPath) {
        $this.FullPath = $fullPath
        $this.Name = Split-Path $fullPath -Leaf
        $this.Children = [System.Collections.ArrayList]::new()
        
        if (Test-Path $fullPath) {
            $item = Get-Item $fullPath -ErrorAction SilentlyContinue
            if ($item) {
                $this.IsDirectory = $item.PSIsContainer
                $this.Size = if (-not $this.IsDirectory -and $item.Length) { $item.Length } else { 0 }
                $this.LastModified = $item.LastWriteTime
                
                # Check if directory has children without loading them
                if ($this.IsDirectory) {
                    try {
                        $hasItems = Get-ChildItem $fullPath -Force -ErrorAction Stop | Select-Object -First 1
                        $this.HasChildren = $hasItems -ne $null
                    } catch {
                        $this.HasChildren = $false
                    }
                }
            }
        }
    }
    
    [void] LoadChildren() {
        if ($this.IsLoaded -or -not $this.IsDirectory) {
            return
        }
        
        try {
            $items = Get-ChildItem $this.FullPath -Force -ErrorAction Stop | Sort-Object @{Expression={$_.PSIsContainer}; Descending=$true}, Name
            
            $this.Children.Clear()
            foreach ($item in $items) {
                $child = [FileSystemNode]::new($item.FullName)
                $child.Parent = $this
                $child.Level = $this.Level + 1
                $this.Children.Add($child) | Out-Null
            }
            
            $this.IsLoaded = $true
            $this.HasChildren = $this.Children.Count -gt 0
            
        } catch {
            # Access denied or other error - mark as loaded but empty
            $this.IsLoaded = $true
            $this.HasChildren = $false
        }
    }
    
    [string] GetIcon() {
        if ($this.IsDirectory) {
            if ($this.IsExpanded) { 
                return "📂" 
            } else { 
                return "📁" 
            }
        }
        
        # File type icons based on extension
        $ext = [System.IO.Path]::GetExtension($this.Name).ToLower()
        switch ($ext) {
            ".ps1" { return "📜" }
            ".txt" { return "📄" }
            ".log" { return "📋" }
            ".json" { return "📋" }
            ".xml" { return "📋" }
            ".md" { return "📝" }
            ".zip" { return "📦" }
            ".exe" { return "⚙️" }
            ".dll" { return "🔧" }
            ".png" { return "🖼️" }
            ".jpg" { return "🖼️" }
            ".gif" { return "🖼️" }
            default { return "📄" }
        }
        return "📄"  # Fallback
    }
    
    [string] GetSizeString() {
        if ($this.IsDirectory) {
            return ""
        }
        
        if ($this.Size -lt 1KB) {
            return "$($this.Size) B"
        } elseif ($this.Size -lt 1MB) {
            return "$([math]::Round($this.Size / 1KB, 1)) KB"
        } elseif ($this.Size -lt 1GB) {
            return "$([math]::Round($this.Size / 1MB, 1)) MB"
        } else {
            return "$([math]::Round($this.Size / 1GB, 2)) GB"
        }
    }
}

class FastFileTree : UIElement {
    [string]$RootPath = ""
    [FileSystemNode]$RootNode
    [System.Collections.ArrayList]$_flatView
    [int]$SelectedIndex = 0
    [int]$ScrollOffset = 0
    [bool]$ShowBorder = $true
    [string]$Title = "File Browser"
    [bool]$ShowSize = $true
    [bool]$ShowModified = $false
    [string]$Filter = "*"
    
    # Events
    [scriptblock]$OnSelectionChanged = {}
    [scriptblock]$OnFileSelected = {}
    [scriptblock]$OnDirectoryChanged = {}
    
    # Visual settings
    [int]$IndentSize = 2
    [string]$ExpandedIcon = "▼"
    [string]$CollapsedIcon = "▶"
    
    hidden [ThemeManager]$Theme
    hidden [string]$_cachedRender = ""
    hidden [int]$_lastSelectedIndex = -1
    hidden [System.Collections.Generic.HashSet[string]]$_expandedPaths
    
    FastFileTree() : base() {
        $this._flatView = [System.Collections.ArrayList]::new()
        $this._expandedPaths = [System.Collections.Generic.HashSet[string]]::new()
        $this.IsFocusable = $true
        
        # Default to current directory
        $this.RootPath = $PWD.Path
    }
    
    FastFileTree([string]$rootPath) : base() {
        $this._flatView = [System.Collections.ArrayList]::new()
        $this._expandedPaths = [System.Collections.Generic.HashSet[string]]::new()
        $this.IsFocusable = $true
        $this.RootPath = $rootPath
    }
    
    [void] Initialize([ServiceContainer]$services) {
        if ($services) {
            $this.Theme = $services.GetService("ThemeManager")
            if ($this.Theme) {
                $this.Theme.Subscribe({ $this.OnThemeChanged() })
                $this.OnThemeChanged()
            }
        }
        
        $this.LoadDirectory($this.RootPath)
    }
    
    [void] OnThemeChanged() {
        $this._cachedRender = ""
        $this.Invalidate()
    }
    
    [void] Invalidate() {
        $this._cachedRender = ""
        ([UIElement]$this).Invalidate()
    }
    
    # Public API
    [void] LoadDirectory([string]$path) {
        if (-not (Test-Path $path -PathType Container)) {
            return
        }
        
        try {
            $this.RootPath = Resolve-Path $path
            $this.RootNode = [FileSystemNode]::new($this.RootPath)
            $this.RootNode.IsExpanded = $true
            $this.RootNode.LoadChildren()
            
            # Auto-expand remembered paths
            $this.RestoreExpandedState()
            
            $this.RebuildFlatView()
            $this.SelectedIndex = 0
            $this.ScrollOffset = 0
            $this.Invalidate()
            
            # Fire directory changed event
            if ($this.OnDirectoryChanged) {
                & $this.OnDirectoryChanged $this.RootPath
            }
            
        } catch {
            # Handle errors - could show in status or log
            if ($global:Logger) {
                $global:Logger.Error("FastFileTree: Failed to load directory '$path': $($_.Exception.Message)")
            }
        }
    }
    
    [void] NavigateUp() {
        $parentPath = Split-Path $this.RootPath -Parent
        if ($parentPath -and (Test-Path $parentPath)) {
            $this.LoadDirectory($parentPath)
        }
    }
    
    [void] NavigateToSelected() {
        $selected = $this.GetSelectedNode()
        if ($selected -and $selected.IsDirectory) {
            $this.LoadDirectory($selected.FullPath)
        }
    }
    
    [FileSystemNode] GetSelectedNode() {
        if ($this.SelectedIndex -ge 0 -and $this.SelectedIndex -lt $this._flatView.Count) {
            return $this._flatView[$this.SelectedIndex]
        }
        return $null
    }
    
    [void] ExpandSelected() {
        $selected = $this.GetSelectedNode()
        if ($selected -and $selected.IsDirectory -and -not $selected.IsExpanded) {
            $this.ToggleExpanded($selected)
        }
    }
    
    [void] CollapseSelected() {
        $selected = $this.GetSelectedNode()
        if ($selected -and $selected.IsDirectory -and $selected.IsExpanded) {
            $this.ToggleExpanded($selected)
        }
    }
    
    [void] ToggleExpanded([FileSystemNode]$node) {
        if (-not $node.IsDirectory) {
            return
        }
        
        $node.IsExpanded = -not $node.IsExpanded
        
        if ($node.IsExpanded) {
            $node.LoadChildren()
            $this._expandedPaths.Add($node.FullPath) | Out-Null
        } else {
            $this._expandedPaths.Remove($node.FullPath) | Out-Null
        }
        
        $this.RebuildFlatView()
        
        # Try to keep selection on the same node
        $this.SetSelectedNode($node)
        $this.Invalidate()
    }
    
    [void] SetSelectedNode([FileSystemNode]$node) {
        for ($i = 0; $i -lt $this._flatView.Count; $i++) {
            if ($this._flatView[$i].FullPath -eq $node.FullPath) {
                $this.SelectIndex($i)
                break
            }
        }
    }
    
    [void] SelectIndex([int]$index) {
        if ($index -ge 0 -and $index -lt $this._flatView.Count) {
            $oldIndex = $this.SelectedIndex
            $this.SelectedIndex = $index
            $this.EnsureVisible()
            
            if ($oldIndex -ne $this.SelectedIndex) {
                if ($this.OnSelectionChanged) {
                    & $this.OnSelectionChanged
                }
            }
            
            $this.Invalidate()
        }
    }
    
    [void] RefreshCurrent() {
        # Save current selection
        $selectedPath = $null
        $selected = $this.GetSelectedNode()
        if ($selected) {
            $selectedPath = $selected.FullPath
        }
        
        # Reload directory
        $this.LoadDirectory($this.RootPath)
        
        # Restore selection if possible
        if ($selectedPath) {
            for ($i = 0; $i -lt $this._flatView.Count; $i++) {
                if ($this._flatView[$i].FullPath -eq $selectedPath) {
                    $this.SelectIndex($i)
                    break
                }
            }
        }
    }
    
    # Internal methods
    [void] RebuildFlatView() {
        $this._flatView.Clear()
        if ($this.RootNode) {
            $this.AddNodeToFlatView($this.RootNode)
        }
        
        # Ensure selection is valid
        if ($this.SelectedIndex -ge $this._flatView.Count) {
            $this.SelectedIndex = [Math]::Max(0, $this._flatView.Count - 1)
        }
    }
    
    [void] AddNodeToFlatView([FileSystemNode]$node) {
        # Apply filter for non-directories
        if (-not $node.IsDirectory -and $this.Filter -ne "*") {
            if (-not ($node.Name -like $this.Filter)) {
                return
            }
        }
        
        $this._flatView.Add($node) | Out-Null
        
        if ($node.IsExpanded) {
            foreach ($child in $node.Children) {
                $this.AddNodeToFlatView($child)
            }
        }
    }
    
    [void] RestoreExpandedState() {
        if ($this.RootNode) {
            $this.RestoreExpandedStateRecursive($this.RootNode)
        }
    }
    
    [void] RestoreExpandedStateRecursive([FileSystemNode]$node) {
        if ($this._expandedPaths.Contains($node.FullPath)) {
            $node.IsExpanded = $true
            $node.LoadChildren()
        }
        
        foreach ($child in $node.Children) {
            $this.RestoreExpandedStateRecursive($child)
        }
    }
    
    [void] EnsureVisible() {
        # Calculate visible lines based on current dimensions
        $effectiveShowBorder = $this.ShowBorder -and $this.Width -ge 3 -and $this.Height -ge 2
        $borderReduction = $effectiveShowBorder ? 2 : 0
        $titleReduction = ($this.Title -and $this.Height -gt $borderReduction) ? 1 : 0
        $visibleLines = [Math]::Max(0, $this.Height - $borderReduction - $titleReduction)
        
        if ($visibleLines -gt 0) {
            if ($this.SelectedIndex -lt $this.ScrollOffset) {
                $this.ScrollOffset = $this.SelectedIndex
            } elseif ($this.SelectedIndex -ge $this.ScrollOffset + $visibleLines) {
                $this.ScrollOffset = $this.SelectedIndex - $visibleLines + 1
            }
            
            $this.ScrollOffset = [Math]::Max(0, $this.ScrollOffset)
        }
    }
    
    # Rendering
    [string] OnRender() {
        if ([string]::IsNullOrEmpty($this._cachedRender)) {
            $this.RebuildCache()
        }
        return $this._cachedRender
    }
    
    [void] RebuildCache() {
        # Validate dimensions before rendering
        if ($this.Width -le 0 -or $this.Height -le 0) {
            $this._cachedRender = ""
            return
        }
        
        # Disable border if dimensions are too small
        $effectiveShowBorder = $this.ShowBorder -and $this.Width -ge 3 -and $this.Height -ge 2
        
        $sb = Get-PooledStringBuilder 4096  # File trees can be quite large
        
        # Colors
        $borderColor = if ($this.Theme) { $this.Theme.GetColor("border") } else { "" }
        $titleColor = if ($this.Theme) { $this.Theme.GetColor("title") } else { "" }
        $selectedBg = if ($this.Theme) { $this.Theme.GetBgColor("selected") } else { "" }
        $normalColor = if ($this.Theme) { $this.Theme.GetColor("normal") } else { "" }
        $directoryColor = if ($this.Theme) { $this.Theme.GetColor("directory") } else { $normalColor }
        $fileColor = if ($this.Theme) { $this.Theme.GetColor("file") } else { $normalColor }
        $focusBorder = if ($this.Theme) { $this.Theme.GetColor("border.focused") } else { $borderColor }
        
        $currentBorderColor = if ($this.IsFocused) { $focusBorder } else { $borderColor }
        
        # Calculate content area with proper bounds checking
        $contentY = $this.Y
        $contentHeight = $this.Height
        $contentWidth = $this.Width - ($effectiveShowBorder ? 2 : 0)
        
        # Ensure content width is never negative
        if ($contentWidth -lt 0) {
            $contentWidth = 0
        }
        
        if ($effectiveShowBorder) {
            # Top border - safe to render since we validated Width >= 3
            $sb.Append([VT]::MoveTo($this.X, $this.Y))
            $sb.Append($currentBorderColor)
            $sb.Append([VT]::TL() + ([VT]::H() * ($this.Width - 2)) + [VT]::TR())
            $contentY++
            $contentHeight--
            
            # Title
            if ($this.Title -and $contentWidth -gt 0) {
                $sb.Append([VT]::MoveTo($this.X + 1, $contentY))
                $sb.Append($titleColor)
                $titleText = "$($this.Title) - $($this.RootPath)"
                if ($titleText.Length -gt $contentWidth) {
                    $titleText = "..." + $titleText.Substring($titleText.Length - $contentWidth + 3)
                }
                $titleLine = $titleText.PadRight($contentWidth).Substring(0, $contentWidth)
                $sb.Append($titleLine)
                $contentY++
                $contentHeight--
            }
        } else {
            # Title without border
            if ($this.Title -and $this.Width -gt 0) {
                $sb.Append([VT]::MoveTo($this.X, $contentY))
                $sb.Append($titleColor)
                $titleText = "$($this.Title) - $($this.RootPath)"
                $titleLine = $titleText.PadRight($this.Width).Substring(0, $this.Width)
                $sb.Append($titleLine)
                $contentY++
                $contentHeight--
            }
        }
        
        # Render file/directory entries
        $visibleLines = $contentHeight - ($effectiveShowBorder ? 1 : 0)  # Reserve bottom border
        $startIndex = $this.ScrollOffset
        $endIndex = [Math]::Min($startIndex + $visibleLines, $this._flatView.Count)
        
        for ($i = $startIndex; $i -lt $endIndex; $i++) {
            $node = $this._flatView[$i]
            $y = $contentY + ($i - $startIndex)
            
            if ($contentWidth -gt 0) {
                $sb.Append([VT]::MoveTo($this.X + ($effectiveShowBorder ? 1 : 0), $y))
            
                # Background for selected item
                if ($i -eq $this.SelectedIndex) {
                    $sb.Append($selectedBg)
                } else {
                    $sb.Append($normalColor)
                }
                
                # Build display line
                $line = ""
                
                # Indentation
                $line += " " * ($node.Level * $this.IndentSize)
                
                # Expand/collapse icon for directories
                if ($node.IsDirectory -and $node.HasChildren) {
                    $line += if ($node.IsExpanded) { $this.ExpandedIcon + " " } else { $this.CollapsedIcon + " " }
                } else {
                    $line += "  "  # Space for alignment
                }
                
                # File/directory icon
                $line += $node.GetIcon() + " "
                
                # Name
                $line += $node.Name
                
                # Size (for files, if enabled)
                if ($this.ShowSize -and -not $node.IsDirectory) {
                    $sizeStr = $node.GetSizeString()
                    if ($sizeStr) {
                        $line += " ($sizeStr)"
                    }
                }
                
                # Pad and truncate to fit
                $line = $line.PadRight($contentWidth).Substring(0, $contentWidth)
                $sb.Append($line)
                
                # Apply appropriate color
                $sb.Append([VT]::MoveTo($this.X + ($effectiveShowBorder ? 1 : 0), $y))
                if ($i -eq $this.SelectedIndex) {
                    $sb.Append($selectedBg)
                } else {
                    $color = if ($node.IsDirectory) { $directoryColor } else { $fileColor }
                    $sb.Append($color)
                }
                $sb.Append($line)
            }
            
            # Side borders
            if ($effectiveShowBorder) {
                $sb.Append([VT]::MoveTo($this.X, $y))
                $sb.Append($currentBorderColor)
                $sb.Append([VT]::V())
                
                $sb.Append([VT]::MoveTo($this.X + $this.Width - 1, $y))
                $sb.Append($currentBorderColor)
                $sb.Append([VT]::V())
            }
        }
        
        # Fill empty lines
        for ($i = $endIndex - $startIndex; $i -lt $visibleLines; $i++) {
            $y = $contentY + $i
            if ($contentWidth -gt 0) {
                $sb.Append([VT]::MoveTo($this.X + ($effectiveShowBorder ? 1 : 0), $y))
                $sb.Append($normalColor)
                $sb.Append(" ".PadRight($contentWidth))
            }
            
            if ($effectiveShowBorder) {
                $sb.Append([VT]::MoveTo($this.X, $y))
                $sb.Append($currentBorderColor)
                $sb.Append([VT]::V())
                
                $sb.Append([VT]::MoveTo($this.X + $this.Width - 1, $y))
                $sb.Append($currentBorderColor)
                $sb.Append([VT]::V())
            }
        }
        
        if ($effectiveShowBorder) {
            # Bottom border - safe to render since we validated Width >= 3
            $bottomY = $this.Y + $this.Height - 1
            $sb.Append([VT]::MoveTo($this.X, $bottomY))
            $sb.Append($currentBorderColor)
            $sb.Append([VT]::BL() + ([VT]::H() * ($this.Width - 2)) + [VT]::BR())
        }
        
        $sb.Append([VT]::Reset())
        $this._cachedRender = $sb.ToString()
        Return-PooledStringBuilder $sb  # Return to pool for reuse
    }
    
    # Input handling
    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        $handled = $false
        $oldIndex = $this.SelectedIndex
        
        switch ($key.Key) {
            ([System.ConsoleKey]::UpArrow) {
                if ($this.SelectedIndex -gt 0) {
                    $this.SelectedIndex--
                    $handled = $true
                }
            }
            ([System.ConsoleKey]::DownArrow) {
                if ($this.SelectedIndex -lt $this._flatView.Count - 1) {
                    $this.SelectedIndex++
                    $handled = $true
                }
            }
            ([System.ConsoleKey]::PageUp) {
                $pageSize = $this.Height - 3
                $this.SelectedIndex = [Math]::Max(0, $this.SelectedIndex - $pageSize)
                $handled = $true
            }
            ([System.ConsoleKey]::PageDown) {
                $pageSize = $this.Height - 3
                $this.SelectedIndex = [Math]::Min($this._flatView.Count - 1, $this.SelectedIndex + $pageSize)
                $handled = $true
            }
            ([System.ConsoleKey]::Home) {
                $this.SelectedIndex = 0
                $handled = $true
            }
            ([System.ConsoleKey]::End) {
                $this.SelectedIndex = [Math]::Max(0, $this._flatView.Count - 1)
                $handled = $true
            }
            ([System.ConsoleKey]::Enter) {
                $selected = $this.GetSelectedNode()
                if ($selected) {
                    if ($selected.IsDirectory) {
                        if ($selected.HasChildren) {
                            $this.ToggleExpanded($selected)
                        } else {
                            $this.LoadDirectory($selected.FullPath)
                        }
                    } else {
                        # Fire file selected event
                        if ($this.OnFileSelected) {
                            & $this.OnFileSelected $selected
                        }
                    }
                }
                $handled = $true
            }
            ([System.ConsoleKey]::Spacebar) {
                $selected = $this.GetSelectedNode()
                if ($selected -and $selected.IsDirectory -and $selected.HasChildren) {
                    $this.ToggleExpanded($selected)
                    $handled = $true
                }
            }
            ([System.ConsoleKey]::Backspace) {
                $this.NavigateUp()
                $handled = $true
            }
            ([System.ConsoleKey]::F5) {
                $this.RefreshCurrent()
                $handled = $true
            }
        }
        
        # Handle character keys for quick navigation
        if (-not $handled -and $key.KeyChar -ge 'A' -and $key.KeyChar -le 'z') {
            $this.QuickNavigate($key.KeyChar)
            $handled = $true
        }
        
        if ($handled) {
            $this.EnsureVisible()
            $this.Invalidate()
            
            # Fire selection changed event
            if ($oldIndex -ne $this.SelectedIndex -and $this.OnSelectionChanged) {
                & $this.OnSelectionChanged
            }
        }
        
        return $handled
    }
    
    [void] QuickNavigate([char]$char) {
        $startIndex = ($this.SelectedIndex + 1) % $this._flatView.Count
        
        for ($i = 0; $i -lt $this._flatView.Count; $i++) {
            $index = ($startIndex + $i) % $this._flatView.Count
            $node = $this._flatView[$index]
            
            if ($node.Name.Length -gt 0 -and [char]::ToLower($node.Name[0]) -eq [char]::ToLower($char)) {
                $this.SelectIndex($index)
                break
            }
        }
    }
    
    # Helper methods for rendering refactoring
    [hashtable] GetThemeColors() {
        return @{
            Border = if ($this.Theme) { $this.Theme.GetColor("border") } else { "" }
            Title = if ($this.Theme) { $this.Theme.GetColor("title") } else { "" }
            SelectedBg = if ($this.Theme) { $this.Theme.GetBgColor("selected") } else { "" }
            Normal = if ($this.Theme) { $this.Theme.GetColor("normal") } else { "" }
            Directory = if ($this.Theme) { $this.Theme.GetColor("directory") } else { "" }
            File = if ($this.Theme) { $this.Theme.GetColor("file") } else { "" }
            FocusBorder = if ($this.Theme) { $this.Theme.GetColor("border.focused") } else { "" }
        }
    }
    
    [hashtable] CalculateContentArea([bool]$effectiveShowBorder) {
        $contentY = $this.Y
        $contentHeight = $this.Height
        $contentWidth = $this.Width - ($effectiveShowBorder ? 2 : 0)
        
        # Ensure content width is never negative
        if ($contentWidth -lt 0) {
            $contentWidth = 0
        }
        
        return @{
            Y = $contentY
            Height = $contentHeight
            Width = $contentWidth
        }
    }
    
    [void] RenderBorder([System.Text.StringBuilder]$sb, [hashtable]$colors, [bool]$effectiveShowBorder) {
        if (-not $effectiveShowBorder) { return }
        
        $currentBorderColor = if ($this.IsFocused) { $colors.FocusBorder } else { $colors.Border }
        
        # Top border
        $sb.Append([VT]::MoveTo($this.X, $this.Y))
        $sb.Append($currentBorderColor)
        $sb.Append([VT]::TL() + ([VT]::H() * ($this.Width - 2)) + [VT]::TR())
    }
    
    [hashtable] RenderTitle([System.Text.StringBuilder]$sb, [hashtable]$colors, [hashtable]$contentArea, [bool]$effectiveShowBorder) {
        $contentY = $contentArea.Y
        $contentHeight = $contentArea.Height
        $contentWidth = $contentArea.Width
        
        if ($effectiveShowBorder) {
            $contentY++
            $contentHeight--
            
            # Title with border
            if ($this.Title -and $contentWidth -gt 0) {
                $sb.Append([VT]::MoveTo($this.X + 1, $contentY))
                $sb.Append($colors.Title)
                $titleText = "$($this.Title) - $($this.RootPath)"
                if ($titleText.Length -gt $contentWidth) {
                    $titleText = "..." + $titleText.Substring($titleText.Length - $contentWidth + 3)
                }
                $titleLine = $titleText.PadRight($contentWidth).Substring(0, $contentWidth)
                $sb.Append($titleLine)
                $contentY++
                $contentHeight--
            }
        } else {
            # Title without border
            if ($this.Title -and $this.Width -gt 0) {
                $sb.Append([VT]::MoveTo($this.X, $contentY))
                $sb.Append($colors.Title)
                $titleText = "$($this.Title) - $($this.RootPath)"
                $titleLine = $titleText.PadRight($this.Width).Substring(0, $this.Width)
                $sb.Append($titleLine)
                $contentY++
                $contentHeight--
            }
        }
        
        return @{
            Y = $contentY
            Height = $contentHeight
            Width = $contentWidth
        }
    }
    
    [void] OnGotFocus() {
        $this._cachedRender = ""
        $this.Invalidate()
    }
    
    [void] OnLostFocus() {
        $this._cachedRender = ""
        $this.Invalidate()
    }
}