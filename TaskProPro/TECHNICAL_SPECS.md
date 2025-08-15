# TaskProPro Technical Specifications

## Implementation Blueprint for C# Task Management Components

This document provides the concrete technical specifications needed to implement TaskProPro, bridging between the high-level design and actual code implementation.

---

## Data Models

### Core Task Model
```csharp
namespace TaskPro.Data {
    public class SimpleTask {
        // Core Properties
        public string Id { get; set; } = Guid.NewGuid().ToString();
        public string Title { get; set; } = "";
        public string Notes { get; set; } = "";
        public bool Completed { get; set; } = false;
        
        // Metadata
        public DateTime CreatedDate { get; set; } = DateTime.Now;
        public DateTime ModifiedDate { get; set; } = DateTime.Now;
        public DateTime DueDate { get; set; } = DateTime.MinValue;
        
        // Organization
        public Priority Priority { get; set; } = Priority.Medium;
        public List<string> Tags { get; set; } = new List<string>();
        public string ColorTheme { get; set; } = "default";
        
        // Hierarchy
        public string ParentId { get; set; } = "";
        public List<SimpleTask> Subtasks { get; set; } = new List<SimpleTask>();
        public bool SubtasksCollapsed { get; set; } = false;
        public int SortOrder { get; set; } = 0;
        
        // Project Integration
        public string ID1 { get; set; } = "";  // Project code
        public string ID2 { get; set; } = "";  // Secondary project code
        
        // Business Logic Methods
        public bool IsParent() => string.IsNullOrEmpty(ParentId);
        public bool IsSubtask() => !string.IsNullOrEmpty(ParentId);
        public bool HasSubtasks() => Subtasks.Any();
        public void Touch() => ModifiedDate = DateTime.Now;
    }
    
    public enum Priority {
        Today = 0,    // Highest priority - gold color
        High = 1,     // Red color
        Medium = 2,   // Orange color  
        Low = 3       // Green color
    }
}
```

### UI Models
```csharp
namespace TaskPro.UI {
    public class TaskListItem {
        public SimpleTask Task { get; set; }
        public int Level { get; set; }           // 0 = parent, 1 = subtask
        public bool IsLast { get; set; }         // For tree drawing
        public bool IsExpanded { get; set; }     // For hierarchical display
        public bool HasChildren { get; set; }    // Performance optimization
        public SimpleTask ParentTask { get; set; } // Quick access to parent
    }
    
    public class FilterCriteria {
        public Priority Priority { get; set; } = Priority.Medium;  // All priorities if null
        public string TagFilter { get; set; } = "";               // Empty = no tag filter
        public string SearchText { get; set; } = "";              // Empty = no search
        public bool ShowOnlyToday { get; set; } = false;          // Today filter
        public bool ShowCompleted { get; set; } = true;           // Include completed tasks
        
        public string GetDisplayText() {
            var parts = new List<string>();
            if (Priority != Priority.Medium) parts.Add(Priority.ToString());
            if (!string.IsNullOrEmpty(TagFilter)) parts.Add($"#{TagFilter}");
            if (!string.IsNullOrEmpty(SearchText)) parts.Add($"\"{SearchText}\"");
            if (ShowOnlyToday) parts.Add("Today");
            return parts.Any() ? string.Join(" ", parts) : "All";
        }
    }
    
    public struct Rectangle {
        public int X { get; set; }
        public int Y { get; set; }
        public int Width { get; set; }
        public int Height { get; set; }
        
        public int Right => X + Width;
        public int Bottom => Y + Height;
        
        public Rectangle(int x, int y, int width, int height) {
            X = x; Y = y; Width = width; Height = height;
        }
    }
}
```

---

## Core Data Management

