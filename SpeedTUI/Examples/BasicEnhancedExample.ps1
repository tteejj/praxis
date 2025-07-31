# Basic Enhanced SpeedTUI Example
# Demonstrates the new features while maintaining simplicity

# Load the enhanced components
. "$PSScriptRoot/../Core/Internal/PerformanceCore.ps1"
. "$PSScriptRoot/../Services/EnhancedThemeManager.ps1"
. "$PSScriptRoot/../Core/EnhancedComponent.ps1"
. "$PSScriptRoot/../Core/EventManager.ps1"
. "$PSScriptRoot/../Utils/DevHelpers.ps1"

<#
.SYNOPSIS
Basic example showing enhanced SpeedTUI features

.DESCRIPTION
This example demonstrates:
- Automatic performance optimizations (invisible)
- Easy theme switching
- Simple component positioning
- Event-driven architecture
- Development helpers

.EXAMPLE
./BasicEnhancedExample.ps1
#>

Write-Host "=== Enhanced SpeedTUI Basic Example ===" -ForegroundColor Cyan
Write-Host "Demonstrating new features with simple code..." -ForegroundColor Green

# Start performance monitoring (optional)
Write-Host "`nStarting performance monitoring..." -ForegroundColor Yellow
Start-SpeedTUIPerformanceMonitoring

# Show available themes
Write-Host "`nAvailable themes:" -ForegroundColor Magenta
$themeManager = Get-ThemeManager
$themes = $themeManager.GetAvailableThemes()
foreach ($theme in $themes) {
    $info = $themeManager.GetThemeInfo($theme)
    Write-Host "  $theme - $($info.Description)" -ForegroundColor Gray
}

# Set a theme
Write-Host "`nSetting theme to 'matrix'..." -ForegroundColor Yellow
Set-SpeedTUITheme "matrix"

# Create components with enhanced features
Write-Host "`nCreating enhanced components..." -ForegroundColor Yellow

# Create buttons with different themes and colors
$button1 = [EnhancedComponent]::new()
$button1.Id = "button1"
$button1.SetPosition(10, 5)
$button1.SetSize(20, 3)
$button1.SetTheme("matrix")
$button1.SetColor("primary")

$button2 = [EnhancedComponent]::new()
$button2.Id = "button2"
$button2.SetPosition(35, 5)
$button2.SetSize(20, 3)
$button2.SetTheme("amber")
$button2.SetColor("secondary")

$button3 = [EnhancedComponent]::new()
$button3.Id = "button3"
$button3.SetPosition(60, 5)
$button3.SetSize(20, 3)
$button3.SetTheme("electric")
$button3.SetColor("primary")

# Create some labels and arrange them automatically
$label1 = [EnhancedComponent]::new()
$label1.Id = "label1"
$label1.SetSize(15, 1)

$label2 = [EnhancedComponent]::new() 
$label2.Id = "label2"
$label2.SetSize(15, 1)

$label3 = [EnhancedComponent]::new()
$label3.Id = "label3" 
$label3.SetSize(15, 1)

# Arrange labels horizontally
Write-Host "Arranging labels horizontally..." -ForegroundColor Yellow
@($label1, $label2, $label3) | Arrange-Horizontally -StartX 10 -StartY 10 -Spacing 5

# Set up event system
Write-Host "`nSetting up event system..." -ForegroundColor Yellow
$events = Get-EventManager

# Subscribe to component events
$buttonClickId = $events.On("component.clicked") { param($eventData)
    $componentId = $eventData.Get("ComponentId")
    $theme = $eventData.Get("Theme")
    Write-Host "Component '$componentId' with theme '$theme' was clicked!" -ForegroundColor Green
    
    # Fire a secondary event
    Fire-Event "user.interaction" @{
        Type = "click"
        Component = $componentId
        Timestamp = [DateTime]::Now
    }
}

# Subscribe to user interaction events
$interactionId = Subscribe-Event "user.interaction" { param($e)
    $type = $e.Get("Type")
    $component = $e.Get("Component")
    Write-Host "User interaction: $type on $component" -ForegroundColor Blue
}

# Simulate component interactions
Write-Host "`nSimulating component interactions..." -ForegroundColor Yellow

# Fire some events to demonstrate the system
$events.Fire("component.clicked", @{
    ComponentId = $button1.Id
    Theme = $button1.ThemeName
    Position = @{ X = $button1.X; Y = $button1.Y }
})

$events.Fire("component.clicked", @{
    ComponentId = $button2.Id  
    Theme = $button2.ThemeName
    Position = @{ X = $button2.X; Y = $button2.Y }
})

# Show component information
Write-Host "`nComponent Information:" -ForegroundColor Magenta
Write-Host "Button 1: $($button1.Id) at $($button1.X),$($button1.Y) with theme '$($button1.ThemeName)'" -ForegroundColor Gray
Write-Host "Button 2: $($button2.Id) at $($button2.X),$($button2.Y) with theme '$($button2.ThemeName)'" -ForegroundColor Gray
Write-Host "Button 3: $($button3.Id) at $($button3.X),$($button3.Y) with theme '$($button3.ThemeName)'" -ForegroundColor Gray

