# CommandLibraryScreen.ps1 - Complete command library screen
# Using TaskPro's proven architecture with CommandListScreen

class CommandLibraryScreen {
    # Properties
    [int]$Width = 80
    [int]$Height = 25
    [string]$Title = "Command Library"
    
    # Core component - uses TaskPro's proven architecture
    [CommandListScreen]$CommandListScreen
    [CommandService]$CommandService
    
    # State
    [bool]$Running = $true
    [bool]$_hasRendered = $false
    
    CommandLibraryScreen([CommandService]$commandService) {
        $this.CommandService = $commandService
        $this.InitializeComponents()
    }
    
    [void] InitializeComponents() {
        # Get console size
        $this.Width = [Console]::WindowWidth
        $this.Height = [Console]::WindowHeight
        
        # Create the command list screen using TaskPro's proven architecture
        $this.CommandListScreen = [CommandListScreen]::new($this.CommandService)
        $this.CommandListScreen.Initialize($this.Width, $this.Height)
    }
    
    [string] Render() {
        # Delegate entirely to CommandListScreen - it handles everything
        return $this.CommandListScreen.Render()
    }
    
    [void] Run() {
        $originalCursor = $true
        try {
            $originalCursor = [Console]::CursorVisible
            [Console]::CursorVisible = $false
        } catch {
            # Console operations not supported in this environment
        }
        
        try {
            # Store previous render for comparison
            $lastRender = ""
            
            while ($this.Running) {
                # Build the full screen render
                $currentRender = $this.Render()
                
                # Only output if something changed
                if ($currentRender -ne $lastRender) {
                    [Console]::SetCursorPosition(0, 0)
                    Write-Host -NoNewline $currentRender
                    $lastRender = $currentRender
                }
                
                # Handle input (defensive)
                try {
                    if ([Console]::KeyAvailable) {
                        $key = [Console]::ReadKey($true)
                        if (-not $this.HandleInput($key)) {
                            $this.Running = $false
                        }
                    }
                } catch {
                    # Console input not available - exit gracefully
                    $this.Running = $false
                }
                
                Start-Sleep -Milliseconds 50
            }
        } finally {
            try {
                [Console]::CursorVisible = $originalCursor
            } catch {
                # Console operations not supported
            }
        }
    }
    
    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        # Delegate entirely to CommandListScreen - it handles ALL input including shortcuts
        return $this.CommandListScreen.HandleInput($key)
    }
    
    # CommandLibraryScreen is now just a thin wrapper around CommandListScreen
    # All functionality is delegated to the proven TaskPro architecture
}