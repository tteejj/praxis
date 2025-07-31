# Enhanced SpeedTUI Demo - Showcasing the enhanced system with themes and performance
# This demo shows how the enhanced system provides simple APIs with powerful features

# Import the enhanced SpeedTUI system
using module ..\Core\EnhancedComponent_NEW.ps1
using module ..\Components\Button_ENHANCED.ps1
using module ..\Core\Terminal_ENHANCED.ps1
using module ..\Services\ThemeManager_ENHANCED.ps1

<#
.SYNOPSIS
Interactive demo showcasing enhanced SpeedTUI features

.DESCRIPTION
Demonstrates the enhanced SpeedTUI system with:
- Simple, clear APIs (SetPosition, SetSize, SetTheme, SetColor)
- Multiple built-in themes (matrix, amber, electric, default)
- Performance optimizations (automatic caching, batched rendering)
- Event system integration
- Real-time theme switching

.EXAMPLE
.\EnhancedSpeedTUIDemo.ps1
#>

# Clear screen and setup
Clear-Host
Write-Host "Enhanced SpeedTUI Demo - Loading..." -ForegroundColor Cyan
Start-Sleep -Seconds 1

# Get enhanced instances
$terminal = Get-EnhancedTerminal
$themeManager = Get-ThemeManager

# Initialize terminal
$terminal.Initialize()
$terminal.Clear()

# === Demo Header ===
$terminal.WriteAtThemed(2, 1, "╔══════════════════════════════════════════════════╗", "primary")
$terminal.WriteAtThemed(2, 2, "║         Enhanced SpeedTUI Demo System           ║", "primary") 
$terminal.WriteAtThemed(2, 3, "║     Simple APIs • Powerful Features • Fast      ║", "secondary")
$terminal.WriteAtThemed(2, 4, "╚══════════════════════════════════════════════════╝", "primary")

# === Theme Selector Buttons ===
$terminal.WriteAtThemed(2, 6, "Themes:", "text")

# Create theme buttons using enhanced Button component
$matrixBtn = [Button]::new("Matrix")
$matrixBtn.SetPosition(10, 6)
$matrixBtn.SetSize(12, 3)
$matrixBtn.SetTheme("matrix")
$matrixBtn.SetColor("primary")
$matrixBtn.OnClick = {
    $global:demoTheme = "matrix"
    Update-DemoTheme
}

$amberBtn = [Button]::new("Amber")
$amberBtn.SetPosition(24, 6)
$amberBtn.SetSize(12, 3)
$amberBtn.SetTheme("amber")
$amberBtn.SetColor("primary")
$amberBtn.OnClick = {
    $global:demoTheme = "amber"
    Update-DemoTheme
}

$electricBtn = [Button]::new("Electric")
$electricBtn.SetPosition(38, 6)
$electricBtn.SetSize(12, 3)
$electricBtn.SetTheme("electric")
$electricBtn.SetColor("primary")
$electricBtn.OnClick = {
    $global:demoTheme = "electric"
    Update-DemoTheme
}

$defaultBtn = [Button]::new("Default")
$defaultBtn.SetPosition(52, 6)
$defaultBtn.SetSize(12, 3)
$defaultBtn.SetTheme("default")
$defaultBtn.SetColor("primary")
$defaultBtn.OnClick = {
    $global:demoTheme = "default"
    Update-DemoTheme
}

# === Feature Demo Buttons ===
$terminal.WriteAtThemed(2, 11, "Enhanced Features:", "text")

# Performance demo button
$perfBtn = [Button]::new("Performance Stats")
$perfBtn.SetPosition(10, 13)
$perfBtn.SetSize(18, 3)
$perfBtn.SetColor("info")
$perfBtn.OnClick = { Show-PerformanceStats }

# Color demo button  
$colorBtn = [Button]::new("Custom Colors")
$colorBtn.SetPosition(30, 13)
$colorBtn.SetSize(16, 3)
$colorBtn.SetColor("warning")
$colorBtn.OnClick = { Show-ColorDemo }

# Exit button
$exitBtn = [Button]::new("Exit Demo")
$exitBtn.SetPosition(48, 13)
$exitBtn.SetSize(12, 3)
$exitBtn.SetColor("error")
$exitBtn.SetAsCancel($true)
$exitBtn.OnClick = { $global:demoRunning = $false }

# === Demo Functions ===

function Update-DemoTheme {
    $terminal.SetTheme($global:demoTheme)
    
    # Apply theme to all buttons
    $matrixBtn.SetTheme($global:demoTheme)
    $amberBtn.SetTheme($global:demoTheme)
    $electricBtn.SetTheme($global:demoTheme)
    $defaultBtn.SetTheme($global:demoTheme)
    $perfBtn.SetTheme($global:demoTheme)
    $colorBtn.SetTheme($global:demoTheme)
    $exitBtn.SetTheme($global:demoTheme)
    
    # Update display
    $terminal.WriteAtThemed(2, 18, "Current Theme: $($global:demoTheme.ToUpper())", "success")
    
    # Show theme colors
    Show-ThemeColors
    
    Render-Demo
}

function Show-ThemeColors {
    $terminal.WriteAtThemed(2, 20, "Theme Colors:", "text")
    
    $y = 21
    $colors = @("primary", "secondary", "success", "warning", "error", "info")
    
    foreach ($color in $colors) {
        $terminal.WriteAtThemed(4, $y, "███", $color)
        $terminal.WriteAtThemed(8, $y, $color, "text")
        $y++
    }
}

