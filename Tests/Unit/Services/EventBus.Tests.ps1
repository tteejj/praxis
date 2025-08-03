# EventBus.Tests.ps1 - Tests for EventBus service

BeforeAll {
    Import-Module "$PSScriptRoot/../../TestHelpers.psm1" -Force
    Initialize-PraxisForTesting
}

Describe "EventBus Service" {
    BeforeEach {
        $eventBus = [EventBus]::new()
        $global:Logger = New-MockLogger
    }
    
    Context "Subscription" {
        It "Should subscribe handlers to events" {
            $handlerCalled = $false
            $handler = {
                param($sender, $eventData)
                $handlerCalled = $true
            }.GetNewClosure()
            
            $handlerId = $eventBus.Subscribe('test.event', $handler)
            
            $handlerId | Should -Not -BeNullOrEmpty
            $handlerId | Should -Match "handler_\d+"
        }
        
        It "Should allow multiple handlers for same event" {
            $handler1Called = $false
            $handler2Called = $false
            
            $handler1 = { $handler1Called = $true }.GetNewClosure()
            $handler2 = { $handler2Called = $true }.GetNewClosure()
            
            $id1 = $eventBus.Subscribe('test.event', $handler1)
            $id2 = $eventBus.Subscribe('test.event', $handler2)
            
            $id1 | Should -Not -Be $id2
        }
    }
    
    Context "Publishing" {
        It "Should call all subscribed handlers" {
            $results = [System.Collections.ArrayList]::new()
            
            $handler1 = {
                param($sender, $eventData)
                $results.Add("Handler1: $($eventData.Value)") | Out-Null
            }.GetNewClosure()
            
            $handler2 = {
                param($sender, $eventData)
                $results.Add("Handler2: $($eventData.Value)") | Out-Null
            }.GetNewClosure()
            
            $eventBus.Subscribe('test.event', $handler1)
            $eventBus.Subscribe('test.event', $handler2)
            
            $eventBus.Publish('test.event', @{Value = "TestData"})
            
            $results.Count | Should -Be 2
            $results[0] | Should -Be "Handler1: TestData"
            $results[1] | Should -Be "Handler2: TestData"
        }
        
        It "Should pass sender and event data correctly" {
            $capturedSender = $null
            $capturedData = $null
            
            $handler = {
                param($sender, $eventData)
                $capturedSender = $sender
                $capturedData = $eventData
            }.GetNewClosure()
            
            $eventBus.Subscribe('test.event', $handler)
            
            $testSender = @{Name = "TestSender"}
            $testData = @{Message = "Hello"; Count = 42}
            
            $eventBus.Publish('test.event', $testData, $testSender)
            
            $capturedSender.Name | Should -Be "TestSender"
            $capturedData.Message | Should -Be "Hello"
            $capturedData.Count | Should -Be 42
        }
        
        It "Should handle events with no subscribers gracefully" {
            { $eventBus.Publish('unsubscribed.event', @{}) } | Should -Not -Throw
        }
    }
    
    Context "Unsubscription" {
        It "Should unsubscribe handlers" {
            $callCount = 0
            $handler = {
                $callCount++
            }.GetNewClosure()
            
            $handlerId = $eventBus.Subscribe('test.event', $handler)
            
            # First publish should call handler
            $eventBus.Publish('test.event', @{})
            $callCount | Should -Be 1
            
            # Unsubscribe
            $eventBus.Unsubscribe($handlerId)
            
            # Second publish should not call handler
            $eventBus.Publish('test.event', @{})
            $callCount | Should -Be 1
        }
    }
    
    Context "Error Handling" {
        It "Should continue calling other handlers if one throws" {
            $handler1Called = $false
            $handler2Called = $false
            $handler3Called = $false
            
            $handler1 = { $handler1Called = $true }.GetNewClosure()
            $handler2 = { throw "Handler error" }.GetNewClosure()
            $handler3 = { $handler3Called = $true }.GetNewClosure()
            
            $eventBus.Subscribe('test.event', $handler1)
            $eventBus.Subscribe('test.event', $handler2)
            $eventBus.Subscribe('test.event', $handler3)
            
            $eventBus.Publish('test.event', @{})
            
            $handler1Called | Should -Be $true
            $handler3Called | Should -Be $true
            
            # Check that error was logged
            $errorLogs = $global:Logger.Logs | Where-Object { $_.Level -eq "ERROR" }
            $errorLogs.Count | Should -BeGreaterThan 0
        }
    }
    
    Context "Event Names" {
        It "Should use EventNames enum values" {
            # Test that common event names are defined
            [EventNames]::ThemeChanged | Should -Be 'theme.changed'
            [EventNames]::ProjectCreated | Should -Be 'project.created'
            [EventNames]::ProjectUpdated | Should -Be 'project.updated'
            [EventNames]::ProjectDeleted | Should -Be 'project.deleted'
            [EventNames]::TaskCreated | Should -Be 'task.created'
            [EventNames]::TaskUpdated | Should -Be 'task.updated'
            [EventNames]::TaskDeleted | Should -Be 'task.deleted'
        }
    }
    
    Context "Performance" {
        It "Should handle high-frequency events efficiently" {
            $callCount = 0
            $handler = { $callCount++ }.GetNewClosure()
            
            # Subscribe 10 handlers
            for ($i = 0; $i -lt 10; $i++) {
                $eventBus.Subscribe('perf.test', $handler)
            }
            
            $perf = Measure-Performance -Name "1000 events with 10 handlers" -ScriptBlock {
                for ($i = 0; $i -lt 1000; $i++) {
                    $eventBus.Publish('perf.test', @{Index = $i})
                }
            }
            
            $callCount | Should -Be 10000  # 1000 events * 10 handlers
            $perf.ElapsedMilliseconds | Should -BeLessThan 1000  # Should complete in under 1 second
        }
    }
    
    Context "Thread Safety" {
        It "Should handle concurrent operations" -Skip {
            # PowerShell doesn't have true threading, but we can test
            # that the data structures don't get corrupted
            
            $results = [System.Collections.Concurrent.ConcurrentBag[string]]::new()
            
            $handler = {
                param($sender, $eventData)
                $results.Add("Event: $($eventData.Id)")
            }.GetNewClosure()
            
            # Subscribe handlers
            for ($i = 0; $i -lt 5; $i++) {
                $eventBus.Subscribe("concurrent.test", $handler)
            }
            
            # Simulate concurrent publishing
            $jobs = @()
            for ($i = 0; $i -lt 10; $i++) {
                $jobs += Start-Job -ScriptBlock {
                    param($bus, $id)
                    $bus.Publish("concurrent.test", @{Id = $id})
                } -ArgumentList $eventBus, $i
            }
            
            $jobs | Wait-Job | Remove-Job
            
            # Should have 50 results (10 events * 5 handlers)
            $results.Count | Should -Be 50
        }
    }
}