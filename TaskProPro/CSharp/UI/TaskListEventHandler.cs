using System;
using System.Collections.Generic;
using System.Linq;
using TaskPro.Core;
using TaskPro.Data;

namespace TaskPro.UI
{
    /// <summary>
    /// Specialized event handler for task list input processing
    /// Handles all keyboard shortcuts and navigation
    /// </summary>
    public class TaskListEventHandler
    {
        // Dependencies
        public TaskManager TaskManager { get; set; }
        public StatusBar StatusBar { get; set; }
        public object ParentScreen { get; set; }
        
        // Event delegates
        public Action<SimpleTask> OnTaskEdit { get; set; }
        public Action<SimpleTask> OnTaskNotes { get; set; }
        public Action<SimpleTask> OnTaskDelete { get; set; }
        public Action OnNewTask { get; set; }
        public Action OnFilterToggle { get; set; }
        public Action OnThemeToggle { get; set; }
        public Action OnRefresh { get; set; }
        public Action<string> OnQuickAdd { get; set; }
        public Action OnTimeTracker { get; set; }
        
        // State
        private string quickAddBuffer = "";
        private bool isQuickAddMode = false;
        
        /// <summary>
        /// Process input event and execute appropriate action
        /// </summary>
        public bool HandleInput(InputEvent input, List<TaskListItem> items, ref int selectedIndex)
        {
            // QUICK ADD MODE - Type to create tasks instantly
            if (isQuickAddMode)
            {
                return HandleQuickAddInput(input);
            }
            
            // NAVIGATION KEYS
            if (input.IsArrowUp)
            {
                if (selectedIndex > 0)
                {
                    selectedIndex--;
                    if (StatusBar != null) StatusBar.ShowMessage($"Selected task {selectedIndex + 1}/{items.Count}");
                }
                return true;
            }
            
            if (input.IsArrowDown)
            {
                if (selectedIndex < items.Count - 1)
                {
                    selectedIndex++;
                    if (StatusBar != null) StatusBar.ShowMessage($"Selected task {selectedIndex + 1}/{items.Count}");
                }
                return true;
            }
            
            if (input.IsPageUp)
            {
                selectedIndex = Math.Max(0, selectedIndex - 10);
                if (StatusBar != null) StatusBar.ShowMessage($"Page up - Task {selectedIndex + 1}/{items.Count}");
                return true;
            }
            
            if (input.IsPageDown)
            {
                selectedIndex = Math.Min(items.Count - 1, selectedIndex + 10);
                if (StatusBar != null) StatusBar.ShowMessage($"Page down - Task {selectedIndex + 1}/{items.Count}");
                return true;
            }
            
            if (input.IsHome)
            {
                selectedIndex = 0;
                if (StatusBar != null) StatusBar.ShowMessage("First task");
                return true;
            }
            
            if (input.IsEnd)
            {
                selectedIndex = Math.Max(0, items.Count - 1);
                if (StatusBar != null) StatusBar.ShowMessage("Last task");
                return true;
            }
            
            // ACTION KEYS - Get selected task
            var selectedTask = (selectedIndex >= 0 && selectedIndex < items.Count) ? 
                items[selectedIndex].Task : null;
            
            // ENTER - Open notes editor
            if (input.IsEnter)
            {
                if (selectedTask != null)
                {
                    OnTaskNotes?.Invoke(selectedTask);
                    StatusBar?.ShowSuccess($"Opening notes for: {selectedTask.Title}");
                }
                return true;
            }
            
            // SPACEBAR - Toggle completion
            if (input.IsSpace)
            {
                if (selectedTask != null)
                {
                    ToggleTaskCompletion(selectedTask);
                }
                return true;
            }
            
            // CHARACTER-BASED SHORTCUTS
            if (input.IsPrintableChar && !input.Ctrl && !input.Alt)
            {
                return HandleCharacterShortcut(input.Char, selectedTask);
            }
            
            // CTRL COMBINATIONS
            if (input.Ctrl)
            {
                return HandleCtrlShortcut(input, selectedTask);
            }
            
            // F-KEY SHORTCUTS
            if (input.IsFunction)
            {
                return HandleFunctionKey(input, selectedTask);
            }
            
            return false;
        }
        
        /// <summary>
        /// Handle character-based shortcuts (N, E, D, etc.)
        /// </summary>
        private bool HandleCharacterShortcut(char ch, SimpleTask selectedTask)
        {
            switch (char.ToUpper(ch))
            {
                case 'N':
                    OnNewTask?.Invoke();
                    if (StatusBar != null) StatusBar.ShowMessage("Creating new task...");
                    return true;
                    
                case 'E':
                    if (selectedTask != null)
                    {
                        OnTaskEdit?.Invoke(selectedTask);
                        if (StatusBar != null) StatusBar.ShowMessage($"Editing: {selectedTask.Title}");
                    }
                    return true;
                    
                case 'D':
                    if (selectedTask != null)
                    {
                        OnTaskDelete?.Invoke(selectedTask);
                    }
                    return true;
                    
                case '/':
                    OnFilterToggle?.Invoke();
                    if (StatusBar != null) StatusBar.ShowMessage("Filter toggled");
                    return true;
                    
                case 'T':
                    OnThemeToggle?.Invoke();
                    if (StatusBar != null) StatusBar.ShowMessage("Theme cycled");
                    return true;
                    
                case 'R':
                    OnRefresh?.Invoke();
                    StatusBar?.ShowSuccess("Data refreshed");
                    return true;
                    
                case '+':
                    StartQuickAddMode();
                    return true;
                    
                case 'P':
                    if (selectedTask != null)
                    {
                        CyclePriority(selectedTask);
                    }
                    return true;
                    
                case 'C':
                    if (selectedTask != null)
                    {
                        ToggleTaskCompletion(selectedTask);
                    }
                    return true;
                    
                default:
                    return false;
            }
        }
        
