# LayoutExamplesScreen.ps1 - Examples of underutilized layout components

class LayoutExamplesScreen : Screen {
    hidden [MinimalListBox]$ExampleList
    hidden [Container]$ExampleArea
    hidden [VerticalSplit]$MainSplit
    
    LayoutExamplesScreen() : base() {
        $this.Name = "Layout Examples"
    }
    
    [void] OnInitialize() {
        ([Screen]$this).OnInitialize()
        
        # Main vertical split
        $this.MainSplit = [VerticalSplit]::new()
        $this.MainSplit.SplitPosition = 10
        $this.AddChild($this.MainSplit)
        
        # Top: Example selector
        $topContainer = [Container]::new()
        $this.ExampleList = [MinimalListBox]::new()
        $this.ExampleList.ShowBorder = $true
        $this.ExampleList.SetItems(@(
            "GridPanel - Flexible Grid Layout",
            "DockPanel - Docked Layout", 
            "HorizontalSplit - Side by Side",
            "VerticalSplit - Top and Bottom",
            "Nested Splits - Complex Layout",
            "Mixed Layout - All Combined"
        ))
        $this.ExampleList.OnSelectionChanged = {
            $this.ShowExample($this.ExampleList.SelectedIndex)
        }.GetNewClosure()
        $topContainer.AddChild($this.ExampleList)
        $topContainer.LayoutChildren = {
            if ($this.Children.Count -gt 0) {
                $this.Children[0].SetBounds($this.X + 2, $this.Y + 2, $this.Width - 4, $this.Height - 2)
            }
        }
        $this.MainSplit.SetTopChild($topContainer)
        
        # Bottom: Example area
        $this.ExampleArea = [Container]::new()
        $this.ExampleArea.DrawBackground = $true
        $this.MainSplit.SetBottomChild($this.ExampleArea)
        
        # Default to first example
        $this.ExampleList.SelectedIndex = 0
        $this.ShowExample(0)
    }
    
    [void] ShowExample([int]$index) {
        $this.ExampleArea.Children.Clear()
        
        switch ($index) {
            0 { $this.ShowGridPanelExample() }
            1 { $this.ShowDockPanelExample() }
            2 { $this.ShowHorizontalSplitExample() }
            3 { $this.ShowVerticalSplitExample() }
            4 { $this.ShowNestedSplitsExample() }
            5 { $this.ShowMixedLayoutExample() }
        }
        
        $this.ExampleArea.Invalidate()
    }
    
    [void] ShowGridPanelExample() {
        $grid = [GridPanel]::new()
        $grid.Rows = 3
        $grid.Columns = 3
        $grid.RowHeights = @(0.2, 0.6, 0.2)  # 20%, 60%, 20%
        $grid.ColumnWidths = @(0.25, 0.5, 0.25)  # 25%, 50%, 25%
        
        # Add cells with different content
        for ($row = 0; $row -lt 3; $row++) {
            for ($col = 0; $col -lt 3; $col++) {
                $cell = $this.CreateDemoPanel("Cell R$($row+1)C$($col+1)", 
                    "Grid[$row,$col]`nFlexible sizing")
                $grid.SetCell($row, $col, $cell)
            }
        }
        
        # Center cell spans 2 columns
        $centerCell = $this.CreateDemoPanel("Spanning Cell", 
            "This cell spans`n2 columns using`nSetCell with span")
        $grid.SetCell(1, 0, $centerCell, 1, 2)  # row 1, col 0, rowspan 1, colspan 2
        
        $this.ExampleArea.AddChild($grid)
    }
    
