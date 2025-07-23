# TestScreen.ps1 - Simple test screen to verify PRAXIS is working

class TestScreen : Screen {
    [string]$Message = "PRAXIS Test Screen"
    [int]$Counter = 0
    hidden [string]$_cachedContent = ""
    
    TestScreen() : base() {
        $this.Title = "Test"
    }
    
    [void] OnInitialize() {
        if ($global:Logger) {
            $global:Logger.Debug("TestScreen.OnInitialize: $($this.Title)")
        }
        
        # No more BindKey - use HandleScreenInput instead
        
        # Don't rebuild content here - wait until we have bounds
    }
    
    # Handle screen-specific input
    [bool] HandleScreenInput([System.ConsoleKeyInfo]$key) {
        if ($key.Key -eq [System.ConsoleKey]::Spacebar) {
            $this.Counter++
            $this._cachedContent = ""  # Force re-render
            $this.RequestRender() 
            return $true
        }
        elseif ($key.KeyChar -eq 'q') {
            $this.Active = $false
            return $true
        }
        
        return $false
    }
    
    [void] OnThemeChanged() {
        ([Screen]$this).OnThemeChanged()
        $this._cachedContent = ""
        $this.RebuildContent()
    }
    
    [void] RebuildContent() {
        $sb = [System.Text.StringBuilder]::new()
        
        # Calculate absolute positions
        $absoluteCenterY = $this.Y + [int]($this.Height / 2)
        $absoluteCenterX = $this.X + [int](($this.Width - $this.Message.Length) / 2)
        
        # Title
        $sb.Append([VT]::MoveTo($absoluteCenterX, $absoluteCenterY - 2))
        $sb.Append($this.Theme.GetColor("accent"))
        $sb.Append($this.Message)
        
        # Counter
        $counterText = "Counter: $($this.Counter)"
        $counterX = $this.X + [int](($this.Width - $counterText.Length) / 2)
        $sb.Append([VT]::MoveTo($counterX, $absoluteCenterY))
        $sb.Append($this.Theme.GetColor("foreground"))
        $sb.Append($counterText)
        
        # Instructions
        $instructionText = "Press SPACE to increment, Q to quit"
        $instructionX = $this.X + [int](($this.Width - $instructionText.Length) / 2)
        $sb.Append([VT]::MoveTo($instructionX, $absoluteCenterY + 2))
        $sb.Append($this.Theme.GetColor("disabled"))
        $sb.Append($instructionText)
        
        # FPS counter (bottom right)
        if ($global:ScreenManager) {
            $fps = [Math]::Round($global:ScreenManager.GetFPS(), 1)
            $fpsText = "FPS: $fps"
            $sb.Append([VT]::MoveTo($this.X + $this.Width - $fpsText.Length - 2, $this.Y + $this.Height - 2))
            $sb.Append($this.Theme.GetColor("success"))
            $sb.Append($fpsText)
        }
        
        $sb.Append([VT]::Reset())
        
        $this._cachedContent = $sb.ToString()
    }
    
    [string] OnRender() {
        if ($global:Logger) {
            $global:Logger.Debug("TestScreen.OnRender: Bounds X=$($this.X) Y=$($this.Y) W=$($this.Width) H=$($this.Height)")
        }
        
        # Check if we need to rebuild
        if ([string]::IsNullOrEmpty($this._cachedContent)) {
            $this.RebuildContent()
        }
        
        # Return base background + our content
        return ([Container]$this).OnRender() + $this._cachedContent
    }
}