        /// <summary>
        /// Handle Ctrl key combinations
        /// </summary>
        private bool HandleCtrlShortcut(InputEvent input, SimpleTask selectedTask)
        {
            switch (char.ToUpper(input.Char))
            {
                case 'Q':
                    // Request exit via reflection or interface
                    var requestExitMethod = ParentScreen?.GetType().GetMethod("RequestExit");
                    requestExitMethod?.Invoke(ParentScreen, null);
                    return true;
                    
                case 'S':
                    TaskManager?.Save();
                    StatusBar?.ShowSuccess("Tasks saved");
                    return true;
                    
                case 'A':
                    StartQuickAddMode();
                    return true;
                    
                case 'F':
                    OnFilterToggle?.Invoke();
                    return true;
                    
                default:
                    return false;
            }
        }
        
        /// <summary>
        /// Handle function key shortcuts
        /// </summary>
        private bool HandleFunctionKey(InputEvent input, SimpleTask selectedTask)
        {
            switch (input.FunctionKey)
            {
                case 1: // F1
                    OnTimeTracker?.Invoke();
                    if (StatusBar != null) StatusBar.ShowMessage("Opening time tracker...");
                    return true;
                    
                case 5: // F5
                    OnRefresh?.Invoke();
                    StatusBar?.ShowSuccess("Refreshed");
                    return true;
                    
                case 12: // F12
                    OnThemeToggle?.Invoke();
                    return true;
                    
                default:
                    return false;
            }
        }
        
        /// <summary>
        /// Handle quick add mode input
        /// </summary>
        private bool HandleQuickAddInput(InputEvent input)
        {
            if (input.IsEscape)
            {
                CancelQuickAddMode();
                return true;
            }
            
            if (input.IsEnter)
            {
                CompleteQuickAdd();
                return true;
            }
            
            if (input.IsBackspace)
            {
                if (quickAddBuffer.Length > 0)
                {
                    quickAddBuffer = quickAddBuffer.Substring(0, quickAddBuffer.Length - 1);
                    if (StatusBar != null) StatusBar.ShowMessage($"Quick Add: {quickAddBuffer}_");
                }
                else
                {
                    CancelQuickAddMode();
                }
                return true;
            }
            
            if (input.IsPrintableChar)
            {
                quickAddBuffer += input.Char;
                if (StatusBar != null) StatusBar.ShowMessage($"Quick Add: {quickAddBuffer}_");
                return true;
            }
            
            return false;
        }
        
        /// <summary>
        /// Toggle task completion status
        /// </summary>
        private void ToggleTaskCompletion(SimpleTask task)
        {
            if (task == null) return;
            
            task.Completed = !task.Completed;
            task.Touch();
            TaskManager?.UpdateTask(task);
            
            var status = task.Completed ? "completed" : "reopened";
            StatusBar?.ShowSuccess($"Task {status}: {task.Title}");
        }
        
        /// <summary>
        /// Cycle through priority levels
        /// </summary>
        private void CyclePriority(SimpleTask task)
        {
            if (task == null) return;
            
            task.Priority = task.Priority switch
            {
                Priority.Low => Priority.Medium,
                Priority.Medium => Priority.High,
                Priority.High => Priority.Today,
                Priority.Today => Priority.Low,
                _ => Priority.Medium
            };
            
            task.Touch();
            TaskManager?.UpdateTask(task);
            StatusBar?.ShowSuccess($"Priority changed to: {task.Priority}");
        }
        
        /// <summary>
        /// Start quick add mode for rapid task creation
        /// </summary>
        private void StartQuickAddMode()
        {
            isQuickAddMode = true;
            quickAddBuffer = "";
            if (StatusBar != null) StatusBar.ShowMessage("Quick Add Mode - Type task title (Enter=Save, Esc=Cancel)");
        }
        
        /// <summary>
        /// Complete quick add operation
        /// </summary>
        private void CompleteQuickAdd()
        {
            if (!string.IsNullOrWhiteSpace(quickAddBuffer))
            {
                OnQuickAdd?.Invoke(quickAddBuffer.Trim());
                StatusBar?.ShowSuccess($"Created task: {quickAddBuffer}");
            }
            
            CancelQuickAddMode();
        }
        
        /// <summary>
        /// Cancel quick add mode
        /// </summary>
        private void CancelQuickAddMode()
        {
            isQuickAddMode = false;
            quickAddBuffer = "";
            if (StatusBar != null) StatusBar.ShowMessage("Quick add cancelled");
        }
        
        /// <summary>
        /// Get keyboard shortcuts help text
        /// </summary>
        public List<(string Key, string Action)> GetShortcutsHelp()
        {
            return new List<(string, string)>
            {
                ("N", "New Task"),
                ("E", "Edit Task"), 
                ("Enter", "Notes"),
                ("Space/C", "Complete"),
                ("D", "Delete"),
                ("P", "Priority"),
                ("T", "Theme"),
                ("/", "Filter"),
                ("R/F5", "Refresh"),
                ("+/Ctrl+A", "Quick Add"),
                ("F1", "Time Track"),
                ("Ctrl+Q", "Quit"),
                ("Ctrl+S", "Save")
            };
        }
        
        /// <summary>
        /// Check if currently in quick add mode
        /// </summary>
        public bool IsQuickAddMode => isQuickAddMode;
        
        /// <summary>
        /// Get current quick add buffer for display
        /// </summary>
        public string QuickAddBuffer => quickAddBuffer;
    }
}