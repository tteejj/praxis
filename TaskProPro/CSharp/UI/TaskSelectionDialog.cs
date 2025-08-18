using System;
using System.Collections.Generic;
using System.Linq;
using TaskPro.Core;
using TaskPro.Data;

namespace TaskPro.UI {
    public class TaskSelectionDialog {
        // Configuration
        public TaskManager TaskManager { get; set; }
        public StatusBar StatusBar { get; set; }
        
        // CYBERPUNK COLOR PALETTE
        public ConsoleColor HeaderColor { get; set; } = ConsoleColor.Cyan;
        public ConsoleColor BorderColor { get; set; } = ConsoleColor.Cyan;
        public ConsoleColor BackgroundColor { get; set; } = ConsoleColor.Black;
        public ConsoleColor SelectionColor { get; set; } = ConsoleColor.DarkBlue;
        public ConsoleColor AmberText { get; set; } = ConsoleColor.Yellow;
        public ConsoleColor StatusGreen { get; set; } = ConsoleColor.Green;
        public ConsoleColor SubtaskColor { get; set; } = ConsoleColor.DarkGray;
        public ConsoleColor ProjectColor { get; set; } = ConsoleColor.Cyan;
        public ConsoleColor TimeCodeColor { get; set; } = ConsoleColor.Magenta;
        
        // State
        private bool isActive = false;
        private List<TaskSelectionItem> availableItems = new List<TaskSelectionItem>();
        private int selectedIndex = 0;
        private int scrollTop = 0;
        private string searchFilter = "";
        private SimpleTimeEntry targetTimeEntry = null;
        private Action<SimpleTimeEntry> onSelectionComplete = null;
        
        // Selection modes
        // private bool showTasksWithID2 = true;  // Show tasks that have ID2 set - Feature not implemented yet
        private bool allowManualEntry = true;  // Allow manual ID1/ID2 entry
        
        public bool IsActive => isActive;
        
        public TaskSelectionDialog() {
            // Initialize with default configuration
        }
        
        public void StartSelection(SimpleTimeEntry timeEntry, Action<SimpleTimeEntry> onComplete) {
            targetTimeEntry = timeEntry;
            onSelectionComplete = onComplete;
            isActive = true;
            searchFilter = "";
            selectedIndex = 0;
            scrollTop = 0;
            
            RefreshAvailableItems();
        }
        
        public void Cancel() {
            isActive = false;
            targetTimeEntry = null;
            onSelectionComplete = null;
            searchFilter = "";
        }
        
        private void RefreshAvailableItems() {
            availableItems.Clear();
            
            if (TaskManager == null) return;
            
            // Add manual entry option first
            if (allowManualEntry) {
                availableItems.Add(new TaskSelectionItem {
                    Type = TaskSelectionType.ManualEntry,
                    DisplayText = "[MANUAL ENTRY] - Enter custom ID1/ID2",
                    ID1 = "",
                    ID2 = "",
                    Description = "Manual time code entry"
                });
            }
            
            // Get all tasks and filter
            var allTasks = TaskManager.GetAllTasks();
            var filteredTasks = allTasks.Where(t => !t.Completed).ToList();
            
            // Apply search filter if active
            if (!string.IsNullOrEmpty(searchFilter)) {
                var filter = searchFilter.ToLower();
                filteredTasks = filteredTasks.Where(t => 
                    (t.Title?.ToLower().Contains(filter) ?? false) ||
                    (t.ID1?.ToLower().Contains(filter) ?? false) ||
                    (t.ID2?.ToLower().Contains(filter) ?? false) ||
                    (t.Tags?.Any(tag => tag.ToLower().Contains(filter)) ?? false)
                ).ToList();
            }
            
            // Group tasks by ID1 and add them
            var tasksByID1 = filteredTasks.GroupBy(t => t.ID1 ?? "").ToList();
            
            foreach (var group in tasksByID1.OrderBy(g => g.Key)) {
                if (string.IsNullOrEmpty(group.Key)) continue;
                
                // Add group header for ID1
                availableItems.Add(new TaskSelectionItem {
                    Type = TaskSelectionType.ID1Header,
                    DisplayText = $"━━━ {group.Key} ━━━",
                    ID1 = group.Key,
                    ID2 = "",
                    Description = $"Time code category: {group.Key}"
                });
                
                // Add specific tasks with ID2
                foreach (var task in group.Where(t => !string.IsNullOrEmpty(t.ID2)).OrderBy(t => t.ID2)) {
                    availableItems.Add(new TaskSelectionItem {
                        Type = TaskSelectionType.TaskWithID2,
                        DisplayText = $"  {task.ID1}/{task.ID2} - {task.Title}",
                        ID1 = task.ID1,
                        ID2 = task.ID2,
                        Description = task.Title,
                        TaskId = task.Id,
                        Task = task
                    });
                }
                
                // Add generic option for this ID1 category
                availableItems.Add(new TaskSelectionItem {
                    Type = TaskSelectionType.GenericID1,
                    DisplayText = $"  [{group.Key}] - Generic time code",
                    ID1 = group.Key,
                    ID2 = "",
                    Description = $"Generic {group.Key} time entry"
                });
            }
            
            // Adjust selection if out of bounds
            if (selectedIndex >= availableItems.Count) {
                selectedIndex = Math.Max(0, availableItems.Count - 1);
            }
        }
        
