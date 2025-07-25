# EventBus Service for PRAXIS
# Based on AxiomPhoenix EventManager with adaptations for PRAXIS architecture
# Provides pub/sub event system for decoupled communication between components

class EventBus {
    [hashtable]$EventHandlers = @{}
    [int]$NextHandlerId = 1
    [System.Collections.Generic.List[hashtable]]$EventHistory
    [int]$MaxHistorySize = 100
    [bool]$EnableHistory = $false  # Disabled by default for performance
    [ServiceContainer]$ServiceContainer
    [bool]$EnableDebugLogging = $false  # Enable detailed event logging
    hidden [int]$TotalEventsPublished = 0
    hidden [int]$TotalHandlersCalled = 0
    
    EventBus() {
        $this.EventHistory = [System.Collections.Generic.List[hashtable]]::new()
    }
    
    [void] Initialize([ServiceContainer]$container) {
        $this.ServiceContainer = $container
        $logger = $container.GetService('Logger')
        if ($logger) {
            $logger.Log("EventBus initialized", "Info")
        }
    }
    
    # Subscribe to an event with a handler
    # Returns a subscription ID that can be used to unsubscribe
    [string] Subscribe([string]$eventName, [scriptblock]$handler) {
        if ([string]::IsNullOrWhiteSpace($eventName)) {
            if ($global:Logger) {
                $global:Logger.Error("EventBus.Subscribe: Event name is null or empty")
                $global:Logger.Error("Stack trace: " + [System.Environment]::StackTrace)
            }
            throw [ArgumentException]::new("Event name cannot be null or empty")
        }
        if (-not $handler) {
            throw [ArgumentNullException]::new("Handler cannot be null")
        }
        
        if (-not $this.EventHandlers.ContainsKey($eventName)) {
            $this.EventHandlers[$eventName] = @{}
        }
        
        $handlerId = "handler_$($this.NextHandlerId)"
        $this.NextHandlerId++
        
        $this.EventHandlers[$eventName][$handlerId] = @{
            Handler = $handler
            SubscribedAt = [DateTime]::Now
            ExecutionCount = 0
        }
        
        $logger = $this.ServiceContainer.GetService('Logger')
        if ($logger) {
            $logger.Log("EventBus: Subscribed handler '$handlerId' to event '$eventName'", "Debug")
        }
        
        return $handlerId
    }
    
    # Subscribe with a weak reference to an object
    # Automatically unsubscribes if the object is garbage collected
    [string] SubscribeWeak([string]$eventName, [object]$target, [scriptblock]$handler) {
        $weakRef = [System.WeakReference]::new($target)
        $wrappedHandler = {
            param($sender, $eventData)
            $strongRef = $weakRef.Target
            if ($strongRef) {
                & $handler $sender $eventData
            } else {
                # Target has been garbage collected, unsubscribe
                $eventBus = $sender
                $eventBus.Unsubscribe($eventName, $args[0])
            }
        }.GetNewClosure()
        
        return $this.Subscribe($eventName, $wrappedHandler)
    }
    
    # Unsubscribe a specific handler
    [void] Unsubscribe([string]$eventName, [string]$handlerId) {
        if ($this.EventHandlers.ContainsKey($eventName)) {
            if ($this.EventHandlers[$eventName].ContainsKey($handlerId)) {
                $this.EventHandlers[$eventName].Remove($handlerId)
                
                # Clean up empty event entries
                if ($this.EventHandlers[$eventName].Count -eq 0) {
                    $this.EventHandlers.Remove($eventName)
                }
                
                $logger = $this.ServiceContainer.GetService('Logger')
                if ($logger) {
                    $logger.Log("EventBus: Unsubscribed handler '$handlerId' from event '$eventName'", "Debug")
                }
            }
        }
    }
    
    # Unsubscribe all handlers for an event
    [void] UnsubscribeAll([string]$eventName) {
        if ($this.EventHandlers.ContainsKey($eventName)) {
            $handlerCount = $this.EventHandlers[$eventName].Count
            $this.EventHandlers.Remove($eventName)
            
            $logger = $this.ServiceContainer.GetService('Logger')
            if ($logger) {
                $logger.Log("EventBus: Unsubscribed all $handlerCount handlers from event '$eventName'", "Debug")
            }
        }
    }
    
