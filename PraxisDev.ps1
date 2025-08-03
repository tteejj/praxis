# PraxisDev.ps1 - Development utilities that make Praxis actually usable
# This fixes the real problems: positioning, borders, themes, and complex APIs

# Load Praxis
. "$PSScriptRoot/Start.ps1"

#region Debugging Tools - See what's actually happening
function Show-ComponentBounds {
    param([UIElement]$Component)
    
    Write-Host "Component: $($Component.GetType().Name)" -ForegroundColor Cyan
    Write-Host "  Position: X=$($Component.X), Y=$($Component.Y)" -ForegroundColor Yellow
    Write-Host "  Size: Width=$($Component.Width), Height=$($Component.Height)" -ForegroundColor Yellow
    Write-Host "  Visible: $($Component.Visible)" -ForegroundColor Yellow
    
    if ($Component.Children) {
        foreach ($child in $Component.Children) {
            Show-ComponentBounds $child
        }
    }
}

function Test-ScreenLayout {
    param([Screen]$Screen)
    
    # Render to a buffer to see exact output
    $buffer = $Screen.Render()
    
    # Show the raw render output with visible markers
    Write-Host "=== RAW RENDER OUTPUT ===" -ForegroundColor Green
    $lines = $buffer -split "`n"
    $lineNum = 0
    foreach ($line in $lines) {
        Write-Host ("{0,3}: {1}" -f $lineNum, $line.Replace("`e", "<ESC>"))
        $lineNum++
    }
    
    # Show component tree
    Write-Host "`n=== COMPONENT TREE ===" -ForegroundColor Green
    Show-ComponentBounds $Screen
}
#endregion

#region Position Fixing - Make components appear where you want
function Set-AbsolutePosition {
    param(
        [UIElement]$Component,
        [int]$X,
        [int]$Y
    )
    
    # Force absolute positioning, ignoring parent offsets
    $Component.X = $X
    $Component.Y = $Y
    
    # Invalidate entire render tree to force update
    $root = $Component
    while ($root.Parent) { $root = $root.Parent }
    $root.Invalidate()
    
    Write-Host "Set $($Component.GetType().Name) to absolute position ($X, $Y)" -ForegroundColor Green
}

function Fix-ChildPositioning {
    param([Container]$Container)
    
    # Common issue: children positioned relative to parent but parent has offset
    foreach ($child in $Container.Children) {
        # Make child positions relative to parent's actual position
        if ($child.X -lt $Container.X) {
            $child.X = $Container.X + $child.X
        }
        if ($child.Y -lt $Container.Y) {
            $child.Y = $Container.Y + $child.Y
        }
    }
}
#endregion

#region Border Fixing - Make borders render correctly
function Fix-BorderRendering {
    param([UIElement]$Component)
    
    # Common issue: borders render outside component bounds
    if ($Component -is [Container] -or $Component.PSObject.Properties['ShowBorder']) {
        # Ensure border is within bounds
        if ($Component.PSObject.Properties['BorderType']) {
            # Force border to single line for predictability
            $Component.BorderType = [BorderType]::Single
        }
        
        # Ensure content is inset from border
        if ($Component.Children) {
            foreach ($child in $Component.Children) {
                if ($child.X -eq $Component.X) { $child.X += 1 }
                if ($child.Y -eq $Component.Y) { $child.Y += 1 }
                if ($child.Width -eq $Component.Width) { $child.Width -= 2 }
                if ($child.Height -eq $Component.Height) { $child.Height -= 2 }
            }
        }
    }
}

function Test-BorderAlignment {
    param([Screen]$Screen)
    
    # Create test screen with borders
    $testContainer = [Container]::new()
    $testContainer.SetBounds(5, 5, 30, 10)
    $testContainer.ShowBorder = $true
    $testContainer.BorderType = [BorderType]::Single
    
    $Screen.AddChild($testContainer)
    $Screen.Render()
    
    # Check if border is where expected
    Write-Host "Border should be at (5,5) with size 30x10" -ForegroundColor Yellow
}
#endregion

