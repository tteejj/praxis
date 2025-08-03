# PraxisEasyAPI.ps1 - Complete abstraction layer for easy Praxis development
# This ACTUALLY interfaces with Praxis's real components

# Load the actual Praxis base components and services
. "$PSScriptRoot/Base/UIElement.ps1"
. "$PSScriptRoot/Base/Screen.ps1"
. "$PSScriptRoot/Base/Container.ps1"
. "$PSScriptRoot/Base/FocusableComponent.ps1"
. "$PSScriptRoot/Base/BaseDialog.ps1"
. "$PSScriptRoot/Base/SimpleDialog.ps1"
. "$PSScriptRoot/Base/CleanDialog.ps1"
. "$PSScriptRoot/Core/ServiceContainer.ps1"
. "$PSScriptRoot/Core/VT100.ps1"
. "$PSScriptRoot/Core/BorderStyle.ps1"
. "$PSScriptRoot/Core/RenderHelper.ps1"
. "$PSScriptRoot/Core/StringCache.ps1"
. "$PSScriptRoot/Services/ThemeManager.ps1"
. "$PSScriptRoot/Components/MinimalButton.ps1"
. "$PSScriptRoot/Components/MinimalListBox.ps1"
. "$PSScriptRoot/Components/MinimalDataGrid.ps1"
. "$PSScriptRoot/Components/MinimalTextBox.ps1"

#region Layout System that works with UIElement
class EasyLayout {
    hidden [Container]$Container
    hidden [string]$LayoutType = "vertical"  # vertical, horizontal, grid, absolute
    hidden [int]$Spacing = 1
    hidden [hashtable]$Padding = @{Top=1; Right=1; Bottom=1; Left=1}
    hidden [UIElement[]]$ManagedElements = @()
    
    EasyLayout([Container]$container) {
        $this.Container = $container
    }
    
    # Fluent API for configuration
    [EasyLayout] Vertical() {
        $this.LayoutType = "vertical"
        return $this
    }
    
    [EasyLayout] Horizontal() {
        $this.LayoutType = "horizontal"
        return $this
    }
    
    [EasyLayout] Grid([int]$columns) {
        $this.LayoutType = "grid"
        $this.Container.PSObject.Properties.Add([PSNoteProperty]::new('GridColumns', $columns))
        return $this
    }
    
    [EasyLayout] WithSpacing([int]$spacing) {
        $this.Spacing = $spacing
        return $this
    }
    
    [EasyLayout] WithPadding([int]$all) {
        $this.Padding = @{Top=$all; Right=$all; Bottom=$all; Left=$all}
        return $this
    }
    
    [EasyLayout] WithPadding([int]$vertical, [int]$horizontal) {
        $this.Padding = @{Top=$vertical; Right=$horizontal; Bottom=$vertical; Left=$horizontal}
        return $this
    }
    
    # Add element and auto-layout
    [void] Add([UIElement]$element) {
        $this.Container.AddChild($element)
        $this.ManagedElements += $element
        $this.ArrangeElements()
    }
    
    # Arrange all managed elements based on layout type
    [void] ArrangeElements() {
        $startX = $this.Container.X + $this.Padding.Left
        $startY = $this.Container.Y + $this.Padding.Top
        $availableWidth = $this.Container.Width - $this.Padding.Left - $this.Padding.Right
        $availableHeight = $this.Container.Height - $this.Padding.Top - $this.Padding.Bottom
        
        switch ($this.LayoutType) {
            "vertical" {
                $currentY = $startY
                foreach ($element in $this.ManagedElements) {
                    $element.SetBounds($startX, $currentY, 
                        [Math]::Min($element.Width, $availableWidth), $element.Height)
                    $currentY += $element.Height + $this.Spacing
                }
            }
            
            "horizontal" {
                $currentX = $startX
                foreach ($element in $this.ManagedElements) {
                    $element.SetBounds($currentX, $startY, $element.Width, $element.Height)
                    $currentX += $element.Width + $this.Spacing
                }
            }
            
            "grid" {
                $columns = $this.Container.GridColumns ?? 3
                $cellWidth = [Math]::Floor($availableWidth / $columns)
                $col = 0
                $row = 0
                
                foreach ($element in $this.ManagedElements) {
                    $x = $startX + ($col * $cellWidth)
                    $y = $startY + ($row * ($element.Height + $this.Spacing))
                    $element.SetBounds($x, $y, [Math]::Min($element.Width, $cellWidth - $this.Spacing), $element.Height)
                    
                    $col++
                    if ($col -ge $columns) {
                        $col = 0
                        $row++
                    }
                }
            }
        }
    }
}
#endregion