### TaskManager.cs - Core CRUD Operations
```csharp
namespace TaskPro.Data {
    public class TaskManager {
        private TaskPersistence persistence;
        private TaskFilter filter;
        private List<SimpleTask> allTasks;
        
        // Constructor
        public TaskManager(string dataFilePath) {
            persistence = new TaskPersistence(dataFilePath);
            filter = new TaskFilter();
            LoadFromDisk();
        }
        
        // Core Data Operations
        public List<SimpleTask> GetAllTasks() => allTasks.ToList();
        public List<SimpleTask> GetParentTasks() => allTasks.Where(t => t.IsParent()).ToList();
        public SimpleTask GetTask(string id) => allTasks.FirstOrDefault(t => t.Id == id);
        public SimpleTask GetParentTask(string childId) {
            var child = GetTask(childId);
            return child?.IsSubtask() == true ? GetTask(child.ParentId) : null;
        }
        
        // CRUD Operations
        public void AddTask(SimpleTask task) {
            task.Touch();
            allTasks.Add(task);
            SaveToDisk();
        }
        
        public void UpdateTask(SimpleTask task) {
            task.Touch();
            var index = allTasks.FindIndex(t => t.Id == task.Id);
            if (index >= 0) {
                allTasks[index] = task;
                SaveToDisk();
            }
        }
        
        public void DeleteTask(string id) {
            // Delete task and all its subtasks
            var task = GetTask(id);
            if (task != null) {
                if (task.IsParent()) {
                    // Delete all subtasks first
                    var subtasksToDelete = allTasks.Where(t => t.ParentId == id).ToList();
                    foreach (var subtask in subtasksToDelete) {
                        allTasks.Remove(subtask);
                    }
                }
                allTasks.Remove(task);
                SaveToDisk();
            }
        }
        
        public void ToggleComplete(string id) {
            var task = GetTask(id);
            if (task != null) {
                task.Completed = !task.Completed;
                task.Touch();
                SaveToDisk();
            }
        }
        
        // Task Movement
        public void MoveTaskUp(string id) {
            var task = GetTask(id);
            if (task?.IsParent() == true) {
                var parentTasks = GetParentTasks().OrderBy(t => t.SortOrder).ToList();
                var currentIndex = parentTasks.FindIndex(t => t.Id == id);
                if (currentIndex > 0) {
                    // Swap sort orders
                    var temp = parentTasks[currentIndex - 1].SortOrder;
                    parentTasks[currentIndex - 1].SortOrder = task.SortOrder;
                    task.SortOrder = temp;
                    SaveToDisk();
                }
            }
        }
        
        public void MoveTaskDown(string id) {
            var task = GetTask(id);
            if (task?.IsParent() == true) {
                var parentTasks = GetParentTasks().OrderBy(t => t.SortOrder).ToList();
                var currentIndex = parentTasks.FindIndex(t => t.Id == id);
                if (currentIndex < parentTasks.Count - 1) {
                    // Swap sort orders
                    var temp = parentTasks[currentIndex + 1].SortOrder;
                    parentTasks[currentIndex + 1].SortOrder = task.SortOrder;
                    task.SortOrder = temp;
                    SaveToDisk();
                }
            }
        }
        
        // Filtering
        public List<SimpleTask> ApplyFilter(FilterCriteria criteria) {
            return filter.ApplyFilters(GetParentTasks(), criteria);
        }
        
        public List<TaskListItem> BuildFlatList(List<SimpleTask> tasks, bool globalCollapseSubtasks) {
            var flatList = new List<TaskListItem>();
            
            foreach (var task in tasks.OrderBy(t => t.SortOrder)) {
                // Add parent task
                flatList.Add(new TaskListItem {
                    Task = task,
                    Level = 0,
                    IsExpanded = !task.SubtasksCollapsed && !globalCollapseSubtasks,
                    HasChildren = task.HasSubtasks(),
                    ParentTask = null
                });
                
                // Add subtasks if expanded
                if (!task.SubtasksCollapsed && !globalCollapseSubtasks) {
                    var subtasks = task.Subtasks.OrderBy(st => st.SortOrder);
                    foreach (var subtask in subtasks) {
                        flatList.Add(new TaskListItem {
                            Task = subtask,
                            Level = 1,
                            IsExpanded = false,
                            HasChildren = false,
                            ParentTask = task
                        });
                    }
                }
            }
            
            return flatList;
        }
        
        // Persistence
        private void LoadFromDisk() {
            allTasks = persistence.LoadTasks();
        }
        
        private void SaveToDisk() {
            persistence.SaveTasks(allTasks);
        }
    }
}
```

