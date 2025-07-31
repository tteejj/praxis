# SpeedTUI Logging Configuration Guide

## Debug Mode

Run with `-Debug` flag to enable detailed logging:
```powershell
pwsh ./Start.ps1 -Debug
```

## Zero Performance Impact

When NOT in debug mode:
- Logger GlobalLevel defaults to Debug
- Individual components only log at Debug level or above
- Trace logs are completely skipped (no performance impact)
- No console output

## Modular Logging Levels

You can configure logging per module/component for hybrid logging:

```powershell
# In SpeedTUI.ps1 or your configuration
$logger = Get-Logger

# Set global level (affects all modules)
$logger.GlobalLevel = [LogLevel]::Info  # Only Info and above

# Set specific module to trace level
$logger.SetModuleLevel("SpeedTUI", [LogLevel]::Trace)

# Set specific component to trace level
$logger.SetComponentLevel("SpeedTUI", "TimeTrackingScreen", [LogLevel]::Trace)
$logger.SetComponentLevel("SpeedTUI", "FormManager", [LogLevel]::Debug)
$logger.SetComponentLevel("SpeedTUI", "InputField", [LogLevel]::Trace)

# Other modules stay at Info level
$logger.SetModuleLevel("Services", [LogLevel]::Info)
```

## Log Levels

- **Trace**: Most detailed - every keystroke, method entry/exit
- **Debug**: Detailed debugging info - state changes, important values
- **Info**: General information - service initialization, major operations
- **Warn**: Warning conditions
- **Error**: Error conditions with full exception details
- **Fatal**: Fatal errors that stop execution

## Reading Logs

Logs are stored in `/Logs/speedtui_YYYYMMDD_HHMMSS.log`

When debugging the null reference error:
1. Enable debug mode
2. Reproduce the error
3. Check the log file for detailed trace information
4. Look for the last entries before the error

## Example Custom Configuration

For debugging only TimeTracking issues:
```powershell
# Global stays at Info (minimal logging)
$logger.GlobalLevel = [LogLevel]::Info

# TimeTracking components at Trace level
$logger.SetComponentLevel("SpeedTUI", "TimeTrackingScreen", [LogLevel]::Trace)
$logger.SetComponentLevel("SpeedTUI", "TimeTrackingService", [LogLevel]::Trace)
$logger.SetComponentLevel("SpeedTUI", "FormManager", [LogLevel]::Trace)
$logger.SetComponentLevel("SpeedTUI", "InputField", [LogLevel]::Trace)

# Main loop at Debug
$logger.SetComponentLevel("SpeedTUI", "MainLoop", [LogLevel]::Debug)
```

This gives you detailed logs for TimeTracking while keeping other modules quiet.