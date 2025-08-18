using System;
using System.Collections.Generic;
using System.Linq;
using TaskPro.Core;
using TaskPro.Data;

namespace TaskPro.UI {
    public class TaskListWidget : ListWidget<TaskListItem> {
        // Configuration
        public TaskManager TaskManager { get; set; }
        public FilterCriteria CurrentFilter { get; set; } = new FilterCriteria();
        public bool GlobalCollapseSubtasks { get; set; } = false;
        public StatusBar StatusBar { get; set; }
        public InlineEditor InlineEditor { get; set; }
        public TagEditor TagEditor { get; set; }
        public TaskCreationDialog TaskCreationDialog { get; set; }
        public NotesEditorDialog NotesEditorDialog { get; set; }
        public ColorPickerDialog ColorPickerDialog { get; set; }
        
        // CYBERPUNK COLOR PALETTE - BRIGHT GLOWING TERMINAL AESTHETIC
        public ConsoleColor HeaderColor { get; set; } = ConsoleColor.Cyan;          // BRIGHT CYAN HEADERS
        public ConsoleColor HighPriorityColor { get; set; } = ConsoleColor.Red;     // EMERGENCY RED
        public ConsoleColor MediumPriorityColor { get; set; } = ConsoleColor.Yellow; // AMBER WARNINGS  
        public ConsoleColor LowPriorityColor { get; set; } = ConsoleColor.Green;    // SYSTEM GREEN
        public ConsoleColor TodayPriorityColor { get; set; } = ConsoleColor.Magenta; // CRITICAL MAGENTA
        public ConsoleColor SubtaskColor { get; set; } = ConsoleColor.Gray;         // VISIBLE GRAY
        public ConsoleColor TagColor { get; set; } = ConsoleColor.Cyan;             // BRIGHT CYAN TAGS
        
        // Extended cyberpunk palette - ENHANCED BRIGHTNESS
        public ConsoleColor BorderColor { get; set; } = ConsoleColor.Cyan;          // GLOWING CYAN BORDERS
        public ConsoleColor BackgroundColor { get; set; } = ConsoleColor.Black;     // DEEP SPACE BLACK
        public new ConsoleColor SelectionColor { get; set; } = ConsoleColor.Blue;   // BRIGHT BLUE SELECTION
        public ConsoleColor AmberText { get; set; } = ConsoleColor.Yellow;          // CLASSIC AMBER TERMINAL
        public ConsoleColor StatusGreen { get; set; } = ConsoleColor.Green;         // BRIGHT GREEN STATUS
        public ConsoleColor DangerRed { get; set; } = ConsoleColor.Red;             // ALERT RED
        public ConsoleColor DataBlue { get; set; } = ConsoleColor.Blue;             // DATA FIELDS
        public ConsoleColor HintColor { get; set; } = ConsoleColor.Gray;            // VISIBLE HINT TEXT
        public ConsoleColor HighlightColor { get; set; } = ConsoleColor.Yellow;     // BRIGHT YELLOW HIGHLIGHTS
        
        // State
        private List<TaskListItem> cachedFlatList = new List<TaskListItem>();
        private string lastFilterHash = "";
        
        // UNIFIED RENDERING STATE
        public string CurrentMode { get; set; } = "Tasks";
        
        // Status information for unified display - no external dependencies
        public int StatusTaskCount { get; set; } = 0;
        public int StatusSelectedIndex { get; set; } = 0;
        public string StatusFilterText { get; set; } = "";
        public int StatusCompletedCount { get; set; } = 0;
        public bool StatusHasDueTasks { get; set; } = false;
        
        // PERFORMANCE OPTIMIZATION - Task display cache
        private readonly Dictionary<string, TaskDisplayCache> taskDisplayCache = new Dictionary<string, TaskDisplayCache>();
        
        // Filter input state - EXACT feature parity with standalone
        private bool filterInputActive = false;
        private string filterInputValue = "";
        private int filterInputCursor = 0;
        private string currentFilterMode = "All";  // "All", "Today", "High", "Medium", "Low"
        private string tagFilter = "";             // Tag-based filter like "work", "personal"
        
        // Inline editing state - EXACT feature parity with standalone
        private int editingIndex = -1;
        private string editingField = "";          // "title", "priority", "date", "tags", "status"
        private string editingValue = "";
        private SimpleTask editingTask = null;
        private bool isNewTask = false;
        
        // Constructor to set up task formatting
        public TaskListWidget() {
            // Configure the base ListWidget to render tasks properly
            base.ItemFormatter = FormatTaskItem;
            base.ItemColorProvider = GetTaskItemColor;
            base.ShowPillboxSelection = true;
            
            // Initialize inline editor
            InlineEditor = new InlineEditor();
            InlineEditor.TaskUpdated += OnTaskUpdated;
            InlineEditor.EditCancelled += OnEditCancelled;
            InlineEditor.StatusMessage += OnStatusMessage;
            
            // Initialize tag editor
            TagEditor = new TagEditor();
            TagEditor.TagsUpdated += OnTaskUpdated;
            TagEditor.EditCancelled += OnEditCancelled;
            TagEditor.StatusMessage += OnStatusMessage;
            
            // Initialize task creation dialog
            TaskCreationDialog = new TaskCreationDialog();
            TaskCreationDialog.TaskCreated += OnTaskCreated;
            TaskCreationDialog.DialogCancelled += OnEditCancelled;
            TaskCreationDialog.StatusMessage += OnStatusMessage;
            
            // Initialize notes editor dialog
            NotesEditorDialog = new NotesEditorDialog();
            NotesEditorDialog.NotesUpdated += OnTaskUpdated;
            NotesEditorDialog.EditorClosed += OnEditCancelled;
            NotesEditorDialog.StatusMessage += OnStatusMessage;
            
            // Initialize color picker dialog
            ColorPickerDialog = new ColorPickerDialog();
            ColorPickerDialog.TaskColorUpdated += OnTaskUpdated;
            ColorPickerDialog.DialogClosed += OnEditCancelled;
            ColorPickerDialog.StatusMessage += OnStatusMessage;
        }
        
        // CYBERPUNK TASK FORMATTING - Proper columnar layout with actual data
        private string FormatTaskItem(TaskListItem item) {
            var task = item.Task;
            var level = item.Level;
            
            // FIXED COLUMN WIDTHS to match headers exactly
            // ST │PRI │DUE DATE  │ID1     │ID2     │TASK TITLE                        │TAGS
            // 3  │4   │10        │8       │8       │33                                │remaining
            
            // Column 1: Status (2 chars + 1 space = 3 total)
            var statusIcon = task.GetStatusIcon();
            var statusCol = statusIcon.PadRight(2).Substring(0, 2);
            
            // Column 2: Priority (3 chars + 1 space = 4 total) 
            var priorityIcon = task.GetCyberpunkPriority();
            var priorityCol = priorityIcon.PadRight(3).Substring(0, 3);
            
            // Column 3: Due Date (9 chars + 1 space = 10 total)
            var dateText = task.GetCyberpunkDate();
            var dateCol = dateText.PadRight(9).Substring(0, 9);
            
            // Column 4: ID1 (7 chars + 1 space = 8 total)
            var id1Display = string.IsNullOrEmpty(task.ID1) ? "---" : task.ID1;
            var id1Col = id1Display.PadRight(7).Substring(0, 7);
            
            // Column 5: ID2 (7 chars + 1 space = 8 total)
            var id2Display = string.IsNullOrEmpty(task.ID2) ? "---" : task.ID2;
            var id2Col = id2Display.PadRight(7).Substring(0, 7);
            
            // Column 6: Title (32 chars + 1 space = 33 total)
            var title = task.Title ?? "";
            if (title.Length > 32) {
                title = title.Substring(0, 29) + "...";
            }
            var titleCol = title.PadRight(32);
            
            // Apply indentation for subtasks
            if (level > 0) {
                var indent = new string(' ', level * 2);
                titleCol = indent + titleCol.Substring(Math.Min(indent.Length, titleCol.Length));
            }
            
            // Column 7: Tags (remaining space)
            var tagText = "";
            if (task.Tags.Any()) {
                tagText = string.Join(" ", task.Tags.Select(t => $"<{t}>"));
            }
            
            // Join with exact separators
            return $"{statusCol} │{priorityCol} │{dateCol} │{id1Col} │{id2Col} │{titleCol} │{tagText}";
        }
        