#region Theme Fixing - Make themes actually apply
function Force-ThemeRefresh {
    param([Screen]$Screen)
    
    # Get current theme
    $themeManager = $global:ServiceContainer.GetService('ThemeManager')
    $currentTheme = $themeManager.CurrentTheme
    
    # Force re-application by clearing caches
    if ($Screen.PSObject.Properties['_renderCache']) {
        $Screen._renderCache = ""
        $Screen._cacheInvalid = $true
    }
    
    # Recursively invalidate all children
    function Invalidate-Tree($elem) {
        $elem.Invalidate()
        if ($elem.PSObject.Properties['_renderCache']) {
            $elem._renderCache = ""
            $elem._cacheInvalid = $true
        }
        foreach ($child in $elem.Children) {
            Invalidate-Tree $child
        }
    }
    
    Invalidate-Tree $Screen
    
    # Force theme propagation
    $Screen.PropagateTheme($themeManager)
    
    Write-Host "Forced theme refresh for $($currentTheme.Name)" -ForegroundColor Green
}

function Test-ThemeApplication {
    param(
        [Screen]$Screen,
        [string]$ThemeName
    )
    
    $themeManager = $global:ServiceContainer.GetService('ThemeManager')
    
    Write-Host "Current theme: $($themeManager.CurrentTheme.Name)" -ForegroundColor Yellow
    
    # Change theme
    $themeManager.SetTheme($ThemeName)
    
    # Force refresh
    Force-ThemeRefresh $Screen
    
    # Check what colors are actually being used
    $theme = $themeManager.CurrentTheme
    Write-Host "Theme colors:" -ForegroundColor Yellow
    Write-Host "  Background: $($theme.GetColor('Background').ToEscapeSequence())" 
    Write-Host "  Text: $($theme.GetColor('Text').ToEscapeSequence())"
    Write-Host "  Primary: $($theme.GetColor('Primary').ToEscapeSequence())"
}
#endregion

#region Simple Screen Builder - SpeedTUI-style but using Praxis
function New-SimpleScreen {
    param(
        [string]$Title,
        [scriptblock]$Definition
    )
    
    # Create a screen with automatic layout
    $screen = [Screen]::new()
    $screen.Title = $Title
    
    # Container for auto-layout
    $mainContainer = [Container]::new()
    $mainContainer.SetBounds(0, 2, [Console]::WindowWidth, [Console]::WindowHeight - 3)
    $screen.AddChild($mainContainer)
    
    # Current Y position for vertical stacking
    $currentY = 1
    
    # Helper functions available in definition
    $helpers = @{
        AddPanel = {
            param($title, $height = 10)
            
            $panel = [Container]::new()
            $panel.SetBounds(2, $currentY, [Console]::WindowWidth - 4, $height)
            $panel.ShowBorder = $true
            $panel.BorderType = [BorderType]::Rounded
            
            # Add title as label
            if ($title) {
                $label = [UIElement]::new()
                $label.SetBounds(4, 0, $title.Length, 1)
                $label | Add-Member -MemberType ScriptMethod -Name OnRender -Value {
                    return [VT]::MoveTo($this.X, $this.Y) + $title + [VT]::Reset
                }.GetNewClosure() -Force
                $panel.AddChild($label)
            }
            
            $mainContainer.AddChild($panel)
            $script:currentY += $height + 1
            
            return $panel
        }
        
        AddButton = {
            param($container, $text, $x, $y)
            
            $button = [MinimalButton]::new()
            $button.Text = $text
            $button.IsFocusable = $true
            $button.SetBounds($container.X + $x, $container.Y + $y, $text.Length + 4, 3)
            
            # Fix positioning relative to container
            Fix-ChildPositioning $container
            
            $container.AddChild($button)
            return $button
        }
        
        AddList = {
            param($container, $items, $x = 2, $y = 2)
            
            $list = [MinimalListBox]::new()
            $list.Items.Clear()
            $list.Items.AddRange($items)
            $list.IsFocusable = $true
            $list.SetBounds($container.X + $x, $container.Y + $y, 
                           $container.Width - 4, [Math]::Min($items.Count + 2, 10))
            
            $container.AddChild($list)
            return $list
        }
    }
    
    # Execute definition with helpers
    & $Definition $screen $helpers
    
    # Fix all positioning issues
    Fix-ScreenPositioning $screen
    
    return $screen
}