### TaskPersistence.cs - Data Persistence
```csharp
namespace TaskPro.Data {
    public class TaskPersistence {
        private string filePath;
        private string backupDirectory;
        
        public TaskPersistence(string dataFilePath) {
            filePath = dataFilePath;
            backupDirectory = Path.Combine(Path.GetDirectoryName(filePath), "backups");
            Directory.CreateDirectory(backupDirectory);
        }
        
        public List<SimpleTask> LoadTasks() {
            try {
                if (!File.Exists(filePath)) {
                    return new List<SimpleTask>();
                }
                
                var json = File.ReadAllText(filePath);
                var tasks = JsonSerializer.Deserialize<List<SimpleTask>>(json, GetJsonOptions());
                return tasks ?? new List<SimpleTask>();
            }
            catch (Exception ex) {
                // Try to load from most recent backup
                var backups = GetBackupFiles().OrderByDescending(f => f.CreationTime).ToList();
                foreach (var backup in backups.Take(3)) {
                    try {
                        var json = File.ReadAllText(backup.FullName);
                        var tasks = JsonSerializer.Deserialize<List<SimpleTask>>(json, GetJsonOptions());
                        return tasks ?? new List<SimpleTask>();
                    }
                    catch {
                        continue; // Try next backup
                    }
                }
                
                throw new InvalidOperationException($"Could not load tasks from {filePath} or any backup: {ex.Message}");
            }
        }
        
        public void SaveTasks(List<SimpleTask> tasks) {
            try {
                // Create backup before saving
                CreateBackup();
                
                var json = JsonSerializer.Serialize(tasks, GetJsonOptions());
                
                // Atomic save using temp file
                var tempFile = filePath + ".tmp";
                File.WriteAllText(tempFile, json);
                File.Move(tempFile, filePath, true);
                
                // Clean old backups (keep last 10)
                CleanOldBackups();
            }
            catch (Exception ex) {
                throw new InvalidOperationException($"Failed to save tasks to {filePath}: {ex.Message}");
            }
        }
        
        private void CreateBackup() {
            if (File.Exists(filePath)) {
                var timestamp = DateTime.Now.ToString("yyyyMMdd_HHmmss");
                var backupFile = Path.Combine(backupDirectory, $"tasks_backup_{timestamp}.json");
                File.Copy(filePath, backupFile);
            }
        }
        
        private void CleanOldBackups() {
            var backups = GetBackupFiles().OrderByDescending(f => f.CreationTime).ToList();
            foreach (var backup in backups.Skip(10)) {
                try {
                    backup.Delete();
                }
                catch {
                    // Ignore cleanup errors
                }
            }
        }
        
        private FileInfo[] GetBackupFiles() {
            var backupDir = new DirectoryInfo(backupDirectory);
            return backupDir.Exists ? backupDir.GetFiles("tasks_backup_*.json") : new FileInfo[0];
        }
        
        private JsonSerializerOptions GetJsonOptions() {
            return new JsonSerializerOptions {
                WriteIndented = true,
                PropertyNamingPolicy = JsonNamingPolicy.CamelCase
            };
        }
    }
}
```

### TaskFilter.cs - Advanced Filtering
```csharp
namespace TaskPro.Data {
    public class TaskFilter {
        public List<SimpleTask> ApplyFilters(List<SimpleTask> tasks, FilterCriteria criteria) {
            var filtered = tasks.AsEnumerable();
            
            // Priority filter
            if (criteria.Priority != Priority.Medium) {
                filtered = filtered.Where(t => t.Priority == criteria.Priority);
            }
            
            // Tag filter
            if (!string.IsNullOrEmpty(criteria.TagFilter)) {
                filtered = filtered.Where(t => 
                    t.Tags.Any(tag => tag.Contains(criteria.TagFilter, StringComparer.OrdinalIgnoreCase)));
            }
            
            // Search filter (title and notes)
            if (!string.IsNullOrEmpty(criteria.SearchText)) {
                var searchLower = criteria.SearchText.ToLower();
                filtered = filtered.Where(t => 
                    t.Title.ToLower().Contains(searchLower) ||
                    t.Notes.ToLower().Contains(searchLower));
            }
            
            // Today filter
            if (criteria.ShowOnlyToday) {
                var today = DateTime.Today;
                filtered = filtered.Where(t => 
                    t.Priority == Priority.Today ||
                    t.DueDate.Date == today);
            }
            
            // Completed filter
            if (!criteria.ShowCompleted) {
                filtered = filtered.Where(t => !t.Completed);
            }
            
            return filtered.ToList();
        }
        
        public bool MatchesFilter(SimpleTask task, FilterCriteria criteria) {
            return ApplyFilters(new[] { task }, criteria).Any();
        }
    }
}
```