        // Color provider for tasks - Enhanced with RGB/theme support
        private ConsoleColor GetTaskItemColor(TaskListItem item) {
            var task = item.Task;
            
            if (task.Completed) {
                return ConsoleColor.DarkGray;
            }
            
            // Use existing task priority color system - no external dependencies
            
            // Fall back to task's own priority color method
            return task.GetPriorityColor();
        }
        
        // Input Handling
        public new bool HandleInput(InputEvent input) {
            // Check if color picker dialog is active first (highest priority)
            if (ColorPickerDialog?.IsActive == true) {
                return ColorPickerDialog.HandleInput(input);
            }
            
            // Check if notes editor dialog is active
            if (NotesEditorDialog?.IsActive == true) {
                return NotesEditorDialog.HandleInput(input);
            }
            
            // Check if task creation dialog is active
            if (TaskCreationDialog?.IsActive == true) {
                return TaskCreationDialog.HandleInput(input);
            }
            
            // Handle filter input mode - EXACT feature parity
            if (filterInputActive) {
                return HandleFilterInput(input);
            }
            
            // Handle inline editing mode - EXACT feature parity
            if (editingIndex >= 0) {
                return HandleEditingInput(input);
            }
            
            // Check if inline editor is active
            if (InlineEditor?.IsActive == true) {
                return InlineEditor.HandleInput(input);
            }
            
            // Check if tag editor is active
            if (TagEditor?.IsActive == true) {
                return TagEditor.HandleInput(input);
            }
            
            // Navigation - let base class handle basic navigation, add task movement
            if (input.IsArrowUp && input.Ctrl) {
                MoveTaskUp();
                return true;
            }
            
            if (input.IsArrowDown && input.Ctrl) {
                MoveTaskDown();
                return true;
            }
            
            // Task operations
            if (input.Key == ConsoleKey.Spacebar) {
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
                if (input.Shift) {
                    // Shift+T: Open color picker for custom colors
                    OpenColorPicker();
                } else {
                    // T: Toggle through predefined themes
                    ToggleTheme();
                }
                return true;
            }
            
            if (input.Key == ConsoleKey.O && input.Ctrl) {
                // Ctrl+O: Open color picker (alternative shortcut)
                OpenColorPicker();
                return true;
            }
            
            if (input.Key == ConsoleKey.R) {
                StartTagEditor();
                return true;
            }
            
            if (input.Key == ConsoleKey.C) {
                ToggleTaskCollapse();
                return true;
            }
            
            if (input.Key == ConsoleKey.G) {
                ToggleGlobalCollapse();
                return true;
            }
            
            if (input.Key == ConsoleKey.E) {
                // Start inline editing of current task - EXACT feature parity
                if (base.HasSelection) {
                    StartInlineEdit();
                }
                return true;
            }
            
            if (input.Key == ConsoleKey.N) {
                // Start inline add new task - EXACT feature parity
                StartInlineAdd();
                return true;
            }
            
            if (input.Key == ConsoleKey.S) {
                // Start inline subtask creation - EXACT feature parity
                if (base.HasSelection) {
                    StartInlineSubtask();
                }
                return true;
            }
            
            if (input.Char == '/') {
                ActivateFilter();
                return true;
            }
            
            return base.HandleInput(input);
        }
        
        // Task Operations
        private void ToggleTaskCompletion() {
            if (base.HasSelection) {
                var task = base.SelectedItem.Task;
                TaskManager.ToggleComplete(task.Id);
                RefreshList();
                
                // User feedback
                var status = task.Completed ? "completed" : "reopened";
                StatusBar?.ShowSuccess($"Task '{TruncateTitle(task.Title, 30)}' {status}");
            }
        }
        
        private void MoveTaskUp() {
            if (base.HasSelection && base.SelectedItem.Level == 0) {
                var task = base.SelectedItem.Task;
                TaskManager.MoveTaskUp(task.Id);
                RefreshList();
                StatusBar?.ShowSuccess($"Moved '{TruncateTitle(task.Title, 30)}' up");
            }
        }
        
        private void MoveTaskDown() {
            if (base.HasSelection && base.SelectedItem.Level == 0) {
                var task = base.SelectedItem.Task;
                TaskManager.MoveTaskDown(task.Id);
                RefreshList();
                StatusBar?.ShowSuccess($"Moved '{TruncateTitle(task.Title, 30)}' down");
            }
        }
        
        private void CreateNewTask() {
            TaskCreationDialog?.StartDialog();
        }
        
        private void DeleteCurrentTask() {
            if (base.HasSelection) {
                var task = base.SelectedItem.Task;
                TaskManager.DeleteTask(task.Id);
                RefreshList();
                StatusBar?.ShowWarning($"Deleted task '{TruncateTitle(task.Title, 30)}'");
            }
        }
        
        private void OpenNotesEditor() {
            if (base.HasSelection) {
                NotesEditorDialog?.StartEditing(base.SelectedItem.Task);
            }
        }
        
        // Global theme state - cycling through cyberpunk color schemes
        private static int globalThemeIndex = 0;
        private static readonly ConsoleColor[] themeColors = { ConsoleColor.Cyan, ConsoleColor.Green, ConsoleColor.Magenta, ConsoleColor.Yellow };
        private static readonly string[] themeNames = { "Cyberpunk Blue", "Matrix Green", "Neon Purple", "Amber Terminal" };
        
        private void ToggleTheme() {
            // Cycle through predefined cyberpunk themes
            globalThemeIndex = (globalThemeIndex + 1) % themeColors.Length;
            var newThemeColor = themeColors[globalThemeIndex];
            var themeName = themeNames[globalThemeIndex];
            
            // Apply theme to UI colors
            HeaderColor = newThemeColor;
            BorderColor = newThemeColor;
            DataBlue = newThemeColor;
            
            RefreshList();
            
            // Show theme change message
            StatusBar?.ShowSuccess($"Theme: {themeName}");
        }
        
        private void OpenColorPicker() {
            // Open color picker for custom colors
            if (base.HasSelection) {
                ColorPickerDialog?.StartColorPicker(base.SelectedItem.Task);
            }
        }
        
        private void ToggleTaskCollapse() {
            // Toggle collapse/expand for individual task - EXACT feature parity
            if (base.HasSelection) {
                var item = base.SelectedItem;
                var task = item.Task;
                
                // Only parent tasks (level 0) can be collapsed
                if (item.Level == 0 && task.HasSubtasks()) {
                    task.SubtasksCollapsed = !task.SubtasksCollapsed;
                    task.Touch();
                    
                    TaskManager?.UpdateTask(task);
                    RefreshList(true); // Force rebuild to show/hide subtasks
                    
                    var action = task.SubtasksCollapsed ? "collapsed" : "expanded";
                    StatusBar?.ShowSuccess($"Task '{TruncateTitle(task.Title, 25)}' {action}");
                } else {
                    StatusBar?.ShowWarning("Only parent tasks with subtasks can be collapsed");
                }
            }
        }
        
        private void ToggleGlobalCollapse() {
            // Toggle global collapse for all subtasks - EXACT feature parity
            GlobalCollapseSubtasks = !GlobalCollapseSubtasks;
            RefreshList(true); // Force rebuild to show/hide all subtasks
            
            var action = GlobalCollapseSubtasks ? "collapsed" : "expanded";
            StatusBar?.ShowSuccess($"All subtasks {action} globally");
        }
        
        private void EditTags() {
            // Implementation for tag editing
        }
        
        private void StartInlineEditTitle() {
            if (base.HasSelection) {
                InlineEditor?.StartEdit(base.SelectedItem.Task, EditMode.Title);
            }
        }
        
        private void StartInlineEditPriority() {
            if (base.HasSelection) {
                InlineEditor?.StartEdit(base.SelectedItem.Task, EditMode.Priority);
            }
        }
        
        private void StartInlineEditDueDate() {
            if (base.HasSelection) {
                InlineEditor?.StartEdit(base.SelectedItem.Task, EditMode.DueDate);
            }
        }
        
        private void StartTagEditor() {
            if (base.HasSelection) {
                TagEditor?.StartTagEditing(base.SelectedItem.Task, TaskManager);
            }
        }
        
        private void StartInlineEditTags() {
            if (base.HasSelection) {
                InlineEditor?.StartEdit(base.SelectedItem.Task, EditMode.Tags);
            }
        }
        