        public bool HandleInput(InputEvent input) {
            if (!isActive) return false;
            
            // Navigation
            if (input.IsArrowUp) {
                if (selectedIndex > 0) {
                    selectedIndex--;
                    EnsureVisible();
                }
                return true;
            }
            
            if (input.IsArrowDown) {
                if (selectedIndex < availableItems.Count - 1) {
                    selectedIndex++;
                    EnsureVisible();
                }
                return true;
            }
            
            // Selection
            if (input.IsEnter) {
                MakeSelection();
                return true;
            }
            
            // Cancel
            if (input.IsEscape) {
                Cancel();
                return true;
            }
            
            // Search filtering
            if (input.IsPrintableChar && !input.Ctrl && !input.Alt) {
                searchFilter += input.Char;
                RefreshAvailableItems();
                return true;
            }
            
            if (input.IsBackspace) {
                if (!string.IsNullOrEmpty(searchFilter)) {
                    searchFilter = searchFilter.Substring(0, searchFilter.Length - 1);
                    RefreshAvailableItems();
                }
                return true;
            }
            
            return false;
        }
        
        private void MakeSelection() {
            if (selectedIndex < 0 || selectedIndex >= availableItems.Count) return;
            
            var selectedItem = availableItems[selectedIndex];
            
            if (selectedItem.Type == TaskSelectionType.ID1Header) {
                // Can't select header - do nothing
                return;
            }
            
            if (targetTimeEntry != null) {
                switch (selectedItem.Type) {
                    case TaskSelectionType.ManualEntry:
                        // Keep current values or clear for manual entry
                        targetTimeEntry.UnlinkFromTask();
                        break;
                        
                    case TaskSelectionType.TaskWithID2:
                        // Link to specific task
                        targetTimeEntry.LinkToTask(
                            selectedItem.TaskId, 
                            selectedItem.Description, 
                            selectedItem.ID1, 
                            selectedItem.ID2
                        );
                        break;
                        
                    case TaskSelectionType.GenericID1:
                        // Set generic time code
                        targetTimeEntry.ID1 = selectedItem.ID1;
                        targetTimeEntry.ID2 = "";
                        targetTimeEntry.Description = selectedItem.Description;
                        targetTimeEntry.UnlinkFromTask();
                        break;
                }
                
                targetTimeEntry.Touch();
            }
            
            isActive = false;
            onSelectionComplete?.Invoke(targetTimeEntry);
            
            StatusBar?.ShowSuccess($"Selected: {selectedItem.DisplayText}");
        }
        
        private void EnsureVisible() {
            if (availableItems.Count == 0) return;
            
            var maxVisible = 8; // Approximate visible items in dialog
            
            if (selectedIndex < scrollTop) {
                scrollTop = selectedIndex;
            } else if (selectedIndex >= scrollTop + maxVisible) {
                scrollTop = selectedIndex - maxVisible + 1;
            }
            
            scrollTop = Math.Max(0, Math.Min(scrollTop, availableItems.Count - maxVisible));
        }
        