---

## UI Components

### TaskListWidget.cs - Main Task Display
```csharp
namespace TaskPro.UI {
    public class TaskListWidget : ListWidget<TaskListItem> {
        // Configuration
        public TaskManager TaskManager { get; set; }
        public FilterCriteria CurrentFilter { get; set; } = new FilterCriteria();
        public bool GlobalCollapseSubtasks { get; set; } = false;
        public bool ShowPillboxSelection { get; set; } = true;
        
        // Colors
        public ConsoleColor HeaderColor { get; set; } = ConsoleColor.Cyan;
        public ConsoleColor HighPriorityColor { get; set; } = ConsoleColor.Red;
        public ConsoleColor MediumPriorityColor { get; set; } = ConsoleColor.Yellow;
        public ConsoleColor LowPriorityColor { get; set; } = ConsoleColor.Green;
        public ConsoleColor TodayPriorityColor { get; set; } = ConsoleColor.Magenta;
        public ConsoleColor SubtaskColor { get; set; } = ConsoleColor.Gray;
        public ConsoleColor TagColor { get; set; } = ConsoleColor.DarkGray;
        
        // State
        private List<TaskListItem> cachedFlatList;
        private string lastFilterHash;
        
        // Override base rendering
        protected override void RenderItem(ScreenBuffer screen, Rectangle itemRect, 
                                         TaskListItem item, bool isSelected) {
            var task = item.Task;
            var level = item.Level;
            
            // Background for selection
            if (isSelected) {
                screen.FillRect(itemRect.X, itemRect.Y, itemRect.Width, 1, ' ', 
                               ConsoleColor.White, ConsoleColor.DarkBlue);
            }
            
            var x = itemRect.X;
            
            // Status icon (☐ or ■)
            var statusIcon = task.Completed ? "■" : "☐";
            var statusColor = task.Completed ? ConsoleColor.DarkGray : GetPriorityColor(task.Priority);
            screen.WriteAt(x, itemRect.Y, statusIcon, statusColor);
            x += 3;
            
            // Priority indicator
            var priorityChar = GetPriorityChar(task.Priority);
            screen.WriteAt(x, itemRect.Y, priorityChar, GetPriorityColor(task.Priority));
            x += 2;
            
            // Due date
            var dueDateText = FormatDueDate(task.DueDate);
            screen.WriteAt(x, itemRect.Y, dueDateText.PadRight(11), GetDateColor(task.DueDate));
            x += 11;
            
            // Tree indentation for subtasks
            if (level == 1) {
                screen.WriteAt(x, itemRect.Y, "    └─ ", SubtaskColor);
                x += 7;
            }
            
            // Task title
            var titleWidth = itemRect.Width - (x - itemRect.X) - 15; // Leave room for tags
            var title = TruncateWithEllipsis(task.Title, titleWidth);
            var titleColor = task.Completed ? ConsoleColor.DarkGray : 
                           (level == 1 ? SubtaskColor : ConsoleColor.White);
            screen.WriteAt(x, itemRect.Y, title, titleColor);
            
            // Tags (right-aligned if space allows)
            if (task.Tags.Any()) {
                var tagsText = "⟨" + string.Join(", ", task.Tags) + "⟩";
                var tagsX = itemRect.Right - tagsText.Length;
                if (tagsX > x + title.Length + 2) {
                    screen.WriteAt(tagsX, itemRect.Y, tagsText, TagColor);
                }
            }
            
            // Pillbox selection
            if (isSelected && ShowPillboxSelection) {
                RenderPillboxSelection(screen, itemRect);
            }
        }
        
        private void RenderPillboxSelection(ScreenBuffer screen, Rectangle itemRect) {
            var pillboxWidth = Math.Min(itemRect.Width, 60);
            
            // Top border
            if (itemRect.Y > 0) {
                screen.WriteAt(0, itemRect.Y - 1, "╭" + new string('─', pillboxWidth - 2) + "╮", HeaderColor);
            }
            
            // Side borders
            screen.WriteAt(0, itemRect.Y, "│", HeaderColor);
            screen.WriteAt(pillboxWidth - 1, itemRect.Y, "│", HeaderColor);
            
            // Bottom border
            if (itemRect.Y < screen.Height - 1) {
                screen.WriteAt(0, itemRect.Y + 1, "╰" + new string('─', pillboxWidth - 2) + "╯", HeaderColor);
            }
        }
        
        // Input Handling
        public override bool HandleInput(InputEvent input) {
            // Navigation
            if (input.IsArrowUp) {
                if (input.Ctrl) {
                    MoveTaskUp();
                } else {
                    NavigateUp();
                }
                return true;
            }
            
            if (input.IsArrowDown) {
                if (input.Ctrl) {
                    MoveTaskDown();
                } else {
                    NavigateDown();
                }
                return true;
            }
            
            // Task operations
            if (input.IsSpace) {
                ToggleTaskCompletion();
                return true;
            }
            
            if (input.Key == ConsoleKey.N) {
                CreateNewTask();
                return true;
            }
            
            if (input.Key == ConsoleKey.D) {
                DeleteCurrentTask();
                return true;
            }
            
            if (input.IsEnter) {
                OpenNotesEditor();
                return true;
            }
            
            if (input.Key == ConsoleKey.T) {
                ToggleTheme();
                return true;
            }
            
            if (input.Key == ConsoleKey.R) {
                EditTags();
                return true;
            }
            
            if (input.Key == ConsoleKey.E) {
                StartInlineEdit();
                return true;
            }
            
            if (input.KeyChar == '/') {
                ActivateFilter();
                return true;
            }
            
            return base.HandleInput(input);
        }
        
        // Task Operations
        private void ToggleTaskCompletion() {
            if (HasSelection) {
                TaskManager.ToggleComplete(SelectedItem.Task.Id);
                RefreshList();
            }
        }
        
        private void MoveTaskUp() {
            if (HasSelection && SelectedItem.Level == 0) {
                TaskManager.MoveTaskUp(SelectedItem.Task.Id);
                RefreshList();
            }
        }
        
        private void MoveTaskDown() {
            if (HasSelection && SelectedItem.Level == 0) {
                TaskManager.MoveTaskDown(SelectedItem.Task.Id);
                RefreshList();
            }
        }
        
        private void CreateNewTask() {
            // Implementation for task creation dialog
        }
        
        private void DeleteCurrentTask() {
            if (HasSelection) {
                TaskManager.DeleteTask(SelectedItem.Task.Id);
                RefreshList();
            }
        }
        
        private void OpenNotesEditor() {
            // Implementation for notes editor
        }
        
        // Data Management
        public void RefreshList(bool forceRebuild = false) {
            var currentFilterHash = GenerateFilterHash();
            
            if (!forceRebuild && currentFilterHash == lastFilterHash && cachedFlatList != null) {
                Items = cachedFlatList;
                return;
            }
            
            var filteredTasks = TaskManager.ApplyFilter(CurrentFilter);
            cachedFlatList = TaskManager.BuildFlatList(filteredTasks, GlobalCollapseSubtasks);
            Items = cachedFlatList;
            lastFilterHash = currentFilterHash;
        }
        
        private string GenerateFilterHash() {
            return $"{CurrentFilter.GetDisplayText()}_{GlobalCollapseSubtasks}";
        }
        
        // Utility Methods
        private ConsoleColor GetPriorityColor(Priority priority) {
            return priority switch {
                Priority.Today => TodayPriorityColor,
                Priority.High => HighPriorityColor,
                Priority.Medium => MediumPriorityColor,
                Priority.Low => LowPriorityColor,
                _ => ConsoleColor.White
            };
        }
        
        private string GetPriorityChar(Priority priority) {
            return priority switch {
                Priority.Today => "T",
                Priority.High => "H",
                Priority.Medium => "M",
                Priority.Low => "L",
                _ => "M"
            };
        }
        
        private string FormatDueDate(DateTime dueDate) {
            if (dueDate == DateTime.MinValue) return "          ";
            
            var today = DateTime.Today;
            if (dueDate.Date == today) return "Today     ";
            if (dueDate.Date == today.AddDays(1)) return "Tomorrow  ";
            if (dueDate.Date == today.AddDays(-1)) return "Yesterday ";
            
            return dueDate.ToString("yyyy-MM-dd");
        }
        
        private ConsoleColor GetDateColor(DateTime dueDate) {
            if (dueDate == DateTime.MinValue) return ConsoleColor.DarkGray;
            
            var today = DateTime.Today;
            var daysDiff = (dueDate.Date - today).Days;
            
            if (daysDiff < 0) return ConsoleColor.Red;      // Overdue
            if (daysDiff == 0) return ConsoleColor.Yellow;  // Today
            if (daysDiff <= 7) return ConsoleColor.Cyan;    // This week
            return ConsoleColor.Green;                      // Future
        }
        
        private string TruncateWithEllipsis(string text, int maxLength) {
            if (text.Length <= maxLength) return text;
            return text.Substring(0, maxLength - 1) + "…";
        }
    }
}
```

