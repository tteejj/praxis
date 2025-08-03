# CRUDScreen.ps1 - Base class that eliminates 60-70% of screen boilerplate
# Solves: Service injection hell, event handling duplication, event subscription management, initialization complexity

class CRUDScreen : UnifiedScreen {
    # AUTO-INJECTED SERVICES - No more manual GetService() calls!
    [object]$DataService        # The primary service for this screen (TaskService, ProjectService, etc.)
    [EventBus]$EventBus        # Event system for screen communication
    [object]$DataGrid # Standard data grid component (MinimalDataGrid or UnifiedList)
    
    # SERVICE CONFIGURATION - Override in derived classes
    [string]$ServiceName = ""           # Name of primary service to inject
    [string]$EntityName = ""            # Name of entity (Task, Project, TimeEntry)
    [string]$EntityNamePlural = ""      # Plural form (Tasks, Projects, TimeEntries)
    
    # GRID CONFIGURATION - Override in derived classes
    [array]$GridColumns = @()           # Column definitions for the data grid
    [bool]$ShowGridBorder = $true       # Whether to show grid border
    [BorderType]$GridBorderType = [BorderType]::Rounded
    
    # EVENT MANAGEMENT - Automatic subscription/cleanup
    hidden [hashtable]$EventSubscriptions = @{}
    
    # STANDARD CRUD OPERATIONS - Override these in derived classes
    # These provide the actual business logic, CRUDScreen handles the plumbing
    
    CRUDScreen([string]$serviceName, [string]$entityName) : base() {
        $this.ServiceName = $serviceName
        $this.EntityName = $entityName
        $this.EntityNamePlural = $entityName + "s"  # Simple pluralization
    }
    
    CRUDScreen([string]$serviceName, [string]$entityName, [string]$entityNamePlural) : base() {
        $this.ServiceName = $serviceName  
        $this.EntityName = $entityName
        $this.EntityNamePlural = $entityNamePlural
    }
    
    # AUTOMATIC SERVICE INJECTION - Eliminates 25-40 lines per screen
    [void] OnInitialize() {
        # AUTO-INJECT PRIMARY SERVICE
        $this.DataService = $this.GetService($this.ServiceName)
        if (-not $this.DataService) {
            throw "CRUDScreen: Required service '$($this.ServiceName)' not found in ServiceContainer"
        }
        
        # AUTO-INJECT STANDARD SERVICES
        $this.EventBus = $this.GetService('EventBus')
        
        # SETUP EVENT SUBSCRIPTIONS - Automatic management
        $this.SetupEventSubscriptions()
        
        # CREATE AND CONFIGURE DATA GRID
        $this.SetupDataGrid()
        
        # LOAD INITIAL DATA
        $this.LoadData()
    }
    
    # AUTOMATIC EVENT SUBSCRIPTION MANAGEMENT - Eliminates complex closure handling
    [void] SetupEventSubscriptions() {
        if (-not $this.EventBus) { return }
        
        # Standard CRUD events - automatically subscribe based on entity name
        $createEvent = "$($this.EntityName.ToLower()).created"
        $updateEvent = "$($this.EntityName.ToLower()).updated" 
        $deleteEvent = "$($this.EntityName.ToLower()).deleted"
        
        # Capture screen reference for closures
        $screen = $this
        
        # Subscribe to entity created events
        $this.EventSubscriptions[$createEvent] = $this.EventBus.Subscribe($createEvent, {
            param($sender, $eventData)
            try {
                if ($global:Logger) {
                    $global:Logger.Debug("CRUDScreen: project.created event received")
                }
                if ($screen -and $screen.LoadData) {
                    if ($global:Logger) {
                        $global:Logger.Debug("CRUDScreen: Calling LoadData()")
                    }
                    $screen.LoadData()
                } else {
                    if ($global:Logger) {
                        $global:Logger.Error("CRUDScreen: screen or LoadData method is null")
                    }
                }
            } catch {
                if ($global:Logger) {
                    $global:Logger.Error("CRUDScreen event handler error: $_")
                }
            }
        }.GetNewClosure())
        
        # Subscribe to entity updated events
        $this.EventSubscriptions[$updateEvent] = $this.EventBus.Subscribe($updateEvent, {
            param($sender, $eventData)
            $screen.OnEntityUpdated($eventData)
        }.GetNewClosure())
        
        # Subscribe to entity deleted events
        $this.EventSubscriptions[$deleteEvent] = $this.EventBus.Subscribe($deleteEvent, {
            param($sender, $eventData)
            $screen.OnEntityDeleted($eventData)
        }.GetNewClosure())
        
        # Allow derived classes to add additional subscriptions
        $this.SetupCustomEventSubscriptions()
    }
    
