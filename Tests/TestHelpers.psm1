# TestHelpers.psm1 - Common test helpers and mocks for PRAXIS tests

# Mock ServiceContainer
function New-MockServiceContainer {
    $mock = New-Object PSObject
    $services = @{}
    
    Add-Member -InputObject $mock -MemberType ScriptMethod -Name "GetService" -Value {
        param($serviceName)
        return $services[$serviceName]
    }
    
    Add-Member -InputObject $mock -MemberType ScriptMethod -Name "Register" -Value {
        param($serviceName, $service)
        $services[$serviceName] = $service
    }
    
    return $mock
}

# Mock Logger
function New-MockLogger {
    $mock = New-Object PSObject
    $logs = [System.Collections.ArrayList]::new()
    
    Add-Member -InputObject $mock -MemberType ScriptMethod -Name "Debug" -Value {
        param($message)
        $logs.Add(@{Level="DEBUG"; Message=$message; Time=[DateTime]::Now}) | Out-Null
    }
    
    Add-Member -InputObject $mock -MemberType ScriptMethod -Name "Info" -Value {
        param($message)
        $logs.Add(@{Level="INFO"; Message=$message; Time=[DateTime]::Now}) | Out-Null
    }
    
    Add-Member -InputObject $mock -MemberType ScriptMethod -Name "Warning" -Value {
        param($message)
        $logs.Add(@{Level="WARNING"; Message=$message; Time=[DateTime]::Now}) | Out-Null
    }
    
    Add-Member -InputObject $mock -MemberType ScriptMethod -Name "Error" -Value {
        param($message)
        $logs.Add(@{Level="ERROR"; Message=$message; Time=[DateTime]::Now}) | Out-Null
    }
    
    Add-Member -InputObject $mock -MemberType NoteProperty -Name "Logs" -Value $logs
    
    return $mock
}

# Mock ThemeManager
function New-MockThemeManager {
    $mock = New-Object PSObject
    
    Add-Member -InputObject $mock -MemberType ScriptMethod -Name "GetColor" -Value {
        param($colorPath)
        return "`e[38;2;255;255;255m"  # White
    }
    
    Add-Member -InputObject $mock -MemberType ScriptMethod -Name "GetBgColor" -Value {
        param($colorPath)
        return "`e[48;2;0;0;0m"  # Black background
    }
    
    Add-Member -InputObject $mock -MemberType ScriptMethod -Name "GetCurrentTheme" -Value {
        return @{
            Name = "MockTheme"
            Colors = @{}
        }
    }
    
    return $mock
}

# Mock EventBus
function New-MockEventBus {
    $mock = New-Object PSObject
    $handlers = @{}
    $publishedEvents = [System.Collections.ArrayList]::new()
    
    Add-Member -InputObject $mock -MemberType ScriptMethod -Name "Subscribe" -Value {
        param($eventName, $handler)
        if (-not $handlers[$eventName]) {
            $handlers[$eventName] = [System.Collections.ArrayList]::new()
        }
        $handlers[$eventName].Add($handler) | Out-Null
        return "handler_" + [Guid]::NewGuid().ToString()
    }
    
    Add-Member -InputObject $mock -MemberType ScriptMethod -Name "Publish" -Value {
        param($eventName, $eventData)
        $publishedEvents.Add(@{Event=$eventName; Data=$eventData; Time=[DateTime]::Now}) | Out-Null
        if ($handlers[$eventName]) {
            foreach ($handler in $handlers[$eventName]) {
                & $handler $null $eventData
            }
        }
    }
    
    Add-Member -InputObject $mock -MemberType ScriptMethod -Name "Unsubscribe" -Value {
        param($handlerId)
        # Simplified - doesn't actually remove
    }
    
    Add-Member -InputObject $mock -MemberType NoteProperty -Name "PublishedEvents" -Value $publishedEvents
    
    return $mock
}

# Mock FocusManager
function New-MockFocusManager {
    $mock = New-Object PSObject
    $focusedElement = $null
    
    Add-Member -InputObject $mock -MemberType ScriptMethod -Name "SetFocus" -Value {
        param($element)
        $focusedElement = $element
        if ($element) {
            $element.IsFocused = $true
        }
    }
    
    Add-Member -InputObject $mock -MemberType ScriptMethod -Name "GetFocused" -Value {
        return $focusedElement
    }
    
    Add-Member -InputObject $mock -MemberType ScriptMethod -Name "ClearFocus" -Value {
        if ($focusedElement) {
            $focusedElement.IsFocused = $false
        }
        $focusedElement = $null
    }
    
    return $mock
}

# Performance measurement helper
function Measure-Performance {
    param(
        [scriptblock]$ScriptBlock,
        [string]$Name = "Operation"
    )
    
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $result = & $ScriptBlock
    $stopwatch.Stop()
    
    return @{
        Name = $Name
        Result = $result
        ElapsedMilliseconds = $stopwatch.ElapsedMilliseconds
        ElapsedTicks = $stopwatch.ElapsedTicks
    }
}

# Console key helper
function New-ConsoleKeyInfo {
    param(
        [char]$KeyChar = [char]0,
        [System.ConsoleKey]$Key = [System.ConsoleKey]::NoName,
        [bool]$Shift = $false,
        [bool]$Alt = $false,
        [bool]$Control = $false
    )
    
    $modifiers = [System.ConsoleModifiers]::None
    if ($Shift) { $modifiers = $modifiers -bor [System.ConsoleModifiers]::Shift }
    if ($Alt) { $modifiers = $modifiers -bor [System.ConsoleModifiers]::Alt }
    if ($Control) { $modifiers = $modifiers -bor [System.ConsoleModifiers]::Control }
    
    return [System.ConsoleKeyInfo]::new($KeyChar, $Key, $Shift, $Alt, $Control)
}

# Load all PRAXIS classes for testing
function Initialize-PraxisForTesting {
    param(
        [string]$PraxisPath = (Split-Path -Parent $PSScriptRoot)
    )
    
    # Load in correct order
    $loadOrder = @(
        "Core/VT100.ps1"
        "Core/BorderStyle.ps1"
        "Core/StringCache.ps1"
        "Base/UIElement.ps1"
        "Base/Container.ps1"
        "Base/Screen.ps1"
        "Base/FocusableComponent.ps1"
        "Models/*.ps1"
        "Services/*.ps1"
        "Components/*.ps1"
        "Screens/*.ps1"
    )
    
    foreach ($pattern in $loadOrder) {
        $files = Get-ChildItem -Path "$PraxisPath/$pattern" -ErrorAction SilentlyContinue
        foreach ($file in $files) {
            . $file.FullName
        }
    }
}

Export-ModuleMember -Function @(
    'New-MockServiceContainer',
    'New-MockLogger',
    'New-MockThemeManager',
    'New-MockEventBus',
    'New-MockFocusManager',
    'Measure-Performance',
    'New-ConsoleKeyInfo',
    'Initialize-PraxisForTesting'
)