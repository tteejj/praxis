# EventBus.ps1 - Decoupled communication system for SimpleTaskPro
# Provides publish/subscribe pattern to eliminate tight coupling between components

class EventBus {
    # Static registry of all event subscriptions
    static [hashtable]$Subscriptions = @{}
    
    # Subscribe to an event with a callback scriptblock  
    static [void] Subscribe([string]$eventName, [scriptblock]$callback) {
        if (-not [EventBus]::Subscriptions.ContainsKey($eventName)) {
            [EventBus]::Subscriptions[$eventName] = [System.Collections.Generic.List[object]]::new()
        }
        
        [EventBus]::Subscriptions[$eventName].Add(@{
            Type = "ScriptBlock"
            Callback = $callback
        })
        
        if ($global:Debug) {
            Write-Host "EventBus: Subscribed to '$eventName' with ScriptBlock (total subscribers: $([EventBus]::Subscriptions[$eventName].Count))" -ForegroundColor Green
        }
    }
    
    # Subscribe to an event with object method reference (PowerShell-safe)
    static [void] Subscribe([string]$eventName, [object]$targetObject, [string]$methodName) {
        if (-not [EventBus]::Subscriptions.ContainsKey($eventName)) {
            [EventBus]::Subscriptions[$eventName] = [System.Collections.Generic.List[object]]::new()
        }
        
        [EventBus]::Subscriptions[$eventName].Add(@{
            Type = "MethodReference" 
            Object = $targetObject
            Method = $methodName
        })
        
        if ($global:Debug) {
            Write-Host "EventBus: Subscribed to '$eventName' with $($targetObject.GetType().Name)::$methodName (total subscribers: $([EventBus]::Subscriptions[$eventName].Count))" -ForegroundColor Green
        }
    }
    
    # Unsubscribe from an event  
    static [void] Unsubscribe([string]$eventName, [scriptblock]$callback) {
        if ([EventBus]::Subscriptions.ContainsKey($eventName)) {
            [EventBus]::Subscriptions[$eventName].Remove($callback)
            
            # Clean up empty event lists
            if ([EventBus]::Subscriptions[$eventName].Count -eq 0) {
                [EventBus]::Subscriptions.Remove($eventName)
            }
            
            if ($global:Debug) {
                Write-Host "EventBus: Unsubscribed from '$eventName'" -ForegroundColor Yellow
            }
        }
    }
    
    # Publish an event to all subscribers
    static [void] Publish([string]$eventName, [object]$data = $null) {
        if ($global:Debug) {
            Write-Host "EventBus: Publishing '$eventName' with data: $($data | ConvertTo-Json -Compress -Depth 1)" -ForegroundColor Cyan
        }
        
        if ([EventBus]::Subscriptions.ContainsKey($eventName)) {
            $subscribers = [EventBus]::Subscriptions[$eventName]
            
            foreach ($subscriber in $subscribers) {
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
                    Write-Host "EventBus: Error executing subscriber for '$eventName': $_" -ForegroundColor Red
                    if ($global:Debug) {
                        Write-Host "EventBus: Stack trace: $($_.ScriptStackTrace)" -ForegroundColor Red
                    }
                }
            }
        } else {
            if ($global:Debug) {
                Write-Host "EventBus: No subscribers for '$eventName'" -ForegroundColor Gray
            }
        }
    }
    
    # Get list of all active events (for debugging)
    static [string[]] GetActiveEvents() {
        return [EventBus]::Subscriptions.Keys
    }
    
    # Clear all subscriptions (useful for cleanup/testing)
    static [void] Clear() {
        [EventBus]::Subscriptions.Clear()
        if ($global:Debug) {
            Write-Host "EventBus: All subscriptions cleared" -ForegroundColor Yellow
        }
    }
    
    # Get subscription count for an event
    static [int] GetSubscriberCount([string]$eventName) {
        if ([EventBus]::Subscriptions.ContainsKey($eventName)) {
            return [EventBus]::Subscriptions[$eventName].Count
        }
        return 0
    }
}