        private void ActivateFilter() {
            // EXACT feature parity with standalone filter system
            if (filterInputActive) {
                // If filter is already active, clear it
                filterInputValue = "";
                filterInputCursor = 0;
            } else {
                // If filter exists, start with current filter value for editing
                if (currentFilterMode != "All" || tagFilter != "") {
                    string existingFilter = tagFilter != "" ? $"#{tagFilter}" : currentFilterMode.ToLower();
                    filterInputValue = existingFilter;
                    filterInputCursor = existingFilter.Length;
                }
                StartFilterInput();
            }
        }
        
        private void StartFilterInput() {
            // Start complex filter input mode - EXACT feature parity
            filterInputActive = true;
            filterInputValue = "";
            filterInputCursor = 0;
        }
        
        private void EndFilterInput(bool apply) {
            if (apply && !string.IsNullOrWhiteSpace(filterInputValue)) {
                ApplyFilterFromInput();
                RefreshTaskList();
            }
            
            filterInputActive = false;
            filterInputValue = "";
            filterInputCursor = 0;
        }
        
        private void ApplyFilterFromInput() {
            // Parse filter: #tag for tag filter, priority names for priority filter - EXACT feature parity
            string filterText = filterInputValue.Trim();
            
            if (filterText == "clear") {
                // Clear all filters
                currentFilterMode = "All";
                tagFilter = "";
            } else if (filterText.StartsWith("#")) {
                tagFilter = filterText.Substring(1);
                currentFilterMode = "All";  // Reset priority filter
            } else if (filterText == "high" || filterText == "h") {
                currentFilterMode = "High";
                tagFilter = "";
            } else if (filterText == "medium" || filterText == "med" || filterText == "m") {
                currentFilterMode = "Medium";
                tagFilter = "";
            } else if (filterText == "low" || filterText == "l") {
                currentFilterMode = "Low";
                tagFilter = "";
            } else if (filterText == "today" || filterText == "t") {
                currentFilterMode = "Today";
                tagFilter = "";
            } else if (filterText == "all" || filterText == "*") {
                currentFilterMode = "All";
                tagFilter = "";
            } else {
                // Default to tag filter (without #)
                tagFilter = filterText;
                currentFilterMode = "All";
            }
        }
        
        private bool HandleFilterInput(InputEvent input) {
            // EXACT feature parity with standalone filter input handling
            if (input.IsEnter) {
                EndFilterInput(true);
                return true;
            }
            
            if (input.IsEscape) {
                EndFilterInput(false);
                return true;
            }
            
            if (input.IsBackspace) {
                if (filterInputCursor > 0) {
                    filterInputValue = filterInputValue.Remove(filterInputCursor - 1, 1);
                    filterInputCursor--;
                }
                return true;
            }
            
            if (input.IsDelete) {
                if (filterInputCursor < filterInputValue.Length) {
                    filterInputValue = filterInputValue.Remove(filterInputCursor, 1);
                }
                return true;
            }
            
            if (input.IsArrowLeft) {
                if (filterInputCursor > 0) {
                    filterInputCursor--;
                }
                return true;
            }
            
            if (input.IsArrowRight) {
                if (filterInputCursor < filterInputValue.Length) {
                    filterInputCursor++;
                }
                return true;
            }
            
            if (input.IsHome) {
                filterInputCursor = 0;
                return true;
            }
            
            if (input.IsEnd) {
                filterInputCursor = filterInputValue.Length;
                return true;
            }
            
            // Regular character input
            if (input.IsPrintableChar && !input.Ctrl && !input.Alt) {
                filterInputValue = filterInputValue.Insert(filterInputCursor, input.Char.ToString());
                filterInputCursor++;
                return true;
            }
            
            return false;
        }
        
        // Helper method for truncating task titles
        private string TruncateTitle(string title, int maxLength) {
            if (title.Length <= maxLength) return title;
            return title.Substring(0, maxLength - 3) + "...";
        }
        
        // Data Management
        public void RefreshList(bool forceRebuild = false) {
            var currentFilterHash = GenerateFilterHash();
            
            if (!forceRebuild && currentFilterHash == lastFilterHash && cachedFlatList != null) {
                base.Items = cachedFlatList;
                return;
            }
            
            // Apply filtering - EXACT feature parity with standalone
            RefreshTaskList();
            lastFilterHash = currentFilterHash;
        }
        
        private void RefreshTaskList() {
            if (TaskManager == null) return;
            
            // Get all tasks from manager
            var allTasks = TaskManager.GetParentTasks(); // Get parent tasks only
            
            // Apply filtering - EXACT feature parity with standalone
            var filteredTasks = FilterTasks(allTasks).ToList();
            
            // Use TaskManager's BuildFlatList for proper hierarchical display with collapse/expand
            var flatItems = TaskManager.BuildFlatList(filteredTasks, GlobalCollapseSubtasks);
            
            base.Items = flatItems;
            cachedFlatList = flatItems;
        }
        
        private IEnumerable<SimpleTask> FilterTasks(IEnumerable<SimpleTask> tasks) {
            // EXACT feature parity with standalone FilterTasks method
            if (currentFilterMode == "All" && tagFilter == "") {
                return tasks;
            }
            
            var filteredTasks = new List<SimpleTask>();
            var today = DateTime.Today;
            
            foreach (var task in tasks) {
                bool includeTask = false;
                
                // Priority/Date filtering
                switch (currentFilterMode) {
                    case "All":
                        includeTask = true;
                        break;
                    case "Today":
                        // Include if priority is "Today" OR due date is today
                        includeTask = (task.Priority == Priority.Today) || 
                                     (task.DueDate != DateTime.MinValue && task.DueDate.Date == today);
                        break;
                    case "High":
                        includeTask = (task.Priority == Priority.High);
                        break;
                    case "Medium":
                        includeTask = (task.Priority == Priority.Medium);
                        break;
                    case "Low":
                        includeTask = (task.Priority == Priority.Low);
                        break;
                }
                
                // Tag filtering (additional filter)
                if (includeTask && tagFilter != "") {
                    includeTask = false;
                    // Check if task has the filtered tag (case insensitive)
                    foreach (var tag in task.Tags) {
                        if (string.Equals(tag, tagFilter, StringComparison.OrdinalIgnoreCase)) {
                            includeTask = true;
                            break;
                        }
                    }
                }
                
                if (includeTask) {
                    filteredTasks.Add(task);
                }
            }
            
            return filteredTasks;
        }
        
