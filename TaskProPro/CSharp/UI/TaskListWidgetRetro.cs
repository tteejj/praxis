using System;
using System.Collections.Generic;
using System.Linq;
using TaskPro.Core;
using TaskPro.Data;

namespace TaskPro.UI
{
    /// <summary>
    /// RETRO CYBERPUNK TASK LIST WIDGET - Pure 80s terminal aesthetic
    /// Alternative to the Unicode-heavy TaskListWidget for authentic retro feel
    /// Features: ASCII-only borders, background highlights, Matrix-style colors
    /// </summary>
    public class TaskListWidgetRetro : ListWidget<TaskListItem>
    {
        // RETRO RENDERER - Pure ASCII + background highlights
        private readonly TaskListRendererRetro retroRenderer;
        
        // Core dependencies
        public TaskManager TaskManager { get; set; }
        public StatusBar StatusBar { get; set; }
        public FilterCriteria CurrentFilter { get; set; } = new FilterCriteria();
        
        // Display state
        private List<TaskListItem> cachedItems = new List<TaskListItem>();
        private string lastFilterHash = "";
        
        // RETRO MODE SETTINGS - Customize the cyberpunk experience
        public bool GlitchEffectEnabled { get; set; } = false;      // ASCII glitch for critical tasks
        public bool MatrixModeEnabled { get; set; } = true;         // Green Matrix-style colors
        public bool BladeRunnerModeEnabled { get; set; } = false;   // Cyan/Magenta Blade Runner style
        public bool TerminalScanlines { get; set; } = false;        // Simulate CRT scanlines
        
        /// <summary>
        /// Initialize retro cyberpunk task list widget
        /// </summary>
        public TaskListWidgetRetro()
        {
            // Initialize retro renderer
            retroRenderer = new TaskListRendererRetro();
            
            // Apply retro color theme
            ApplyRetroTheme();
            
            // Configure base widget for retro operation
            base.ShowPillboxSelection = false; // We handle selection with ASCII
            
            // Set up retro-specific formatting
            base.ItemFormatter = item => FormatItemRetroStyle(item);
            base.ItemColorProvider = GetRetroItemColor;
        }
        
        /// <summary>
        /// Apply cyberpunk color theme based on mode settings
        /// </summary>
        private void ApplyRetroTheme()
        {
            if (MatrixModeEnabled)
            {
                // Matrix green theme
                retroRenderer.CyberpunkGreen = ConsoleColor.Green;
                retroRenderer.CyberpunkCyan = ConsoleColor.DarkGreen;
                retroRenderer.HeaderBg = ConsoleColor.DarkGreen;
                retroRenderer.SystemBg = ConsoleColor.DarkGreen;
            }
            else if (BladeRunnerModeEnabled)
            {
                // Blade Runner cyan/magenta theme
                retroRenderer.CyberpunkCyan = ConsoleColor.Cyan;
                retroRenderer.CyberpunkMagenta = ConsoleColor.Magenta;
                retroRenderer.HeaderBg = ConsoleColor.DarkCyan;
                retroRenderer.SystemBg = ConsoleColor.DarkMagenta;
            }
            // Default cyberpunk theme already set in renderer
        }
        
        // CRUD Event Handler - same as TaskListWidget
        private TaskListEventHandler eventHandler;
        
        // Dialog instances for CRUD operations
        private TaskCreationDialog taskCreationDialog;
        private NotesEditorDialog notesEditorDialog;
        