        public void Render(ScreenBuffer screen, Rectangle bounds) {
            if (!isActive) return;
            
            // Calculate dialog size and position
            var dialogWidth = Math.Min(80, bounds.Width - 4);
            var dialogHeight = Math.Min(20, bounds.Height - 4);
            var dialogX = bounds.X + (bounds.Width - dialogWidth) / 2;
            var dialogY = bounds.Y + (bounds.Height - dialogHeight) / 2;
            
            // Draw cyberpunk border
            DrawCyberpunkBorder(screen, dialogX, dialogY, dialogWidth, dialogHeight);
            
            // Header
            var headerText = "SELECT TIME ENTRY SOURCE";
            var headerX = dialogX + (dialogWidth - headerText.Length) / 2;
            screen.WriteAt(headerX, dialogY + 1, headerText, HeaderColor, BackgroundColor);
            
            // Search filter display
            if (!string.IsNullOrEmpty(searchFilter)) {
                var filterText = $"Filter: {searchFilter}";
                screen.WriteAt(dialogX + 2, dialogY + 2, filterText, AmberText, BackgroundColor);
            }
            
            // Content area
            var contentY = dialogY + 4;
            var contentHeight = dialogHeight - 6;
            
            if (availableItems.Count == 0) {
                var noItemsMsg = "No items available";
                var msgX = dialogX + (dialogWidth - noItemsMsg.Length) / 2;
                screen.WriteAt(msgX, contentY + contentHeight / 2, noItemsMsg, SubtaskColor, BackgroundColor);
                return;
            }
            
            // Render items
            var endIndex = Math.Min(availableItems.Count, scrollTop + contentHeight);
            
            for (int i = scrollTop; i < endIndex; i++) {
                var item = availableItems[i];
                var displayIndex = i - scrollTop;
                var y = contentY + displayIndex;
                
                if (y >= contentY + contentHeight) break;
                
                // Selection highlighting
                var isSelected = (selectedIndex == i);
                if (isSelected) {
                    screen.FillRect(dialogX + 1, y, dialogWidth - 2, 1, ' ', 
                                  BackgroundColor, SelectionColor);
                }
                
                // Item rendering
                var itemColor = GetItemColor(item);
                var bgColor = isSelected ? SelectionColor : BackgroundColor;
                var displayText = item.DisplayText;
                
                if (displayText.Length > dialogWidth - 4) {
                    displayText = displayText.Substring(0, dialogWidth - 7) + "...";
                }
                
                screen.WriteAt(dialogX + 2, y, displayText, itemColor, bgColor);
            }
            
            // Status line
            var statusText = "Enter=Select  Esc=Cancel  Type=Filter";
            screen.WriteAt(dialogX + 2, dialogY + dialogHeight - 2, statusText, StatusGreen, BackgroundColor);
        }
        
        private ConsoleColor GetItemColor(TaskSelectionItem item) {
            return item.Type switch {
                TaskSelectionType.ManualEntry => AmberText,
                TaskSelectionType.ID1Header => HeaderColor,
                TaskSelectionType.TaskWithID2 => ProjectColor,
                TaskSelectionType.GenericID1 => TimeCodeColor,
                _ => SubtaskColor
            };
        }
        
        private void DrawCyberpunkBorder(ScreenBuffer screen, int x, int y, int width, int height) {
            var borderColor = BorderColor;
            
            // Top border
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
    }
    
    public enum TaskSelectionType {
        ManualEntry,
        ID1Header,
        TaskWithID2,
        GenericID1
    }
    
    public class TaskSelectionItem {
        public TaskSelectionType Type { get; set; }
        public string DisplayText { get; set; } = "";
        public string ID1 { get; set; } = "";
        public string ID2 { get; set; } = "";
        public string Description { get; set; } = "";
        public string TaskId { get; set; } = "";
        public SimpleTask Task { get; set; }
    }
}