function Fix-ScreenPositioning {
    param([Screen]$Screen)
    
    # Fix all containers
    foreach ($child in $Screen.Children) {
        if ($child -is [Container]) {
            Fix-ChildPositioning $child
            Fix-BorderRendering $child
        }
    }
    
    # Force complete re-render
    $Screen.Invalidate()
}
#endregion

#region Simple Dialog Builder - Make dialogs that actually work
function New-SimpleDialog {
    param(
        [string]$Title,
        [string]$Message,
        [hashtable[]]$Fields = @(),
        [string[]]$Buttons = @("OK", "Cancel")
    )
    
    # Calculate dialog size based on content
    $maxFieldWidth = 40
    $dialogWidth = [Math]::Max(60, $maxFieldWidth + 20)
    $dialogHeight = 10 + ($Fields.Count * 3) + 4  # Title + fields + buttons + padding
    
    # Create dialog using CleanDialog as base
    $dialog = [CleanDialog]::new($Title, $Message)
    $dialog.SetBounds(
        ([Console]::WindowWidth - $dialogWidth) / 2,
        ([Console]::WindowHeight - $dialogHeight) / 2,
        $dialogWidth,
        $dialogHeight
    )
    
    # Add fields
    $fieldY = 4
    $createdFields = @{}
    
    foreach ($field in $Fields) {
        $textbox = [MinimalTextBox]::new()
        $textbox.Label = $field.Label
        $textbox.Text = $field.DefaultValue ?? ""
        $textbox.IsFocusable = $true
        $textbox.SetBounds(4, $fieldY, $maxFieldWidth, 3)
        
        $dialog.AddChild($textbox)
        $createdFields[$field.Name] = $textbox
        
        $fieldY += 3
    }
    
    # Add buttons with proper positioning
    $buttonY = $dialogHeight - 4
    $totalButtonWidth = 0
    $buttonList = @()
    
    foreach ($btnText in $Buttons) {
        $button = [MinimalButton]::new()
        $button.Text = $btnText
        $button.IsFocusable = $true
        $button.Width = [Math]::Max($btnText.Length + 4, 10)
        $button.Height = 3
        $totalButtonWidth += $button.Width + 2
        $buttonList += $button
    }
    
    # Center buttons
    $buttonX = ($dialogWidth - $totalButtonWidth) / 2
    foreach ($button in $buttonList) {
        $button.SetBounds($buttonX, $buttonY, $button.Width, $button.Height)
        $dialog.AddChild($button)
        
        # Add result handler
        $button | Add-Member -MemberType ScriptMethod -Name HandleInput -Value {
            param([System.ConsoleKeyInfo]$key)
            if ($key.Key -eq [System.ConsoleKey]::Enter -or $key.Key -eq [System.ConsoleKey]::Spacebar) {
                $result = @{
                    Button = $this.Text
                    Fields = @{}
                }
                
                # Collect field values
                foreach ($name in $createdFields.Keys) {
                    $result.Fields[$name] = $createdFields[$name].Text
                }
                
                $this.GetRoot().DialogResult = $result
                $this.GetRoot().ShouldClose = $true
                return $true
            }
            return $false
        }.GetNewClosure() -Force
        
        $buttonX += $button.Width + 2
    }
    
    # Fix dialog positioning
    Fix-DialogPositioning $dialog
    
    return $dialog
}

function Fix-DialogPositioning {
    param([BaseDialog]$Dialog)
    
    # Ensure dialog is centered
    $Dialog.X = ([Console]::WindowWidth - $Dialog.Width) / 2
    $Dialog.Y = ([Console]::WindowHeight - $Dialog.Height) / 2
    
    # Fix all child positions to be relative to dialog
    foreach ($child in $Dialog.Children) {
        if ($child.X -lt $Dialog.X) {
            $child.X = $Dialog.X + $child.X
        }
        if ($child.Y -lt $Dialog.Y) {
            $child.Y = $Dialog.Y + $child.Y
        }
    }
    
    # Force border refresh
    Fix-BorderRendering $Dialog
}
#endregion