        /// <summary>
        /// Initialize CRUD event handler and dialogs
        /// </summary>
        private void InitializeEventHandler()
        {
            if (eventHandler == null)
            {
                // Initialize dialogs
                InitializeDialogs();
                
                eventHandler = new TaskListEventHandler
                {
                    TaskManager = this.TaskManager,
                    StatusBar = this.StatusBar,
                    ParentScreen = this
                };
                
                // Set up event handlers for CRUD operations - ACTUAL IMPLEMENTATIONS
                eventHandler.OnTaskEdit = (task) => {
                    if (StatusBar != null) StatusBar.ShowMessage($"Edit task: {task.Title}");
                    // Use TaskCreationDialog to edit existing task
                    EditTask(task);
                };
                
                eventHandler.OnTaskNotes = (task) => {
                    if (StatusBar != null) StatusBar.ShowMessage($"Opening notes for: {task.Title}");
                    // Use NotesEditorDialog
                    EditTaskNotes(task);
                };
                
                eventHandler.OnTaskDelete = (task) => {
                    if (TaskManager != null)
                    {
                        TaskManager.DeleteTask(task.Id);
                        RefreshTaskList();
                        if (StatusBar != null) StatusBar.ShowSuccess($"Deleted task: {task.Title}");
                    }
                };
                
                eventHandler.OnNewTask = () => {
                    if (StatusBar != null) StatusBar.ShowMessage("Creating new task...");
                    // Use TaskCreationDialog
                    CreateNewTask();
                };
                
                eventHandler.OnRefresh = () => {
                    RefreshTaskList();
                    if (StatusBar != null) StatusBar.ShowMessage("Task list refreshed");
                };
            }
        }
        
        /// <summary>
        /// Initialize dialog instances
        /// </summary>
        private void InitializeDialogs()
        {
            if (taskCreationDialog == null)
            {
                taskCreationDialog = new TaskCreationDialog();
                
                // Wire up events
                taskCreationDialog.TaskCreated += (task) => {
                    if (TaskManager != null)
                    {
                        TaskManager.AddTask(task);
                        RefreshTaskList();
                        if (StatusBar != null) StatusBar.ShowSuccess($"Created task: {task.Title}");
                    }
                };
                
                taskCreationDialog.DialogCancelled += () => {
                    if (StatusBar != null) StatusBar.ShowMessage("Task creation cancelled");
                };
            }
            
            if (notesEditorDialog == null)
            {
                notesEditorDialog = new NotesEditorDialog();
                
                // Wire up events
                notesEditorDialog.NotesUpdated += (task) => {
                    if (TaskManager != null)
                    {
                        TaskManager.UpdateTask(task);
                        RefreshTaskList();
                        if (StatusBar != null) StatusBar.ShowSuccess($"Saved notes for: {task.Title}");
                    }
                };
                
                notesEditorDialog.EditorClosed += () => {
                    if (StatusBar != null) StatusBar.ShowMessage("Notes editor closed");
                };
            }
        }
        
        /// <summary>
        /// Create new task using dialog
        /// </summary>
        private void CreateNewTask()
        {
            if (taskCreationDialog != null)
            {
                taskCreationDialog.StartDialog();
            }
        }
        
        /// <summary>
        /// Edit existing task using dialog
        /// </summary>
        private void EditTask(SimpleTask task)
        {
            if (taskCreationDialog != null)
            {
                taskCreationDialog.StartEditDialog(task);
            }
        }
        
        /// <summary>
        /// Edit task notes using notes editor
        /// </summary>
        private void EditTaskNotes(SimpleTask task)
        {
            if (notesEditorDialog != null)
            {
                notesEditorDialog.StartEditing(task);
            }
        }
        
        /// <summary>
        /// Handle input with CRUD operations and retro cyberpunk features
        /// </summary>
        public new bool HandleInput(InputEvent input)
        {
            // Initialize event handler if needed
            InitializeEventHandler();
            
            // Handle active dialogs first (dialogs consume all input when active)
            if (taskCreationDialog != null && taskCreationDialog.IsActive)
            {
                return taskCreationDialog.HandleInput(input);
            }
            
            if (notesEditorDialog != null && notesEditorDialog.IsActive)
            {
                return notesEditorDialog.HandleInput(input);
            }
            
            // Handle retro-specific shortcuts
            switch (input.Key)
            {
                case ConsoleKey.M:
                    if (input.Ctrl) { ToggleMatrixMode(); return true; }
                    break;
                    
                case ConsoleKey.B:
                    if (input.Ctrl) { ToggleBladeRunnerMode(); return true; }
                    break;
                    
                case ConsoleKey.G:
                    if (input.Ctrl) { ToggleGlitchEffect(); return true; }
                    break;
                    
                case ConsoleKey.S:
                    if (input.Ctrl) { ToggleScanlines(); return true; }
                    break;
            }
            
            // Handle CRUD operations using existing event handler
            var selectedIndex = base.SelectedIndex;
            if (eventHandler.HandleInput(input, base.Items.ToList(), ref selectedIndex))
            {
                // Update selection if changed
                if (selectedIndex != base.SelectedIndex && selectedIndex < base.Items.Count)
                {
                    base.SelectItem(base.Items[selectedIndex]);
                }
                return true;
            }
            
            // Fall back to base navigation
            return base.HandleInput(input);
        }
        