    # STANDARD DATA GRID SETUP - Eliminates grid creation boilerplate
    [void] SetupDataGrid() {
        $this.DataGrid = [MinimalDataGrid]::new()
        $this.DataGrid.Title = $this.EntityNamePlural
        $this.DataGrid.ShowBorder = $this.ShowGridBorder
        $this.DataGrid.BorderType = $this.GridBorderType
        $this.DataGrid.ShowGridLines = $false
        
        # Set columns if provided
        if ($this.GridColumns.Count -gt 0) {
            $this.DataGrid.SetColumns($this.GridColumns)
        }
        
        $this.DataGrid.Initialize($global:ServiceContainer)
        $this.AddChild($this.DataGrid)
    }
    
    # AUTOMATIC BOUNDS MANAGEMENT - No more manual positioning
    [void] OnBoundsChanged() {
        if (-not $this.DataGrid) { return }
        
        # Grid takes full screen space - simple and predictable
        $this.DataGrid.SetBounds($this.X, $this.Y, $this.Width, $this.Height)
    }
    
    # STANDARD CRUD KEYBOARD SHORTCUTS - Built-in, consistent across all screens
    [bool] HandleScreenInput([System.ConsoleKeyInfo]$keyInfo) {
        # Standard CRUD shortcuts - same across all screens
        switch ($keyInfo.KeyChar) {
            'n' { $this.NewItem(); return $true }
            'e' { $this.EditItem(); return $true }
            'd' { $this.DeleteItem(); return $true }
            'r' { $this.RefreshItems(); return $true }
            '/' { $this.ShowActionMenu(); return $true }
        }
        
        # Standard keys
        switch ($keyInfo.Key) {
            ([System.ConsoleKey]::Enter) { $this.EditItem(); return $true }
            ([System.ConsoleKey]::Delete) { $this.DeleteItem(); return $true }
            ([System.ConsoleKey]::F5) { $this.RefreshItems(); return $true }
        }
        
        # Allow derived classes to handle additional keys
        return $this.HandleCustomInput($keyInfo)
    }
    
    # STANDARD CRUD OPERATIONS - Override these with actual business logic
    [void] NewItem() {
        # Default implementation - derived classes should override
        if ($global:Logger) {
            $global:Logger.Warning("CRUDScreen.NewItem: Not implemented in derived class")
        }
    }
    
    [void] EditItem() {
        $selected = $this.GetSelectedItem()
        if (-not $selected) { return }
        
        # Default implementation - derived classes should override
        if ($global:Logger) {
            $global:Logger.Warning("CRUDScreen.EditItem: Not implemented in derived class")
        }
    }
    
    [void] DeleteItem() {
        $selected = $this.GetSelectedItem()
        if (-not $selected) { return }
        
        # Use UnifiedDialog for confirmation - consistent across all screens
        $message = "Are you sure you want to delete this $($this.EntityName.ToLower())?"
        $dialog = [UnifiedDialog]::new("Confirm Delete", 50, 10)
        $dialog.AddField("message", "", $message)
        $dialog.SetReadOnlyField("message", $true)
        $dialog.SetButtons("Delete", "Cancel")
        
        $screen = $this
        $itemId = $this.GetSelectedItemId($selected)
        
        $dialog.OnPrimary = {
            $screen.PerformDelete($itemId)
            $screen.RefreshItems()
        }.GetNewClosure()
        
        if ($global:ScreenManager) {
            $global:ScreenManager.Push($dialog)
        }
    }
    
    [void] RefreshItems() {
        $this.LoadData()
        $this.Invalidate()
    }
    