#region Easy Panel (extends Container with simple API)
class EasyPanel : Container {
    [string]$Title
    [EasyLayout]$Layout
    [BorderType]$BorderType = [BorderType]::Rounded
    [bool]$ShowTitle = $true
    
    EasyPanel([string]$title) : base() {
        $this.Title = $title
        $this.Layout = [EasyLayout]::new($this)
        $this.ShowBorder = $true
    }
    
    # Simple component addition methods
    [MinimalButton] AddButton([string]$text, [scriptblock]$onClick) {
        $button = [MinimalButton]::new()
        $button.Text = $text
        $button.IsFocusable = $true
        
        if ($onClick) {
            # Create proper click handler
            $button.PSObject.Properties.Add([PSNoteProperty]::new('OnClick', $onClick))
            
            # Override HandleInput to call OnClick on Enter/Space
            $button | Add-Member -MemberType ScriptMethod -Name HandleInput -Value {
                param([System.ConsoleKeyInfo]$key)
                if ($key.Key -eq [System.ConsoleKey]::Enter -or $key.Key -eq [System.ConsoleKey]::Spacebar) {
                    if ($this.OnClick) {
                        & $this.OnClick
                    }
                    return $true
                }
                return $false
            } -Force
        }
        
        # Auto-size button
        $button.Width = [Math]::Max($text.Length + 4, 10)
        $button.Height = 3
        
        $this.Layout.Add($button)
        return $button
    }
    
    [MinimalListBox] AddList([string[]]$items) {
        $list = [MinimalListBox]::new()
        $list.Items.Clear()
        $list.Items.AddRange($items)
        $list.IsFocusable = $true
        $list.Height = [Math]::Min($items.Count + 2, 10)
        $list.Width = $this.Width - 4
        
        $this.Layout.Add($list)
        return $list
    }
    
    [MinimalDataGrid] AddDataGrid([array]$data, [hashtable[]]$columns) {
        $grid = [MinimalDataGrid]::new()
        $grid.IsFocusable = $true
        
        # Configure columns
        foreach ($col in $columns) {
            $grid.AddColumn($col)
        }
        
        # Set data
        $grid.SetItems($data)
        
        # Auto-size
        $grid.Width = $this.Width - 4
        $grid.Height = [Math]::Min($data.Count + 4, 15)
        
        $this.Layout.Add($grid)
        return $grid
    }
    
    [MinimalTextBox] AddTextBox([string]$label, [string]$defaultValue = "") {
        $textbox = [MinimalTextBox]::new()
        $textbox.Label = $label
        $textbox.Text = $defaultValue
        $textbox.IsFocusable = $true
        $textbox.Width = $this.Width - 4
        $textbox.Height = 3
        
        $this.Layout.Add($textbox)
        return $textbox
    }
    
    # Add raw text/label
    [void] AddText([string]$text, [string]$color = "Text") {
        # Create a simple label component
        $label = [UIElement]::new()
        $label.Height = 1
        $label.Width = $text.Length
        
        # Override OnRender to display text
        $label | Add-Member -MemberType ScriptMethod -Name OnRender -Value {
            $theme = $this.ServiceContainer.GetService('ThemeManager')
            $colors = $theme.GetColor($color)
            return [RenderHelper]::MoveTo($this.X, $this.Y) + $colors.ToEscapeSequence() + $text + [VT]::Reset
        }.GetNewClosure() -Force
        
        $this.Layout.Add($label)
    }
    
    # Configure layout
    [EasyPanel] UseVerticalLayout() {
        $this.Layout.Vertical()
        return $this
    }
    
    [EasyPanel] UseHorizontalLayout() {
        $this.Layout.Horizontal()
        return $this
    }
    
    [EasyPanel] UseGridLayout([int]$columns) {
        $this.Layout.Grid($columns)
        return $this
    }
    
    # Override OnBoundsChanged to re-layout
    [void] OnBoundsChanged() {
        ([Container]$this).OnBoundsChanged()
        if ($this.Layout) {
            $this.Layout.ArrangeElements()
        }
    }
}
#endregion

#region Easy Screen (extends Screen with simple API)
class EasyScreen : Screen {
    hidden [hashtable]$Panels = @{}
    hidden [EasyLayout]$MainLayout
    
    EasyScreen([string]$title) : base() {
        $this.Title = $title
        # Create main container for auto-layout
        $mainContainer = [Container]::new()
        $mainContainer.SetBounds(0, 1, [Console]::WindowWidth, [Console]::WindowHeight - 2)
        $this.AddChild($mainContainer)
        $this.MainLayout = [EasyLayout]::new($mainContainer).Vertical().WithSpacing(0)
    }
    
