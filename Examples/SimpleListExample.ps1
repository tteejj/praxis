# SimpleListExample.ps1 - Example of using SimpleList with UnifiedScreen

. "$PSScriptRoot/../Base/UnifiedScreen.ps1"
. "$PSScriptRoot/../Components/SimpleList.ps1"

class ExampleScreen : UnifiedScreen {
    [SimpleList]$MenuList
    [SimpleList]$ActionList
    
    ExampleScreen() : base("Simple List Example") {
        $this.ShowBorder = $true
    }
    
    [void] OnScreenInitialize() {
        # Create menu list
        $this.MenuList = [SimpleList]::new()
        $this.MenuList.Title = "Main Menu"
        $this.MenuList.ShowBorder = $true
        $this.MenuList.SetItems(@(
            "Projects",
            "Tasks", 
            "Time Tracking",
            "Reports",
            "Settings"
        ))
        
        # Create action list
        $this.ActionList = [SimpleList]::new()
        $this.ActionList.Title = "Actions"
        $this.ActionList.ShowBorder = $true
        $this.ActionList.SetItems(@(
            "Create New",
            "Edit Selected",
            "Delete",
            "Export",
            "Refresh"
        ))
        
        # Set callbacks
        $this.MenuList.OnItemActivated = {
            param($item)
            Write-Host "`nSelected menu item: $item" -ForegroundColor Yellow
        }.GetNewClosure()
        
        $this.ActionList.OnItemActivated = {
            param($item)
            Write-Host "`nSelected action: $item" -ForegroundColor Green
        }.GetNewClosure()
        
        # Add components
        $this.AddChild($this.MenuList)
        $this.AddChild($this.ActionList)
    }
    
    [void] LayoutContent() {
        # Left menu - 30% width
        $menuWidth = [int]($this.Width * 0.3)
        $this.MenuList.SetBounds(
            $this.GetContentX(),
            $this.GetContentY(),
            $menuWidth,
            $this.GetContentHeight()
        )
        
        # Right actions - remaining width
        $actionX = $this.GetContentX() + $menuWidth + 1
        $actionWidth = $this.GetContentWidth() - $menuWidth - 1
        $this.ActionList.SetBounds(
            $actionX,
            $this.GetContentY(),
            $actionWidth,
            $this.GetContentHeight()
        )
    }
    
    [bool] HandleScreenInput([System.ConsoleKeyInfo]$key) {
        switch ($key.Key) {
            ([System.ConsoleKey]::Tab) {
                # Toggle focus between lists
                if ($this.FocusManager) {
                    if ($this.MenuList.IsFocused) {
                        $this.FocusManager.Focus($this.ActionList)
                    } else {
                        $this.FocusManager.Focus($this.MenuList)
                    }
                }
                return $true
            }
            ([System.ConsoleKey]::Escape) {
                # Exit
                return $false
            }
        }
        return $false
    }
}

# Test the example
try {
    # Initialize services
    . "$PSScriptRoot/../Services/ServiceContainer.ps1"
    . "$PSScriptRoot/../Services/EventBus.ps1"
    . "$PSScriptRoot/../Services/ThemeManager.ps1"
    . "$PSScriptRoot/../Services/FocusManager.ps1"
    . "$PSScriptRoot/../Core/ScreenManager.ps1"
    
    $container = [ServiceContainer]::new()
    $container.AddService('EventBus', [EventBus]::new())
    $container.AddService('ThemeManager', [ThemeManager]::new())
    $container.AddService('FocusManager', [FocusManager]::new())
    $container.AddService('ScreenManager', [ScreenManager]::new())
    
    # Create and show screen
    $screen = [ExampleScreen]::new()
    $screen.ServiceContainer = $container
    $screen.Initialize()
    
    # Simple render loop
    [Console]::Clear()
    $screen.SetBounds(0, 0, [Console]::WindowWidth, [Console]::WindowHeight)
    $screen.OnActivated()
    
    Write-Host $screen.Render() -NoNewline
    
    Write-Host "`n`nPress Tab to switch focus, Enter to select, Escape to exit" -ForegroundColor Cyan
    
    while ($true) {
        $key = [Console]::ReadKey($true)
        if ($key.Key -eq [System.ConsoleKey]::Escape) {
            break
        }
        
        if ($screen.HandleInput($key)) {
            [Console]::SetCursorPosition(0, 0)
            Write-Host $screen.Render() -NoNewline
        }
    }
} catch {
    Write-Host "Error: $_" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor DarkGray
}