# MinimalShowcaseScreen.ps1 - Showcase of minimalist UI components

class MinimalShowcaseScreen : Screen {
    hidden [MinimalListBox]$ComponentList
    hidden [Container]$DemoArea
    hidden [MinimalButton]$TestButton
    hidden [MinimalTextBox]$TestInput
    hidden [MinimalListBox]$TestList
    hidden [HorizontalSplit]$MainSplit
    hidden [VerticalSplit]$RightSplit
    
    MinimalShowcaseScreen() : base() {
        $this.Name = "Minimal UI Showcase"
    }
    
    [void] OnInitialize() {
        ([Screen]$this).OnInitialize()
        
        # Create main horizontal split
        $this.MainSplit = [HorizontalSplit]::new()
        $this.MainSplit.SplitPosition = 30
        $this.AddChild($this.MainSplit)
        
        # Left side - component list
        $this.ComponentList = [MinimalListBox]::new()
        $this.ComponentList.ShowBorder = $true
        $this.ComponentList.SetItems(@(
            "Minimal Button",
            "Minimal TextBox", 
            "Minimal ListBox",
            "Focus Navigation",
            "Theme Colors"
        ))
        $this.ComponentList.OnSelectionChanged = {
            $this.ShowDemo($this.ComponentList.SelectedIndex)
        }.GetNewClosure()
        $this.MainSplit.SetLeftChild($this.ComponentList)
        
        # Right side - vertical split for demo area
        $this.RightSplit = [VerticalSplit]::new()
        $this.RightSplit.SplitPosition = -10  # Bottom 10 lines for info
        $this.MainSplit.SetRightChild($this.RightSplit)
        
        # Demo area container
        $this.DemoArea = [Container]::new()
        $this.DemoArea.DrawBackground = $true
        $this.RightSplit.SetTopChild($this.DemoArea)
        
        # Info panel
        $infoPanel = [Container]::new()
        $infoText = [UIElement]::new()
        $infoText.OnRender = {
            $sb = Get-PooledStringBuilder 512
            $sb.Append([VT]::MoveTo($this.X + 2, $this.Y + 2))
            $sb.Append("Tab/Shift+Tab: Navigate • Enter/Space: Activate • 1-5: Quick select")
            $sb.Append([VT]::MoveTo($this.X + 2, $this.Y + 3))
            $sb.Append("Focus style: Minimal underline for clean appearance")
            $result = $sb.ToString()
            Return-PooledStringBuilder $sb
            return $result
        }.GetNewClosure()
        $infoPanel.AddChild($infoText)
        $this.RightSplit.SetBottomChild($infoPanel)
        
        # Default to first demo
        $this.ComponentList.SelectedIndex = 0
        $this.ShowDemo(0)
    }
    
    [void] ShowDemo([int]$index) {
        # Clear demo area
        $this.DemoArea.Children.Clear()
        
        switch ($index) {
            0 { $this.ShowButtonDemo() }
            1 { $this.ShowTextBoxDemo() }
            2 { $this.ShowListBoxDemo() }
            3 { $this.ShowFocusDemo() }
            4 { $this.ShowThemeDemo() }
        }
        
        $this.DemoArea.Invalidate()
    }
    
    [void] ShowButtonDemo() {
        $container = [VerticalSplit]::new()
        $container.SplitPosition = 10
        
        # Title
        $title = $this.CreateTitle("Minimal Button Demo")
        $container.SetTopChild($title)
        
        # Buttons
        $buttonPanel = [Container]::new()
        
        $btn1 = [MinimalButton]::new("Primary Action")
        $btn1.IsDefault = $true
        $btn1.OnClick = {
            [System.Console]::Beep(800, 100)
        }
        
        $btn2 = [MinimalButton]::new("Secondary")
        $btn2.OnClick = {
            [System.Console]::Beep(600, 100)
        }
        
        $btn3 = [MinimalButton]::new("Cancel")
        $btn3.OnClick = {
            [System.Console]::Beep(400, 100)
        }
        
        $buttonPanel.AddChild($btn1)
        $buttonPanel.AddChild($btn2)
        $buttonPanel.AddChild($btn3)
        
        # Layout buttons
        $buttonPanel.LayoutChildren = {
            $y = $this.Y + 2
            $x = $this.X + 5
            foreach ($child in $this.Children) {
                $child.SetBounds($x, $y, 20, 1)
                $y += 3
            }
        }.GetNewClosure()
        
        $container.SetBottomChild($buttonPanel)
        $this.DemoArea.AddChild($container)
    }
    
    [void] ShowTextBoxDemo() {
        $container = [VerticalSplit]::new()
        $container.SplitPosition = 10
        
        # Title
        $title = $this.CreateTitle("Minimal TextBox Demo")
        $container.SetTopChild($title)
        
        # Input fields
        $inputPanel = [Container]::new()
        
        $input1 = [MinimalTextBox]::new()
        $input1.Placeholder = "Enter your name..."
        
        $input2 = [MinimalTextBox]::new()
        $input2.Placeholder = "Password"
        $input2.IsPassword = $true
        
        $input3 = [MinimalTextBox]::new()
        $input3.Text = "Pre-filled text"
        $input3.MaxLength = 20
        
        $inputPanel.AddChild($input1)
        $inputPanel.AddChild($input2)
        $inputPanel.AddChild($input3)
        
        # Layout inputs
        $inputPanel.LayoutChildren = {
            $y = $this.Y + 2
            $x = $this.X + 5
            foreach ($child in $this.Children) {
                $child.SetBounds($x, $y, 30, 1)
                $y += 3
            }
        }.GetNewClosure()
        
        $container.SetBottomChild($inputPanel)
        $this.DemoArea.AddChild($container)
    }
    