        private string GenerateFilterHash() {
            // Include filter state in hash to detect filter changes
            return $"{currentFilterMode}|{tagFilter}|{GlobalCollapseSubtasks}";
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
        
        // CYBERPUNK DATE FORMATTING - Terminal computer style
        private string FormatCyberpunkDate(DateTime dueDate) {
            if (dueDate == DateTime.MinValue) return "--:--:--   ";
            
            var today = DateTime.Today;
            var daysDiff = (dueDate.Date - today).Days;
            
            return daysDiff switch {
                0 => "[TODAY]   ",
                1 => "[TOM]     ",
                -1 => "[YEST]    ",
                < -1 => $"[{Math.Abs(daysDiff)}d AGO] ",
                <= 7 => $"[+{daysDiff}d]    ",
                _ => dueDate.ToString("MMdd.yy   ")
            };
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
        
        // Event handlers for inline editor and dialogs
        private void OnTaskUpdated(SimpleTask task) {
            // Update the task in the manager and refresh
            TaskManager?.UpdateTask(task);
            RefreshList();
        }
        
        private void OnTaskCreated(SimpleTask task) {
            // Add the new task to the manager and refresh
            TaskManager?.AddTask(task);
            RefreshList();
            
            // Try to select the newly created task
            base.SelectItemByPredicate(item => item.Task.Id == task.Id);
        }
        
        private void OnEditCancelled() {
            // Just refresh display, no data changes
            // The base ListWidget will handle the display update
        }
        
        private void OnStatusMessage(string message) {
            StatusBar?.ShowMessage(message);
        }
        
        // UNIFIED CYBERPUNK RENDER SYSTEM - Full screen control with performance optimization
        public override void Render(Core.ScreenBuffer screen, Core.Rectangle bounds) {
            // DEBUG: Write to file to verify this method is called
            System.IO.File.AppendAllText("DEBUG-RENDER.log", $"[{System.DateTime.Now:HH:mm:ss.fff}] TaskListWidget.Render() CALLED - ENHANCED UI ACTIVE\n");
            
            // FULL SCREEN CYBERPUNK INTERFACE - Professional terminal aesthetic
            
            // Clear entire screen with black background
            screen.FillRect(bounds.X, bounds.Y, bounds.Width, bounds.Height, ' ', 
                          ConsoleColor.White, BackgroundColor);
            
            // 1. CYBERPUNK HEADER SECTION (Lines 0-4)
            RenderUnifiedHeader(screen, bounds);
            
            // 2. TASK LIST SECTION (Lines 5+)
            var listStartY = 5;
            var listHeight = bounds.Height - 8; // Reserve space for status
            var listBounds = new Rectangle(1, listStartY, bounds.Width - 2, listHeight);
            RenderOptimizedTaskList(screen, listBounds);
            
            // 3. STATUS BAR SECTION (Bottom lines)
            var statusY = bounds.Height - 3;
            var statusBounds = new Rectangle(0, statusY, bounds.Width, 3);
            RenderUnifiedStatusBar(screen, statusBounds);
            
            // 4. PROFESSIONAL OVERLAYS - Enhanced UI elements
            RenderOverlays(screen, bounds);
        }
        
        /// <summary>
        /// Render unified cyberpunk header with professional borders
        /// </summary>
        private void RenderUnifiedHeader(ScreenBuffer screen, Rectangle bounds) {
            // TOP BORDER - Use optimized RenderOptimizer
            var topBorder = RenderOptimizer.BuildBorder(bounds.Width, BorderType.Top);
            screen.WriteAt(0, 0, topBorder, ConsoleColor.Cyan, ConsoleColor.Black);
            
            // MAIN TITLE LINE
            var titleText = " ★★★ TASKPROPRO CYBERPUNK ENHANCED ★★★ ";
            var filterText = CurrentFilter?.GetDisplayText() ?? "All";
            if (filterText != "All") {
                titleText += $" [FLT:{filterText.ToUpper()}] ";
            }
            var titleX = (bounds.Width - titleText.Length) / 2;
            screen.WriteAt(0, 1, "║".PadRight(bounds.Width - 1) + "║", HeaderColor, BackgroundColor);
            screen.WriteAt(titleX, 1, titleText, HeaderColor, BackgroundColor);
            
            // SYSTEM STATUS LINE
            var systemStatus = " [SYS:ONLINE] [MODE:TASK_MGMT] [F1:TIME_TRACK] ";
            screen.WriteAt(0, 2, "║".PadRight(bounds.Width - 1) + "║", HeaderColor, BackgroundColor);
            screen.WriteAt(2, 2, systemStatus, StatusGreen, BackgroundColor);
            
            // SELECTION INFO LINE
            var taskCount = StatusTaskCount;
            var selectedIndex = StatusSelectedIndex;
            var selectionInfo = taskCount > 0 ? 
                $" SELECTED: {selectedIndex + 1}/{taskCount} TASKS " : 
                " NO ACTIVE TASKS ";
            screen.WriteAt(0, 3, "║".PadRight(bounds.Width - 1) + "║", HeaderColor, BackgroundColor);
            screen.WriteAt(2, 3, selectionInfo, HighlightColor, BackgroundColor);
            
            // MIDDLE BORDER
            var middleBorder = RenderOptimizer.BuildBorder(bounds.Width, BorderType.Middle);
            screen.WriteAt(0, 4, middleBorder, HeaderColor, BackgroundColor);
        }
        
        /// <summary>
        /// Render optimized task list with caching and single-call row rendering
        /// </summary>
        private void RenderOptimizedTaskList(ScreenBuffer screen, Rectangle bounds) {
            // EXCEL-STYLE COLUMN HEADERS - Fixed width columns  
            // PRI(3) | DUE(10) | ID1(4) | ID2(12) | TITLE(remaining) | TAGS(15)
            var headers = $"{"PRI",-3}│{"DUE DATE",-10}│{"ID1",-4}│{"ID2",-12}│{"TASK TITLE",-30}│{"TAGS",-15}";
            screen.WriteAt(bounds.X, bounds.Y, headers.PadRight(bounds.Width), ConsoleColor.Cyan, ConsoleColor.Black);
            
            // SEPARATOR LINE - Use optimized border builder
            var separator = RenderOptimizer.BuildBorder(bounds.Width, BorderType.Separator);
            screen.WriteAt(bounds.X, bounds.Y + 1, separator, ConsoleColor.Cyan, ConsoleColor.Black);
            
            // TASK ROWS with optimized rendering
            var taskBounds = new Rectangle(bounds.X, bounds.Y + 2, bounds.Width, bounds.Height - 2);
            
            if (base.Items == null || !base.Items.Any()) {
                // No tasks message
                var noTasksMsg = "[NO ACTIVE TASKS IN SYSTEM]";
                var msgX = taskBounds.X + (taskBounds.Width - noTasksMsg.Length) / 2;
                var msgY = taskBounds.Y + taskBounds.Height / 2;
                screen.WriteAt(msgX, msgY, noTasksMsg, SubtaskColor, BackgroundColor);
            } else {
                // Calculate visible items with scrolling
                var startIndex = Math.Max(0, base.SelectedIndex - taskBounds.Height / 2);
                var endIndex = Math.Min(base.Items.Count, startIndex + taskBounds.Height);
                
                for (int i = startIndex; i < endIndex && i < base.Items.Count; i++) {
                    var item = base.Items[i];
                    var displayIndex = i - startIndex;
                    var y = taskBounds.Y + displayIndex;
                    
                    if (y >= taskBounds.Y + taskBounds.Height) break;
                    
                    // OPTIMIZED ROW RENDERING - Single call with cached formatting
                    var isSelected = (base.SelectedIndex == i);
                    var bgColor = isSelected ? SelectionColor : BackgroundColor;
                    
                    if (isSelected) {
                        screen.FillRect(taskBounds.X, y, taskBounds.Width, 1, ' ', 
                                      ConsoleColor.White, SelectionColor);
                    }
                    
                    var rowText = GetOptimizedTaskRow(item);
                    screen.WriteAt(taskBounds.X, y, rowText.PadRight(taskBounds.Width), 
                                 GetEnhancedTaskColor(item), bgColor);
                }
            }
        }
        
        /// <summary>
        /// Get optimized task row with caching and StringBuilder pooling
        /// </summary>
        private string GetOptimizedTaskRow(TaskListItem item) {
            var task = item.Task;
            var cacheKey = task.Id;
            
            // Check cache validity
            if (taskDisplayCache.TryGetValue(cacheKey, out var cache) && 
                cache.IsValid && cache.LastModified >= task.ModifiedDate) {
                return cache.FormattedRow;
            }
            
            // Build optimized row with StringBuilder
            var sb = new System.Text.StringBuilder(120);
            
            // Column 1: Status (2 chars)
            var statusIcon = task.GetStatusIcon();
            sb.Append(PadRightFast(statusIcon, 2));
            sb.Append(" │");
            
            // Column 2: Priority (3 chars)
            var priorityIcon = task.GetCyberpunkPriority();
            sb.Append(PadRightFast(priorityIcon, 3));
            sb.Append(" │");
            
            // Column 3: Due Date (9 chars)
            var dateText = task.GetCyberpunkDate();
            sb.Append(PadRightFast(dateText, 9));
            sb.Append(" │");
            
            // Column 4: ID1 (7 chars)
            var id1Display = string.IsNullOrEmpty(task.ID1) ? "---" : task.ID1;
            sb.Append(PadRightFast(id1Display, 7));
            sb.Append(" │");
            
            // Column 5: ID2 (7 chars)
            var id2Display = string.IsNullOrEmpty(task.ID2) ? "---" : task.ID2;
            sb.Append(PadRightFast(id2Display, 7));
            sb.Append(" │");
            
            // Column 6: Title (32 chars)
            var title = task.Title ?? "";
            if (title.Length > 32) {
                title = title.Substring(0, 29) + "...";
            }
            sb.Append(PadRightFast(title, 32));
            sb.Append(" │");
            
            // Column 7: Tags
            if (task.Tags.Any()) {
                var tagText = string.Join(" ", task.Tags.Select(t => $"<{t}>"));
                sb.Append(tagText);
            }
            
            var formattedRow = sb.ToString();
            
            // Update cache
            taskDisplayCache[cacheKey] = new TaskDisplayCache {
                FormattedRow = formattedRow,
                LastModified = task.ModifiedDate,
                IsValid = true
            };
            
            return formattedRow;
        }
        
        /// <summary>
        /// Render unified status bar at bottom
        /// </summary>
        private void RenderUnifiedStatusBar(ScreenBuffer screen, Rectangle bounds) {
            // BOTTOM BORDER
            var bottomBorder = RenderOptimizer.BuildBorder(bounds.Width, BorderType.Bottom);
            screen.WriteAt(0, bounds.Y + 2, bottomBorder, HeaderColor, BackgroundColor);
            
            // STATUS CONTENT
            var selectedTask = base.SelectedItem?.Task;
            var leftStatus = selectedTask != null ? 
                           $" ACTIVE: {TruncateTitle(selectedTask.Title, 40)} " : 
                           " READY FOR INPUT ";
            screen.WriteAt(0, bounds.Y, "║".PadRight(bounds.Width - 1) + "║", HeaderColor, BackgroundColor);
            screen.WriteAt(2, bounds.Y, leftStatus, StatusGreen, BackgroundColor);
            
            // RIGHT STATUS
            var completedCount = StatusCompletedCount;
            var rightStatus = $" COMPLETED: {completedCount} | MODE:TASK_MGMT ";
            var rightX = bounds.Width - rightStatus.Length - 2;
            screen.WriteAt(rightX, bounds.Y, rightStatus, AmberText, BackgroundColor);
            
            // HELP LINE
            var helpText = " N:New │ E:Edit │ Enter:Notes │ Space:Complete │ T:Theme │ /:Filter │ Ctrl+Q:Quit ";
            screen.WriteAt(0, bounds.Y + 1, "║".PadRight(bounds.Width - 1) + "║", HeaderColor, BackgroundColor);
            var helpX = (bounds.Width - helpText.Length) / 2;
            screen.WriteAt(helpX, bounds.Y + 1, helpText, HintColor, BackgroundColor);
        }
        
        /// <summary>
        /// Render all overlay dialogs and UI elements
        /// </summary>
        private void RenderOverlays(ScreenBuffer screen, Rectangle bounds) {
            // Render professional inline editing overlay if active
            if (editingIndex >= 0) {
                RenderProfessionalInlineEditor(screen, bounds);
            }
            
            // Render inline editor if active (overlay on top)
            if (InlineEditor?.IsActive == true) {
                InlineEditor.Render(screen, bounds);
            }
            
            // Render tag editor if active (overlay on top)
            if (TagEditor?.IsActive == true) {
                TagEditor.Render(screen, bounds);
            }
            
            // Render task creation dialog if active (overlay on top of everything)
            if (TaskCreationDialog?.IsActive == true) {
                TaskCreationDialog.Render(screen, bounds);
            }
            
            // Render notes editor dialog if active (high priority overlay)
            if (NotesEditorDialog?.IsActive == true) {
                NotesEditorDialog.Render(screen, bounds);
            }
            
            // Render color picker dialog if active (highest priority overlay)
            if (ColorPickerDialog?.IsActive == true) {
                ColorPickerDialog.Render(screen, bounds);
            }
            
            // Render enhanced filter input with professional styling
            if (filterInputActive) {
                RenderEnhancedFilterInput(screen, bounds);
            }
            
            // Render status overlay for operations
            RenderStatusOverlay(screen, bounds);
        }
        
        // ENHANCED RENDERING METHODS FOR PROFESSIONAL UI
        
        private void RenderProfessionalInlineEditor(ScreenBuffer screen, Rectangle bounds) {
            if (editingIndex < 0 || editingTask == null) return;
            
            // CYBERPUNK INLINE EDITOR - Terminal computer interface
            var overlayWidth = Math.Min(bounds.Width - 6, 65);
            var overlayHeight = 15;
            var overlayX = bounds.X + (bounds.Width - overlayWidth) / 2;
            var overlayY = bounds.Y + 4;
            
            // Terminal shadow effect (classic computer style)
            for (int y = 1; y <= overlayHeight; y++) {
                for (int x = 2; x <= overlayWidth + 1; x++) {
                    if (overlayX + x < bounds.Width && overlayY + y < bounds.Height) {
                        screen.WriteAt(overlayX + x, overlayY + y, "▓", ConsoleColor.DarkGray, BackgroundColor);
                    }
                }
            }
            
            // Main terminal panel background
            screen.FillRect(overlayX, overlayY, overlayWidth, overlayHeight, ' ', 
                          AmberText, BackgroundColor);
            
            // Cyberpunk border
            DrawModernBorder(screen, overlayX, overlayY, overlayWidth, overlayHeight, HeaderColor);
            
            // Terminal header with classic styling
            var titleText = $"EDIT MODE - {TruncateTitle(editingTask.Title, 30)}";
            screen.WriteAt(overlayX + 2, overlayY + 1, titleText, AmberText, BackgroundColor);
            
            // System status indicator
            var statusText = "[SYSTEM: READY FOR INPUT]";
            screen.WriteAt(overlayX + 2, overlayY + 2, statusText, StatusGreen, BackgroundColor);
            
            // Field editing area with terminal styling
            var fieldY = overlayY + 4;
            var fieldNames = new[] { "priority", "date", "title", "id1", "id2", "tags", "notes" };
            var fieldLabels = new[] { "PRIORITY", "DUE DATE", "TASK TITLE", "PROJECT ID1", "PROJECT ID2", "TAGS", "NOTES" };
            
            for (int i = 0; i < fieldNames.Length; i++) {
                var field = fieldNames[i];
                var isActive = field == editingField;
                var label = fieldLabels[i];
                
                // Terminal field label with brackets
                var labelColor = isActive ? AmberText : DataBlue;
                var labelText = isActive ? $">{label}:" : $" {label}:";
                screen.WriteAt(overlayX + 2, fieldY, labelText, labelColor, BackgroundColor);
                
                // Field value with cyberpunk input styling
                var valueX = overlayX + 14;
                var valueWidth = overlayWidth - 16;
                var displayValue = GetFieldDisplayValue(field);
                
                if (isActive) {
                    // Active field with cyberpunk highlight
                    screen.WriteAt(valueX - 1, fieldY, "[", HeaderColor, BackgroundColor);
                    screen.FillRect(valueX, fieldY, valueWidth - 2, 1, ' ', BackgroundColor, HeaderColor);
                    screen.WriteAt(valueX + valueWidth - 2, fieldY, "]", HeaderColor, BackgroundColor);
                    
                    var truncatedValue = displayValue.Length > valueWidth - 4 ? 
                                       displayValue.Substring(0, valueWidth - 4) : displayValue;
                    screen.WriteAt(valueX, fieldY, truncatedValue.PadRight(valueWidth - 2), 
                                 BackgroundColor, HeaderColor);
                    
                    // Professional terminal cursor with enhanced animation
                    var cursorVisible = (DateTime.Now.Millisecond / 300) % 2 == 0;
                    if (cursorVisible) {
                        var cursorX = valueX + Math.Min(editingValue.Length, valueWidth - 3);
                        screen.WriteAt(cursorX, fieldY, "█", AmberText, HeaderColor);
                    }
                    
                    // Field validation indicator
                    var isValidInput = ValidateFieldInput(editingField, editingValue);
                    var indicatorChar = isValidInput ? "✓" : "⚠";
                    var indicatorColor = isValidInput ? StatusGreen : DangerRed;
                    screen.WriteAt(valueX + valueWidth - 1, fieldY, indicatorChar, indicatorColor, HeaderColor);
                } else {
                    // Inactive field with terminal styling
                    screen.WriteAt(valueX - 1, fieldY, "[", DataBlue, BackgroundColor);
                    screen.FillRect(valueX, fieldY, valueWidth - 2, 1, ' ', BackgroundColor, BackgroundColor);
                    screen.WriteAt(valueX + valueWidth - 2, fieldY, "]", DataBlue, BackgroundColor);
                    
                    var truncatedValue = displayValue.Length > valueWidth - 4 ? 
                                       displayValue.Substring(0, valueWidth - 4) : displayValue;
                    screen.WriteAt(valueX, fieldY, truncatedValue, SubtaskColor, BackgroundColor);
                }
                
                fieldY += 2;
            }
            
            // Enhanced terminal command help with real-time field guidance
            var helpY = overlayY + overlayHeight - 3;
            screen.WriteAt(overlayX + 2, helpY, "COMMANDS:", DataBlue, BackgroundColor);
            
            // Dynamic help text based on current field
            var fieldHelp = GetFieldHelpText(editingField);
            var commandHelp = "TAB=NEXT FIELD  ENTER=SAVE  ESC=ABORT";
            screen.WriteAt(overlayX + 2, helpY + 1, commandHelp, StatusGreen, BackgroundColor);
            
            // Field-specific help on the right
            if (!string.IsNullOrEmpty(fieldHelp)) {
                var helpX = overlayX + overlayWidth - fieldHelp.Length - 2;
                if (helpX > overlayX + commandHelp.Length + 4) {
                    screen.WriteAt(helpX, helpY + 1, fieldHelp, HeaderColor, BackgroundColor);
                }
            }
        }
        
        private void RenderEnhancedFilterInput(ScreenBuffer screen, Rectangle bounds) {
            var filterY = bounds.Y + bounds.Height - 1;
            
            // CYBERPUNK FILTER INPUT - Terminal command line style
            screen.FillRect(bounds.X, filterY, bounds.Width, 1, ' ', AmberText, BackgroundColor);
            
            // Classic terminal prompt
            var filterPrompt = "FILTER> ";
            screen.WriteAt(bounds.X + 1, filterY, filterPrompt, StatusGreen, BackgroundColor);
            
            // Terminal input field with cyberpunk styling
            var inputX = bounds.X + filterPrompt.Length + 1;
            var inputWidth = Math.Min(25, bounds.Width - inputX - 40);
            
            // Input field with terminal brackets
            screen.WriteAt(inputX - 1, filterY, "[", HeaderColor, BackgroundColor);
            screen.FillRect(inputX, filterY, inputWidth, 1, ' ', BackgroundColor, HeaderColor);
            screen.WriteAt(inputX + inputWidth, filterY, "]", HeaderColor, BackgroundColor);
            
            // Input text with classic green terminal color
            var displayText = filterInputValue.Length > inputWidth - 1 ? 
                            filterInputValue.Substring(0, inputWidth - 1) : filterInputValue;
            screen.WriteAt(inputX, filterY, displayText.PadRight(inputWidth), 
                         StatusGreen, BackgroundColor);
            
            // Classic terminal cursor (blinking block)
            if ((DateTime.Now.Millisecond / 500) % 2 == 0) {
                var cursorX = inputX + Math.Min(filterInputCursor, inputWidth - 1);
                screen.WriteAt(cursorX, filterY, "█", AmberText, BackgroundColor);
            }
            
            // Terminal-style help text
            var helpText = "SYNTAX: #tag | high/med/low | today | clear";
            var helpX = inputX + inputWidth + 4;
            if (helpX + helpText.Length < bounds.Width) {
                screen.WriteAt(helpX, filterY, helpText, DataBlue, BackgroundColor);
            }
        }
        
        private void RenderStatusOverlay(ScreenBuffer screen, Rectangle bounds) {
            // CYBERPUNK STATUS OVERLAY - Terminal computer feedback
            if (editingIndex >= 0) {
                var statusY = bounds.Y + bounds.Height - 3;
                var statusText = $"[EDIT MODE ACTIVE] FIELD: {editingField?.ToUpper() ?? "NONE"}";
                screen.WriteAt(bounds.X + 2, statusY, statusText, AmberText, BackgroundColor);
            }
        }
        
        
        // MULTI-COLOR CYBERPUNK TASK RENDERING - Each column gets appropriate colors
        private void RenderCyberpunkTaskRow(ScreenBuffer screen, Rectangle bounds, int y, TaskListItem item, ConsoleColor bgColor) {
            var task = item.Task;
            
            // EXCEL-STYLE ROW with exact column alignment
            // PRI(3) | DUE(10) | ID1(4) | ID2(12) | TITLE(30) | TAGS(15)
            
            // Column 1: Priority (3 chars)
            var priorityIcon = task.GetCyberpunkPriority();
            var priorityCol = priorityIcon.PadRight(3).Substring(0, 3);
            var priorityColor = task.Priority switch {
                Priority.Today => ConsoleColor.Red,
                Priority.High => HighPriorityColor,
                Priority.Medium => MediumPriorityColor,
                Priority.Low => LowPriorityColor,
                _ => AmberText
            };
            
            // OPTIMIZED ROW BUILDING - Use StringBuilder pooling for performance
            var sb = RenderOptimizer.GetStringBuilder();
            
            // Column 1: Priority (3 chars) - with color
            var priorityText = RenderOptimizer.PadRightFast(priorityCol, 3);
            sb.Append(priorityText).Append('│');
            
            // Column 2: Due Date (10 chars) 
            var dateText = task.GetCyberpunkDate();
            var dateCol = RenderOptimizer.PadRightFast(dateText, 10);
            sb.Append(dateCol).Append('│');
            
            // Column 3: ID1 (4 chars)
            var id1Display = string.IsNullOrEmpty(task.ID1) ? "" : task.ID1;
            var id1Col = RenderOptimizer.PadRightFast(id1Display, 4);
            sb.Append(id1Col).Append('│');
            
            // Column 4: ID2 (12 chars)
            var id2Display = string.IsNullOrEmpty(task.ID2) ? "" : task.ID2;
            var id2Col = RenderOptimizer.PadRightFast(id2Display, 12);
            sb.Append(id2Col).Append('│');
            
            // Column 5: Title (30 chars)
            var title = task.Title ?? "";
            var titleCol = RenderOptimizer.PadRightFast(title, 30);
            sb.Append(titleCol).Append('│');
            
            // Column 6: Tags (15 chars)
            var tagsText = string.Join(",", task.Tags.Take(3));
            var tagsCol = RenderOptimizer.PadRightFast(tagsText, 15);
            sb.Append(tagsCol);
            
            // SINGLE ALLOCATION ROW - Much faster than string interpolation
            var rowText = sb.ToString();
            screen.WriteAt(bounds.X, y, rowText, ConsoleColor.White, bgColor);
        }
        
        private ConsoleColor GetDateDisplayColor(DateTime dueDate) {
            if (dueDate == DateTime.MinValue) return SubtaskColor;
            
            var today = DateTime.Today;
            var daysDiff = (dueDate.Date - today).Days;
            
            return daysDiff switch {
                < 0 => DangerRed,       // Overdue - bright red
                0 => TodayPriorityColor, // Today - magenta
                <= 7 => HeaderColor,     // This week - cyan
                _ => StatusGreen         // Future - green
            };
        }
        
        // ENHANCED TASK COLOR SYSTEM - Professional cyberpunk aesthetic
        private ConsoleColor GetEnhancedTaskColor(TaskListItem item) {
            var task = item.Task;
            
            // Completed tasks in dim color
            if (task.Completed) {
                return SubtaskColor;
            }
            
            // Use task's existing color system - no external dependencies
            
            // Enhanced priority-based cyberpunk colors
            return task.Priority switch {
                Priority.Today => DangerRed,      // Critical today tasks - bright red
                Priority.High => AmberText,       // High priority - classic amber terminal
                Priority.Medium => HeaderColor,   // Medium priority - cyan
                Priority.Low => StatusGreen,      // Low priority - green
                _ => AmberText                    // Default amber
            };
        }
        
        // CYBERPUNK BORDER DRAWING - Professional terminal aesthetic
        private void DrawCyberpunkBorder(ScreenBuffer screen, int x, int y, int width, int height) {
            // CLASSIC CYBERPUNK TERMINAL BORDER - Like the game screenshots
            var borderColor = BorderColor;
            
            // Top border with classic terminal styling
            screen.WriteAt(x, y, "╔", borderColor, BackgroundColor);
            for (int i = 1; i < width - 1; i++) {
                screen.WriteAt(x + i, y, "═", borderColor, BackgroundColor);
            }
            screen.WriteAt(x + width - 1, y, "╗", borderColor, BackgroundColor);
            
            // Side borders
            for (int i = 1; i < height - 1; i++) {
                screen.WriteAt(x, y + i, "║", borderColor, BackgroundColor);
                screen.WriteAt(x + width - 1, y + i, "║", borderColor, BackgroundColor);
            }
            
            // Bottom border
            screen.WriteAt(x, y + height - 1, "╚", borderColor, BackgroundColor);
            for (int i = 1; i < width - 1; i++) {
                screen.WriteAt(x + i, y + height - 1, "═", borderColor, BackgroundColor);
            }
            screen.WriteAt(x + width - 1, y + height - 1, "╝", borderColor, BackgroundColor);
        }
        
        private void DrawModernBorder(ScreenBuffer screen, int x, int y, int width, int height, ConsoleColor color) {
            // Cyberpunk-style border with specified color
            screen.WriteAt(x, y, "╔", color, BackgroundColor);
            for (int i = 1; i < width - 1; i++) {
                screen.WriteAt(x + i, y, "═", color, BackgroundColor);
            }
            screen.WriteAt(x + width - 1, y, "╗", color, BackgroundColor);
            
            for (int i = 1; i < height - 1; i++) {
                screen.WriteAt(x, y + i, "║", color, BackgroundColor);
                screen.WriteAt(x + width - 1, y + i, "║", color, BackgroundColor);
            }
            
            screen.WriteAt(x, y + height - 1, "╚", color, BackgroundColor);
            for (int i = 1; i < width - 1; i++) {
                screen.WriteAt(x + i, y + height - 1, "═", color, BackgroundColor);
            }
            screen.WriteAt(x + width - 1, y + height - 1, "╝", color, BackgroundColor);
        }
        
        private string GetFieldDisplayValue(string field) {
            if (editingTask == null) return "";
            
            if (field == editingField) {
                return editingValue ?? "";
            }
            
            return field switch {
                "priority" => editingTask.Priority switch {
                    Priority.High => "High",
                    Priority.Medium => "Medium",
                    Priority.Low => "Low", 
                    Priority.Today => "Today",
                    _ => "Medium"
                },
                "date" => editingTask.DueDate != DateTime.MinValue ? editingTask.DueDate.ToString("yyyy-MM-dd") : "",
                "title" => editingTask.Title ?? "",
                "tags" => string.Join(", ", editingTask.Tags),
                "id1" => editingTask.ID1 ?? "",
                "id2" => editingTask.ID2 ?? "",
                "notes" => editingTask.Notes ?? "",
                "status" => editingTask.Completed ? "Completed" : "Pending",
                _ => ""
            };
        }
        
        
        public string GetFilterStatusText() {
            // EXACT feature parity with standalone header display
            string headerText = "TASKPRO - Task Manager";
            if (currentFilterMode != "All") {
                headerText += $" [Filter: {currentFilterMode}]";
            }
            if (tagFilter != "") {
                headerText += $" [Tag: #{tagFilter}]";
            }
            return headerText;
        }
        
        // CYBERPUNK FILTER STATUS - Terminal computer style
        private string GetCyberpunkFilterStatus() {
            var status = "";
            if (currentFilterMode != "All") {
                status += $"[FLT:{currentFilterMode.ToUpper()}]";
            }
            if (tagFilter != "") {
                status += $"[TAG:{tagFilter.ToUpper()}]";
            }
            return status;
        }
        
        // ENHANCED INLINE EDITING SYSTEM - Professional UI and Visual Feedback
        private Dictionary<string, string> fieldDisplayNames = new Dictionary<string, string>
        {
            ["priority"] = "PRIORITY",
            ["date"] = "DUE DATE", 
            ["title"] = "TASK TITLE",
            ["tags"] = "TAGS",
            ["id1"] = "PROJECT ID1",
            ["id2"] = "PROJECT ID2",
            ["notes"] = "NOTES"
        };
        
        private Dictionary<string, ConsoleColor> fieldColors = new Dictionary<string, ConsoleColor>
        {
            ["priority"] = ConsoleColor.Red,
            ["date"] = ConsoleColor.Cyan,
            ["title"] = ConsoleColor.Yellow,
            ["tags"] = ConsoleColor.Magenta,
            ["id1"] = ConsoleColor.Green,
            ["id2"] = ConsoleColor.Blue,
            ["notes"] = ConsoleColor.White
        };
        
        // PROFESSIONAL VALIDATION AND HELP SYSTEM
        
        private bool ValidateFieldInput(string field, string value) {
            if (string.IsNullOrEmpty(value)) return true; // Empty is often valid
            
            return field switch {
                "priority" => "hmlt".Contains(value.ToLower()) && value.Length == 1,
                "date" => IsValidDateFormat(value),
                "title" => value.Length <= 100 && !string.IsNullOrWhiteSpace(value),
                "tags" => value.Length <= 200,
                "id1" => value.Length <= 20 && !value.Contains(' '),
                "id2" => value.Length <= 20 && !value.Contains(' '),
                "notes" => value.Length <= 1000,
                _ => true
            };
        }
        
        private string GetFieldHelpText(string field) {
            return field switch {
                "priority" => "h/m/l/t",
                "date" => "yyyy-mm-dd or t/tom/mon",
                "title" => "Task description",
                "tags" => "tag1, tag2, tag3",
                "id1" => "Project code",
                "id2" => "Sub-project",
                "notes" => "Additional details",
                _ => ""
            };
        }
        
        private bool IsValidDateFormat(string input) {
            if (string.IsNullOrWhiteSpace(input)) return true;
            
            input = input.Trim().ToLower();
            
            // Quick shortcuts are always valid
            if (new[] { "t", "today", "tom", "tomorrow", "mon", "tue", "wed", "thu", "fri", "sat", "sun" }.Contains(input))
                return true;
                
            // Relative dates
            if (input.StartsWith("+") && input.Length > 1) {
                var numberPart = input.Substring(1);
                if (numberPart.EndsWith("w") && int.TryParse(numberPart.Substring(0, numberPart.Length - 1), out _))
                    return true;
                if (int.TryParse(numberPart, out _))
                    return true;
            }
            
            // Regular date parsing
            return DateTime.TryParse(input, out _);
        }
        
        // PROFESSIONAL INLINE EDITING METHODS
        
        private void StartInlineEdit() {
            if (!base.HasSelection) return;
            
            var item = base.SelectedItem;
            editingIndex = base.SelectedIndex;
            editingTask = item.Task;
            editingField = "priority";  // Start with priority (leftmost)
            
            // Preserve existing priority when starting edit
            editingValue = editingTask.Priority switch {
                Priority.High => "h",
                Priority.Medium => "m",
                Priority.Low => "l",
                Priority.Today => "t",
                _ => ""
            };
            isNewTask = false;
        }
        
        private void StartInlineAdd() {
            // Create new task and add to list for immediate editing
            var newTask = new SimpleTask {
                Title = "",
                Priority = Priority.Medium
            };
            
            var newItem = new TaskListItem { Task = newTask };
            var items = base.Items.ToList();
            items.Add(newItem);
            base.Items = items;
            
            editingIndex = items.Count - 1;
            editingTask = newTask;
            editingField = "title";  // Start with title for immediate input
            editingValue = "";
            base.SelectItemByPredicate(item => item == newItem);
            isNewTask = true;
        }
        
        private void StartInlineSubtask() {
            if (!base.HasSelection) return;
            
            // Create new subtask under current task
            var parentTask = base.SelectedItem.Task;
            var newSubtask = new SimpleTask {
                Title = "",
                Priority = Priority.Medium,
                ParentId = parentTask.Id
            };
            
            // Add to parent's subtasks
            parentTask.Subtasks.Add(newSubtask);
            
            // Refresh list and find the new subtask
            RefreshList(true);
            
            // Find the new subtask in the list
            for (int i = 0; i < base.Items.Count; i++) {
                if (base.Items[i].Task.Id == newSubtask.Id) {
                    editingIndex = i;
                    editingTask = newSubtask;
                    editingField = "title";
                    editingValue = "";
                    base.SelectItemByPredicate(item => item.Task.Id == newSubtask.Id);
                    isNewTask = true;
                    break;
                }
            }
        }
        
        private bool HandleEditingInput(InputEvent input) {
            // EXACT feature parity with standalone editing input handling
            
            if (input.IsEnter) {
                SaveInlineEdit();
                return true;
            }
            
            if (input.IsEscape) {
                CancelInlineEdit();
                return true;
            }
            
            if (input.IsTab) {
                if (input.Shift) {
                    PreviousEditField();
                } else {
                    NextEditField();
                }
                return true;
            }
            
            if (input.IsArrowUp) {
                // Save and move to previous task
                SaveInlineEdit();
                if (editingIndex > 0) {
                    // Move to previous item by index
                    if (editingIndex - 1 < base.Items.Count) {
                        base.SelectItem(base.Items[editingIndex - 1]);
                    }
                    StartInlineEdit();
                }
                return true;
            }
            
            if (input.IsArrowDown) {
                // Save and move to next task
                SaveInlineEdit();
                if (editingIndex < base.Items.Count - 1) {
                    // Move to next item by index
                    if (editingIndex + 1 < base.Items.Count) {
                        base.SelectItem(base.Items[editingIndex + 1]);
                    }
                    StartInlineEdit();
                }
                return true;
            }
            
            if (input.IsBackspace) {
                if (editingValue.Length > 0) {
                    editingValue = editingValue.Substring(0, editingValue.Length - 1);
                }
                return true;
            }
            
            if (input.IsDelete) {
                // Clear current field
                editingValue = "";
                return true;
            }
            
            // Regular character input with field-specific validation
            if (input.IsPrintableChar && !input.Ctrl && !input.Alt) {
                string newValue = editingValue + input.Char;
                
                // Validate input based on field type
                bool isValid = editingField switch {
                    "priority" => newValue.Length <= 1 && "hmlt".Contains(newValue.ToLower()),
                    "date" => IsValidDateInput(newValue),
                    "title" => newValue.Length <= 100,
                    "tags" => newValue.Length <= 200,
                    "id1" => newValue.Length <= 20,
                    "id2" => newValue.Length <= 20,
                    "notes" => newValue.Length <= 1000,
                    _ => true
                };
                
                if (isValid) {
                    editingValue = newValue;
                }
                return true;
            }
            
            return false;
        }
        
        private bool IsValidDateInput(string input) {
            // Allow various date formats and shortcuts
            return input.Length <= 20; // Basic length check for now
        }
        
        private void NextEditField() {
            // Save current field value and move to next field - EXACT feature parity
            ApplyCurrentFieldValue();
            
            editingField = editingField switch {
                "priority" => "date",
                "date" => "title", 
                "title" => "id1",
                "id1" => "id2",
                "id2" => "tags",
                "tags" => "notes",
                "notes" => "priority",
                _ => "priority"
            };
            
            LoadFieldValue();
        }
        
        private void PreviousEditField() {
            // Save current field value and move to previous field - EXACT feature parity
            ApplyCurrentFieldValue();
            
            editingField = editingField switch {
                "priority" => "notes",
                "date" => "priority",
                "title" => "date",
                "id1" => "title",
                "id2" => "id1",
                "tags" => "id2",
                "notes" => "tags",
                _ => "priority"
            };
            
            LoadFieldValue();
        }
        
        private void ApplyCurrentFieldValue() {
            if (editingTask == null) return;
            
            // Allow empty values for some fields
            var trimmedValue = editingValue?.Trim() ?? "";
            
            switch (editingField) {
                case "title":
                    if (!string.IsNullOrWhiteSpace(trimmedValue)) {
                        editingTask.Title = trimmedValue;
                    }
                    break;
                case "priority":
                    if (!string.IsNullOrWhiteSpace(trimmedValue)) {
                        editingTask.Priority = ConvertPriorityInput(trimmedValue);
                    }
                    break;
                case "date":
                    editingTask.DueDate = ConvertDateInput(trimmedValue);
                    break;
                case "tags":
                    var tagParts = trimmedValue.Split(',').Select(t => t.Trim()).Where(t => !string.IsNullOrEmpty(t)).ToList();
                    editingTask.Tags = tagParts;
                    break;
                case "id1":
                    editingTask.ID1 = trimmedValue;
                    break;
                case "id2":
                    editingTask.ID2 = trimmedValue;
                    break;
                case "notes":
                    editingTask.Notes = editingValue ?? ""; // Keep original formatting for notes
                    break;
            }
        }
        
        private void LoadFieldValue() {
            // Load current field value for editing - EXACT feature parity
            editingValue = editingField switch {
                "priority" => editingTask.Priority switch {
                    Priority.High => "h",
                    Priority.Medium => "m",
                    Priority.Low => "l",
                    Priority.Today => "t",
                    _ => "m"
                },
                "date" => editingTask.DueDate != DateTime.MinValue ? editingTask.DueDate.ToString("yyyy-MM-dd") : "",
                "title" => editingTask.Title ?? "",
                "tags" => string.Join(", ", editingTask.Tags),
                "id1" => editingTask.ID1 ?? "",
                "id2" => editingTask.ID2 ?? "",
                "notes" => editingTask.Notes ?? "",
                _ => ""
            };
        }
        
        private Priority ConvertPriorityInput(string input) {
            // Convert h/m/l/t input to Priority enum - EXACT feature parity
            return input.ToLower().Trim() switch {
                "h" => Priority.High,
                "m" => Priority.Medium,
                "l" => Priority.Low,
                "t" => Priority.Today,
                _ => Priority.Medium
            };
        }
        
        private DateTime ConvertDateInput(string input) {
            // Enhanced date input with shortcuts - EXACT feature parity
            input = input.Trim().ToLower();
            if (string.IsNullOrEmpty(input)) return DateTime.MinValue;
            
            var today = DateTime.Today;
            
            // Quick shortcuts
            return input switch {
                "t" or "today" => today,
                "tom" or "tomorrow" => today.AddDays(1),
                "mon" => GetNextWeekday(DayOfWeek.Monday),
                "tue" => GetNextWeekday(DayOfWeek.Tuesday),
                "wed" => GetNextWeekday(DayOfWeek.Wednesday),
                "thu" => GetNextWeekday(DayOfWeek.Thursday),
                "fri" => GetNextWeekday(DayOfWeek.Friday),
                "sat" => GetNextWeekday(DayOfWeek.Saturday),
                "sun" => GetNextWeekday(DayOfWeek.Sunday),
                _ => ParseComplexDate(input)
            };
        }
        
        private DateTime GetNextWeekday(DayOfWeek targetDay) {
            var today = DateTime.Today;
            int daysUntilTarget = ((int)targetDay - (int)today.DayOfWeek + 7) % 7;
            if (daysUntilTarget == 0) daysUntilTarget = 7; // Next week if today is the target day
            return today.AddDays(daysUntilTarget);
        }
        
        private DateTime ParseComplexDate(string input) {
            var today = DateTime.Today;
            
            // Relative dates (+3, +1w, etc.)
            if (input.StartsWith("+") && input.Length > 1) {
                var numberPart = input.Substring(1);
                if (numberPart.EndsWith("w") && int.TryParse(numberPart.Substring(0, numberPart.Length - 1), out int weeks)) {
                    return today.AddDays(weeks * 7);
                }
                if (int.TryParse(numberPart, out int days)) {
                    return today.AddDays(days);
                }
            }
            
            // Try to parse as regular date
            if (DateTime.TryParse(input, out DateTime result)) {
                return result;
            }
            
            return DateTime.MinValue;
        }
        
        private void SaveInlineEdit() {
            // Apply final field value and save - EXACT feature parity
            ApplyCurrentFieldValue();
            
            if (isNewTask) {
                if (!string.IsNullOrWhiteSpace(editingTask.Title)) {
                    // Save new task
                    TaskManager?.AddTask(editingTask);
                } else {
                    // Remove empty new task
                    var items = base.Items.ToList();
                    items.RemoveAt(editingIndex);
                    base.Items = items;
                }
            } else {
                // Update existing task
                TaskManager?.UpdateTask(editingTask);
            }
            
            EndInlineEdit();
            RefreshList(true);
        }
        
        private void CancelInlineEdit() {
            // Cancel editing and remove new task if needed - EXACT feature parity
            if (isNewTask) {
                var items = base.Items.ToList();
                if (editingIndex >= 0 && editingIndex < items.Count) {
                    items.RemoveAt(editingIndex);
                    base.Items = items;
                    
                    if (base.SelectedIndex >= items.Count) {
                        if (items.Count > 0) {
                            base.SelectItem(items[Math.Max(0, items.Count - 1)]);
                        }
                    }
                }
            }
            
            EndInlineEdit();
        }
        
        private void EndInlineEdit() {
            // Clear editing state - EXACT feature parity
            editingIndex = -1;
            editingField = "";
            editingValue = "";
            editingTask = null;
            isNewTask = false;
        }
        
        // INLINE OPTIMIZATION HELPERS - High performance rendering utilities
        
        /// <summary>
        /// Fast string padding with zero allocation for small sizes
        /// </summary>
        private static string PadRightFast(string input, int totalWidth) {
            if (input.Length >= totalWidth) 
                return input.Substring(0, totalWidth);
                
            return input.PadRight(totalWidth);
        }
        
        /// <summary>
        /// Build professional box drawing border inline
        /// </summary>
        
        /// <summary>
        /// Cache class for optimized task display data
        /// </summary>
        public class TaskDisplayCache {
            public string FormattedRow { get; set; } = "";
            public DateTime LastModified { get; set; } = DateTime.MinValue;
            public bool IsValid { get; set; } = false;
        }
    }
}