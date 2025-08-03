# UnifiedComponentsDemo.ps1 - Demonstration of all unified components working together
# This shows the proper theme integration and consistent behavior

class UnifiedComponentsDemo : Screen {
    [UnifiedList]$TestList
    [UnifiedInput]$TestInput
    [UnifiedButton]$TestButton
    [UnifiedFileTree]$TestFileTree
    
    UnifiedComponentsDemo() : base() {
        $this.Title = "Unified Components Demo - Consistent Amber Theme"
    }
    
    [void] OnInitialize() {
        ([Screen]$this).OnInitialize()
        
        # Create test data for the list
        $testItems = @(
            @{ Name = "ProjectsScreen"; Status = "✓ Migrated"; Component = "UnifiedList (DataGrid mode)" }
            @{ Name = "TaskScreen"; Status = "⏳ Pending"; Component = "UnifiedList (DataGrid mode)" }
            @{ Name = "CommandLibraryScreen"; Status = "⏳ Pending"; Component = "UnifiedList (SearchList mode)" }
            @{ Name = "FileBrowserScreen"; Status = "⏳ Pending"; Component = "UnifiedFileTree (Ranger mode)" }
            @{ Name = "All Dialogs"; Status = "✓ UnifiedDialog"; Component = "UnifiedInput + UnifiedButton" }
        )
        
        # Create UnifiedList in DataGrid mode (like ProjectsScreen will use)
        $this.TestList = [UnifiedList]::new([UnifiedListMode]::DataGrid)
        $this.TestList.Title = "Screens Migration Status"
        $this.TestList.ShowBorder = $true
        
        # Define columns for the demo
        $columns = @(
            @{
                Name = "Name"
                Header = "Screen"
                Width = 20
            },
            @{
                Name = "Status"  
                Header = "Status"
                Width = 12
            },
            @{
                Name = "Component"
                Header = "New Component"
                Width = 0  # Flexible width
            }
        )
        $this.TestList.SetColumns($columns)
        $this.TestList.SetItems($testItems)
        $this.AddChild($this.TestList)
        
        # Create UnifiedInput in Field mode (like dialogs will use)
        $this.TestInput = [UnifiedInput]::new([UnifiedInputMode]::Field)
        $this.TestInput.SetLabel("Test Input")
        $this.TestInput.Placeholder = "Type here to test consistent theming..."
        $this.TestInput.ShowBorder = $false  # Clean look like DialogField
        $this.AddChild($this.TestInput)
        
        # Create UnifiedButton (like dialogs will use)
        $this.TestButton = [UnifiedButton]::new("Test Button")
        $this.TestButton.IsDefault = $true
        $demo = $this
        $this.TestButton.OnClick = {
            # Show that button works - add item to list
            $newItem = @{ 
                Name = "TestItem$((Get-Date).Millisecond)"
                Status = "✓ Added"
                Component = "UnifiedButton click test"
            }
            $currentItems = [System.Collections.ArrayList]::new()
            foreach ($item in $demo.TestList.Items) {
                $currentItems.Add($item) | Out-Null
            }
            $currentItems.Add($newItem) | Out-Null
            $demo.TestList.SetItems($currentItems)
        }.GetNewClosure()
        $this.AddChild($this.TestButton)
        
        # Create UnifiedFileTree in Simple mode (for space constraints)
        $this.TestFileTree = [UnifiedFileTree]::new([UnifiedFileTreeMode]::Simple, $PWD.Path)
        $this.TestFileTree.Title = "File Browser Test"
        $this.TestFileTree.ShowBorder = $true
        $this.AddChild($this.TestFileTree)
    }
    
    [void] OnBoundsChanged() {
        ([Screen]$this).OnBoundsChanged()
        
        if ($this.Width -le 0 -or $this.Height -le 0) {
            return
        }
        
        # Layout components in a 2x2 grid to show all unified components
        $halfWidth = [int]($this.Width / 2)
        $halfHeight = [int]($this.Height / 2)
        
        # Top left: UnifiedList (main component)
        if ($this.TestList) {
            $this.TestList.SetBounds($this.X, $this.Y, $halfWidth - 1, $halfHeight - 2)
        }
        
        # Top right: UnifiedFileTree
        if ($this.TestFileTree) {
            $this.TestFileTree.SetBounds($this.X + $halfWidth, $this.Y, $halfWidth, $halfHeight - 2)
        }
        
        # Bottom left: UnifiedInput
        if ($this.TestInput) {
            $this.TestInput.SetBounds($this.X + 2, $this.Y + $halfHeight, $halfWidth - 4, 1)
        }
        
        # Bottom right: UnifiedButton
        if ($this.TestButton) {
            $this.TestButton.SetBounds($this.X + $halfWidth + 2, $this.Y + $halfHeight, 15, 3)
        }
    }
    
    [bool] HandleScreenInput([System.ConsoleKeyInfo]$keyInfo) {
        # Tab navigation between components
        switch ($keyInfo.Key) {
            ([System.ConsoleKey]::F1) {
                # Focus the list
                $focusManager = $this.GetService('FocusManager')
                if ($focusManager) {
                    $focusManager.SetFocus($this.TestList)
                }
                return $true
            }
            ([System.ConsoleKey]::F2) {
                # Focus the input
                $focusManager = $this.GetService('FocusManager')
                if ($focusManager) {
                    $focusManager.SetFocus($this.TestInput)
                }
                return $true
            }
            ([System.ConsoleKey]::F3) {
                # Focus the button
                $focusManager = $this.GetService('FocusManager')
                if ($focusManager) {
                    $focusManager.SetFocus($this.TestButton)
                }
                return $true
            }
            ([System.ConsoleKey]::F4) {
                # Focus the file tree
                $focusManager = $this.GetService('FocusManager')
                if ($focusManager) {
                    $focusManager.SetFocus($this.TestFileTree)
                }
                return $true
            }
        }
        
        return $false
    }
}