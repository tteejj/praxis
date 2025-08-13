# Core/Logger.ps1 - Centralized, file-based logging service.

enum LogLevel {
    Debug = 0
    Info = 1
    Warn = 2
    Error = 3
    Fatal = 4
}

class Logger {
    [string]$LogFile
    [LogLevel]$LogLevel = [LogLevel]::Info
    [bool]$IsInitialized = $false

    [void] Initialize([string]$logPath, [LogLevel]$level) {
        if ($this.IsInitialized) { return }
        $this.LogFile = Join-Path $logPath "SimpleTaskPro-$(Get-Date -Format 'yyyy-MM-dd').log"
        $this.LogLevel = $level
        
        try {
            $logDir = Split-Path -Parent $this.LogFile
            if (-not (Test-Path $logDir)) {
                New-Item -ItemType Directory -Path $logDir -Force | Out-Null
            }
            "--- Log Initialized at $(Get-Date) ---" | Out-File -FilePath $this.LogFile -Append -Encoding UTF8
            $this.IsInitialized = $true
        } catch {
            Write-Host "FATAL: Could not initialize logger at $($this.LogFile). Error: $_" -ForegroundColor Red
        }
    }

    [void] Log([LogLevel]$level, [string]$message) {
        if (-not $this.IsInitialized -or $level -lt $this.LogLevel) { return }

        $timestamp = Get-Date -Format "HH:mm:ss"
        $levelString = $level.ToString().ToUpper().PadRight(5)
        "$timestamp $levelString - $message" | Out-File -FilePath $this.LogFile -Append -Encoding UTF8
    }

    [void] Debug([string]$message) { $this.Log([LogLevel]::Debug, $message) }
    [void] Info([string]$message)  { $this.Log([LogLevel]::Info, $message) }
    [void] Warn([string]$message)  { $this.Log([LogLevel]::Warn, $message) }
    [void] Error([string]$message, [object]$exception = $null) {
        $fullMessage = $message
        if ($exception) {
            $fullMessage += "`n$($exception.ToString())"
            # Handle both Exception and ErrorRecord types
            if ($exception.PSObject.Properties['ScriptStackTrace']) {
                $fullMessage += "`nStack Trace:`n$($exception.ScriptStackTrace)"
            }
        }
        $this.Log([LogLevel]::Error, $fullMessage)
    }
}