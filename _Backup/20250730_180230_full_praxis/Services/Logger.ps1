# Logger.ps1 - Fast logging service adapted from AxiomPhoenix
# Optimized for speed - no console output, minimal file I/O

class Logger {
    [string]$LogPath
    [System.Collections.Queue]$LogQueue
    [int]$MaxQueueSize = 100  # Smaller queue for faster flushing
    [bool]$EnableFileLogging = $true
    [bool]$EnableConsoleLogging = $false  # Never log to console in TUI
    [string]$MinimumLevel = "Info"
    [hashtable]$LevelPriority = @{
        'Trace' = 0
        'Debug' = 1
        'Info' = 2
        'Warning' = 3
        'Error' = 4
        'Fatal' = 5
    }
    hidden [System.Text.StringBuilder]$_buffer
    hidden [int]$_unflushedCount = 0
    hidden [int]$_flushThreshold = 10  # Flush every N messages
    
    Logger() {
        # Use PRAXIS data directory
        $praxisDir = if ($global:PraxisRoot) { $global:PraxisRoot } else { (Get-Location).Path }
        $logDir = Join-Path $praxisDir "_Logs"
        if (-not (Test-Path $logDir)) {
            New-Item -ItemType Directory -Path $logDir -Force | Out-Null
        }
        $this.LogPath = Join-Path $logDir "praxis.log"
        $this._Initialize()
    }
    
    hidden [void] _Initialize() {
        $this.LogQueue = [System.Collections.Queue]::new()
        $this._buffer = [System.Text.StringBuilder]::new(4096)  # Pre-allocate buffer
        
        # Check for debug mode
        if ($global:PraxisDebug -or $env:PRAXIS_DEBUG) {
            $this.MinimumLevel = "Debug"
        }
        
        # Rotate log if too large (>10MB)
        try {
            if ((Test-Path $this.LogPath) -and (Get-Item $this.LogPath).Length -gt 10MB) {
                $backupPath = $this.LogPath + ".old"
                Move-Item $this.LogPath $backupPath -Force -ErrorAction SilentlyContinue
            }
        } catch {
            # Ignore rotation errors
        }
    }
    
    [void] Log([string]$message, [string]$level = "Info") {
        # Fast level check
        if ($this.LevelPriority[$level] -lt $this.LevelPriority[$this.MinimumLevel]) {
            return
        }
        
        # Format timestamp efficiently
        $timestamp = [DateTime]::Now.ToString('yyyy-MM-dd HH:mm:ss.fff')
        $levelPadded = $level.ToUpper().PadRight(7)
        
        # Build log line
        $logLine = "$timestamp [$levelPadded] $message"
        
        # Add to buffer instead of queue for speed
        $this._buffer.AppendLine($logLine)
        $this._unflushedCount++
        
        # Auto-flush on threshold or error/fatal
        if ($this._unflushedCount -ge $this._flushThreshold -or 
            $level -eq "Error" -or $level -eq "Fatal") {
            $this.Flush()
        }
    }
    
    [void] LogException([Exception]$exception, [string]$context = "") {
        $message = if ($context) { "$context - " } else { "" }
        $message += "$($exception.GetType().Name): $($exception.Message)"
        $this.Log($message, "Error")
        
        # Log stack trace as debug
        if ($exception.StackTrace) {
            $this.Log("Stack: $($exception.StackTrace -replace "`n", " ")", "Debug")
        }
    }
    
    [void] Flush() {
        if ($this._buffer.Length -eq 0 -or -not $this.EnableFileLogging) {
            return
        }
        
        try {
            # Write buffer to file in one operation
            [System.IO.File]::AppendAllText($this.LogPath, $this._buffer.ToString())
            $this._buffer.Clear()
            $this._unflushedCount = 0
        }
        catch {
            # Ignore logging errors to prevent crashes
        }
    }
    
    # Quick logging methods
    [void] Debug([string]$message) { $this.Log($message, "Debug") }
    [void] Info([string]$message) { $this.Log($message, "Info") }
    [void] Warning([string]$message) { $this.Log($message, "Warning") }
    [void] Error([string]$message) { $this.Log($message, "Error") }
    
    [void] Cleanup() {
        $this.Flush()
    }
}

# Global Write-Log function for compatibility
function global:Write-Log {
    param(
        [string]$Message,
        [string]$Level = "Info"
    )
    
    if ($global:Logger) {
        $global:Logger.Log($Message, $Level)
    }
}