    # Add panel with automatic positioning
    [EasyPanel] AddPanel([string]$name, [int]$height = 10) {
        $panel = [EasyPanel]::new($name)
        $panel.Height = $height
        $panel.Width = [Console]::WindowWidth - 4
        
        $this.Panels[$name] = $panel
        $this.MainLayout.Add($panel)
        
        return $panel
    }
    
    # Add side-by-side panels
    [hashtable] AddSplitPanels([string]$leftName, [string]$rightName, [int]$splitPercent = 50) {
        # Create horizontal container
        $splitContainer = [Container]::new()
        $splitContainer.Height = [Console]::WindowHeight - 6
        $splitContainer.Width = [Console]::WindowWidth - 4
        
        $leftWidth = [Math]::Floor($splitContainer.Width * $splitPercent / 100)
        $rightWidth = $splitContainer.Width - $leftWidth - 1
        
        $leftPanel = [EasyPanel]::new($leftName)
        $leftPanel.SetBounds(0, 0, $leftWidth, $splitContainer.Height)
        $splitContainer.AddChild($leftPanel)
        
        $rightPanel = [EasyPanel]::new($rightName)
        $rightPanel.SetBounds($leftWidth + 1, 0, $rightWidth, $splitContainer.Height)
        $splitContainer.AddChild($rightPanel)
        
        $this.Panels[$leftName] = $leftPanel
        $this.Panels[$rightName] = $rightPanel
        
        $this.MainLayout.Add($splitContainer)
        
        return @{
            Left = $leftPanel
            Right = $rightPanel
        }
    }
    
    # Get panel by name
    [EasyPanel] GetPanel([string]$name) {
        return $this.Panels[$name]
    }
    
    # Add status bar at bottom
    [void] AddStatusBar([string]$text) {
        $statusBar = [UIElement]::new()
        $statusBar.SetBounds(0, [Console]::WindowHeight - 1, [Console]::WindowWidth, 1)
        
        $statusBar | Add-Member -MemberType ScriptMethod -Name OnRender -Value {
            $theme = $this.ServiceContainer.GetService('ThemeManager')
            $colors = $theme.GetColor("StatusBar")
            $clearLine = [StringCache]::GetSpaces([Console]::WindowWidth)
            return [VT]::MoveTo(0, [Console]::WindowHeight - 1) + 
                   $colors.ToEscapeSequence() + $clearLine +
                   [VT]::MoveTo(1, [Console]::WindowHeight - 1) + $text + [VT]::Reset
        }.GetNewClosure() -Force
        
        $this.AddChild($statusBar)
    }
}
#endregion

#region Dialog Helpers (using Praxis dialogs)
function Show-EasyDialog {
    param(
        [string]$Title,
        [string]$Message,
        [string[]]$Buttons = @("OK"),
        [string]$DefaultButton = $null
    )
    
    # Use CleanDialog for simple dialogs
    $dialog = [CleanDialog]::new($Title, $Message)
    
    # Add buttons
    $buttonIndex = 0
    foreach ($btnText in $Buttons) {
        $button = [MinimalButton]::new()
        $button.Text = $btnText
        $button.IsFocusable = $true
        $button.Width = [Math]::Max($btnText.Length + 4, 10)
        $button.Height = 3
        
        # Set as default if specified
        if ($btnText -eq $DefaultButton) {
            $button.IsDefault = $true
        }
        
        # Add click handler to close dialog with result
        $button | Add-Member -MemberType ScriptMethod -Name HandleInput -Value {
            param([System.ConsoleKeyInfo]$key)
            if ($key.Key -eq [System.ConsoleKey]::Enter -or $key.Key -eq [System.ConsoleKey]::Spacebar) {
                $this.GetRoot().DialogResult = $this.Text
                $this.GetRoot().ShouldClose = $true
                return $true
            }
            return $false
        } -Force
        
        $dialog.AddButton($button)
        $buttonIndex++
    }
    
    # Show dialog and return result
    return $dialog.ShowDialog()
}