        /// <summary>
        /// Render with pure retro cyberpunk aesthetic and handle dialogs
        /// </summary>
        public new void Render(ScreenBuffer screen, Rectangle bounds)
        {
            // Use retro renderer for complete ASCII experience
            var selectedIndex = Math.Max(0, base.SelectedIndex);
            retroRenderer.RenderRetroInterface(screen, bounds, "TASKPRO RETRO SYSTEM", 
                CurrentFilter, base.Items.ToList(), selectedIndex);
                
            // Add scanline effect if enabled
            if (TerminalScanlines)
            {
                RenderScanlineEffect(screen, bounds);
            }
            
            // Render active dialogs on top
            if (taskCreationDialog != null && taskCreationDialog.IsActive)
            {
                taskCreationDialog.Render(screen, bounds);
            }
            
            if (notesEditorDialog != null && notesEditorDialog.IsActive)
            {
                notesEditorDialog.Render(screen, bounds);
            }
        }
        
        /// <summary>
        /// Simulate CRT scanlines for authentic retro feel
        /// </summary>
        private void RenderScanlineEffect(ScreenBuffer screen, Rectangle bounds)
        {
            // Every other line gets darker background by overlaying dark characters
            for (int y = 1; y < bounds.Height; y += 2)
            {
                for (int x = 0; x < bounds.Width; x++)
                {
                    // Overlay scanline effect with dim characters
                    screen.WriteAt(x, y, "▓", ConsoleColor.DarkGray, ConsoleColor.Black);
                }
            }
        }
        
        /// <summary>
        /// Format item with retro styling for base widget compatibility
        /// </summary>
        private string FormatItemRetroStyle(TaskListItem item)
        {
            var task = item.Task;
            
            // Simple retro format for base widget fallback
            var priority = GetRetroPriorityChar(task.Priority);
            var title = (task.Title ?? "").PadRight(30);
            if (title.Length > 30) title = title.Substring(0, 27) + "...";
            
            return $"[{priority}] {title}";
        }
        
        /// <summary>
        /// Get retro priority character
        /// </summary>
        private char GetRetroPriorityChar(Priority priority)
        {
            return priority switch
            {
                Priority.Today => 'T',
                Priority.High => 'H',
                Priority.Medium => 'M',
                Priority.Low => 'L',
                _ => '?'
            };
        }
        
        /// <summary>
        /// Get retro item color for base widget
        /// </summary>
        private ConsoleColor GetRetroItemColor(TaskListItem item)
        {
            if (item.Task.Completed) return ConsoleColor.DarkGray;
            
            return item.Task.Priority switch
            {
                Priority.Today => ConsoleColor.Magenta,
                Priority.High => ConsoleColor.Red,
                Priority.Medium => ConsoleColor.Yellow,
                Priority.Low => ConsoleColor.Green,
                _ => ConsoleColor.White
            };
        }
        
        // RETRO MODE TOGGLES - Customize the cyberpunk experience
        
        /// <summary>
        /// Toggle Matrix green theme
        /// </summary>
        public void ToggleMatrixMode()
        {
            MatrixModeEnabled = !MatrixModeEnabled;
            if (MatrixModeEnabled) BladeRunnerModeEnabled = false;
            ApplyRetroTheme();
            StatusBar?.ShowMessage($"Matrix Mode: {(MatrixModeEnabled ? "ENABLED" : "DISABLED")}");
        }
        