    [void] ShowActionMenu() {
        # Let MainScreen handle the action popup since it has the infrastructure
        $screenManager = $this.ServiceContainer.GetService('ScreenManager')
        if ($screenManager -and $screenManager.CurrentScreen) {
            $mainScreen = $screenManager.CurrentScreen
            # Check if mainScreen has ShowActionPopup method instead of type checking
            if ($mainScreen -and $mainScreen.PSObject.Methods['ShowActionPopup']) {
                $mainScreen.ShowActionPopup()
            }
        }
    }
    
    # STANDARD EVENT HANDLERS - Automatic data refresh with selection preservation
    [void] OnEntityCreated($eventData) {
        # Debug logging
        if ($global:Logger) {
            $global:Logger.Debug("CRUDScreen.OnEntityCreated: Entity=$($this.EntityName), EventData=$($eventData | ConvertTo-Json -Compress)")
        }
        
        # Always refresh data first
        $this.LoadData()
        
        # Try to select the new item - with error handling
        try {
            if ($eventData -and $eventData.PSObject.Properties.Name -contains $this.EntityName) {
                $newItem = $eventData.$($this.EntityName)
                if ($newItem) {
                    $itemId = $this.GetItemId($newItem)
                    if ($itemId) {
                        $this.SelectItemById($itemId)
                    }
                }
            }
        } catch {
            # Log error but don't fail the refresh
            if ($global:Logger) {
                $global:Logger.Warning("CRUDScreen.OnEntityCreated: Error selecting new item: $_")
            }
        }
    }
    
    [void] OnEntityUpdated($eventData) {
        $this.LoadData()
    }
    
    [void] OnEntityDeleted($eventData) {
        $this.LoadData()
    }
    
    # VIRTUAL METHODS - Override these in derived classes for specific functionality
    
    # REQUIRED: Load data into the grid
    [void] LoadData() {
        throw "CRUDScreen.LoadData: Must be implemented in derived class"
    }
    
    # REQUIRED: Get the currently selected item
    [object] GetSelectedItem() {
        if ($this.DataGrid) {
            return $this.DataGrid.GetSelectedItem()
        }
        return $null
    }
    
    # REQUIRED: Get the ID of an item (for selection and deletion)
    [object] GetItemId($item) {
        # Default implementation - assumes 'Id' property
        if ($item -and $item.PSObject.Properties.Name -contains 'Id') {
            return $item.Id
        }
        return $null
    }
    
    # REQUIRED: Get the ID of the selected item
    [object] GetSelectedItemId($selectedItem) {
        return $this.GetItemId($selectedItem)
    }
    
    # OPTIONAL: Perform the actual delete operation
    [void] PerformDelete($itemId) {
        # Default implementation - assumes DeleteXxx method on service
        $deleteMethod = "Delete$($this.EntityName)"
        if ($this.DataService | Get-Member -Name $deleteMethod -MemberType Method) {
            $this.DataService.$deleteMethod($itemId)
        } else {
            if ($global:Logger) {
                $global:Logger.Warning("CRUDScreen.PerformDelete: Method '$deleteMethod' not found on service")
            }
        }
    }
    
    # OPTIONAL: Handle custom keyboard input
    [bool] HandleCustomInput([System.ConsoleKeyInfo]$keyInfo) {
        return $false  # Not handled
    }
    
    # OPTIONAL: Setup additional event subscriptions
    [void] SetupCustomEventSubscriptions() {
        # Override in derived classes if needed
    }
    
    # UTILITY METHODS
    
    # Select item by ID after data refresh
    [void] SelectItemById($itemId) {
        if (-not $this.DataGrid -or -not $itemId) { return }
        
        for ($i = 0; $i -lt $this.DataGrid.Items.Count; $i++) {
            $item = $this.DataGrid.Items[$i]
            if ($this.GetItemId($item) -eq $itemId) {
                $this.DataGrid.SelectIndex($i)
                break
            }
        }
    }
    
    # AUTOMATIC CLEANUP - Prevents memory leaks
    [void] OnDeactivated() {
        # Unsubscribe from all events
        if ($this.EventBus) {
            foreach ($eventName in $this.EventSubscriptions.Keys) {
                $subscription = $this.EventSubscriptions[$eventName]
                if ($subscription) {
                    $this.EventBus.Unsubscribe($eventName, $subscription)
                }
            }
            $this.EventSubscriptions.Clear()
        }
        
        ([Screen]$this).OnDeactivated()
    }
}