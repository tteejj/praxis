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
        
        // Colors
        public ConsoleColor HeaderColor { get; set; } = ConsoleColor.Cyan;
        public ConsoleColor HighPriorityColor { get; set; } = ConsoleColor.Red;
        public ConsoleColor MediumPriorityColor { get; set; } = ConsoleColor.Yellow;
        public ConsoleColor LowPriorityColor { get; set; } = ConsoleColor.Green;
        public ConsoleColor TodayPriorityColor { get; set; } = ConsoleColor.Magenta;
        public ConsoleColor SubtaskColor { get; set; } = ConsoleColor.Gray;
        public ConsoleColor TagColor { get; set; } = ConsoleColor.DarkGray;
        
        // State
        private List<TaskListItem> cachedFlatList = new List<TaskListItem>();
        private string lastFilterHash = "";
        
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
        }
        
        // Task formatting for the base ListWidget
        private string FormatTaskItem(TaskListItem item) {
            var task = item.Task;
            var level = item.Level;
            
            // Build the formatted string for this task
            var result = "";
            
            // Status icon (☐ or ■)
            var statusIcon = task.Completed ? "■" : "☐";
            result += statusIcon + " ";
            
            // Priority indicator
            var priorityChar = GetPriorityChar(task.Priority);
            result += priorityChar + " ";
            
            // Due date
            var dueDateText = FormatDueDate(task.DueDate);
            result += dueDateText.PadRight(11) + " ";
            
            // Tree indentation for subtasks
            if (level == 1) {
                result += "    └─ ";
            }
            
            // Task title
            result += task.Title;
            
            // Tags (if any)
            if (task.Tags.Any()) {
                result += " ⟨" + string.Join(", ", task.Tags) + "⟩";
            }
            
            return result;
        }
        
        // Color provider for tasks
        private ConsoleColor GetTaskItemColor(TaskListItem item) {
            var task = item.Task;
            
            if (task.Completed) {
                return ConsoleColor.DarkGray;
            }
            
            return GetPriorityColor(task.Priority);
        }
        
        // Input Handling
        public new bool HandleInput(InputEvent input) {
            // Check if notes editor dialog is active first (highest priority)
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
                ToggleTheme();
                return true;
            }
            
            if (input.Key == ConsoleKey.R) {
                EditTags();
                return true;
            }
            
            if (input.Key == ConsoleKey.E) {
                StartInlineEditTitle();
                return true;
            }
            
            if (input.Key == ConsoleKey.P) {
                StartInlineEditPriority();
                return true;
            }
            
            if (input.Key == ConsoleKey.U) {
                StartInlineEditDueDate();
                return true;
            }
            
            if (input.Key == ConsoleKey.R) {
                StartTagEditor();
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
        
        private void ToggleTheme() {
            // Implementation for theme toggling
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
            var filteredTasks = FilterTasks(allTasks);
            
            // Convert to display items
            var items = new List<TaskListItem>();
            foreach (var task in filteredTasks) {
                items.Add(new TaskListItem { Task = task });
            }
            
            base.Items = items;
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
        
        // Render method to include editor overlays
        public new void Render(Core.ScreenBuffer screen, Core.Rectangle bounds) {
            // Render the base list widget
            base.Render(screen, bounds);
            
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
            
            // Render notes editor dialog if active (highest priority overlay)
            if (NotesEditorDialog?.IsActive == true) {
                NotesEditorDialog.Render(screen, bounds);
            }
            
            // Render filter input if active - EXACT feature parity with standalone
            if (filterInputActive) {
                RenderFilterInput(screen, bounds);
            }
        }
        
        private void RenderFilterInput(ScreenBuffer screen, Rectangle bounds) {
            // EXACT feature parity with standalone filter input rendering
            int filterY = bounds.Y + bounds.Height - 1;
            
            // Clear the line first
            screen.FillRect(0, filterY, bounds.Width, 1, ' ', ConsoleColor.Gray, ConsoleColor.Black);
            
            // Show filter input as a proper textbox
            string filterPrompt = "Filter: ";
            screen.WriteAt(0, filterY, filterPrompt, TagColor);
            
            // Show the input text with cursor
            int inputX = filterPrompt.Length;
            if (!string.IsNullOrEmpty(filterInputValue)) {
                screen.WriteAt(inputX, filterY, filterInputValue, ConsoleColor.White);
            }
            
            // Position cursor at current input position
            int cursorX = inputX + filterInputCursor;
            if (cursorX < bounds.Width) {
                // Show a visible cursor character
                char cursorChar = cursorX < inputX + filterInputValue.Length ? filterInputValue[filterInputCursor] : ' ';
                screen.WriteAt(cursorX, filterY, cursorChar.ToString(), ConsoleColor.Black, ConsoleColor.White);
            }
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
        
        // INLINE EDITING METHODS - EXACT feature parity with standalone
        
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
                    "status" => newValue.Length <= 1,
                    "priority" => newValue.Length <= 1 && "hmlt".Contains(newValue.ToLower()),
                    "date" => IsValidDateInput(newValue),
                    "title" => newValue.Length <= 100,
                    "tags" => newValue.Length <= 200,
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
                "title" => "tags",
                "tags" => "priority",
                _ => "priority"
            };
            
            LoadFieldValue();
        }
        
        private void PreviousEditField() {
            // Save current field value and move to previous field - EXACT feature parity
            ApplyCurrentFieldValue();
            
            editingField = editingField switch {
                "priority" => "tags",
                "date" => "priority",
                "title" => "date",
                "tags" => "title",
                _ => "priority"
            };
            
            LoadFieldValue();
        }
        
        private void ApplyCurrentFieldValue() {
            if (string.IsNullOrWhiteSpace(editingValue)) return;
            
            switch (editingField) {
                case "title":
                    editingTask.Title = editingValue.Trim();
                    break;
                case "priority":
                    editingTask.Priority = ConvertPriorityInput(editingValue);
                    break;
                case "date":
                    editingTask.DueDate = ConvertDateInput(editingValue);
                    break;
                case "tags":
                    var tagParts = editingValue.Split(',').Select(t => t.Trim()).Where(t => !string.IsNullOrEmpty(t)).ToList();
                    editingTask.Tags = tagParts;
                    break;
                case "status":
                    editingTask.Completed = editingValue.ToLower().Contains("x") || editingValue.Contains("■");
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
                    _ => ""
                },
                "date" => editingTask.DueDate != DateTime.MinValue ? editingTask.DueDate.ToString("yyyy-MM-dd") : "",
                "title" => editingTask.Title,
                "tags" => string.Join(", ", editingTask.Tags),
                "status" => editingTask.Completed ? "■" : "☐",
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
    }
}