#region Quick Fixes for Common Issues
function Fix-ProjectsScreen {
    # Load the screen
    $screen = [ProjectsScreen]::new()
    $screen.OnInitialize()
    
    # Fix common issues
    Write-Host "Fixing ProjectsScreen layout..." -ForegroundColor Yellow
    
    # Fix grid positioning
    if ($screen.ProjectGrid) {
        $screen.ProjectGrid.SetBounds(2, 3, [Console]::WindowWidth - 4, [Console]::WindowHeight - 8)
        Fix-BorderRendering $screen.ProjectGrid
    }
    
    # Force theme application
    Force-ThemeRefresh $screen
    
    return $screen
}

function Fix-DialogButtons {
    param([BaseDialog]$Dialog)
    
    # Find all buttons
    $buttons = $Dialog.Children | Where-Object { $_ -is [MinimalButton] }
    
    if ($buttons.Count -gt 0) {
        # Calculate total width
        $totalWidth = ($buttons | Measure-Object -Property Width -Sum).Sum + (($buttons.Count - 1) * 2)
        
        # Center horizontally
        $startX = ($Dialog.Width - $totalWidth) / 2
        $y = $Dialog.Height - 4
        
        foreach ($button in $buttons) {
            $button.SetBounds($Dialog.X + $startX, $Dialog.Y + $y, $button.Width, $button.Height)
            $startX += $button.Width + 2
        }
    }
}
#endregion

#region Testing Tools
function Test-Component {
    param(
        [UIElement]$Component,
        [string]$TestName = "Component Test"
    )
    
    Write-Host "`n=== $TestName ===" -ForegroundColor Cyan
    
    # Create test screen
    $screen = [Screen]::new()
    $screen.Title = $TestName
    $screen.AddChild($Component)
    
    # Show bounds before render
    Write-Host "Before render:" -ForegroundColor Yellow
    Show-ComponentBounds $Component
    
    # Render
    $output = $screen.Render()
    
    # Show bounds after render
    Write-Host "`nAfter render:" -ForegroundColor Yellow
    Show-ComponentBounds $Component
    
    # Show actual render output
    Write-Host "`nRender output:" -ForegroundColor Yellow
    Write-Host $output
    
    return $screen
}

function Test-DialogCreation {
    $dialog = New-SimpleDialog -Title "Test Dialog" -Message "This is a test" -Fields @(
        @{Name="Field1"; Label="Enter name:"; DefaultValue=""},
        @{Name="Field2"; Label="Enter value:"; DefaultValue=""}
    ) -Buttons @("Save", "Cancel")
    
    Test-Component $dialog "Dialog Test"
}
#endregion

Write-Host @"

PraxisDev loaded. Available commands:

DEBUGGING:
- Show-ComponentBounds `$component    # See where components think they are
- Test-ScreenLayout `$screen         # See raw render output
- Test-Component `$component         # Test individual component rendering

FIXING:
- Fix-ProjectsScreen                 # Returns fixed ProjectsScreen
- Fix-ChildPositioning `$container   # Fix children positions relative to parent
- Fix-BorderRendering `$component    # Fix border rendering issues
- Force-ThemeRefresh `$screen        # Force theme to apply
- Fix-DialogButtons `$dialog         # Fix button positioning in dialogs

BUILDING:
- New-SimpleScreen "Title" { }       # Create screen with auto-layout
- New-SimpleDialog                   # Create dialog that actually works

TESTING:
- Test-BorderAlignment `$screen      # Test if borders render correctly
- Test-ThemeApplication `$screen     # Test theme changes
- Test-DialogCreation                # Test dialog creation

Example:
  `$screen = Fix-ProjectsScreen
  Test-ScreenLayout `$screen

"@ -ForegroundColor Green