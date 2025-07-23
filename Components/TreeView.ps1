# TreeView.ps1 - Hierarchical tree view component based on ALCAR patterns
# Fast string-based rendering with expand/collapse functionality

class TreeNode {
    [string]$Id
    [object]$Data
    [TreeNode]$Parent
    [System.Collections.ArrayList]$Children
    [bool]$IsExpanded = $true
    [int]$Level = 0
    [string]$DisplayText
    
    TreeNode() {
        $this.Children = [System.Collections.ArrayList]::new()
        $this.Id = [System.Guid]::NewGuid().ToString()
    }
    
    TreeNode([string]$displayText) {
        $this.Children = [System.Collections.ArrayList]::new()
        $this.Id = [System.Guid]::NewGuid().ToString()
        $this.DisplayText = $displayText
    }
    
    TreeNode([string]$displayText, [object]$data) {
        $this.Children = [System.Collections.ArrayList]::new()
        $this.Id = [System.Guid]::NewGuid().ToString()
        $this.DisplayText = $displayText
        $this.Data = $data
    }
    
    [void] AddChild([TreeNode]$child) {
        $child.Parent = $this
        $this.Children.Add($child) | Out-Null
        $this.UpdateLevels()
    }
    
    [void] RemoveChild([TreeNode]$child) {
        $this.Children.Remove($child)
        $child.Parent = $null
    }
    
    [void] UpdateLevels() {
        # Recursively update all child levels
        foreach ($child in $this.Children) {
            $child.Level = $this.Level + 1
            $child.UpdateLevels()
        }
    }
    
    [bool] HasChildren() {
        return $this.Children.Count -gt 0
    }
}

class TreeView : UIElement {
    [System.Collections.ArrayList]$Nodes
    [System.Collections.ArrayList]$_flatView  # Flattened display view
    [int]$SelectedIndex = 0
    [int]$ScrollOffset = 0
    [bool]$ShowBorder = $true
    [string]$Title = ""
    [scriptblock]$OnSelectionChanged = {}
    [scriptblock]$OnNodeExpanded = {}
    [scriptblock]$OnNodeCollapsed = {}
    
    # Visual settings
    [string]$ExpandedIcon = "▼"
    [string]$CollapsedIcon = "▶"
    [string]$LeafIcon = "•"
    [int]$IndentSize = 2
    
    hidden [ThemeManager]$Theme
    hidden [string]$_cachedRender = ""
    
    TreeView() : base() {
        $this.Nodes = [System.Collections.ArrayList]::new()
        $this._flatView = [System.Collections.ArrayList]::new()
        $this.IsFocusable = $true
    }
    
    [void] Initialize([ServiceContainer]$services) {
        $this.Theme = $services.GetService("ThemeManager")
        if ($this.Theme) {
            $this.Theme.Subscribe({ $this.OnThemeChanged() })
            $this.OnThemeChanged()
        }
        $this.RebuildFlatView()
    }
    
    [void] OnThemeChanged() {
        $this._cachedRender = ""
        $this.Invalidate()
    }
    
    [void] Invalidate() {
        $this._cachedRender = ""
        ([UIElement]$this).Invalidate()
    }
    
    # Public API methods
    [TreeNode] AddRootNode([string]$displayText) {
        $node = [TreeNode]::new($displayText)
        $node.Level = 0
        $this.Nodes.Add($node) | Out-Null
        $this.RebuildFlatView()
        return $node
    }
    
    [TreeNode] AddRootNode([string]$displayText, [object]$data) {
        $node = [TreeNode]::new($displayText, $data)
        $node.Level = 0
        $this.Nodes.Add($node) | Out-Null
        $this.RebuildFlatView()
        return $node
    }
    
    [void] Clear() {
        $this.Nodes.Clear()
        $this._flatView.Clear()
        $this.SelectedIndex = 0
        $this.ScrollOffset = 0
        $this.Invalidate()
    }
    
    [TreeNode] GetSelectedNode() {
        if ($this.SelectedIndex -ge 0 -and $this.SelectedIndex -lt $this._flatView.Count) {
            return $this._flatView[$this.SelectedIndex]
        }
        return $null
    }
    