---

## Application Integration

### TaskProPro.ps1 - Main Application
```powershell
#!/usr/bin/env pwsh
# TaskProPro.ps1 - Professional Task Management Application

param(
    [string]$DataFile = "$PSScriptRoot/Data/tasks.json",
    [switch]$Debug
)

# Set debug mode
$global:Debug = $Debug.IsPresent

try {
    # Load professional TUI foundation
    . "$PSScriptRoot/Load-TaskProPro.ps1"
    
    Write-Host "Starting TaskProPro..." -ForegroundColor Cyan
    
    # Initialize data directory
    $dataDir = Split-Path $DataFile -Parent
    if (-not (Test-Path $dataDir)) {
        New-Item -ItemType Directory -Path $dataDir -Force | Out-Null
    }
    
    # Initialize components
    $taskManager = [TaskPro.Data.TaskManager]::new($DataFile)
    $screen = [TaskPro.Core.ScreenBuffer]::new([Console]::WindowWidth, [Console]::WindowHeight)
    $taskListWidget = [TaskPro.UI.TaskListWidget]::new()
    
    # Configure task list widget
    $taskListWidget.TaskManager = $taskManager
    $taskListWidget.ShowPillboxSelection = $true
    $taskListWidget.RefreshList($true)
    
    # Hide cursor and clear screen
    [Console]::CursorVisible = $false
    Clear-Host
    
    # Main application loop
    $running = $true
    $lastWindowSize = @{ Width = [Console]::WindowWidth; Height = [Console]::WindowHeight }
    
    while ($running) {
        try {
            # Check for window resize
            $currentSize = @{ Width = [Console]::WindowWidth; Height = [Console]::WindowHeight }
            if ($currentSize.Width -ne $lastWindowSize.Width -or $currentSize.Height -ne $lastWindowSize.Height) {
                $screen = [TaskPro.Core.ScreenBuffer]::new($currentSize.Width, $currentSize.Height)
                $lastWindowSize = $currentSize
            }
            
            # Begin frame
            $screen.BeginFrame()
            
            # Header
            $headerText = "TaskProPro - Professional Task Manager"
            $filterText = $taskListWidget.CurrentFilter.GetDisplayText()
            if ($filterText -ne "All") {
                $headerText += " | Filter: $filterText"
            }
            $screen.WriteAt(0, 0, $headerText, [ConsoleColor]::Cyan)
            
            # Task count info
            $taskCount = $taskListWidget.ItemCount
            $selectedInfo = if ($taskCount -gt 0) { "Selected: $($taskListWidget.SelectedIndex + 1)/$taskCount" } else { "No tasks" }
            $screen.WriteAt(0, 1, $selectedInfo, [ConsoleColor]::DarkGray)
            
            # Separator
            $screen.WriteAt(0, 2, "─" * $screen.Width, [ConsoleColor]::DarkGray)
            
            # Task list
            $listRect = [TaskPro.Core.Rectangle]::new(0, 3, $screen.Width, $screen.Height - 5)
            $taskListWidget.Render($screen, $listRect)
            
            # Status bar
            $statusY = $screen.Height - 2
            $screen.FillRect(0, $statusY, $screen.Width, 1, ' ', [ConsoleColor]::White, [ConsoleColor]::DarkBlue)
            
            $shortcuts = "↑↓:Navigate | N:New | Enter:Notes | D:Delete | /:Filter | Ctrl+Q:Quit"
            $screen.WriteAt(1, $statusY, $shortcuts, [ConsoleColor]::White, [ConsoleColor]::DarkBlue)
            
            # End frame - single write, zero flicker!
            $screen.EndFrame()
            
            # Handle input
            if ([TaskPro.Core.InputManager]::IsInputAvailable()) {
                $input = [TaskPro.Core.InputManager]::ReadInput()
                
                # Global shortcuts
                if ($input.IsCtrlQ) {
                    $running = $false
                    continue
                }
                
                if ($input.IsCtrlR) {
                    $taskListWidget.RefreshList($true)
                    continue
                }
                
                # Route to task list widget
                $taskListWidget.HandleInput($input)
            }
            
            # 60 FPS refresh rate
            Start-Sleep -Milliseconds 16
            
        } catch {
            $running = $false
            throw
        }
    }
    
} catch {
    Write-Host "TaskProPro Error: $_" -ForegroundColor Red
    if ($global:Debug) {
        Write-Host "Stack Trace: $($_.ScriptStackTrace)" -ForegroundColor Yellow
    }
} finally {
    # Cleanup
    [Console]::CursorVisible = $true
    Clear-Host
    
    Write-Host ""
    Write-Host "TaskProPro session ended." -ForegroundColor Green
}
```