# Demonstrate performance stats
Write-Host "`nComponent Performance Stats:" -ForegroundColor Magenta
$stats1 = $button1.GetPerformanceStats()
Write-Host "  $($stats1.Id): Renders=$($stats1.RenderCount), Cache=$($stats1.CacheEnabled)" -ForegroundColor Gray

# Demonstrate development helpers
Write-Host "`nDevelopment Helper Examples:" -ForegroundColor Cyan

# Show a simple layout visualization (simplified for demo)
Write-Host "`nSimulated Layout:" -ForegroundColor Yellow
Write-Host "┌──────────────────────────────────────────────────────────────────────────────┐" -ForegroundColor Green
Write-Host "│                                                                              │" -ForegroundColor Green
Write-Host "│    [Matrix Btn]     [Amber Btn]      [Electric Btn]                         │" -ForegroundColor Green  
Write-Host "│         10,5           35,5             60,5                                 │" -ForegroundColor Green
Write-Host "│                                                                              │" -ForegroundColor Green
Write-Host "│    [Label1]     [Label2]     [Label3]                                       │" -ForegroundColor Green
Write-Host "│      10,10        20,10        30,10                                        │" -ForegroundColor Green
Write-Host "│                                                                              │" -ForegroundColor Green
Write-Host "└──────────────────────────────────────────────────────────────────────────────┘" -ForegroundColor Green

# Show theme colors
Write-Host "`nTheme Color Examples:" -ForegroundColor Cyan
$matrixColor = Get-SpeedTUIColor "primary"
$amberTheme = $themeManager.GetThemeInfo("amber")
$electricTheme = $themeManager.GetThemeInfo("electric")

Write-Host "Matrix theme primary: ${matrixColor}████$([EnhancedColors]::Reset) (Green)" -ForegroundColor Gray
Write-Host "Amber theme: Available colors: $($amberTheme.Colors -join ', ')" -ForegroundColor Gray
Write-Host "Electric theme: Available colors: $($electricTheme.Colors -join ', ')" -ForegroundColor Gray

# Demonstrate event history (if enabled)
$events.SetDebugMode($true)
$events.Fire("demo.event", "This is a demo event")
$events.Fire("demo.event", "This is another demo event")

$history = $events.GetEventHistory(5)
if ($history.Count -gt 0) {
    Write-Host "`nRecent Events:" -ForegroundColor Cyan
    foreach ($event in $history) {
        Write-Host "  $($event.ToString())" -ForegroundColor Gray
    }
}

# Show performance report
Write-Host "`nPerformance Report:" -ForegroundColor Cyan
Show-SpeedTUIPerformanceReport

# Show system statistics
Write-Host "`nSystem Statistics:" -ForegroundColor Cyan
$eventStats = $events.GetStats()
Write-Host "Events fired: $($eventStats.EventsFired)" -ForegroundColor Gray
Write-Host "Handlers executed: $($eventStats.HandlersExecuted)" -ForegroundColor Gray
Write-Host "Registered events: $($eventStats.RegisteredEvents)" -ForegroundColor Gray

$themeStats = $themeManager.GetPerformanceStats()  
Write-Host "Registered themes: $($themeStats.RegisteredThemes)" -ForegroundColor Gray
Write-Host "Theme cache size: $($themeStats.CacheSize)" -ForegroundColor Gray

# Cleanup
Write-Host "`nCleaning up..." -ForegroundColor Yellow
Unsubscribe-Event "user.interaction" $interactionId
$events.Off("component.clicked", $buttonClickId)

Write-Host "`n=== Example Complete ===" -ForegroundColor Cyan
Write-Host "This example demonstrated:" -ForegroundColor Green
Write-Host "  ✓ Automatic performance optimizations" -ForegroundColor Gray
Write-Host "  ✓ Multiple themes (matrix, amber, electric)" -ForegroundColor Gray
Write-Host "  ✓ Simple component positioning and sizing" -ForegroundColor Gray
Write-Host "  ✓ Automatic component arrangement" -ForegroundColor Gray
Write-Host "  ✓ Event-driven architecture" -ForegroundColor Gray
Write-Host "  ✓ Performance monitoring and statistics" -ForegroundColor Gray
Write-Host "  ✓ Development helpers and debugging tools" -ForegroundColor Gray

Write-Host "`nTry these commands to explore more:" -ForegroundColor Yellow
Write-Host "  Show-SpeedTUIExample 'button'" -ForegroundColor Cyan
Write-Host "  Show-SpeedTUIExample 'theming'" -ForegroundColor Cyan  
Write-Host "  Show-SpeedTUIExample 'events'" -ForegroundColor Cyan
Write-Host "  Test-SpeedTUIInstallation" -ForegroundColor Cyan