    # Publish an event with optional data
    [void] Publish([string]$eventName, [hashtable]$eventData = @{}) {
        # Add timestamp to event data
        $eventData['Timestamp'] = [DateTime]::Now
        $eventData['EventName'] = $eventName
        
        $this.TotalEventsPublished++
        
        # Debug logging
        if ($this.EnableDebugLogging) {
            $logger = $this.ServiceContainer.GetService('Logger')
            if ($logger) {
                $logger.Log("EventBus: Publishing event '$eventName' with data: $($eventData | ConvertTo-Json -Compress)", "Debug")
            }
        }
        
        # Add to history if enabled
        if ($this.EnableHistory) {
            $this.AddToHistory($eventName, $eventData)
        }
        
        # Execute handlers
        if ($this.EventHandlers.ContainsKey($eventName)) {
            $handlers = @($this.EventHandlers[$eventName].GetEnumerator())
            
            if ($this.EnableDebugLogging) {
                $debugLogger = $this.ServiceContainer.GetService('Logger')
                if ($debugLogger) {
                    $debugLogger.Log("EventBus: Found $($handlers.Count) handlers for event '$eventName'", "Debug")
                }
            }
            
            foreach ($entry in $handlers) {
                try {
                    $handlerData = $entry.Value
                    $handlerData.ExecutionCount++
                    $this.TotalHandlersCalled++
                    
                    if ($this.EnableDebugLogging) {
                        $debugLogger = $this.ServiceContainer.GetService('Logger')
                        if ($debugLogger) {
                            $debugLogger.Log("EventBus: Calling handler '$($entry.Key)' for event '$eventName'", "Debug")
                        }
                    }
                    
                    # Call handler with EventBus as sender and eventData
                    & $handlerData.Handler $this $eventData
                }
                catch {
                    $logger = $this.ServiceContainer.GetService('Logger')
                    if ($logger) {
                        $logger.Log("EventBus: Error in handler '$($entry.Key)' for event '$eventName': $($_.Exception.Message)", "Error")
                    }
                }
            }
        }
        elseif ($this.EnableDebugLogging) {
            $logger = $this.ServiceContainer.GetService('Logger')
            if ($logger) {
                $logger.Log("EventBus: No handlers registered for event '$eventName'", "Debug")
            }
        }
    }
    
    # Publish an event asynchronously (returns immediately)
    [void] PublishAsync([string]$eventName, [hashtable]$eventData = @{}) {
        $job = Start-Job -ScriptBlock {
            param($eventBus, $eventName, $eventData)
            $eventBus.Publish($eventName, $eventData)
        } -ArgumentList $this, $eventName, $eventData
        
        # Clean up job after completion
        Register-ObjectEvent -InputObject $job -EventName StateChanged -Action {
            if ($Event.SourceEventArgs.JobStateInfo.State -eq 'Completed') {
                Remove-Job -Job $Event.SourceEventArgs
                Unregister-Event -SourceIdentifier $Event.SourceIdentifier
            }
        } | Out-Null
    }
    
    # Add event to history
    hidden [void] AddToHistory([string]$eventName, [hashtable]$eventData) {
        # Sanitize event data to prevent circular references
        $sanitizedData = @{}
        foreach ($key in $eventData.Keys) {
            $value = $eventData[$key]
            if ($value -is [string] -or $value -is [int] -or $value -is [double] -or 
                $value -is [bool] -or $value -is [datetime] -or $value -eq $null) {
                $sanitizedData[$key] = $value
            }
            elseif ($value.GetType().Name -eq 'UIElement' -or $value.GetType().BaseType.Name -eq 'UIElement') {
                # Handle UIElement without requiring the type to be loaded
                $name = if ($value.PSObject.Properties['Name']) { $value.Name } else { 'Unknown' }
                $sanitizedData[$key] = "[UIElement: $name]"
            }
            else {
                $sanitizedData[$key] = "[Object: $($value.GetType().Name)]"
            }
        }
        
        $historyEntry = @{
            EventName = $eventName
            EventData = $sanitizedData
            Timestamp = [DateTime]::Now
            HandlerCount = if ($this.EventHandlers.ContainsKey($eventName)) { 
                $this.EventHandlers[$eventName].Count 
            } else { 0 }
        }
        
        $this.EventHistory.Add($historyEntry)
        
        if ($this.EventHistory.Count -gt $this.MaxHistorySize) {
            $this.EventHistory.RemoveAt(0)
        }
    }
    
    # Get event history
    [hashtable[]] GetEventHistory([string]$eventName = $null) {
        if ($eventName) {
            return $this.EventHistory.Where({ $_.EventName -eq $eventName })
        }
        return $this.EventHistory | ForEach-Object { $_ }
    }
    
