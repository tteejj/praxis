# SpeedTUI Debug Help Guide

## Quick Start

### Enable Debug Logging
```powershell
pwsh ./Start.ps1 -Debug
```

### Find Your Log File
Logs are in the `Logs/` directory with timestamp:
```
Logs/speedtui_20250731_080536.log
```

## Common Debugging Scenarios

### 1. Application Crashes with "null-valued expression"
```powershell
# Run with debug
pwsh ./Start.ps1 -Debug

# Reproduce the crash
# Open the latest log file
# Look for the last few entries before the [Error] line
```

### 2. Screen Not Loading
Look for these log entries:
- `[Info] [SpeedTUI][Startup] Application startup completed`
- `[Debug] [SpeedTUI][TimeTrackingScreen] Initializing forms`
- `[Error]` entries showing what failed

### 3. Input Not Working
Check for:
- `[Trace] [SpeedTUI][MainLoop] Key pressed`
- `[Trace] [SpeedTUI][InputField] HandleInput`
- `[Debug] [SpeedTUI][FormManager] HandleInput`

## Understanding Log Entries

### Log Format
```
2025-07-31 08:05:37.525 [Info] [SpeedTUI][Startup] SpeedTUI 1.0.0 starting up
└─────────┬────────────┘ └─┬─┘ └───┬───┘└───┬────┘ └──────────┬──────────────┘
      Timestamp         Level   Module  Component          Message
```

### Log Levels
- `[Trace]` - Every detail (keystrokes, method calls)
- `[Debug]` - Important state changes
- `[Info]` - Normal operations
- `[Warn]` - Potential issues
- `[Error]` - Failures with stack traces
- `[Fatal]` - Unrecoverable errors

## Configuring Debug Levels

### Default Debug Mode
When you use `-Debug`, these components log at Trace level:
- SpeedTUI (main app)
- TimeTrackingScreen
- FormManager
- InputField

### Custom Debug Configuration

Create a file `debug_config.ps1`:
```powershell
# Debug only specific components
$logger = Get-Logger

# Set everything to Info (minimal)
$logger.GlobalLevel = [LogLevel]::Info

# Set specific components to Trace
$logger.SetComponentLevel("SpeedTUI", "TimeTrackingScreen", [LogLevel]::Trace)
$logger.SetComponentLevel("SpeedTUI", "FormManager", [LogLevel]::Trace)

# Set specific module to Debug
$logger.SetModuleLevel("Services", [LogLevel]::Debug)
```

Then source it after starting:
```powershell
. ./debug_config.ps1
pwsh ./Start.ps1
```

## Analyzing Common Errors

### Null Reference Errors
Look for:
1. Last successful operation before error
2. Object initialization logs
3. Context data showing null values

Example pattern:
```
[Trace] ... AddFormExists = False    ← Form wasn't initialized
[Error] ... You cannot call a method on a null-valued expression
```

### Performance Issues
Look for:
1. `timing.*` performance metrics
2. Large `LineCount` in render operations
3. Repeated operations in tight loops

### Navigation Problems
Track the flow:
```
[Trace] Key pressed | Key = 1
[Debug] NavigateToScreen | screen = TimeTracking  
[Info] TimeTrackingService initialized
[Trace] Render start | ViewMode = List
```

## Advanced Debugging

### Enable Console Output (Temporary)
```powershell
$logger = Get-Logger
$logger.EnableConsole = $true  # See logs in real-time
```

### Log Specific Data
Add temporary logging in your code:
```powershell
$logger = Get-Logger
$logger.Debug("SpeedTUI", "MyComponent", "Checking state", @{
    Variable1 = $myVar1
    Variable2 = $myVar2
    Object = $myObject | ConvertTo-Json -Depth 2
})
```

### Filter Logs
Use PowerShell to analyze:
```powershell
# Find all errors
Get-Content Logs/speedtui_*.log | Select-String "\[Error\]"

# Find specific component
Get-Content Logs/speedtui_*.log | Select-String "FormManager"

# Get last 50 lines before error
$log = Get-Content Logs/speedtui_latest.log
$errorLine = $log | Select-String "\[Error\]" | Select -Last 1
$errorIndex = $log.IndexOf($errorLine.Line)
$log[($errorIndex-50)..$errorIndex]
```

## Performance Considerations

- Debug logging has ZERO impact when `-Debug` is not used
- Trace level is most verbose but only active in debug mode
- Logger checks log level before processing any log data

## Troubleshooting the Logger

### Logger Not Working?
1. Check if log file is created in `Logs/` directory
2. Verify Logger initialization in main script
3. Check file permissions on Logs directory

### Too Much/Little Logging?
Adjust levels dynamically:
```powershell
$logger = Get-Logger
$logger.SetComponentLevel("SpeedTUI", "InputField", [LogLevel]::Info)  # Less verbose
$logger.SetComponentLevel("SpeedTUI", "FormManager", [LogLevel]::Trace)  # More verbose
```

## Quick Reference Commands

```powershell
# Start with debug
pwsh ./Start.ps1 -Debug

# Find latest log
ls Logs/ | Sort-Object LastWriteTime -Descending | Select -First 1

# Tail log file (PowerShell)
Get-Content -Path "Logs/speedtui_20250731_080536.log" -Wait -Tail 50

# Search for errors
Select-String -Path "Logs/*.log" -Pattern "\[Error\]" | Select -Last 10

# Get unique error messages
Get-Content Logs/*.log | Select-String "\[Error\]" | % { $_.Line -replace '^.*\[Error\].*?] ', '' } | Sort-Object -Unique
```