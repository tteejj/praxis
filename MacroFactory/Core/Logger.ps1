# Logger.ps1 - Simple logging for MacroFactory

class Logger {
    [string]$LogFile
    [bool]$EnableDebug = $false
    
    Logger() {
        $this.LogFile = Join-Path $PSScriptRoot ".." "Data" "macrofactory.log"
        $logDir = Split-Path $this.LogFile -Parent
        if (-not (Test-Path $logDir)) {
            New-Item -ItemType Directory -Path $logDir -Force | Out-Null
        }
    }
    
    [void] Info([string]$message) {
        $this.WriteLog("INFO", $message)
    }
    
    [void] Debug([string]$message) {
        if ($this.EnableDebug) {
            $this.WriteLog("DEBUG", $message)
        }
    }
    
    [void] Warning([string]$message) {
        $this.WriteLog("WARN", $message)
    }
    
    [void] Error([string]$message) {
        $this.WriteLog("ERROR", $message)
    }
    
    [void] Success([string]$message) {
        $this.WriteLog("SUCCESS", $message)
    }
    
    hidden [void] WriteLog([string]$level, [string]$message) {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $logEntry = "[$timestamp] [$level] $message"
        Add-Content -Path $this.LogFile -Value $logEntry -ErrorAction SilentlyContinue
    }
    
    [void] Clear() {
        if (Test-Path $this.LogFile) {
            Clear-Content -Path $this.LogFile -ErrorAction SilentlyContinue
        }
    }
}

# Global logger instance
$global:Logger = [Logger]::new()