function Show-PerformanceStats {
    $terminal.ClearRegion(2, 18, 70, 10)
    
    # Get performance stats from various components
    $terminalStats = $terminal.GetPerformanceStats()
    $themeStats = $themeManager.GetPerformanceStats()
    
    $terminal.WriteAtThemed(2, 18, "Performance Statistics:", "success")
    $terminal.WriteAtThemed(4, 20, "Terminal FPS: $($terminalStats.FPS)", "info")
    $terminal.WriteAtThemed(4, 21, "Cache Hit Rate: $($terminalStats.CacheHitRate)%", "info")
    $terminal.WriteAtThemed(4, 22, "Write Operations: $($terminalStats.WriteOperations)", "info")
    $terminal.WriteAtThemed(4, 23, "Theme Lookups: $($themeStats.ColorLookups)", "info")
    $terminal.WriteAtThemed(4, 24, "Theme Cache Hit Rate: $($themeStats.CacheHitRate)%", "info")
    
    $terminal.WriteAtThemed(4, 26, "Press any key to continue...", "textDim")
    [Console]::ReadKey($true) | Out-Null
    
    Show-ThemeColors
}

function Show-ColorDemo {
    $terminal.ClearRegion(2, 18, 70, 10)
    
    $terminal.WriteAtThemed(2, 18, "Custom RGB Color Demo:", "success")
    
    # Show RGB color examples
    $y = 20
    for ($i = 0; $i -lt 5; $i++) {
        $r = 255 - ($i * 40)
        $g = 100 + ($i * 30)
        $b = $i * 50
        
        $terminal.WriteAtRGB(4, $y, "██████ RGB($r, $g, $b)", $r, $g, $b)
        $y++
    }
    
    $terminal.WriteAtThemed(4, 26, "Press any key to continue...", "textDim")
    [Console]::ReadKey($true) | Out-Null
    
    Show-ThemeColors
}

function Render-Demo {
    $terminal.BeginFrame()
    
    # Render all buttons (they handle their own theming)
    $matrixBtn.OnRender()
    $amberBtn.OnRender()
    $electricBtn.OnRender()  
    $defaultBtn.OnRender()
    $perfBtn.OnRender()
    $colorBtn.OnRender()
    $exitBtn.OnRender()
    
    $terminal.EndFrame()
}

function Handle-Input {
    if ([Console]::KeyAvailable) {
        $key = [Console]::ReadKey($true)
        
        # Handle button clicks and navigation
        switch ($key.Key) {
            "D1" { $matrixBtn.Click() }
            "D2" { $amberBtn.Click() }
            "D3" { $electricBtn.Click() }
            "D4" { $defaultBtn.Click() }
            "P" { $perfBtn.Click() }
            "C" { $colorBtn.Click() }
            "Escape" { $exitBtn.Click() }
            "Q" { $global:demoRunning = $false }
        }
        
        return $true
    }
    return $false
}

# === Main Demo Loop ===

# Initialize demo state
$global:demoTheme = "default"
$global:demoRunning = $true

# Show initial theme
Update-DemoTheme

# Display instructions
$terminal.WriteAtThemed(2, 28, "Instructions:", "text")
$terminal.WriteAtThemed(4, 29, "• Click theme buttons (1-4) to switch themes", "textDim")
$terminal.WriteAtThemed(4, 30, "• Press 'P' for performance stats", "textDim")
$terminal.WriteAtThemed(4, 31, "• Press 'C' for custom color demo", "textDim")
$terminal.WriteAtThemed(4, 32, "• Press 'Q' or Escape to exit", "textDim")

# Demo statistics tracking
$frameCount = 0
$startTime = Get-Date

# Main demo loop with performance monitoring
while ($global:demoRunning) {
    $frameStart = Get-Date
    
    # Handle input
    Handle-Input
    
    # Render frame
    Render-Demo
    
    # Update frame counter
    $frameCount++
    
    # Show live FPS every 60 frames
    if ($frameCount % 60 -eq 0) {
        $elapsed = (Get-Date) - $startTime
        $fps = [Math]::Round($frameCount / $elapsed.TotalSeconds, 1)
        $terminal.WriteAtThemed(55, 1, "FPS: $fps    ", "info")
    }
    
    # Maintain ~60 FPS
    $frameTime = ((Get-Date) - $frameStart).TotalMilliseconds
    if ($frameTime -lt 16.67) {
        Start-Sleep -Milliseconds ([int](16.67 - $frameTime))
    }
}

# === Cleanup ===

$terminal.Clear()
$terminal.WriteAtThemed(2, 10, "Enhanced SpeedTUI Demo Complete!", "success")
$terminal.WriteAtThemed(2, 12, "Final Statistics:", "text")

$finalStats = $terminal.GetPerformanceStats()
$themeStats = $themeManager.GetPerformanceStats()

$terminal.WriteAtThemed(4, 14, "Total Frames Rendered: $frameCount", "info")
$terminal.WriteAtThemed(4, 15, "Average FPS: $($finalStats.FPS)", "info")
$terminal.WriteAtThemed(4, 16, "Cache Efficiency: $($finalStats.CacheHitRate)%", "info")
$terminal.WriteAtThemed(4, 17, "Theme Changes: $($themeStats.ColorLookups)", "info")

$terminal.WriteAtThemed(2, 19, "Thank you for trying Enhanced SpeedTUI!", "success")
$terminal.WriteAtThemed(2, 20, "Press any key to exit...", "textDim")

[Console]::ReadKey($true) | Out-Null
$terminal.Cleanup()