    [void] ShowListBoxDemo() {
        $container = [VerticalSplit]::new()
        $container.SplitPosition = 10
        
        # Title
        $title = $this.CreateTitle("Minimal ListBox Demo")
        $container.SetTopChild($title)
        
        # List box
        $list = [MinimalListBox]::new()
        $list.ShowBorder = $true
        $list.SetItems(@(
            "First Item",
            "Second Item", 
            "Third Item",
            "Fourth Item",
            "Fifth Item",
            "Sixth Item",
            "Seventh Item",
            "Eighth Item",
            "Ninth Item",
            "Tenth Item"
        ))
        
        $container.SetBottomChild($list)
        $this.DemoArea.AddChild($container)
    }
    
    [void] ShowFocusDemo() {
        $panel = [Container]::new()
        
        # Create mixed focusable elements
        $title = $this.CreateTitle("Focus Navigation Demo")
        $panel.AddChild($title)
        
        $btn1 = [MinimalButton]::new("First")
        $btn1.TabIndex = 1
        
        $input1 = [MinimalTextBox]::new()
        $input1.Placeholder = "Second"
        $input1.TabIndex = 2
        
        $btn2 = [MinimalButton]::new("Third")
        $btn2.TabIndex = 3
        
        $list = [MinimalListBox]::new()
        $list.TabIndex = 4
        $list.SetItems(@("Fourth (List)", "Item 2", "Item 3"))
        $list.ShowBorder = $true
        
        $btn3 = [MinimalButton]::new("Fifth")
        $btn3.TabIndex = 5
        
        $panel.AddChild($btn1)
        $panel.AddChild($input1)
        $panel.AddChild($btn2)
        $panel.AddChild($list)
        $panel.AddChild($btn3)
        
        # Layout
        $panel.LayoutChildren = {
            $y = $this.Y + 5
            $x = $this.X + 5
            
            $this.Children[0].SetBounds($x, $this.Y + 2, 40, 3)  # Title
            $this.Children[1].SetBounds($x, $y, 15, 1)      # btn1
            $this.Children[2].SetBounds($x + 20, $y, 25, 1) # input1
            $this.Children[3].SetBounds($x, $y + 3, 15, 1)  # btn2
            $this.Children[4].SetBounds($x, $y + 6, 30, 8)  # list
            $this.Children[5].SetBounds($x, $y + 15, 15, 1) # btn3
        }.GetNewClosure()
        
        $this.DemoArea.AddChild($panel)
    }
    
    [void] ShowThemeDemo() {
        $panel = [Container]::new()
        
        $title = $this.CreateTitle("Theme Color Showcase")
        $panel.AddChild($title)
        
        # Create color display
        $colorDisplay = [UIElement]::new()
        $colorDisplay.OnRender = {
            $sb = Get-PooledStringBuilder 1024
            $theme = $this.ServiceContainer.GetService('ThemeManager')
            
            $colors = @(
                @{name="Focus"; key="focus"},
                @{name="Accent"; key="accent"},
                @{name="Success"; key="success"},
                @{name="Warning"; key="warning"},
                @{name="Error"; key="error"},
                @{name="Border"; key="border"},
                @{name="Selection"; key="selection"}
            )
            
            $y = $this.Y + 5
            foreach ($color in $colors) {
                $sb.Append([VT]::MoveTo($this.X + 5, $y))
                $sb.Append($color.name.PadRight(12))
                $sb.Append($theme.GetColor($color.key))
                $sb.Append("████████")
                $sb.Append([VT]::Reset())
                $y += 2
            }
            
            $result = $sb.ToString()
            Return-PooledStringBuilder $sb
            return $result
        }.GetNewClosure()
        
        $panel.AddChild($colorDisplay)
        $this.DemoArea.AddChild($panel)
    }
    
    [UIElement] CreateTitle([string]$text) {
        $title = [UIElement]::new()
        $title.OnRender = {
            $sb = Get-PooledStringBuilder 256
            $theme = $this.ServiceContainer.GetService('ThemeManager')
            $sb.Append([VT]::MoveTo($this.X + 2, $this.Y + 1))
            $sb.Append($theme.GetColor('accent'))
            $sb.Append("═══ ")
            $sb.Append($text)
            $sb.Append(" ═══")
            $sb.Append([VT]::Reset())
            $result = $sb.ToString()
            Return-PooledStringBuilder $sb
            return $result
        }.GetNewClosure()
        return $title
    }
    
    [void] OnBoundsChanged() {
        if ($this.MainSplit) {
            $this.MainSplit.SetBounds($this.X, $this.Y, $this.Width, $this.Height)
        }
    }
    
    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        # Number shortcuts for component list
        if ($key.KeyChar -ge '1' -and $key.KeyChar -le '5') {
            $index = [int]($key.KeyChar - '1')
            if ($index -lt $this.ComponentList.Items.Count) {
                $this.ComponentList.SelectedIndex = $index
                $this.ShowDemo($index)
                return $true
            }
        }
        
        return ([Screen]$this).HandleInput($key)
    }
}