    [void] SetSelectedNode([TreeNode]$node) {
        for ($i = 0; $i -lt $this._flatView.Count; $i++) {
            if ($this._flatView[$i].Id -eq $node.Id) {
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
            
            if ($oldIndex -ne $this.SelectedIndex -and $this.OnSelectionChanged) {
                & $this.OnSelectionChanged
            }
            
            $this.Invalidate()
        }
    }
    
    [void] ToggleExpanded([TreeNode]$node) {
        if (-not $node.HasChildren()) {
            return
        }
        
        $node.IsExpanded = -not $node.IsExpanded
        $this.RebuildFlatView()
        
        # Fire events
        if ($node.IsExpanded -and $this.OnNodeExpanded) {
            & $this.OnNodeExpanded $node
        } elseif (-not $node.IsExpanded -and $this.OnNodeCollapsed) {
            & $this.OnNodeCollapsed $node
        }
        
        # Maintain selection on the same node
        $this.SetSelectedNode($node)
    }
    
    [void] ExpandAll() {
        $this.SetAllExpanded($true)
    }
    
    [void] CollapseAll() {
        $this.SetAllExpanded($false)
    }
    
    [void] SetAllExpanded([bool]$expanded) {
        foreach ($node in $this.Nodes) {
            $this.SetNodeExpanded($node, $expanded)
        }
        $this.RebuildFlatView()
        $this.Invalidate()
    }
    
    [void] SetNodeExpanded([TreeNode]$node, [bool]$expanded) {
        if ($node.HasChildren()) {
            $node.IsExpanded = $expanded
        }
        foreach ($child in $node.Children) {
            $this.SetNodeExpanded($child, $expanded)
        }
    }
    
    # Internal methods
    [void] RebuildFlatView() {
        $this._flatView.Clear()
        foreach ($node in $this.Nodes) {
            $this.AddNodeToFlatView($node)
        }
        
        # Ensure selection is valid
        if ($this.SelectedIndex -ge $this._flatView.Count) {
            $this.SelectedIndex = [Math]::Max(0, $this._flatView.Count - 1)
        }
    }
    
    [void] AddNodeToFlatView([TreeNode]$node) {
        $this._flatView.Add($node) | Out-Null
        
        if ($node.IsExpanded) {
            foreach ($child in $node.Children) {
                $this.AddNodeToFlatView($child)
            }
        }
    }
    
    [void] EnsureVisible() {
        $visibleLines = $this.Height - ($this.ShowBorder ? 2 : 0) - ($this.Title ? 1 : 0)
        
        if ($this.SelectedIndex -lt $this.ScrollOffset) {
            $this.ScrollOffset = $this.SelectedIndex
        } elseif ($this.SelectedIndex -ge $this.ScrollOffset + $visibleLines) {
            $this.ScrollOffset = $this.SelectedIndex - $visibleLines + 1
        }
        
        $this.ScrollOffset = [Math]::Max(0, $this.ScrollOffset)
    }
    
    [string] OnRender() {
        if ([string]::IsNullOrEmpty($this._cachedRender)) {
            $this.RebuildCache()
        }
        return $this._cachedRender
    }
    
    [void] RebuildCache() {
        $sb = [System.Text.StringBuilder]::new()
        
        # Colors
        $borderColor = if ($this.Theme) { $this.Theme.GetColor("border") } else { "" }
        $titleColor = if ($this.Theme) { $this.Theme.GetColor("title") } else { "" }
        $selectedBg = if ($this.Theme) { $this.Theme.GetBgColor("selected") } else { "" }
        $normalColor = if ($this.Theme) { $this.Theme.GetColor("normal") } else { "" }
        $focusBorder = if ($this.Theme) { $this.Theme.GetColor("border.focused") } else { $borderColor }
        
        $currentBorderColor = if ($this.IsFocused) { $focusBorder } else { $borderColor }
        
        # Calculate content area
        $contentY = $this.Y
        $contentHeight = $this.Height
        $contentWidth = $this.Width - ($this.ShowBorder ? 2 : 0)
        
        if ($this.ShowBorder) {
            # Top border
            $sb.Append([VT]::MoveTo($this.X, $this.Y))
            $sb.Append($currentBorderColor)
            $sb.Append([VT]::TL() + ([VT]::H() * ($this.Width - 2)) + [VT]::TR())
            $contentY++
            $contentHeight--
            
            # Title
            if ($this.Title) {
                $sb.Append([VT]::MoveTo($this.X + 1, $contentY))
                $sb.Append($titleColor)
                $titleText = $this.Title.PadRight($contentWidth).Substring(0, $contentWidth)
                $sb.Append($titleText)
                $contentY++
                $contentHeight--
            }
        } else {
            # Title without border
            if ($this.Title) {
                $sb.Append([VT]::MoveTo($this.X, $contentY))
                $sb.Append($titleColor)
                $titleText = $this.Title.PadRight($this.Width).Substring(0, $this.Width)
                $sb.Append($titleText)
                $contentY++
                $contentHeight--
            }
        }
        
        # Render tree nodes
        $visibleLines = $contentHeight - ($this.ShowBorder ? 1 : 0)  # Reserve bottom border
        $startIndex = $this.ScrollOffset
        $endIndex = [Math]::Min($startIndex + $visibleLines, $this._flatView.Count)
        
        for ($i = $startIndex; $i -lt $endIndex; $i++) {
            $node = $this._flatView[$i]
            $y = $contentY + ($i - $startIndex)
            
            $sb.Append([VT]::MoveTo($this.X + ($this.ShowBorder ? 1 : 0), $y))
            
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
            
            # Tree icon
            if ($node.HasChildren()) {
                $line += if ($node.IsExpanded) { $this.ExpandedIcon + " " } else { $this.CollapsedIcon + " " }
            } else {
                $line += $this.LeafIcon + " "
            }
            
            # Node text
            $line += $node.DisplayText
            
            # Pad and truncate to fit
            $line = $line.PadRight($contentWidth).Substring(0, $contentWidth)
            $sb.Append($line)
            
            if ($this.ShowBorder) {
                # Side borders
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
            $sb.Append([VT]::MoveTo($this.X + ($this.ShowBorder ? 1 : 0), $y))
            $sb.Append($normalColor)
            $sb.Append(" ".PadRight($contentWidth))
            
            if ($this.ShowBorder) {
                $sb.Append([VT]::MoveTo($this.X, $y))
                $sb.Append($currentBorderColor)
                $sb.Append([VT]::V())
                
                $sb.Append([VT]::MoveTo($this.X + $this.Width - 1, $y))
                $sb.Append($currentBorderColor)
                $sb.Append([VT]::V())
            }
        }
        
        if ($this.ShowBorder) {
            # Bottom border
            $bottomY = $this.Y + $this.Height - 1
            $sb.Append([VT]::MoveTo($this.X, $bottomY))
            $sb.Append($currentBorderColor)
            $sb.Append([VT]::BL() + ([VT]::H() * ($this.Width - 2)) + [VT]::BR())
        }
        
        $sb.Append([VT]::Reset())
        $this._cachedRender = $sb.ToString()
    }
    
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
                $pageSize = $this.Height - 3  # Approximate visible lines
                $this.SelectedIndex = [Math]::Max(0, $this.SelectedIndex - $pageSize)
                $handled = $true
            }
            ([System.ConsoleKey]::PageDown) {
                $pageSize = $this.Height - 3  # Approximate visible lines
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
                $node = $this.GetSelectedNode()
                if ($node -and $node.HasChildren()) {
                    $this.ToggleExpanded($node)
                    $handled = $true
                }
            }
            ([System.ConsoleKey]::Spacebar) {
                $node = $this.GetSelectedNode()
                if ($node -and $node.HasChildren()) {
                    $this.ToggleExpanded($node)
                    $handled = $true
                }
            }
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
    
    [void] OnGotFocus() {
        $this._cachedRender = ""
        $this.Invalidate()
    }
    
    [void] OnLostFocus() {
        $this._cachedRender = ""
        $this.Invalidate()
    }
}