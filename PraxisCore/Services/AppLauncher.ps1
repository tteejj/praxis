# AppLauncher.ps1 - Service to manage app launching with return to launcher

class AppLauncher {
    static [string]$LauncherPath = "$PSScriptRoot/../../PraxisLauncher.ps1"
    static [bool]$ReturnToLauncher = $true
    
    # Launch an app with wrapper script
    static [void] LaunchApp([string]$appPath, [hashtable]$params = @{}) {
        # Create a wrapper that returns to launcher
        $wrapperContent = @"
#!/usr/bin/env pwsh
# Auto-generated wrapper

# Store original location
`$originalLocation = Get-Location

try {
    # Change to app directory
    Set-Location (Split-Path '$appPath' -Parent)
    
    # Run the app
    & '$appPath' @params
    
} finally {
    # Return to original location
    Set-Location `$originalLocation
    
    # Check if we should return to launcher
    if ('$([AppLauncher]::ReturnToLauncher)' -eq 'True') {
        & '$([AppLauncher]::LauncherPath)'
    }
}
"@
        
        # Create temp wrapper
        $wrapperPath = Join-Path $env:TEMP "praxis-wrapper-$(New-Guid).ps1"
        $wrapperContent | Set-Content $wrapperPath
        
        # Execute wrapper
        & $wrapperPath
        
        # Clean up
        Remove-Item $wrapperPath -Force -ErrorAction SilentlyContinue
    }
    
    # Check if running from launcher
    static [bool] IsFromLauncher() {
        # Check if PRAXIS_LAUNCHER environment variable is set
        return $env:PRAXIS_LAUNCHER -eq "1"
    }
    
    # Exit app and return to launcher if appropriate
    static [void] ExitApp() {
        if ([AppLauncher]::IsFromLauncher()) {
            # Don't exit PowerShell, just return control
            return
        } else {
            # Normal exit
            exit
        }
    }
}