---

## Error Handling Specifications

### Exception Handling Strategy
```csharp
namespace TaskPro.Core {
    public class TaskProException : Exception {
        public TaskProException(string message) : base(message) { }
        public TaskProException(string message, Exception innerException) : base(message, innerException) { }
    }
    
    public class DataPersistenceException : TaskProException {
        public DataPersistenceException(string message) : base($"Data persistence error: {message}") { }
        public DataPersistenceException(string message, Exception innerException) : base($"Data persistence error: {message}", innerException) { }
    }
    
    public class TaskValidationException : TaskProException {
        public TaskValidationException(string message) : base($"Task validation error: {message}") { }
    }
}
```

### Error Recovery Patterns
1. **Data Loading**: Fall back to backups, create new file if all fail
2. **Save Operations**: Use atomic saves with temp files
3. **UI Rendering**: Graceful degradation on render errors
4. **Input Handling**: Ignore invalid inputs, log for debugging

---

## Performance Requirements

### Rendering Performance
- **Target**: 60 FPS (16ms frame time)
- **Single screen write** per frame (zero flicker)
- **Cached list building** to avoid rebuilding unchanged data
- **Efficient string operations** using StringBuilder

### Data Performance  
- **Task loading**: < 100ms for typical datasets (< 1000 tasks)
- **Filtering**: < 50ms for complex filters
- **Save operations**: < 200ms with backup creation
- **Memory usage**: < 50MB for typical usage

### Scalability Limits
- **Maximum tasks**: 10,000 parent tasks
- **Maximum subtasks per parent**: 100
- **Maximum file size**: 50MB JSON file
- **Backup retention**: 10 most recent backups

---

## Implementation Priority

### Phase 1: Core Data (Week 1)
1. **SimpleTask model** with all properties and methods
2. **TaskManager** with CRUD operations and task movement
3. **TaskPersistence** with atomic saves and backup recovery
4. **TaskFilter** with all filtering capabilities

### Phase 2: UI Integration (Week 2)
1. **TaskListWidget** with hierarchical rendering and pillbox selection
2. **Task operations** integration (toggle, delete, create)
3. **Input handling** for all shortcuts and navigation
4. **Filter activation** and management

### Phase 3: Application (Week 3)
1. **TaskProPro.ps1** main application with proper error handling
2. **Window resize handling** and responsive layout
3. **Status bar** and user feedback
4. **Performance optimization** and testing

### Phase 4: Advanced Features (Week 4)
1. **Inline editing** system for task properties
2. **Notes editor** integration
3. **Tag management** with completion
4. **Export/import** functionality

This technical specification provides the concrete implementation blueprint needed to build TaskProPro while ensuring 100% feature preservation and professional performance.