function Show-EasyInputDialog {
    param(
        [string]$Title,
        [string]$Prompt,
        [string]$DefaultValue = ""
    )
    
    # Create custom dialog with text input
    $dialog = [CleanDialog]::new($Title, $Prompt)
    
    # Add text box
    $textbox = [MinimalTextBox]::new()
    $textbox.Text = $DefaultValue
    $textbox.IsFocusable = $true
    $textbox.Width = 40
    $textbox.Height = 3
    
    # Position textbox in dialog content area
    $textbox.SetBounds(2, 4, 40, 3)
    $dialog.AddChild($textbox)
    
    # Add OK/Cancel buttons
    $okButton = [MinimalButton]::new()
    $okButton.Text = "OK"
    $okButton.IsFocusable = $true
    $okButton.IsDefault = $true
    
    $okButton | Add-Member -MemberType ScriptMethod -Name HandleInput -Value {
        param([System.ConsoleKeyInfo]$key)
        if ($key.Key -eq [System.ConsoleKey]::Enter -or $key.Key -eq [System.ConsoleKey]::Spacebar) {
            # Get the textbox value
            $root = $this.GetRoot()
            $textbox = $root.Children | Where-Object { $_ -is [MinimalTextBox] } | Select-Object -First 1
            $root.DialogResult = $textbox.Text
            $root.ShouldClose = $true
            return $true
        }
        return $false
    } -Force
    
    $cancelButton = [MinimalButton]::new()
    $cancelButton.Text = "Cancel"
    $cancelButton.IsFocusable = $true
    
    $cancelButton | Add-Member -MemberType ScriptMethod -Name HandleInput -Value {
        param([System.ConsoleKeyInfo]$key)
        if ($key.Key -eq [System.ConsoleKey]::Enter -or $key.Key -eq [System.ConsoleKey]::Spacebar) {
            $this.GetRoot().DialogResult = $null
            $this.GetRoot().ShouldClose = $true
            return $true
        }
        return $false
    } -Force
    
    $dialog.AddButton($okButton)
    $dialog.AddButton($cancelButton)
    
    # Focus the textbox initially
    $textbox.Focus()
    
    return $dialog.ShowDialog()
}

function Show-EasyListDialog {
    param(
        [string]$Title,
        [string[]]$Items,
        [bool]$MultiSelect = $false
    )
    
    $dialog = [CleanDialog]::new($Title, "Select an item:")
    
    # Add list box
    $listbox = [MinimalListBox]::new()
    $listbox.Items.Clear()
    $listbox.Items.AddRange($Items)
    $listbox.IsFocusable = $true
    $listbox.Height = [Math]::Min($Items.Count + 2, 10)
    $listbox.Width = 40
    $listbox.MultiSelect = $MultiSelect
    
    $listbox.SetBounds(2, 4, 40, $listbox.Height)
    $dialog.AddChild($listbox)
    
    # Add OK/Cancel buttons
    $okButton = [MinimalButton]::new()
    $okButton.Text = "OK"
    $okButton.IsFocusable = $true
    
    $okButton | Add-Member -MemberType ScriptMethod -Name HandleInput -Value {
        param([System.ConsoleKeyInfo]$key)
        if ($key.Key -eq [System.ConsoleKey]::Enter -or $key.Key -eq [System.ConsoleKey]::Spacebar) {
            $root = $this.GetRoot()
            $listbox = $root.Children | Where-Object { $_ -is [MinimalListBox] } | Select-Object -First 1
            if ($listbox.MultiSelect) {
                $root.DialogResult = $listbox.GetSelectedItems()
            } else {
                $root.DialogResult = $listbox.GetSelectedItem()
            }
            $root.ShouldClose = $true
            return $true
        }
        return $false
    } -Force
    
    $dialog.AddButton($okButton)
    $dialog.AddButton([MinimalButton]@{Text="Cancel"; IsFocusable=$true})
    
    # Focus the listbox
    $listbox.Focus()
    
    return $dialog.ShowDialog()
}
#endregion

#region Theme Helpers
function Set-EasyTheme {
    param([string]$themeName)
    
    $themeManager = $global:ServiceContainer.GetService('ThemeManager')
    if ($themeManager) {
        $themeManager.SetTheme($themeName)
    }
}

function Get-AvailableThemes {
    $themeManager = $global:ServiceContainer.GetService('ThemeManager')
    if ($themeManager) {
        return $themeManager.AvailableThemes
    }
    return @()
}
#endregion

#region Component Creation Helpers
function New-Button {
    param(
        [string]$Text,
        [scriptblock]$OnClick = $null
    )
    
    $button = [MinimalButton]::new()
    $button.Text = $Text
    $button.IsFocusable = $true
    $button.Width = [Math]::Max($Text.Length + 4, 10)
    $button.Height = 3
    
    if ($OnClick) {
        $button.PSObject.Properties.Add([PSNoteProperty]::new('OnClick', $OnClick))
        $button | Add-Member -MemberType ScriptMethod -Name HandleInput -Value {
            param([System.ConsoleKeyInfo]$key)
            if ($key.Key -eq [System.ConsoleKey]::Enter -or $key.Key -eq [System.ConsoleKey]::Spacebar) {
                if ($this.OnClick) {
                    & $this.OnClick
                }
                return $true
            }
            return $false
        } -Force
    }
    
    return $button
}