        /// <summary>
        /// Toggle Blade Runner cyan/magenta theme
        /// </summary>
        public void ToggleBladeRunnerMode()
        {
            BladeRunnerModeEnabled = !BladeRunnerModeEnabled;
            if (BladeRunnerModeEnabled) MatrixModeEnabled = false;
            ApplyRetroTheme();
            StatusBar?.ShowMessage($"Blade Runner Mode: {(BladeRunnerModeEnabled ? "ENABLED" : "DISABLED")}");
        }
        
        /// <summary>
        /// Toggle ASCII glitch effect for critical tasks
        /// </summary>
        public void ToggleGlitchEffect()
        {
            GlitchEffectEnabled = !GlitchEffectEnabled;
            StatusBar?.ShowMessage($"Glitch Effect: {(GlitchEffectEnabled ? "ENABLED" : "DISABLED")}");
        }
        
        /// <summary>
        /// Toggle CRT scanline simulation
        /// </summary>
        public void ToggleScanlines()
        {
            TerminalScanlines = !TerminalScanlines;
            StatusBar?.ShowMessage($"Scanlines: {(TerminalScanlines ? "ENABLED" : "DISABLED")}");
        }
        
        // DATA MANAGEMENT - Same as original but with retro flair
        
        /// <summary>
        /// Refresh task list with retro status messages
        /// </summary>
        public void RefreshTaskList()
        {
            if (TaskManager == null) return;
            
            var filterHash = GenerateFilterHash();
            if (filterHash == lastFilterHash && cachedItems.Any())
            {
                base.Items = cachedItems;
                return;
            }
            
            // Get tasks and build flat list
            var allTasks = TaskManager.GetAllTasks();
            var filteredTasks = ApplyCurrentFilter(allTasks);
            var flatList = TaskManager.BuildFlatList(filteredTasks.ToList(), false);
            
            base.Items = flatList;
            cachedItems = flatList;
            lastFilterHash = filterHash;
            
            // Retro status message
            StatusBar?.ShowMessage($"[SYS] Loaded {flatList.Count} tasks into neural matrix");
        }
        
        /// <summary>
        /// Apply current filter criteria
        /// </summary>
        private IEnumerable<SimpleTask> ApplyCurrentFilter(IEnumerable<SimpleTask> tasks)
        {
            // Simple filter implementation - can be enhanced
            return tasks.Where(t => !t.Completed);
        }
        
        /// <summary>
        /// Generate cache key for current filter state
        /// </summary>
        private string GenerateFilterHash()
        {
            return $"{CurrentFilter?.GetDisplayText() ?? "All"}";
        }
        
        /// <summary>
        /// Update dependencies with retro status and initialize event handler
        /// </summary>
        public void UpdateDependencies()
        {
            // Update components if they exist
            if (TaskManager != null)
            {
                StatusBar?.ShowMessage("[SYS] Neural link established - Task Manager online");
            }
            
            // Initialize event handler with dependencies
            InitializeEventHandler();
        }
        
        /// <summary>
        /// Get retro system status for display
        /// </summary>
        public string GetRetroSystemStatus()
        {
            var taskCount = cachedItems?.Count ?? 0;
            var completedCount = cachedItems?.Count(i => i.Task.Completed) ?? 0;
            var activeCount = taskCount - completedCount;
            
            return $"TASKS:{taskCount} ACTIVE:{activeCount} COMPLETED:{completedCount} STATUS:ONLINE";
        }
        
        /// <summary>
        /// Create retro boot sequence message
        /// </summary>
        public void ShowRetroBootSequence()
        {
            StatusBar?.ShowMessage("TASKPRO RETRO SYSTEM V1.0 - NEURAL INTERFACE INITIALIZED");
            // Could add more elaborate boot sequence here
        }
    }
}