# MinimalTaskScreen.ps1 - Minimal working screen to test rendering pipeline
# Bypasses inheritance issues by implementing just what we need

class MinimalTaskScreen {
    # Core services
    [ServiceContainer]$Services
    [RenderEngine]$RenderEngine
    [Logger]$Logger
    
    # Screen properties
    [int]$Width = 80
    [int]$Height = 25
    [string]$Title = "Tasks (Minimal)"
    
    # Constructor - no inheritance, direct initialization
    MinimalTaskScreen([ServiceContainer]$services) {
        "DEBUG: MinimalTaskScreen constructor start $(Get-Date)" | Out-File -FilePath "./startup-debug.log" -Append
        $this.Services = $services
        $this.RenderEngine = $services.GetService("RenderEngine")
        $this.Logger = $services.GetService("Logger")
        "DEBUG: MinimalTaskScreen constructor complete $(Get-Date)" | Out-File -FilePath "./startup-debug.log" -Append
    }
    
    # Initialize method
    [void] Initialize([int]$width, [int]$height) {
        "DEBUG: MinimalTaskScreen Initialize called $(Get-Date)" | Out-File -FilePath "./startup-debug.log" -Append
        $this.Width = $width
        $this.Height = $height
    }
    
    # Minimal render method - just show we can render
    [string] Render() {
        "DEBUG: MinimalTaskScreen Render called $(Get-Date)" | Out-File -FilePath "./startup-debug.log" -Append
        $sb = [System.Text.StringBuilder]::new()
        
        # Clear screen
        [void]$sb.Append("`e[2J`e[H")
        
        # Title
        [void]$sb.Append("=== $($this.Title) ===`n")
        [void]$sb.Append("SimpleTaskPro Phase 5 - Minimal Test`n")
        [void]$sb.Append("Screen successfully created and rendering!`n")
        [void]$sb.Append("Press 'n' to test new task key mapping`n")
        [void]$sb.Append("Press Ctrl+Q to exit`n")
        
        return $sb.ToString()
    }
    
    # Minimal input handler 
    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        "DEBUG: MinimalTaskScreen input: $($key.Key) $(Get-Date)" | Out-File -FilePath "./startup-debug.log" -Append
        
        switch ($key.Key) {
            "Escape" { return $false }  # Exit
            "Q" { 
                if ($key.Modifiers -band [System.ConsoleModifiers]::Control) {
                    return $false  # Exit on Ctrl+Q
                }
            }
            "N" {
                "DEBUG: 'N' key pressed - testing key mapping $(Get-Date)" | Out-File -FilePath "./startup-debug.log" -Append
                return $true
            }
        }
        
        return $true  # Continue running
    }
}