function New-TextBox {
    param(
        [string]$Label = "",
        [string]$DefaultValue = "",
        [int]$Width = 30
    )
    
    $textbox = [MinimalTextBox]::new()
    $textbox.Label = $Label
    $textbox.Text = $DefaultValue
    $textbox.Width = $Width
    $textbox.Height = 3
    $textbox.IsFocusable = $true
    
    return $textbox
}

function New-ListBox {
    param(
        [string[]]$Items,
        [bool]$MultiSelect = $false
    )
    
    $listbox = [MinimalListBox]::new()
    $listbox.Items.Clear()
    $listbox.Items.AddRange($Items)
    $listbox.MultiSelect = $MultiSelect
    $listbox.IsFocusable = $true
    $listbox.Height = [Math]::Min($Items.Count + 2, 10)
    
    return $listbox
}

function New-DataGrid {
    param(
        [array]$Data,
        [hashtable[]]$Columns
    )
    
    $grid = [MinimalDataGrid]::new()
    $grid.IsFocusable = $true
    
    foreach ($col in $Columns) {
        $grid.AddColumn($col)
    }
    
    $grid.SetItems($Data)
    
    return $grid
}
#endregion

#region Position Helpers
function Center-Component {
    param(
        [UIElement]$Component,
        [UIElement]$Container = $null
    )
    
    if (-not $Container) {
        # Center on screen
        $x = ([Console]::WindowWidth - $Component.Width) / 2
        $y = ([Console]::WindowHeight - $Component.Height) / 2
    } else {
        # Center within container
        $x = $Container.X + (($Container.Width - $Component.Width) / 2)
        $y = $Container.Y + (($Container.Height - $Component.Height) / 2)
    }
    
    $Component.SetBounds([Math]::Max(0, $x), [Math]::Max(0, $y), $Component.Width, $Component.Height)
}

function Align-Components {
    param(
        [UIElement[]]$Components,
        [string]$Alignment = "left",  # left, center, right
        [UIElement]$Container = $null
    )
    
    $containerWidth = if ($Container) { $Container.Width } else { [Console]::WindowWidth }
    $containerX = if ($Container) { $Container.X } else { 0 }
    
    foreach ($comp in $Components) {
        $x = switch ($Alignment) {
            "left" { $containerX + 2 }
            "center" { $containerX + ($containerWidth - $comp.Width) / 2 }
            "right" { $containerX + $containerWidth - $comp.Width - 2 }
        }
        $comp.X = [Math]::Max(0, $x)
    }
}

function Stack-Components {
    param(
        [UIElement[]]$Components,
        [string]$Direction = "vertical",  # vertical, horizontal
        [int]$StartX = 0,
        [int]$StartY = 0,
        [int]$Spacing = 1
    )
    
    $currentX = $StartX
    $currentY = $StartY
    
    foreach ($comp in $Components) {
        $comp.SetBounds($currentX, $currentY, $comp.Width, $comp.Height)
        
        if ($Direction -eq "vertical") {
            $currentY += $comp.Height + $Spacing
        } else {
            $currentX += $comp.Width + $Spacing
        }
    }
}
#endregion

#region Quick Screen Builder
function New-EasyScreen {
    param(
        [string]$Title,
        [scriptblock]$Builder
    )
    
    $screen = [EasyScreen]::new($Title)
    
    # Execute builder with screen context
    & $Builder $screen
    
    return $screen
}

# Example usage:
# $screen = New-EasyScreen "My Screen" {
#     param($s)
#     
#     $panel = $s.AddPanel("Main Panel", 20)
#     $panel.AddButton("Click Me", { Write-Host "Clicked!" })
#     $panel.AddList(@("Item 1", "Item 2", "Item 3"))
# }
#endregion

#region Application Integration
function Start-EasyApp {
    param(
        [Screen]$MainScreen,
        [string]$Theme = "amber"
    )
    
    # Ensure services are initialized
    if (-not $global:ServiceContainer) {
        . "$PSScriptRoot/Start.ps1"
    }
    
    # Set theme
    Set-EasyTheme $Theme
    
    # Get screen manager and show screen
    $screenManager = $global:ServiceContainer.GetService('ScreenManager')
    if ($screenManager) {
        $screenManager.PushScreen($MainScreen)
        
        # Main render loop
        while ($screenManager.HasScreens()) {
            $screenManager.HandleInput()
            $screenManager.Render()
        }
    }
}
#endregion

# Export all functions and classes
Export-ModuleMember -Function * -Class *