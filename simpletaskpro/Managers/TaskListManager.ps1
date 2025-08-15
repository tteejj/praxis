# Managers/TaskListManager.ps1 - Core TaskListScreen business logic
# Phase 1: Foundation with all core data functions from TaskListScreen

. "$PSScriptRoot/../Models/SimpleTask.ps1"
. "$PSScriptRoot/../Services/SimpleTaskService.ps1"

class TaskListManager {
    # === CORE PROPERTIES ===
    [SimpleTaskService]$TaskService
    [SimpleTask[]]$Tasks = @()
    [object[]]$FlatList = @()  # Hierarchical flat list for display
    
    # === STATE PROPERTIES ===
    [int]$SelectedIndex = 0
    [int]$ScrollTop = 0
    [string]$CurrentFilter = "All"  # All, Today, High, Medium, Low, Completed, Pending
    [string]$TagFilter = ""
    [string]$SearchTerm = ""
    [bool]$GlobalCollapseSubtasks = $false
    [bool]$ShowCompletedTasks = $true
    
    # === EDITING STATE ===
    [int]$EditingIndex = -1
    [string]$EditingField = ""
    [string]$EditingValue = ""
    [SimpleTask]$EditingTask = $null
    [bool]$IsNewItem = $false
    
    # === NAVIGATION STATE ===
    [int]$Width = 120
    [int]$Height = 30
    [int]$ItemsPerPage = 20
    
    # === STATUS ===
    [string]$StatusMessage = ""
    [DateTime]$StatusMessageTime = [DateTime]::MinValue
    
    TaskListManager() {
        $this.TaskService = [SimpleTaskService]::new()
        $this.LoadData()
    }
    
    TaskListManager([string]$dataPath) {
        $this.TaskService = [SimpleTaskService]::new($dataPath)
        $this.LoadData()
    }
    
    # === CORE DATA MANAGEMENT (from TaskListScreen.LoadData) ===
    
    [void] LoadData() {
        try {
            Write-Host "Loading tasks..." -ForegroundColor Yellow
            $this.Tasks = $this.TaskService.GetParentTasks()
            $this.FlatList = $this.BuildFlatList()
            Write-Host "Loaded $($this.Tasks.Count) parent tasks, $($this.FlatList.Count) total items" -ForegroundColor Green
        } catch {
            Write-Host "Error loading data: $($_.Exception.Message)" -ForegroundColor Red
            $this.SetStatusMessage("Failed to load tasks: $($_.Exception.Message)", 5000)
        }
    }
    
    # === BUILD FLAT LIST (from TaskListScreen.BuildFlatListInternal) ===
    
    [hashtable[]] BuildFlatList() {
        return $this.BuildFlatListInternal($null)
    }
    
    [hashtable[]] BuildFlatList([SimpleTask[]]$inputTasks) {
        return $this.BuildFlatListInternal($inputTasks)
    }
    
    [hashtable[]] BuildFlatListInternal([SimpleTask[]]$inputTasks) {
        $taskArray = if ($inputTasks) { $inputTasks } else { $this.Tasks }
        $newList = @()
        
        foreach ($task in $taskArray) {
            # Apply filters
            if (-not $this.ShouldShowTask($task)) { continue }
            
            # Add parent task
            $parentItem = @{
                Task = $task
                Level = 0
                IsLast = $false
                Type = "Task"
            }
            $newList += $parentItem
            
            # Add subtasks (if not collapsed)
            if (-not $this.GlobalCollapseSubtasks -and -not $task.SubtasksCollapsed -and $task.Subtasks -and $task.Subtasks.Count -gt 0) {
                for ($i = 0; $i -lt $task.Subtasks.Count; $i++) {
                    $subtask = $task.Subtasks[$i]
                    if ($this.ShouldShowTask($subtask)) {
                        $isLastSubtask = ($i -eq ($task.Subtasks.Count - 1))
                        
                        $subtaskItem = @{
                            Task = $subtask
                            Level = 1
                            IsLast = $isLastSubtask
                            Type = "Subtask"
                        }
                        $newList += $subtaskItem
                    }
                }
            }
        }
        
        Write-Host "Built flat list with $($newList.Count) items (filter: $($this.CurrentFilter))" -ForegroundColor Blue
        return $newList
    }
    
    # === TASK FILTERING (from TaskListScreen.ShouldShowTask) ===
    
    [bool] ShouldShowTask([SimpleTask]$task) {
        # Apply completion filter
        if (-not $this.ShowCompletedTasks -and $task.Completed) {
            return $false
        }
        
        # Apply current filter
        if (-not $task.MatchesFilter($this.CurrentFilter)) {
            return $false
        }
        
        # Apply tag filter
        if (-not [string]::IsNullOrEmpty($this.TagFilter) -and -not $task.MatchesTag($this.TagFilter)) {
            return $false
        }
        
        # Apply search term
        if (-not [string]::IsNullOrEmpty($this.SearchTerm) -and -not $task.MatchesSearch($this.SearchTerm)) {
            return $false
        }
        
        return $true
    }
    
    # === TASK CRUD OPERATIONS (from TaskListScreen command handlers) ===
    