    # Clear event history
    [void] ClearHistory() {
        $this.EventHistory.Clear()
    }
    
    # Get information about registered events
    [hashtable] GetEventInfo() {
        $info = @{
            RegisteredEvents = @{}
            TotalHandlers = 0
            TotalEventsPublished = $this.TotalEventsPublished
            TotalHandlersCalled = $this.TotalHandlersCalled
            EnableHistory = $this.EnableHistory
            EnableDebugLogging = $this.EnableDebugLogging
            HistorySize = $this.EventHistory.Count
        }
        
        foreach ($eventName in $this.EventHandlers.Keys) {
            $handlers = $this.EventHandlers[$eventName]
            $info.RegisteredEvents[$eventName] = @{
                HandlerCount = $handlers.Count
                Handlers = $handlers.Keys | ForEach-Object { 
                    @{
                        Id = $_
                        ExecutionCount = $handlers[$_].ExecutionCount
                        SubscribedAt = $handlers[$_].SubscribedAt
                    }
                }
            }
            $info.TotalHandlers += $handlers.Count
        }
        
        return $info
    }
    
    # Get debug report
    [string] GetDebugReport() {
        $sb = [System.Text.StringBuilder]::new()
        $info = $this.GetEventInfo()
        
        $sb.AppendLine("EventBus Debug Report")
        $sb.AppendLine("====================")
        $sb.AppendLine("Total Events Published: $($info.TotalEventsPublished)")
        $sb.AppendLine("Total Handlers Called: $($info.TotalHandlersCalled)")
        $sb.AppendLine("Active Handlers: $($info.TotalHandlers)")
        $sb.AppendLine("History Enabled: $($info.EnableHistory)")
        $sb.AppendLine("Debug Logging: $($info.EnableDebugLogging)")
        $sb.AppendLine("History Size: $($info.HistorySize)/$($this.MaxHistorySize)")
        $sb.AppendLine("")
        $sb.AppendLine("Registered Events:")
        
        foreach ($eventName in $info.RegisteredEvents.Keys | Sort-Object) {
            $eventInfo = $info.RegisteredEvents[$eventName]
            $sb.AppendLine("  $eventName : $($eventInfo.HandlerCount) handler(s)")
            
            foreach ($handler in $eventInfo.Handlers) {
                $sb.AppendLine("    - $($handler.Id): $($handler.ExecutionCount) executions")
            }
        }
        
        return $sb.ToString()
    }
}

# Common Event Names (for consistency across the application)
class EventNames {
    # Project Events
    static [string]$ProjectCreated = 'project.created'
    static [string]$ProjectUpdated = 'project.updated'
    static [string]$ProjectDeleted = 'project.deleted'
    static [string]$ProjectSelected = 'project.selected'
    
    # Task Events
    static [string]$TaskCreated = 'task.created'
    static [string]$TaskUpdated = 'task.updated'
    static [string]$TaskDeleted = 'task.deleted'
    static [string]$TaskSelected = 'task.selected'
    static [string]$TaskStatusChanged = 'task.statusChanged'
    
    # Navigation Events
    static [string]$TabChanged = 'navigation.tabChanged'
    static [string]$ScreenChanged = 'navigation.screenChanged'
    static [string]$DialogOpened = 'navigation.dialogOpened'
    static [string]$DialogClosed = 'navigation.dialogClosed'
    
    # Application Events
    static [string]$AppInitialized = 'app.initialized'
    static [string]$AppShutdown = 'app.shutdown'
    static [string]$ThemeChanged = 'app.themeChanged'
    static [string]$ConfigChanged = 'app.configChanged'
    static [string]$RefreshRequested = 'app.refreshRequested'
    static [string]$DataChanged = 'app.dataChanged'
    
    # Command Events
    static [string]$CommandExecuted = 'command.executed'
    static [string]$CommandRegistered = 'command.registered'
    
    # UI Events
    static [string]$FocusChanged = 'ui.focusChanged'
    static [string]$SelectionChanged = 'ui.selectionChanged'
}

# Helper class for command registration
class CommandRegistration {
    static [void] RegisterCommand([string]$name, [string]$description, [scriptblock]$action) {
        $eventBus = $global:ServiceContainer.GetService('EventBus')
        if ($eventBus) {
            $eventBus.Publish([EventNames]::CommandRegistered, @{
                Name = $name
                Description = $description
                Action = $action
            })
        }
    }
}