    [void] ShowDockPanelExample() {
        $dock = [DockPanel]::new()
        
        # Dock panels to each side
        $topPanel = $this.CreateDemoPanel("Top Dock", "Height: 5 lines")
        $dock.DockTop($topPanel, 5)
        
        $bottomPanel = $this.CreateDemoPanel("Bottom Dock", "Height: 3 lines")
        $dock.DockBottom($bottomPanel, 3)
        
        $leftPanel = $this.CreateDemoPanel("Left Dock", "Width: 20 chars")
        $dock.DockLeft($leftPanel, 20)
        
        $rightPanel = $this.CreateDemoPanel("Right Dock", "Width: 20 chars")
        $dock.DockRight($rightPanel, 20)
        
        # Center fills remaining space
        $centerPanel = $this.CreateDemoPanel("Center Fill", 
            "This panel fills`nall remaining space`nafter docked panels")
        $dock.DockFill($centerPanel)
        
        $this.ExampleArea.AddChild($dock)
    }
    
    [void] ShowHorizontalSplitExample() {
        $split = [HorizontalSplit]::new()
        $split.SplitPosition = 40  # 40% for left panel
        
        $leftPanel = $this.CreateDemoPanel("Left Panel", 
            "40% width`nResizable with`nSplitPosition property")
        $split.SetLeftChild($leftPanel)
        
        $rightPanel = $this.CreateDemoPanel("Right Panel", 
            "60% width`nAutomatically adjusts`nwhen window resizes")
        $split.SetRightChild($rightPanel)
        
        $this.ExampleArea.AddChild($split)
    }
    
    [void] ShowVerticalSplitExample() {
        $split = [VerticalSplit]::new()
        $split.SplitPosition = -8  # Bottom 8 lines
        
        $topPanel = $this.CreateDemoPanel("Top Panel", 
            "Flexible height`nNegative SplitPosition`nmeans lines from bottom")
        $split.SetTopChild($topPanel)
        
        $bottomPanel = $this.CreateDemoPanel("Bottom Panel", 
            "Fixed 8 lines`nUseful for status bars`nor command areas")
        $split.SetBottomChild($bottomPanel)
        
        $this.ExampleArea.AddChild($split)
    }
    
    [void] ShowNestedSplitsExample() {
        # Main horizontal split
        $mainSplitContainer = [HorizontalSplit]::new()
        $mainSplitContainer.SplitPosition = 30
        
        # Left side - vertical split
        $leftSplit = [VerticalSplit]::new()
        $leftSplit.SplitPosition = 50  # 50% split
        
        $leftTop = $this.CreateDemoPanel("Left Top", "Nested splits`nenable complex`nlayouts")
        $leftBottom = $this.CreateDemoPanel("Left Bottom", "Each split can`ncontain more splits")
        
        $leftSplit.SetTopChild($leftTop)
        $leftSplit.SetBottomChild($leftBottom)
        $mainSplitContainer.SetLeftChild($leftSplit)
        
        # Right side - another vertical split
        $rightSplit = [VerticalSplit]::new()
        $rightSplit.SplitPosition = 70  # 70% for top
        
        $rightTop = $this.CreateDemoPanel("Right Top", "70% of right side")
        $rightBottom = $this.CreateDemoPanel("Right Bottom", "30% of right side")
        
        $rightSplit.SetTopChild($rightTop)
        $rightSplit.SetBottomChild($rightBottom)
        $mainSplitContainer.SetRightChild($rightSplit)
        
        $this.ExampleArea.AddChild($mainSplitContainer)
    }
    