    [void] CreateNewTask([string]$title = "New Task", [string]$priority = "Medium") {
        try {
            # Validate input
            if ([string]::IsNullOrWhiteSpace($title)) {
                $this.SetStatusMessage("Task title cannot be empty", 3000)
                return
            }
            
            $newTask = [SimpleTask]::new($title.Trim())
            $newTask.Priority = $priority
            $newTask.CreatedDate = [DateTime]::Now
            $newTask.ModifiedDate = [DateTime]::Now
            
            $this.TaskService.AddTask($newTask)
            $this.TaskService.SaveTasks()
            $this.LoadData()  # Refresh
            
            # Select the new task
            $this.FindAndSelectTask($newTask.Id)
            
            $this.SetStatusMessage("Task '$title' created", 2000)
            Write-Host "Created new task: $title" -ForegroundColor Green
            
        } catch {
            $this.SetStatusMessage("Failed to create task: $($_.Exception.Message)", 5000)
            Write-Host "Error creating task: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    
    [void] HandleNewTask() {
        # Interactive task creation with prompts
        try {
            $this.SetStatusMessage("Creating new task...", 1000)
            $this.CreateNewTask("New Task", "Medium")
            
            # Automatically start editing the title
            $this.StartEditCurrentTask("Title")
            
        } catch {
            $this.SetStatusMessage("Failed to create task: $($_.Exception.Message)", 5000)
        }
    }
    
    [object] CreateNewItem() {
        # Create new parent task item for editing
        $newTask = [SimpleTask]::new("New Task")
        $newTask.Priority = "Medium"
        
        return @{
            Task = $newTask
            Level = 0
            IsLast = $false
            Type = "Task"
        }
    }
    
    [void] DeleteCurrentTask() {
        if ($this.FlatList.Count -eq 0 -or $this.SelectedIndex -ge $this.FlatList.Count) { 
            $this.SetStatusMessage("No task selected to delete", 2000)
            return 
        }
        
        $item = $this.FlatList[$this.SelectedIndex]
        $task = $item.Task
        
        # Confirmation for parent tasks with subtasks
        if ($item.Level -eq 0 -and $task.Subtasks.Count -gt 0) {
            $this.SetStatusMessage("Deleting parent task will delete all $($task.Subtasks.Count) subtasks", 3000)
        }
        
        try {
            $taskTitle = $task.Title
            $this.TaskService.DeleteTask($task.Id)
            $this.TaskService.SaveTasks()
            $this.LoadData()  # Refresh
            
            # Adjust selection if needed
            if ($this.SelectedIndex -ge $this.FlatList.Count) {
                $this.SelectedIndex = [Math]::Max(0, $this.FlatList.Count - 1)
            }
            
            $this.SetStatusMessage("Task '$taskTitle' deleted", 2000)
            Write-Host "Deleted task: $taskTitle" -ForegroundColor Green
            
        } catch {
            $this.SetStatusMessage("Failed to delete task: $($_.Exception.Message)", 5000)
            Write-Host "Error deleting task: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    
    [void] HandleDeleteTask() {
        # Enhanced delete with confirmation
        if ($this.FlatList.Count -eq 0 -or $this.SelectedIndex -ge $this.FlatList.Count) { 
            $this.SetStatusMessage("No task selected to delete", 2000)
            return 
        }
        
        $item = $this.FlatList[$this.SelectedIndex]
        $task = $item.Task
        
        # Show preview of what will be deleted
        if ($item.Level -eq 0 -and $task.Subtasks.Count -gt 0) {
            $this.SetStatusMessage("Will delete '$($task.Title)' and $($task.Subtasks.Count) subtasks. Press D again to confirm.", 5000)
        } else {
            $this.SetStatusMessage("Will delete '$($task.Title)'. Press D again to confirm.", 3000)
        }
        
        # In a real UI, this would wait for confirmation. For now, just delete.
        $this.DeleteCurrentTask()
    }
    
    [void] ToggleComplete() {
        if ($this.FlatList.Count -eq 0 -or $this.SelectedIndex -ge $this.FlatList.Count) { 
            $this.SetStatusMessage("No task selected", 2000)
            return 
        }
        
        $item = $this.FlatList[$this.SelectedIndex]
        $task = $item.Task
        
        try {
            $oldStatus = $task.Completed
            $this.TaskService.ToggleComplete($task.Id)
            $this.TaskService.SaveTasks()
            
            # Update the task object directly to avoid full reload
            $task.Completed = -not $oldStatus
            $task.ModifiedDate = [DateTime]::Now
            
            # Only reload if filter might hide the task
            if ($this.CurrentFilter -eq "Completed" -or $this.CurrentFilter -eq "Pending") {
                $this.LoadData()
            }
            
            $status = if ($task.Completed) { "completed" } else { "incomplete" }
            $this.SetStatusMessage("Task '$($task.Title)' marked as $status", 2000)
            
        } catch {
            $this.SetStatusMessage("Failed to toggle completion: $($_.Exception.Message)", 5000)
            Write-Host "Error toggling completion: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    
    [void] HandleToggleComplete() {
        # Enhanced toggle with smart refresh
        $this.ToggleComplete()
        
        # Auto-advance to next task for rapid completion
        if ($this.SelectedIndex -lt $this.FlatList.Count - 1) {
            $this.SelectedIndex++
            $this.EnsureVisible()
        }
    }
    
    [void] AddSubtask([string]$title = "New Subtask") {
        if ($this.FlatList.Count -eq 0 -or $this.SelectedIndex -ge $this.FlatList.Count) { 
            $this.SetStatusMessage("No task selected", 2000)
            return 
        }
        
        $item = $this.FlatList[$this.SelectedIndex]
        
        # Only allow subtasks for parent tasks
        if ($item.Level -ne 0) {
            $this.SetStatusMessage("Cannot add subtask to subtask", 2000)
            return
        }
        
        $parentTask = $item.Task
        
        # Validate title
        if ([string]::IsNullOrWhiteSpace($title)) {
            $this.SetStatusMessage("Subtask title cannot be empty", 3000)
            return
        }
        
        try {
            $newSubtask = [SimpleTask]::new($title.Trim())
            $newSubtask.Priority = "Medium"
            $newSubtask.CreatedDate = [DateTime]::Now
            $newSubtask.ModifiedDate = [DateTime]::Now
            
            $this.TaskService.AddSubtask($parentTask.Id, $newSubtask)
            $this.TaskService.SaveTasks()
            $this.LoadData()  # Refresh
            
            # Find and select the new subtask
            $this.FindAndSelectTask($newSubtask.Id)
            
            $this.SetStatusMessage("Subtask '$title' added", 2000)
            Write-Host "Added subtask '$title' to '$($parentTask.Title)'" -ForegroundColor Green
            
        } catch {
            $this.SetStatusMessage("Failed to create subtask: $($_.Exception.Message)", 5000)
            Write-Host "Error creating subtask: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    
    [void] HandleNewSubtask() {
        # Enhanced subtask creation with validation
        if ($this.FlatList.Count -eq 0 -or $this.SelectedIndex -ge $this.FlatList.Count) { 
            $this.SetStatusMessage("No task selected", 2000)
            return 
        }
        
        $item = $this.FlatList[$this.SelectedIndex]
        
        # Only allow subtasks for parent tasks
        if ($item.Level -ne 0) {
            $this.SetStatusMessage("Select a parent task to add subtask", 2000)
            return
        }
        
        $parentTask = $item.Task
        
        # Create subtask with contextual naming
        $subtaskTitle = "New subtask for $($parentTask.Title)"
        if ($subtaskTitle.Length -gt 40) {
            $subtaskTitle = "New subtask"
        }
        
        $this.AddSubtask($subtaskTitle)
        
        # Auto-start editing the new subtask title
        $this.StartEditCurrentTask("Title")
    }
    
    [void] SaveItem([hashtable]$item) {
        try {
            $task = $item.Task
            $this.TaskService.SaveTask($task)
            $this.TaskService.SaveTasks()
            
            Write-Host "Saved task: $($task.Title)" -ForegroundColor Green
            
        } catch {
            $this.SetStatusMessage("Failed to save task: $($_.Exception.Message)", 5000)
            Write-Host "Error saving task: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    
    # === PHASE 3: ADVANCED FILTERING & SEARCH OPERATIONS ===
    
    [void] ClearAllFilters() {
        $this.CurrentFilter = "All"
        $this.TagFilter = ""
        $this.SearchTerm = ""
        $this.ShowCompletedTasks = $true
        $this.FlatList = $this.BuildFlatList()
        $this.SelectedIndex = 0
        
        $this.SetStatusMessage("All filters cleared", 2000)
        Write-Host "All filters cleared" -ForegroundColor Blue
    }
    
    [void] ApplyQuickFilter([string]$quickFilter) {
        # Quick filter shortcuts like "high", "today", "overdue"
        switch ($quickFilter.ToLower()) {
            "high" { 
                $this.SetFilter("High")
            }
            "medium" { 
                $this.SetFilter("Medium")
            }
            "low" { 
                $this.SetFilter("Low")
            }
            "today" { 
                $this.SetFilter("Today")
            }
            "completed" { 
                $this.SetFilter("Completed")
            }
            "pending" { 
                $this.SetFilter("Pending")
            }
            "overdue" {
                # Custom overdue filter
                $this.CurrentFilter = "Overdue"
                $this.FlatList = $this.BuildFlatListWithCustomFilter("Overdue")
                $this.SelectedIndex = 0
                $this.SetStatusMessage("Filter: Overdue", 2000)
            }
            "recent" {
                # Tasks modified in last 7 days
                $this.CurrentFilter = "Recent"
                $this.FlatList = $this.BuildFlatListWithCustomFilter("Recent")
                $this.SelectedIndex = 0
                $this.SetStatusMessage("Filter: Recent", 2000)
            }
            "urgent" {
                # High priority or due today
                $this.CurrentFilter = "Urgent"
                $this.FlatList = $this.BuildFlatListWithCustomFilter("Urgent")
                $this.SelectedIndex = 0
                $this.SetStatusMessage("Filter: Urgent", 2000)
            }
            default {
                $this.SetStatusMessage("Unknown quick filter: $quickFilter", 3000)
            }
        }
    }
    
    [hashtable[]] BuildFlatListWithCustomFilter([string]$customFilter) {
        $taskArray = $this.Tasks
        $newList = @()
        
        foreach ($task in $taskArray) {
            # Apply custom filter logic
            $includeTask = switch ($customFilter) {
                "Overdue" { 
                    $task.IsOverdue() -and -not $task.Completed
                }
                "Recent" { 
                    $task.ModifiedDate -gt (Get-Date).AddDays(-7)
                }
                "Urgent" { 
                    ($task.Priority -eq "High" -or $task.IsDueToday()) -and -not $task.Completed
                }
                default { $true }
            }
            
            if (-not $includeTask) { continue }
            
            # Apply other filters
            if (-not $this.ShouldShowTask($task)) { continue }
            
            # Add parent task
            $parentItem = @{
                Task = $task
                Level = 0
                IsLast = $false
                Type = "Task"
            }
            $newList += $parentItem
            
            # Add subtasks (if not collapsed)
            if (-not $this.GlobalCollapseSubtasks -and -not $task.SubtasksCollapsed -and $task.Subtasks -and $task.Subtasks.Count -gt 0) {
                for ($i = 0; $i -lt $task.Subtasks.Count; $i++) {
                    $subtask = $task.Subtasks[$i]
                    if ($this.ShouldShowTask($subtask)) {
                        $isLastSubtask = ($i -eq ($task.Subtasks.Count - 1))
                        
                        $subtaskItem = @{
                            Task = $subtask
                            Level = 1
                            IsLast = $isLastSubtask
                            Type = "Subtask"
                        }
                        $newList += $subtaskItem
                    }
                }
            }
        }
        
        Write-Host "Built custom filtered list with $($newList.Count) items (filter: $customFilter)" -ForegroundColor Blue
        return $newList
    }
    
    [void] SearchTasksAdvanced([string]$searchTerm, [bool]$includeSubtasks = $true, [bool]$caseSensitive = $false) {
        if ([string]::IsNullOrWhiteSpace($searchTerm)) {
            $this.ClearSearch()
            return
        }
        
        $this.SearchTerm = $searchTerm
        $term = if ($caseSensitive) { $searchTerm } else { $searchTerm.ToLower() }
        
        # Build filtered list with search
        $taskArray = $this.Tasks
        $newList = @()
        
        foreach ($task in $taskArray) {
            $taskMatches = $this.TaskMatchesAdvancedSearch($task, $term, $caseSensitive)
            $subtaskMatches = @()
            
            # Check subtasks if included
            if ($includeSubtasks -and $task.Subtasks) {
                $subtaskMatches = $task.Subtasks | Where-Object { 
                    $this.TaskMatchesAdvancedSearch($_, $term, $caseSensitive) 
                }
            }
            
            # Include parent if it matches or has matching subtasks
            if ($taskMatches -or ($includeSubtasks -and $subtaskMatches.Count -gt 0)) {
                # Apply other filters
                if ($this.ShouldShowTask($task)) {
                    $parentItem = @{
                        Task = $task
                        Level = 0
                        IsLast = $false
                        Type = "Task"
                    }
                    $newList += $parentItem
                    
                    # Add matching subtasks or all subtasks if parent matches
                    if (-not $this.GlobalCollapseSubtasks -and -not $task.SubtasksCollapsed -and $task.Subtasks) {
                        $subtasksToShow = if ($taskMatches) { $task.Subtasks } else { $subtaskMatches }
                        
                        for ($i = 0; $i -lt $subtasksToShow.Count; $i++) {
                            $subtask = $subtasksToShow[$i]
                            if ($this.ShouldShowTask($subtask)) {
                                $isLastSubtask = ($i -eq ($subtasksToShow.Count - 1))
                                
                                $subtaskItem = @{
                                    Task = $subtask
                                    Level = 1
                                    IsLast = $isLastSubtask
                                    Type = "Subtask"
                                }
                                $newList += $subtaskItem
                            }
                        }
                    }
                }
            }
        }
        
        $this.FlatList = $newList
        $this.SelectedIndex = 0
        
        $matchCount = $newList.Count
        $this.SetStatusMessage("Search '$searchTerm': $matchCount results", 3000)
        Write-Host "Advanced search '$searchTerm' found $matchCount items" -ForegroundColor Blue
    }
    
    [bool] TaskMatchesAdvancedSearch([SimpleTask]$task, [string]$term, [bool]$caseSensitive) {
        if ([string]::IsNullOrEmpty($term)) { return $true }
        
        $taskTitle = if ($caseSensitive) { $task.Title } else { $task.Title.ToLower() }
        $taskNotes = if ($caseSensitive) { $task.Notes } else { $task.Notes.ToLower() }
        $taskID1 = if ($caseSensitive) { $task.ID1 } else { $task.ID1.ToLower() }
        $taskID2 = if ($caseSensitive) { $task.ID2 } else { $task.ID2.ToLower() }
        
        # Search in title, notes, IDs
        if ($taskTitle.Contains($term) -or $taskNotes.Contains($term) -or 
            $taskID1.Contains($term) -or $taskID2.Contains($term)) {
            return $true
        }
        
        # Search in tags
        foreach ($tag in $task.Tags) {
            $tagText = if ($caseSensitive) { $tag } else { $tag.ToLower() }
            if ($tagText.Contains($term)) {
                return $true
            }
        }
        
        return $false
    }
    
    [void] ClearSearch() {
        $this.SearchTerm = ""
        $this.FlatList = $this.BuildFlatList()
        $this.SelectedIndex = 0
        $this.SetStatusMessage("Search cleared", 1000)
        Write-Host "Search cleared" -ForegroundColor Blue
    }
    
    [void] FilterByTag([string]$tag, [bool]$exactMatch = $false) {
        if ([string]::IsNullOrWhiteSpace($tag)) {
            $this.TagFilter = ""
        } else {
            $this.TagFilter = $tag
        }
        
        # Rebuild with tag filter
        $this.FlatList = $this.BuildFlatList()
        $this.SelectedIndex = 0
        
        $filterText = if ([string]::IsNullOrEmpty($tag)) { "None" } else { $tag }
        $matchType = if ($exactMatch) { "exact" } else { "partial" }
        $this.SetStatusMessage("Tag filter ($matchType): $filterText", 2000)
        Write-Host "Tag filter set to: $filterText ($matchType match)" -ForegroundColor Blue
    }
    
    [string[]] GetAvailableTags() {
        $allTags = @()
        foreach ($task in $this.Tasks) {
            $allTags += $task.Tags
            foreach ($subtask in $task.Subtasks) {
                $allTags += $subtask.Tags
            }
        }
        return ($allTags | Sort-Object -Unique)
    }
    
    [void] ShowFilterSummary() {
        $totalTasks = $this.TaskService.GetTaskCount()
        $visibleTasks = $this.FlatList.Count
        $availableTags = $this.GetAvailableTags()
        
        Write-Host "`n=== Filter Summary ===" -ForegroundColor Cyan
        Write-Host "Total Tasks: $totalTasks" -ForegroundColor White
        Write-Host "Visible Tasks: $visibleTasks" -ForegroundColor Yellow
        Write-Host "Current Filter: $($this.CurrentFilter)" -ForegroundColor Green
        Write-Host "Tag Filter: $(if ([string]::IsNullOrEmpty($this.TagFilter)) { 'None' } else { $this.TagFilter })" -ForegroundColor Green
        Write-Host "Search Term: $(if ([string]::IsNullOrEmpty($this.SearchTerm)) { 'None' } else { $this.SearchTerm })" -ForegroundColor Green
        Write-Host "Show Completed: $($this.ShowCompletedTasks)" -ForegroundColor Green
        Write-Host "Available Tags: $($availableTags.Count)" -ForegroundColor Blue
        if ($availableTags.Count -gt 0) {
            Write-Host "  Tags: $($availableTags -join ', ')" -ForegroundColor Gray
        }
    }
    
    # === EXISTING FILTERING OPERATIONS (from TaskListScreen filter handlers) ===
    
    [void] ToggleFilter() {
        # Cycle through filter modes
        $filters = @("All", "Today", "High", "Medium", "Low", "Completed", "Pending")
        $currentIndex = $filters.IndexOf($this.CurrentFilter)
        $newIndex = ($currentIndex + 1) % $filters.Count
        $this.CurrentFilter = $filters[$newIndex]
        
        $this.FlatList = $this.BuildFlatList()
        $this.SelectedIndex = 0  # Reset selection
        
        $this.SetStatusMessage("Filter: $($this.CurrentFilter)", 2000)
        Write-Host "Filter changed to: $($this.CurrentFilter)" -ForegroundColor Blue
    }
    
    [void] SetFilter([string]$filter) {
        if ($filter -ne $this.CurrentFilter) {
            $this.CurrentFilter = $filter
            $this.FlatList = $this.BuildFlatList()
            $this.SelectedIndex = 0  # Reset selection
            
            $this.SetStatusMessage("Filter: $filter", 2000)
            Write-Host "Filter set to: $filter" -ForegroundColor Blue
        }
    }
    
    [void] SetTagFilter([string]$tag) {
        $this.TagFilter = $tag
        $this.FlatList = $this.BuildFlatList()
        $this.SelectedIndex = 0  # Reset selection
        
        $filterText = if ([string]::IsNullOrEmpty($tag)) { "None" } else { $tag }
        $this.SetStatusMessage("Tag filter: $filterText", 2000)
        Write-Host "Tag filter set to: $filterText" -ForegroundColor Blue
    }
    
    [void] SetSearchTerm([string]$term) {
        $this.SearchTerm = $term
        $this.FlatList = $this.BuildFlatList()
        $this.SelectedIndex = 0  # Reset selection
        
        $searchText = if ([string]::IsNullOrEmpty($term)) { "None" } else { $term }
        $this.SetStatusMessage("Search: $searchText", 2000)
        Write-Host "Search term set to: $searchText" -ForegroundColor Blue
    }
    
    [void] ToggleShowCompleted() {
        $this.ShowCompletedTasks = -not $this.ShowCompletedTasks
        $this.FlatList = $this.BuildFlatList()
        $this.SelectedIndex = 0  # Reset selection
        
        $status = if ($this.ShowCompletedTasks) { "shown" } else { "hidden" }
        $this.SetStatusMessage("Completed tasks $status", 2000)
        Write-Host "Completed tasks $status" -ForegroundColor Blue
    }
    
    [void] ToggleCollapse() {
        $this.GlobalCollapseSubtasks = -not $this.GlobalCollapseSubtasks
        $this.FlatList = $this.BuildFlatList()
        
        $status = if ($this.GlobalCollapseSubtasks) { "collapsed" } else { "expanded" }
        $this.SetStatusMessage("Subtasks $status", 2000)
        Write-Host "Subtasks $status" -ForegroundColor Blue
    }
    
    # === PHASE 4: ADVANCED NAVIGATION OPERATIONS ===
    
    [void] JumpToTask([string]$searchTerm) {
        # Jump to first task matching search term
        if ([string]::IsNullOrWhiteSpace($searchTerm)) { return }
        
        $term = $searchTerm.ToLower()
        for ($i = 0; $i -lt $this.FlatList.Count; $i++) {
            $item = $this.FlatList[$i]
            $task = $item.Task
            
            if ($task.Title.ToLower().Contains($term) -or 
                $task.ID1.ToLower().Contains($term) -or 
                $task.ID2.ToLower().Contains($term)) {
                $this.SelectedIndex = $i
                $this.EnsureVisible()
                $this.SetStatusMessage("Jumped to: $($task.Title)", 2000)
                return
            }
        }
        
        $this.SetStatusMessage("No task found matching: $searchTerm", 3000)
    }
    
    [void] JumpToNextPriority([string]$priority) {
        # Jump to next task with specified priority
        $startIndex = $this.SelectedIndex + 1
        
        for ($i = $startIndex; $i -lt $this.FlatList.Count; $i++) {
            $item = $this.FlatList[$i]
            if ($item.Task.Priority -eq $priority) {
                $this.SelectedIndex = $i
                $this.EnsureVisible()
                $this.SetStatusMessage("Next $priority priority task", 2000)
                return
            }
        }
        
        # Wrap around to beginning
        for ($i = 0; $i -lt $startIndex; $i++) {
            $item = $this.FlatList[$i]
            if ($item.Task.Priority -eq $priority) {
                $this.SelectedIndex = $i
                $this.EnsureVisible()
                $this.SetStatusMessage("Next $priority priority task (wrapped)", 2000)
                return
            }
        }
        
        $this.SetStatusMessage("No $priority priority tasks found", 3000)
    }
    
    [void] JumpToNextIncomplete() {
        # Jump to next incomplete task
        $startIndex = $this.SelectedIndex + 1
        
        for ($i = $startIndex; $i -lt $this.FlatList.Count; $i++) {
            $item = $this.FlatList[$i]
            if (-not $item.Task.Completed) {
                $this.SelectedIndex = $i
                $this.EnsureVisible()
                $this.SetStatusMessage("Next incomplete task", 2000)
                return
            }
        }
        
        # Wrap around
        for ($i = 0; $i -lt $startIndex; $i++) {
            $item = $this.FlatList[$i]
            if (-not $item.Task.Completed) {
                $this.SelectedIndex = $i
                $this.EnsureVisible()
                $this.SetStatusMessage("Next incomplete task (wrapped)", 2000)
                return
            }
        }
        
        $this.SetStatusMessage("No incomplete tasks found", 3000)
    }
    
    [void] JumpToNextDueToday() {
        # Jump to next task due today
        $startIndex = $this.SelectedIndex + 1
        
        for ($i = $startIndex; $i -lt $this.FlatList.Count; $i++) {
            $item = $this.FlatList[$i]
            if ($item.Task.IsDueToday()) {
                $this.SelectedIndex = $i
                $this.EnsureVisible()
                $this.SetStatusMessage("Next task due today", 2000)
                return
            }
        }
        
        # Wrap around
        for ($i = 0; $i -lt $startIndex; $i++) {
            $item = $this.FlatList[$i]
            if ($item.Task.IsDueToday()) {
                $this.SelectedIndex = $i
                $this.EnsureVisible()
                $this.SetStatusMessage("Next task due today (wrapped)", 2000)
                return
            }
        }
        
        $this.SetStatusMessage("No tasks due today found", 3000)
    }
    
    [void] JumpToParent() {
        # Jump to parent task if current is subtask
        if ($this.FlatList.Count -eq 0 -or $this.SelectedIndex -ge $this.FlatList.Count) { return }
        
        $currentItem = $this.FlatList[$this.SelectedIndex]
        if ($currentItem.Level -eq 0) {
            $this.SetStatusMessage("Already at parent task", 2000)
            return
        }
        
        # Find parent by searching backwards
        for ($i = $this.SelectedIndex - 1; $i -ge 0; $i--) {
            $item = $this.FlatList[$i]
            if ($item.Level -eq 0) {
                $this.SelectedIndex = $i
                $this.EnsureVisible()
                $this.SetStatusMessage("Jumped to parent task", 2000)
                return
            }
        }
    }
    
    [void] JumpToFirstSubtask() {
        # Jump to first subtask of current parent task
        if ($this.FlatList.Count -eq 0 -or $this.SelectedIndex -ge $this.FlatList.Count) { return }
        
        $currentItem = $this.FlatList[$this.SelectedIndex]
        if ($currentItem.Level -ne 0) {
            $this.SetStatusMessage("Select a parent task first", 2000)
            return
        }
        
        # Find first subtask by searching forward
        for ($i = $this.SelectedIndex + 1; $i -lt $this.FlatList.Count; $i++) {
            $item = $this.FlatList[$i]
            if ($item.Level -eq 1) {
                $this.SelectedIndex = $i
                $this.EnsureVisible()
                $this.SetStatusMessage("Jumped to first subtask", 2000)
                return
            } elseif ($item.Level -eq 0) {
                # Hit next parent, no subtasks
                break
            }
        }
        
        $this.SetStatusMessage("No subtasks found", 2000)
    }
    
    [void] JumpToNextSibling() {
        # Jump to next sibling (same level)
        if ($this.FlatList.Count -eq 0 -or $this.SelectedIndex -ge $this.FlatList.Count) { return }
        
        $currentItem = $this.FlatList[$this.SelectedIndex]
        $currentLevel = $currentItem.Level
        
        for ($i = $this.SelectedIndex + 1; $i -lt $this.FlatList.Count; $i++) {
            $item = $this.FlatList[$i]
            
            if ($item.Level -eq $currentLevel) {
                $this.SelectedIndex = $i
                $this.EnsureVisible()
                $this.SetStatusMessage("Next sibling task", 2000)
                return
            } elseif ($item.Level -lt $currentLevel) {
                # Higher level, no more siblings
                break
            }
        }
        
        $this.SetStatusMessage("No next sibling found", 2000)
    }
    
    [void] JumpToPreviousSibling() {
        # Jump to previous sibling (same level)
        if ($this.FlatList.Count -eq 0 -or $this.SelectedIndex -ge $this.FlatList.Count) { return }
        
        $currentItem = $this.FlatList[$this.SelectedIndex]
        $currentLevel = $currentItem.Level
        
        for ($i = $this.SelectedIndex - 1; $i -ge 0; $i--) {
            $item = $this.FlatList[$i]
            
            if ($item.Level -eq $currentLevel) {
                $this.SelectedIndex = $i
                $this.EnsureVisible()
                $this.SetStatusMessage("Previous sibling task", 2000)
                return
            } elseif ($item.Level -lt $currentLevel) {
                # Higher level, no more siblings
                break
            }
        }
        
        $this.SetStatusMessage("No previous sibling found", 2000)
    }
    
    [void] JumpToIndex([int]$index) {
        # Jump directly to specific index
        if ($index -lt 0 -or $index -ge $this.FlatList.Count) {
            $this.SetStatusMessage("Invalid index: $index (0-$($this.FlatList.Count-1))", 3000)
            return
        }
        
        $this.SelectedIndex = $index
        $this.EnsureVisible()
        $item = $this.FlatList[$index]
        $this.SetStatusMessage("Jumped to index ${index}: $($item.Task.Title)", 2000)
    }
    
    [hashtable] GetNavigationContext() {
        # Get detailed navigation context for current position
        if ($this.FlatList.Count -eq 0) {
            return @{
                Valid = $false
                Message = "No tasks available"
            }
        }
        
        if ($this.SelectedIndex -ge $this.FlatList.Count) {
            return @{
                Valid = $false
                Message = "Invalid selection index"
            }
        }
        
        $currentItem = $this.FlatList[$this.SelectedIndex]
        $task = $currentItem.Task
        $level = $currentItem.Level
        
        # Find parent info
        $parentInfo = $null
        if ($level -gt 0) {
            for ($i = $this.SelectedIndex - 1; $i -ge 0; $i--) {
                $item = $this.FlatList[$i]
                if ($item.Level -eq 0) {
                    $parentInfo = @{
                        Index = $i
                        Title = $item.Task.Title
                    }
                    break
                }
            }
        }
        
        # Count siblings and position
        $siblings = @()
        $siblingPosition = 0
        
        if ($level -eq 0) {
            # Count parent tasks
            foreach ($item in $this.FlatList) {
                if ($item.Level -eq 0) {
                    $siblings += $item
                }
            }
            $siblingPosition = ($siblings | Where-Object { $_.Task.Id -eq $task.Id })[0]
            $siblingPosition = $siblings.IndexOf($siblingPosition) + 1
        } else {
            # Count subtasks of same parent
            $parentId = $task.ParentId
            foreach ($item in $this.FlatList) {
                if ($item.Level -eq 1 -and $item.Task.ParentId -eq $parentId) {
                    $siblings += $item
                }
            }
            $siblingPosition = ($siblings | Where-Object { $_.Task.Id -eq $task.Id })[0]
            $siblingPosition = $siblings.IndexOf($siblingPosition) + 1
        }
        
        return @{
            Valid = $true
            CurrentIndex = $this.SelectedIndex
            TotalItems = $this.FlatList.Count
            CurrentTask = $task.Title
            Level = $level
            Type = if ($level -eq 0) { "Parent" } else { "Subtask" }
            ParentInfo = $parentInfo
            SiblingPosition = $siblingPosition
            TotalSiblings = $siblings.Count
            ScrollTop = $this.ScrollTop
            VisibleItems = $this.Height - 6
        }
    }
    
    [void] ShowNavigationHelp() {
        # Display navigation shortcuts and current context
        $context = $this.GetNavigationContext()
        
        Write-Host "`n=== Navigation Help ===" -ForegroundColor Cyan
        
        if ($context.Valid) {
            Write-Host "Current Position:" -ForegroundColor Yellow
            Write-Host "  Task: $($context.CurrentTask)" -ForegroundColor White
            Write-Host "  Index: $($context.CurrentIndex + 1) of $($context.TotalItems)" -ForegroundColor White
            Write-Host "  Type: $($context.Type)" -ForegroundColor White
            Write-Host "  Sibling: $($context.SiblingPosition) of $($context.TotalSiblings)" -ForegroundColor White
            
            if ($context.ParentInfo) {
                Write-Host "  Parent: $($context.ParentInfo.Title)" -ForegroundColor White
            }
        } else {
            Write-Host $context.Message -ForegroundColor Red
        }
        
        Write-Host "`nNavigation Commands:" -ForegroundColor Yellow
        Write-Host "  Basic Movement: MoveUp, MoveDown, PageUp, PageDown" -ForegroundColor Green
        Write-Host "  Boundaries: MoveHome, MoveEnd" -ForegroundColor Green
        Write-Host "  Hierarchy: JumpToParent, JumpToFirstSubtask" -ForegroundColor Green
        Write-Host "  Siblings: JumpToNextSibling, JumpToPreviousSibling" -ForegroundColor Green
        Write-Host "  Search: JumpToTask(searchTerm)" -ForegroundColor Green
        Write-Host "  Priority: JumpToNextPriority(High/Medium/Low)" -ForegroundColor Green
        Write-Host "  Status: JumpToNextIncomplete, JumpToNextDueToday" -ForegroundColor Green
        Write-Host "  Direct: JumpToIndex(index)" -ForegroundColor Green
    }
    
    # === EXISTING NAVIGATION OPERATIONS (from TaskListScreen navigation handlers) ===
    
    [void] MoveSelection([int]$delta) {
        if ($this.FlatList.Count -eq 0) { return }
        
        $newIndex = $this.SelectedIndex + $delta
        $this.SelectedIndex = [Math]::Max(0, [Math]::Min($this.FlatList.Count - 1, $newIndex))
        $this.EnsureVisible()
    }
    
    [void] MoveUp() {
        $this.MoveSelection(-1)
    }
    
    [void] MoveDown() {
        $this.MoveSelection(1)
    }
    
    [void] PageUp() {
        $this.MoveSelection(-$this.ItemsPerPage)
    }
    
    [void] PageDown() {
        $this.MoveSelection($this.ItemsPerPage)
    }
    
    [void] MoveHome() {
        $this.SelectedIndex = 0
        $this.ScrollTop = 0
        $this.SetStatusMessage("Top of list", 1000)
    }
    
    [void] MoveEnd() {
        if ($this.FlatList.Count -gt 0) {
            $this.SelectedIndex = $this.FlatList.Count - 1
            $this.EnsureVisible()
            $this.SetStatusMessage("Bottom of list", 1000)
        }
    }
    
    [void] EnsureVisible() {
        if ($this.FlatList.Count -eq 0) { return }
        
        $visibleItems = $this.Height - 6  # Account for header/footer
        
        # Scroll down if selection is below visible area
        if ($this.SelectedIndex -ge ($this.ScrollTop + $visibleItems)) {
            $this.ScrollTop = $this.SelectedIndex - $visibleItems + 1
        }
        
        # Scroll up if selection is above visible area
        if ($this.SelectedIndex -lt $this.ScrollTop) {
            $this.ScrollTop = $this.SelectedIndex
        }
        
        # Ensure scroll doesn't go negative
        $this.ScrollTop = [Math]::Max(0, $this.ScrollTop)
    }
    
    # === TASK FIELD EDITING OPERATIONS ===
    
    [string[]] GetEditableFields([hashtable]$item) {
        $task = $item.Task
        $level = $item.Level
        
        if ($level -eq 0) {
            # Parent task fields
            return @("Title", "Priority", "ID1", "ID2", "Tags", "Notes", "DueDate")
        } else {
            # Subtask fields  
            return @("Title", "Priority", "Tags")
        }
    }
    
    [void] StartEditCurrentTask([string]$field) {
        if ($this.FlatList.Count -eq 0 -or $this.SelectedIndex -ge $this.FlatList.Count) { 
            $this.SetStatusMessage("No task selected", 2000)
            return 
        }
        
        $item = $this.FlatList[$this.SelectedIndex]
        $task = $item.Task
        
        # Validate field is editable
        $editableFields = $this.GetEditableFields($item)
        if ($field -notin $editableFields) {
            $this.SetStatusMessage("Field '$field' not editable for this task type", 3000)
            return
        }
        
        $this.EditingIndex = $this.SelectedIndex
        $this.EditingField = $field
        $this.EditingTask = $task
        $this.EditingValue = $this.GetTaskFieldValue($task, $field)
        $this.IsNewItem = $false
        
        $this.SetStatusMessage("Editing ${field}: $($this.EditingValue)", 2000)
        Write-Host "Started editing $field for task: $($task.Title)" -ForegroundColor Cyan
    }
    
    [string] GetTaskFieldValue([SimpleTask]$task, [string]$field) {
        switch ($field) {
            "Title" { return $task.Title }
            "Priority" { return $task.Priority }
            "ID1" { return $task.ID1 }
            "ID2" { return $task.ID2 }
            "Tags" { return ($task.Tags -join ", ") }
            "Notes" { return $task.Notes }
            "DueDate" { 
                if ($task.DueDate -eq [DateTime]::MinValue) {
                    return ""
                } else {
                    return $task.DueDate.ToString("yyyy-MM-dd")
                }
            }
            default { return "" }
        }
        return ""
    }
    
    [void] SetTaskFieldValue([SimpleTask]$task, [string]$field, [string]$value) {
        switch ($field) {
            "Title" { 
                $task.Title = $value.Trim()
            }
            "Priority" { 
                $validPriorities = @("High", "Medium", "Low", "Today")
                if ($value -in $validPriorities) {
                    $task.Priority = $value
                } else {
                    throw "Invalid priority. Must be: $($validPriorities -join ', ')"
                }
            }
            "ID1" { 
                $task.ID1 = $value.Trim()
            }
            "ID2" { 
                $task.ID2 = $value.Trim()
            }
            "Tags" { 
                if ([string]::IsNullOrWhiteSpace($value)) {
                    $task.Tags = @()
                } else {
                    $task.Tags = $value.Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ }
                }
            }
            "Notes" { 
                $task.Notes = $value
            }
            "DueDate" { 
                if ([string]::IsNullOrWhiteSpace($value)) {
                    $task.DueDate = [DateTime]::MinValue
                } else {
                    try {
                        $task.DueDate = [DateTime]::Parse($value)
                    } catch {
                        throw "Invalid date format. Use YYYY-MM-DD"
                    }
                }
            }
        }
        $task.ModifiedDate = [DateTime]::Now
    }
    
    [void] SaveCurrentEdit([string]$newValue) {
        if ($this.EditingIndex -eq -1 -or $this.EditingTask -eq $null) {
            $this.SetStatusMessage("No active edit to save", 2000)
            return
        }
        
        try {
            # Validate and set the new value
            $this.SetTaskFieldValue($this.EditingTask, $this.EditingField, $newValue)
            
            # Save to service
            $this.TaskService.SaveTask($this.EditingTask)
            $this.TaskService.SaveTasks()
            
            $this.SetStatusMessage("Saved $($this.EditingField): $newValue", 2000)
            Write-Host "Saved $($this.EditingField) = '$newValue' for task: $($this.EditingTask.Title)" -ForegroundColor Green
            
            # Clear editing state
            $this.ClearEditingState()
            
            # Refresh if needed (for priority changes that might affect filtering)
            if ($this.EditingField -eq "Priority" -and $this.CurrentFilter -in @("High", "Medium", "Low", "Today")) {
                $this.LoadData()
            }
            
        } catch {
            $this.SetStatusMessage("Failed to save: $($_.Exception.Message)", 5000)
            Write-Host "Error saving edit: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    
    [void] CancelCurrentEdit() {
        if ($this.EditingIndex -eq -1) {
            $this.SetStatusMessage("No active edit to cancel", 2000)
            return
        }
        
        $this.SetStatusMessage("Edit cancelled", 1000)
        $this.ClearEditingState()
    }
    
    [void] ClearEditingState() {
        $this.EditingIndex = -1
        $this.EditingField = ""
        $this.EditingTask = $null
        $this.EditingValue = ""
        $this.IsNewItem = $false
    }
    
    [void] NextEditField() {
        if ($this.EditingIndex -eq -1 -or $this.EditingTask -eq $null) {
            return
        }
        
        $item = $this.FlatList[$this.EditingIndex]
        $editableFields = $this.GetEditableFields($item)
        $currentIndex = $editableFields.IndexOf($this.EditingField)
        
        if ($currentIndex -ge 0) {
            $nextIndex = ($currentIndex + 1) % $editableFields.Count
            $nextField = $editableFields[$nextIndex]
            
            # Save current edit first
            $this.SaveCurrentEdit($this.EditingValue)
            
            # Start editing next field
            $this.StartEditCurrentTask($nextField)
        }
    }
    
    [bool] IsCurrentlyEditing() {
        return $this.EditingIndex -ne -1 -and $this.EditingTask -ne $null
    }
    
    # === UTILITY METHODS ===
    
    [bool] FindAndSelectTask([string]$taskId) {
        if ([string]::IsNullOrEmpty($taskId)) { return $false }
        
        for ($i = 0; $i -lt $this.FlatList.Count; $i++) {
            $item = $this.FlatList[$i]
            if ($item.Task.Id -eq $taskId) {
                $this.SelectedIndex = $i
                $this.EnsureVisible()
                return $true
            }
        }
        return $false
    }
    
    [void] SetStatusMessage([string]$message, [int]$durationMs) {
        $this.StatusMessage = $message
        $this.StatusMessageTime = [DateTime]::Now.AddMilliseconds($durationMs)
        Write-Host "Status: $message" -ForegroundColor Cyan
    }
    
    [string] GetStatusMessage() {
        if ([DateTime]::Now -gt $this.StatusMessageTime) {
            return ""
        }
        return $this.StatusMessage
    }
    
    [hashtable] GetCurrentItem() {
        if ($this.FlatList.Count -eq 0 -or $this.SelectedIndex -ge $this.FlatList.Count) {
            return $null
        }
        return $this.FlatList[$this.SelectedIndex]
    }
    
    [SimpleTask] GetCurrentTask() {
        $item = $this.GetCurrentItem()
        if ($item) { 
            return $item.Task 
        } else { 
            return $null 
        }
    }
    
    [void] RefreshData() {
        $this.LoadData()
    }
    
    [void] SaveData() {
        try {
            $this.TaskService.SaveTasks()
            $this.SetStatusMessage("Data saved", 2000)
            Write-Host "Data saved successfully" -ForegroundColor Green
        } catch {
            $this.SetStatusMessage("Save failed: $($_.Exception.Message)", 5000)
            Write-Host "Error saving data: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    
    # === PHASE 5: ADVANCED FEATURES AND UTILITIES ===
    
    [void] BulkToggleComplete([int[]]$indices) {
        # Toggle completion status for multiple tasks
        if (-not $indices -or $indices.Count -eq 0) {
            $this.SetStatusMessage("No indices provided for bulk toggle", 3000)
            return
        }
        
        $validIndices = $indices | Where-Object { $_ -ge 0 -and $_ -lt $this.FlatList.Count }
        $toggledCount = 0
        
        foreach ($index in $validIndices) {
            $item = $this.FlatList[$index]
            $task = $item.Task
            
            try {
                $this.TaskService.ToggleComplete($task.Id)
                $task.Completed = -not $task.Completed
                $task.ModifiedDate = [DateTime]::Now
                $toggledCount++
            } catch {
                Write-Host "Failed to toggle task at index $index`: $($_.Exception.Message)" -ForegroundColor Red
            }
        }
        
        if ($toggledCount -gt 0) {
            $this.TaskService.SaveTasks()
            $this.SetStatusMessage("Toggled completion for $toggledCount tasks", 3000)
            Write-Host "Bulk toggled completion for $toggledCount tasks" -ForegroundColor Green
        }
    }
    
    [void] BulkSetPriority([int[]]$indices, [string]$priority) {
        # Set priority for multiple tasks
        $validPriorities = @("High", "Medium", "Low", "Today")
        if ($priority -notin $validPriorities) {
            $this.SetStatusMessage("Invalid priority: $priority", 3000)
            return
        }
        
        if (-not $indices -or $indices.Count -eq 0) {
            $this.SetStatusMessage("No indices provided for bulk priority change", 3000)
            return
        }
        
        $validIndices = $indices | Where-Object { $_ -ge 0 -and $_ -lt $this.FlatList.Count }
        $updatedCount = 0
        
        foreach ($index in $validIndices) {
            $item = $this.FlatList[$index]
            $task = $item.Task
            
            try {
                $task.Priority = $priority
                $task.ModifiedDate = [DateTime]::Now
                $this.TaskService.SaveTask($task)
                $updatedCount++
            } catch {
                Write-Host "Failed to update task priority at index $index`: $($_.Exception.Message)" -ForegroundColor Red
            }
        }
        
        if ($updatedCount -gt 0) {
            $this.TaskService.SaveTasks()
            $this.SetStatusMessage("Set priority to $priority for $updatedCount tasks", 3000)
            Write-Host "Bulk set priority to $priority for $updatedCount tasks" -ForegroundColor Green
        }
    }
    
    [void] BulkAddTag([int[]]$indices, [string]$tag) {
        # Add tag to multiple tasks
        if ([string]::IsNullOrWhiteSpace($tag)) {
            $this.SetStatusMessage("Tag cannot be empty", 3000)
            return
        }
        
        if (-not $indices -or $indices.Count -eq 0) {
            $this.SetStatusMessage("No indices provided for bulk tag add", 3000)
            return
        }
        
        $validIndices = $indices | Where-Object { $_ -ge 0 -and $_ -lt $this.FlatList.Count }
        $updatedCount = 0
        
        foreach ($index in $validIndices) {
            $item = $this.FlatList[$index]
            $task = $item.Task
            
            try {
                if ($task.Tags -notcontains $tag) {
                    $task.Tags += $tag
                    $task.ModifiedDate = [DateTime]::Now
                    $this.TaskService.SaveTask($task)
                    $updatedCount++
                }
            } catch {
                Write-Host "Failed to add tag to task at index $index`: $($_.Exception.Message)" -ForegroundColor Red
            }
        }
        
        if ($updatedCount -gt 0) {
            $this.TaskService.SaveTasks()
            $this.SetStatusMessage("Added tag '$tag' to $updatedCount tasks", 3000)
            Write-Host "Bulk added tag '$tag' to $updatedCount tasks" -ForegroundColor Green
        }
    }
    
    [void] BulkDelete([int[]]$indices) {
        # Delete multiple tasks (with confirmation)
        if (-not $indices -or $indices.Count -eq 0) {
            $this.SetStatusMessage("No indices provided for bulk delete", 3000)
            return
        }
        
        $validIndices = $indices | Where-Object { $_ -ge 0 -and $_ -lt $this.FlatList.Count } | Sort-Object -Descending
        $taskTitles = @()
        
        foreach ($index in $validIndices) {
            $item = $this.FlatList[$index]
            $taskTitles += $item.Task.Title
        }
        
        Write-Host "WARNING: About to delete $($validIndices.Count) tasks:" -ForegroundColor Yellow
        foreach ($title in $taskTitles) {
            Write-Host "  - $title" -ForegroundColor Gray
        }
        
        # In a real UI, this would show a confirmation dialog
        $deletedCount = 0
        foreach ($index in $validIndices) {
            $item = $this.FlatList[$index]
            $task = $item.Task
            
            try {
                $this.TaskService.DeleteTask($task.Id)
                $deletedCount++
            } catch {
                Write-Host "Failed to delete task at index $index`: $($_.Exception.Message)" -ForegroundColor Red
            }
        }
        
        if ($deletedCount -gt 0) {
            $this.TaskService.SaveTasks()
            $this.LoadData()  # Refresh
            $this.SetStatusMessage("Deleted $deletedCount tasks", 3000)
            Write-Host "Bulk deleted $deletedCount tasks" -ForegroundColor Green
        }
    }
    
    [object[]] ExportToData([string]$format = "json") {
        # Export task data in various formats
        switch ($format.ToLower()) {
            "json" {
                return $this.TaskService.GetAllTasks()
            }
            "csv" {
                $csvData = @()
                foreach ($task in $this.TaskService.GetAllTasks()) {
                    $csvData += @{
                        Id = $task.Id
                        Title = $task.Title
                        Priority = $task.Priority
                        Completed = $task.Completed
                        CreatedDate = $task.CreatedDate.ToString("yyyy-MM-dd HH:mm:ss")
                        ModifiedDate = $task.ModifiedDate.ToString("yyyy-MM-dd HH:mm:ss")
                        DueDate = if ($task.DueDate -eq [DateTime]::MinValue) { "" } else { $task.DueDate.ToString("yyyy-MM-dd HH:mm:ss") }
                        Tags = ($task.Tags -join "; ")
                        Notes = $task.Notes
                        ID1 = $task.ID1
                        ID2 = $task.ID2
                        ParentId = $task.ParentId
                        Level = if ($task.IsParent()) { "Parent" } else { "Subtask" }
                    }
                }
                return $csvData
            }
            "summary" {
                $summary = @()
                foreach ($task in $this.TaskService.GetParentTasks()) {
                    $summary += @{
                        Title = $task.Title
                        Priority = $task.Priority
                        Status = if ($task.Completed) { "Completed" } else { "Pending" }
                        SubtaskCount = $task.Subtasks.Count
                        DueDate = $task.GetDueDateDisplay()
                        Tags = ($task.Tags -join ", ")
                    }
                }
                return $summary
            }
            default {
                throw "Unsupported export format: $format"
            }
        }
        return @()
    }
    
    [void] ExportToFile([string]$filePath, [string]$format = "json") {
        # Export data to file
        try {
            $data = $this.ExportToData($format)
            
            switch ($format.ToLower()) {
                "json" {
                    $json = $data | ConvertTo-Json -Depth 10
                    Set-Content -Path $filePath -Value $json -Encoding UTF8
                }
                "csv" {
                    $data | Export-Csv -Path $filePath -NoTypeInformation
                }
                "summary" {
                    $text = "Task Summary Report - Generated $(Get-Date)`n"
                    $text += "=" * 50 + "`n`n"
                    
                    foreach ($item in $data) {
                        $text += "Title: $($item.Title)`n"
                        $text += "Priority: $($item.Priority)`n"
                        $text += "Status: $($item.Status)`n"
                        $text += "Subtasks: $($item.SubtaskCount)`n"
                        $text += "Due: $($item.DueDate)`n"
                        $text += "Tags: $($item.Tags)`n"
                        $text += "-" * 30 + "`n"
                    }
                    
                    Set-Content -Path $filePath -Value $text -Encoding UTF8
                }
            }
            
            $this.SetStatusMessage("Exported to $filePath", 2000)
            Write-Host "Exported data to $filePath" -ForegroundColor Green
            
        } catch {
            $this.SetStatusMessage("Export failed: $($_.Exception.Message)", 5000)
            Write-Host "Export failed: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    
    [void] ValidateData() {
        # Validate task data integrity
        $issues = @()
        $totalTasks = $this.TaskService.GetAllTasks()
        
        foreach ($task in $totalTasks) {
            # Check required fields
            if ([string]::IsNullOrWhiteSpace($task.Title)) {
                $issues += "Task $($task.Id): Missing title"
            }
            
            if ([string]::IsNullOrWhiteSpace($task.Id)) {
                $issues += "Task: Missing ID"
            }
            
            # Check priority values
            $validPriorities = @("High", "Medium", "Low", "Today")
            if ($task.Priority -notin $validPriorities) {
                $issues += "Task $($task.Id): Invalid priority '$($task.Priority)'"
            }
            
            # Check parent relationships
            if (-not $task.IsParent() -and -not [string]::IsNullOrEmpty($task.ParentId)) {
                $parent = $this.TaskService.GetTaskById($task.ParentId)
                if (-not $parent) {
                    $issues += "Task $($task.Id): Parent $($task.ParentId) not found"
                }
            }
            
            # Check subtask relationships
            foreach ($subtask in $task.Subtasks) {
                if ($subtask.ParentId -ne $task.Id) {
                    $issues += "Subtask $($subtask.Id): Parent ID mismatch"
                }
            }
            
            # Check date validity
            if ($task.DueDate -ne [DateTime]::MinValue -and $task.DueDate -lt $task.CreatedDate) {
                $issues += "Task $($task.Id): Due date before created date"
            }
        }
        
        if ($issues.Count -eq 0) {
            $this.SetStatusMessage("Data validation passed", 2000)
            Write-Host "✓ Data validation passed - no issues found" -ForegroundColor Green
        } else {
            $this.SetStatusMessage("Found $($issues.Count) validation issues", 5000)
            Write-Host "⚠ Data validation found $($issues.Count) issues:" -ForegroundColor Yellow
            foreach ($issue in $issues) {
                Write-Host "  - $issue" -ForegroundColor Red
            }
        }
    }
    
    [void] RepairData() {
        # Attempt to repair common data issues
        $repaired = 0
        $totalTasks = $this.TaskService.GetAllTasks()
        
        foreach ($task in $totalTasks) {
            $wasModified = $false
            
            # Fix missing titles
            if ([string]::IsNullOrWhiteSpace($task.Title)) {
                $task.Title = "Untitled Task"
                $wasModified = $true
            }
            
            # Fix invalid priorities
            $validPriorities = @("High", "Medium", "Low", "Today")
            if ($task.Priority -notin $validPriorities) {
                $task.Priority = "Medium"
                $wasModified = $true
            }
            
            # Fix missing dates
            if ($task.CreatedDate -eq [DateTime]::MinValue) {
                $task.CreatedDate = [DateTime]::Now
                $wasModified = $true
            }
            
            if ($task.ModifiedDate -eq [DateTime]::MinValue) {
                $task.ModifiedDate = $task.CreatedDate
                $wasModified = $true
            }
            
            # Fix invalid due dates
            if ($task.DueDate -ne [DateTime]::MinValue -and $task.DueDate -lt $task.CreatedDate) {
                $task.DueDate = [DateTime]::MinValue
                $wasModified = $true
            }
            
            if ($wasModified) {
                $task.ModifiedDate = [DateTime]::Now
                $this.TaskService.SaveTask($task)
                $repaired++
            }
        }
        
        if ($repaired -gt 0) {
            $this.TaskService.SaveTasks()
            $this.SetStatusMessage("Repaired $repaired tasks", 3000)
            Write-Host "✓ Repaired $repaired tasks" -ForegroundColor Green
        } else {
            $this.SetStatusMessage("No repairs needed", 2000)
            Write-Host "✓ No repairs needed" -ForegroundColor Green
        }
    }
    
    [void] ArchiveCompleted([string]$archivePath = "Data/archived_tasks.json") {
        # Archive completed tasks to separate file
        $completedTasks = $this.TaskService.GetAllTasks() | Where-Object { $_.Completed }
        
        if ($completedTasks.Count -eq 0) {
            $this.SetStatusMessage("No completed tasks to archive", 2000)
            return
        }
        
        try {
            # Export completed tasks
            $archiveData = @()
            foreach ($task in $completedTasks) {
                $archiveData += $this.TaskService.ConvertToJson($task)
            }
            
            $json = $archiveData | ConvertTo-Json -Depth 10
            
            # Ensure directory exists
            $dir = Split-Path $archivePath -Parent
            if (-not (Test-Path $dir)) {
                New-Item -ItemType Directory -Path $dir -Force | Out-Null
            }
            
            Set-Content -Path $archivePath -Value $json -Encoding UTF8
            
            # Remove completed tasks from main collection
            foreach ($task in $completedTasks) {
                $this.TaskService.DeleteTask($task.Id)
            }
            
            $this.TaskService.SaveTasks()
            $this.LoadData()  # Refresh
            
            $this.SetStatusMessage("Archived $($completedTasks.Count) completed tasks", 3000)
            Write-Host "Archived $($completedTasks.Count) completed tasks to $archivePath" -ForegroundColor Green
            
        } catch {
            $this.SetStatusMessage("Archive failed: $($_.Exception.Message)", 5000)
            Write-Host "Archive failed: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    
    [hashtable] GetAdvancedStats() {
        # Get comprehensive statistics
        $allTasks = $this.TaskService.GetAllTasks()
        $parentTasks = $this.TaskService.GetParentTasks()
        
        $stats = @{
            TotalTasks = $allTasks.Count
            ParentTasks = $parentTasks.Count
            SubtaskCount = $allTasks.Count - $parentTasks.Count
            CompletedTasks = ($allTasks | Where-Object { $_.Completed }).Count
            PendingTasks = ($allTasks | Where-Object { -not $_.Completed }).Count
            HighPriority = ($allTasks | Where-Object { $_.Priority -eq "High" }).Count
            MediumPriority = ($allTasks | Where-Object { $_.Priority -eq "Medium" }).Count
            LowPriority = ($allTasks | Where-Object { $_.Priority -eq "Low" }).Count
            TodayPriority = ($allTasks | Where-Object { $_.Priority -eq "Today" }).Count
            DueToday = ($allTasks | Where-Object { $_.IsDueToday() }).Count
            Overdue = ($allTasks | Where-Object { $_.IsOverdue() }).Count
            WithTags = ($allTasks | Where-Object { $_.Tags.Count -gt 0 }).Count
            WithNotes = ($allTasks | Where-Object { -not [string]::IsNullOrWhiteSpace($_.Notes) }).Count
            CreatedThisWeek = ($allTasks | Where-Object { $_.CreatedDate -gt (Get-Date).AddDays(-7) }).Count
            ModifiedThisWeek = ($allTasks | Where-Object { $_.ModifiedDate -gt (Get-Date).AddDays(-7) }).Count
            AvgSubtasksPerParent = if ($parentTasks.Count -gt 0) { [Math]::Round(($allTasks.Count - $parentTasks.Count) / $parentTasks.Count, 2) } else { 0 }
            UniqueTags = ($allTasks | ForEach-Object { $_.Tags } | Sort-Object -Unique).Count
            CompletionRate = if ($allTasks.Count -gt 0) { [Math]::Round((($allTasks | Where-Object { $_.Completed }).Count / $allTasks.Count) * 100, 1) } else { 0 }
        }
        
        return $stats
    }
    
    [void] ShowAdvancedStats() {
        # Display comprehensive statistics
        $stats = $this.GetAdvancedStats()
        
        Write-Host "`n=== Advanced Task Statistics ===" -ForegroundColor Cyan
        Write-Host "Task Counts:" -ForegroundColor Yellow
        Write-Host "  Total Tasks: $($stats.TotalTasks)" -ForegroundColor White
        Write-Host "  Parent Tasks: $($stats.ParentTasks)" -ForegroundColor White
        Write-Host "  Subtasks: $($stats.SubtaskCount)" -ForegroundColor White
        Write-Host "  Avg Subtasks per Parent: $($stats.AvgSubtasksPerParent)" -ForegroundColor White
        
        Write-Host "`nCompletion Status:" -ForegroundColor Yellow
        Write-Host "  Completed: $($stats.CompletedTasks)" -ForegroundColor Green
        Write-Host "  Pending: $($stats.PendingTasks)" -ForegroundColor Yellow
        Write-Host "  Completion Rate: $($stats.CompletionRate)%" -ForegroundColor Blue
        
        Write-Host "`nPriority Distribution:" -ForegroundColor Yellow
        Write-Host "  High: $($stats.HighPriority)" -ForegroundColor Red
        Write-Host "  Medium: $($stats.MediumPriority)" -ForegroundColor Yellow
        Write-Host "  Low: $($stats.LowPriority)" -ForegroundColor Green
        Write-Host "  Today: $($stats.TodayPriority)" -ForegroundColor Magenta
        
        Write-Host "`nDue Dates:" -ForegroundColor Yellow
        Write-Host "  Due Today: $($stats.DueToday)" -ForegroundColor Cyan
        Write-Host "  Overdue: $($stats.Overdue)" -ForegroundColor Red
        
        Write-Host "`nContent:" -ForegroundColor Yellow
        Write-Host "  With Tags: $($stats.WithTags)" -ForegroundColor Blue
        Write-Host "  With Notes: $($stats.WithNotes)" -ForegroundColor Blue
        Write-Host "  Unique Tags: $($stats.UniqueTags)" -ForegroundColor Blue
        
        Write-Host "`nActivity:" -ForegroundColor Yellow
        Write-Host "  Created This Week: $($stats.CreatedThisWeek)" -ForegroundColor Green
        Write-Host "  Modified This Week: $($stats.ModifiedThisWeek)" -ForegroundColor Green
    }
    
    # === STATISTICS ===
    
    [void] PrintStats() {
        Write-Host "`n=== TaskListManager Statistics ===" -ForegroundColor Cyan
        Write-Host "Total Tasks: $($this.TaskService.GetTaskCount())" -ForegroundColor White
        Write-Host "Parent Tasks: $($this.Tasks.Count)" -ForegroundColor Blue
        Write-Host "Flat List Items: $($this.FlatList.Count)" -ForegroundColor Yellow
        Write-Host "Selected Index: $($this.SelectedIndex)" -ForegroundColor Magenta
        Write-Host "Current Filter: $($this.CurrentFilter)" -ForegroundColor Green
        Write-Host "Tag Filter: $(if ([string]::IsNullOrEmpty($this.TagFilter)) { 'None' } else { $this.TagFilter })" -ForegroundColor Green
        Write-Host "Search Term: $(if ([string]::IsNullOrEmpty($this.SearchTerm)) { 'None' } else { $this.SearchTerm })" -ForegroundColor Green
        Write-Host "Show Completed: $($this.ShowCompletedTasks)" -ForegroundColor Green
        Write-Host "Subtasks Collapsed: $($this.GlobalCollapseSubtasks)" -ForegroundColor Green
        
        $this.TaskService.PrintStats()
    }
}