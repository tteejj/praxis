# EventBus.ps1 - Decoupled communication system for SimpleTaskPro
# Provides publish/subscribe pattern to eliminate tight coupling between components
#
# Phase 4 Events:
# - "state.changed" - Published by StateManager when application state changes
# - "NavigateTo" - Navigate to a specific screen
# - "NavigateBack" - Navigate back to previous screen  
# - "ApplicationExit" - Request application shutdown
# - "command.executed" - Published by InputProcessor when command is executed
# - "notification:state.changed" - Alias for "state.changed" (Phase 4 compatibility)

class EventBus {
    # Instance registry of all event subscriptions
    [hashtable]$Subscriptions = @{}
    
    EventBus() {
        # EventBus instance created (no logging dependency)
    }
    
    # Subscribe to an event with a callback scriptblock  
    [void] Subscribe([string]$eventName, [scriptblock]$callback) {
        if (-not $this.Subscriptions.ContainsKey($eventName)) {
            $this.Subscriptions[$eventName] = [System.Collections.Generic.List[object]]::new()
        }
        
        $this.Subscriptions[$eventName].Add(@{
            Type = "ScriptBlock"
            Callback = $callback
        })
        
        # New subscription to event (no logging dependency)
    }
    
    # Subscribe to an event with object method reference (PowerShell-safe)
    [void] Subscribe([string]$eventName, [object]$targetObject, [string]$methodName) {
        if (-not $this.Subscriptions.ContainsKey($eventName)) {
            $this.Subscriptions[$eventName] = [System.Collections.Generic.List[object]]::new()
        }
        
        $this.Subscriptions[$eventName].Add(@{
            Type = "MethodReference" 
            Object = $targetObject
            Method = $methodName
        })
        
        # Subscribed to event with method reference (no logging dependency)
    }
    
    # Unsubscribe from an event  
    [void] Unsubscribe([string]$eventName, [scriptblock]$callback) {
        if ($this.Subscriptions.ContainsKey($eventName)) {
            $this.Subscriptions[$eventName].Remove($callback)
            
            # Clean up empty event lists
            if ($this.Subscriptions[$eventName].Count -eq 0) {
                $this.Subscriptions.Remove($eventName)
            }
            
            # Unsubscribed from event (no logging dependency)
        }
    }
    
    # Publish an event to all subscribers
    [void] Publish([string]$eventName, [object]$data = $null) {
        # Publishing event (no logging dependency) 
        
        if ($this.Subscriptions.ContainsKey($eventName)) {
            $subscribers = $this.Subscriptions[$eventName]
            # Publishing event to subscribers (no logging dependency)
            
            # Create a copy of the subscribers list in case a callback modifies the original list
            $subscribersCopy = $subscribers.ToArray()
            
            foreach ($subscriber in $subscribersCopy) {
                try {
                    if ($subscriber.Type -eq "ScriptBlock") {
                        # Traditional scriptblock callback
                        if ($data -ne $null) {
                            & $subscriber.Callback $data
                        } else {
                            & $subscriber.Callback
                        }
                    } elseif ($subscriber.Type -eq "MethodReference") {
                        # Object method reference - PowerShell safe
                        if ($data -ne $null) {
                            $subscriber.Object.($subscriber.Method)($data)
                        } else {
                            $subscriber.Object.($subscriber.Method)()
                        }
                    }
                } catch {
                    # Error executing subscriber (no logging dependency)
                }
            }
        } else {
            # Published event with no subscribers (no logging dependency)
        }
    }
    
    # Get list of all active events (for debugging)
    [string[]] GetActiveEvents() {
        return $this.Subscriptions.Keys
    }
    
    # Clear all subscriptions (useful for cleanup/testing)
    [void] Clear() {
        $this.Subscriptions.Clear()
        # All EventBus subscriptions cleared (no logging dependency)
    }
    
    # Get subscription count for an event
    [int] GetSubscriberCount([string]$eventName) {
        if ($this.Subscriptions.ContainsKey($eventName)) {
            return $this.Subscriptions[$eventName].Count
        }
        return 0
    }
}