    [void] ShowMixedLayoutExample() {
        # DockPanel as main container
        $dock = [DockPanel]::new()
        
        # Top toolbar
        $toolbar = $this.CreateDemoPanel("Toolbar", "Docked to top")
        $dock.DockTop($toolbar, 3)
        
        # Status bar at bottom
        $statusBar = $this.CreateDemoPanel("Status Bar", "Docked to bottom")
        $dock.DockBottom($statusBar, 2)
        
        # Main area is a horizontal split
        $mainSplitContainer = [HorizontalSplit]::new()
        $mainSplitContainer.SplitPosition = 25
        
        # Left sidebar uses GridPanel
        $sidebar = [GridPanel]::new()
        $sidebar.Rows = 3
        $sidebar.Columns = 1
        $sidebar.RowHeights = @(0.3, 0.5, 0.2)
        
        $navPanel = $this.CreateDemoPanel("Navigation", "Grid cell 1")
        $sidebar.SetCell(0, 0, $navPanel)
        
        $toolPanel = $this.CreateDemoPanel("Tools", "Grid cell 2")
        $sidebar.SetCell(1, 0, $toolPanel)
        
        $infoPanel = $this.CreateDemoPanel("Info", "Grid cell 3")
        $sidebar.SetCell(2, 0, $infoPanel)
        
        $mainSplitContainer.SetLeftChild($sidebar)
        
        # Right content area
        $content = $this.CreateDemoPanel("Main Content", 
            "Mixed layout example:`n- DockPanel for frame`n- HorizontalSplit for main`n- GridPanel for sidebar")
        $mainSplitContainer.SetRightChild($content)
        
        # Dock the split panel as center fill
        $dock.DockFill($mainSplitContainer)
        
        $this.ExampleArea.AddChild($dock)
    }
    
    [Container] CreateDemoPanel([string]$title, [string]$content) {
        $panel = [Container]::new()
        $panel.DrawBackground = $true
        
        # Title
        $titleElem = [UIElement]::new()
        $titleElem.OnRender = {
            $sb = Get-PooledStringBuilder 256
            $theme = $this.ServiceContainer.GetService('ThemeManager')
            $sb.Append([VT]::MoveTo($this.X + 2, $this.Y + 1))
            $sb.Append($theme.GetColor('accent'))
            $sb.Append("▌ $title")
            $sb.Append([VT]::Reset())
            $result = $sb.ToString()
            Return-PooledStringBuilder $sb
            return $result
        }.GetNewClosure()
        
        # Content
        $contentElem = [UIElement]::new()
        $contentElem.OnRender = {
            $sb = Get-PooledStringBuilder 512
            $theme = $this.ServiceContainer.GetService('ThemeManager')
            $lines = $content -split "`n"
            $y = $this.Y + 3
            foreach ($line in $lines) {
                $sb.Append([VT]::MoveTo($this.X + 4, $y))
                $sb.Append($theme.GetColor('normal'))
                $sb.Append($line)
                $y++
            }
            $sb.Append([VT]::Reset())
            $result = $sb.ToString()
            Return-PooledStringBuilder $sb
            return $result
        }.GetNewClosure()
        
        # Border
        $borderElem = [UIElement]::new()
        $borderElem.OnRender = {
            if ($this.Parent.Width -lt 10 -or $this.Parent.Height -lt 5) { return "" }
            
            $theme = $this.ServiceContainer.GetService('ThemeManager')
            return [BorderStyle]::RenderBorder(
                $this.Parent.X, $this.Parent.Y, 
                $this.Parent.Width, $this.Parent.Height,
                [BorderType]::Rounded, 
                $theme.GetColor('border')
            )
        }.GetNewClosure()
        
        $panel.AddChild($borderElem)
        $panel.AddChild($titleElem)
        $panel.AddChild($contentElem)
        
        $panel.LayoutChildren = {
            if ($this.Children.Count -ge 3) {
                $this.Children[0].SetBounds($this.X, $this.Y, $this.Width, $this.Height)
                $this.Children[1].SetBounds($this.X, $this.Y, $this.Width, 3)
                $this.Children[2].SetBounds($this.X, $this.Y, $this.Width, $this.Height)
            }
        }
        
        return $panel
    }
    
    [void] OnBoundsChanged() {
        if ($this.MainSplit) {
            $this.MainSplit.SetBounds($this.X, $this.Y, $this.Width, $this.Height)
        }
    }
    
    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        # Number shortcuts
        if ($key.KeyChar -ge '1' -and $key.KeyChar -le '6') {
            $index = [int]($key.KeyChar - '1')
            if ($index -lt $this.ExampleList.Items.Count) {
                $this.ExampleList.SelectedIndex = $index
                $this.ShowExample($index)
                return $true
            }
        }
        
        return ([Screen]$this).HandleInput($key)
    }
}