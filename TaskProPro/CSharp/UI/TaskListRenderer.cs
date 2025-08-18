using System;
using System.Collections.Generic;
using System.Linq;
using TaskPro.Core;
using TaskPro.Data;

namespace TaskPro.UI
{
    /// <summary>
    /// Specialized high-performance renderer for task lists
    /// Handles all visual rendering logic for TaskListWidget
    /// Uses professional BorderDrawingSystem for perfect connections
    /// </summary>
    public class TaskListRenderer
    {
        // CYBERPUNK COLOR PALETTE - BRIGHT GLOWING TERMINAL AESTHETIC
        public ConsoleColor HeaderColor { get; set; } = ConsoleColor.Cyan;
        public ConsoleColor HighPriorityColor { get; set; } = ConsoleColor.Red;
        public ConsoleColor MediumPriorityColor { get; set; } = ConsoleColor.Yellow;
        public ConsoleColor LowPriorityColor { get; set; } = ConsoleColor.Green;
        public ConsoleColor TodayPriorityColor { get; set; } = ConsoleColor.Magenta;
        public ConsoleColor SubtaskColor { get; set; } = ConsoleColor.Gray;
        public ConsoleColor TagColor { get; set; } = ConsoleColor.Cyan;
        public ConsoleColor BorderColor { get; set; } = ConsoleColor.Cyan;
        public ConsoleColor BackgroundColor { get; set; } = ConsoleColor.Black;
        public ConsoleColor SelectionColor { get; set; } = ConsoleColor.Blue;
        public ConsoleColor AmberText { get; set; } = ConsoleColor.Yellow;
        public ConsoleColor StatusGreen { get; set; } = ConsoleColor.Green;
        public ConsoleColor DangerRed { get; set; } = ConsoleColor.Red;
        public ConsoleColor DataBlue { get; set; } = ConsoleColor.Blue;
        public ConsoleColor HintColor { get; set; } = ConsoleColor.Gray;
        public ConsoleColor HighlightColor { get; set; } = ConsoleColor.Yellow;
        
        // Professional border drawing system
        private readonly BorderDrawingSystem borderSystem = new BorderDrawingSystem();

        /// <summary>
        /// Render complete interface with professional connected borders
        /// </summary>
        public void RenderCompleteInterface(ScreenBuffer screen, Rectangle bounds, string titleText, 
            FilterCriteria currentFilter, TaskListColumnManager columnManager, List<TaskListItem> items, int selectedIndex)
        {
            // Initialize border system for screen dimensions
            borderSystem.Initialize(bounds.Width, bounds.Height);
            
            // Calculate column positions for perfect alignment
            var columnPositions = CalculateColumnPositions(columnManager, bounds.Width);
            
            // Design the complete border layout
            SetupBorderLayout(bounds, columnPositions, items.Count);
            
            // Render all sections with perfect borders
            RenderHeaderSection(screen, bounds, titleText, currentFilter);
            RenderColumnHeaderSection(screen, bounds, columnManager);
            RenderDataSection(screen, bounds, columnManager, items, selectedIndex, columnPositions);
            RenderStatusSection(screen, bounds, items);
        }
        
        /// <summary>
        /// Setup complete border layout with all connections
        /// </summary>
        private void SetupBorderLayout(Rectangle bounds, int[] columnPositions, int itemCount)
        {
            // Main outer rectangle
            borderSystem.AddRectangle(0, 0, bounds.Width, bounds.Height, BorderLineType.Heavy);
            
            // Header separator (after line 4)
            borderSystem.AddHorizontalSeparator(4, 0, bounds.Width - 1, BorderLineType.Heavy);
            
            // Column header separator (after line 7) 
            borderSystem.AddHorizontalSeparator(7, 0, bounds.Width - 1, BorderLineType.Heavy);
            
            // Data area column separators
            int dataStartY = 8;
            int dataEndY = Math.Min(dataStartY + itemCount + 1, bounds.Height - 4);
            borderSystem.AddColumnSeparators(columnPositions, dataStartY, dataEndY);
            
            // Status section separator (3 lines from bottom)
            borderSystem.AddHorizontalSeparator(bounds.Height - 4, 0, bounds.Width - 1, BorderLineType.Heavy);
        }
        
        /// <summary>
        /// Calculate exact column positions for border system
        /// FIXED: Proper position calculation that matches column manager exactly
        /// </summary>
        private int[] CalculateColumnPositions(TaskListColumnManager columnManager, int totalWidth)
        {
            var positions = new List<int>();
            int currentX = 1; // Start after left border
            
            // Calculate positions based on actual column layout
            columnManager.CalculateLayout(totalWidth);
            
            for (int i = 0; i < columnManager.Columns.Length - 1; i++)
            {
                currentX += columnManager.Columns[i].Width;
                positions.Add(currentX);
                currentX++; // Account for separator width
            }
            
            return positions.ToArray();
        }
        
        /// <summary>
        /// Render header section using simplified border system
        /// </summary>
        private void RenderHeaderSection(ScreenBuffer screen, Rectangle bounds, string titleText, FilterCriteria currentFilter)
        {
            // Line 0: Top border with perfect corners
            screen.WriteAt(0, 0, borderSystem.RenderBorderLine(0), HeaderColor, BackgroundColor);
            
            // Line 1: Title line with side borders only
            var filterText = currentFilter?.GetDisplayText() ?? "All";
            if (filterText != "All") {
                titleText += $" [FLT:{filterText.ToUpper()}] ";
            }
            var titleContent = titleText.PadLeft((bounds.Width - 2 + titleText.Length) / 2).PadRight(bounds.Width - 2);
            screen.WriteAt(0, 1, borderSystem.RenderContentLine(titleContent), HeaderColor, BackgroundColor);
            
            // Line 2: System status line
            var systemStatus = " [SYS:ONLINE] [MODE:TASK_MGMT] [F1:TIME_TRACK] ";
            screen.WriteAt(0, 2, borderSystem.RenderContentLine(systemStatus), StatusGreen, BackgroundColor);
            
            // Line 3: Selection info line (will be filled by main render)
            var selectionContent = " ";
            screen.WriteAt(0, 3, borderSystem.RenderContentLine(selectionContent), HeaderColor, BackgroundColor);
            
            // Line 4: Header separator with perfect junctions
            screen.WriteAt(0, 4, borderSystem.RenderBorderLine(4), HeaderColor, BackgroundColor);
        }

        /// <summary>
        /// Render column header section with perfect alignment
        /// FIXED: Ensure headers and separators align perfectly with data
        /// </summary>
        private void RenderColumnHeaderSection(ScreenBuffer screen, Rectangle bounds, TaskListColumnManager columnManager)
        {
            var columnPositions = CalculateColumnPositions(columnManager, bounds.Width);
            
            // Line 5: Column headers - get clean header text without separators
            var headerContent = columnManager.GetHeaderRowWithoutSeparators();
            var headerLine = borderSystem.RenderContentLine(headerContent, columnPositions);
            screen.WriteAt(0, 5, headerLine, HeaderColor, BackgroundColor);
            
            // Line 6: Column underline - create dashes aligned with content
            var separatorContent = columnManager.GetSeparatorRowWithoutSeparators();
            var separatorLine = borderSystem.RenderContentLine(separatorContent, columnPositions);
            screen.WriteAt(0, 6, separatorLine, HeaderColor, BackgroundColor);
            
            // Line 7: Column separator line with perfect junctions
            screen.WriteAt(0, 7, borderSystem.RenderBorderLine(7), HeaderColor, BackgroundColor);
        }
        
        /// <summary>
        /// Render data section with perfect column alignment
        /// </summary>
        private void RenderDataSection(ScreenBuffer screen, Rectangle bounds, TaskListColumnManager columnManager, 
            List<TaskListItem> items, int selectedIndex, int[] columnPositions)
        {
            int dataStartY = 8;
            int maxDataLines = bounds.Height - 12; // Reserve space for status
            
            for (int i = 0; i < Math.Min(items.Count, maxDataLines); i++)
            {
                var item = items[i];
                var y = dataStartY + i;
                var isSelected = (i == selectedIndex);
                
                // Get formatted row data WITHOUT separators - let BorderDrawingSystem add them
                var rowContent = columnManager.FormatTaskRowWithoutSeparators(item.Task);
                
                // Apply selection highlighting
                var bgColor = isSelected ? SelectionColor : BackgroundColor;
                var fgColor = GetTaskPriorityColor(item.Task);
                
                // Render with perfect column separators
                screen.WriteAt(0, y, borderSystem.RenderContentLine(rowContent, columnPositions), fgColor, bgColor);
            }
        }
        
        /// <summary>
        /// Render status section with perfect borders
        /// </summary>
        private void RenderStatusSection(ScreenBuffer screen, Rectangle bounds, List<TaskListItem> items)
        {
            int statusStartY = bounds.Height - 4;
            
            // Status separator line
            screen.WriteAt(0, statusStartY, borderSystem.RenderBorderLine(statusStartY), HeaderColor, BackgroundColor);
            
            // Status content lines
            var activeTask = items.FirstOrDefault()?.Task;
            var activeText = activeTask != null ? $"  ACTIVE: {activeTask.Title}" : "  NO TASK SELECTED";
            var completedCount = items.Count(i => i.Task.Completed);
            var statusText = $"COMPLETED: {completedCount} | MODE:TASK_MGMT  ";
            
            // Line 1: Active task info
            var line1Content = activeText.PadRight(bounds.Width - statusText.Length - 2) + statusText;
            screen.WriteAt(0, statusStartY + 1, borderSystem.RenderContentLine(line1Content), StatusGreen, BackgroundColor);
            
            // Line 2: Shortcuts
            var shortcuts = "           N:New │ E:Edit │ Enter:Notes │ Space:Complete │ T:Theme │ /:Filter │ Ctrl+Q:Quit           ";
            var shortcutsContent = shortcuts.PadRight(bounds.Width - 2);
            screen.WriteAt(0, statusStartY + 2, borderSystem.RenderContentLine(shortcutsContent), HintColor, BackgroundColor);
            
            // Line 3: Bottom border with perfect corners
            screen.WriteAt(0, bounds.Height - 1, borderSystem.RenderBorderLine(bounds.Height - 1), HeaderColor, BackgroundColor);
        }
        
        /// <summary>
        /// Get priority-based color for task
        /// </summary>
        private ConsoleColor GetTaskPriorityColor(SimpleTask task)
        {
            if (task.Completed) return SubtaskColor;
            
            return task.Priority switch
            {
                Priority.Today => TodayPriorityColor,
                Priority.High => HighPriorityColor,
                Priority.Medium => MediumPriorityColor,
                Priority.Low => LowPriorityColor,
                _ => AmberText
            };
        }

        // LEGACY METHODS - DEPRECATED - Use RenderCompleteInterface instead
        
        /// <summary>
        /// DEPRECATED: Use RenderCompleteInterface for perfect borders
        /// </summary>
        public void RenderHeader(ScreenBuffer screen, Rectangle bounds, string titleText, FilterCriteria currentFilter)
        {
            // Fallback to complete interface rendering
            RenderCompleteInterface(screen, bounds, titleText, currentFilter, new TaskListColumnManager(), new List<TaskListItem>(), 0);
        }
        
        /// <summary>
        /// DEPRECATED: Use RenderCompleteInterface for perfect borders
        /// </summary>
        public void RenderColumnHeaders(ScreenBuffer screen, Rectangle bounds, TaskListColumnManager columnManager)
        {
            // This method is now part of RenderCompleteInterface
        }

        /// <summary>
        /// Render task row with proper borders and column formatting
        /// </summary>
        public void RenderTaskRow(ScreenBuffer screen, Rectangle bounds, int y, TaskListItem item, ConsoleColor bgColor, TaskListColumnManager columnManager)
        {
            var task = item.Task;
            
            // Use the column manager to format the row consistently with column separators
            var rowText = columnManager.FormatTaskRowWithSeparators(task);
            
            // Apply priority-based coloring to the entire row
            var priorityColor = task.Priority switch {
                Priority.Today => ConsoleColor.Red,
                Priority.High => HighPriorityColor,
                Priority.Medium => MediumPriorityColor,
                Priority.Low => LowPriorityColor,
                _ => AmberText
            };
            
            // Write row with proper borders - ensure it fills the full width
            var borderedRow = "║" + rowText;
            var paddedRow = borderedRow.PadRight(bounds.Width - 1) + "║";
            screen.WriteAt(bounds.X, y, paddedRow, priorityColor, bgColor);
        }

        /// <summary>
        /// Render status bar with shortcuts and active task info
        /// </summary>
        public void RenderStatusBar(ScreenBuffer screen, Rectangle bounds, SimpleTask selectedTask, int completedCount)
        {
            // BOTTOM BORDER
            var bottomBorder = RenderOptimizer.BuildBorder(bounds.Width, BorderType.Bottom);
            screen.WriteAt(0, bounds.Y + 2, bottomBorder, HeaderColor, BackgroundColor);
            
            // STATUS CONTENT
            var leftStatus = selectedTask != null ? 
                $"  ACTIVE: {selectedTask.Title}" : "  NO TASK SELECTED";
            var rightStatus = $"COMPLETED: {completedCount} | MODE:TASK_MGMT  ";
            
            // Left side status
            screen.WriteAt(0, bounds.Y, "║", HeaderColor, BackgroundColor);
            screen.WriteAt(1, bounds.Y, leftStatus.PadRight(bounds.Width - rightStatus.Length - 2), 
                         StatusGreen, BackgroundColor);
            
            // Right side status
            screen.WriteAt(bounds.Width - rightStatus.Length - 1, bounds.Y, rightStatus, 
                         HighlightColor, BackgroundColor);
            screen.WriteAt(bounds.Width - 1, bounds.Y, "║", HeaderColor, BackgroundColor);
            
            // SHORTCUTS LINE
            var shortcuts = "           N:New │ E:Edit │ Enter:Notes │ Space:Complete │ T:Theme │ /:Filter │ Ctrl+Q:Quit           ";
            screen.WriteAt(0, bounds.Y + 1, "║", HeaderColor, BackgroundColor);
            screen.WriteAt(1, bounds.Y + 1, shortcuts.PadRight(bounds.Width - 2), 
                         HintColor, BackgroundColor);
            screen.WriteAt(bounds.Width - 1, bounds.Y + 1, "║", HeaderColor, BackgroundColor);
        }

        /// <summary>
        /// Get appropriate color for due dates
        /// </summary>
        public ConsoleColor GetDateDisplayColor(DateTime dueDate)
        {
            if (dueDate == DateTime.MinValue) return SubtaskColor;
            
            var today = DateTime.Today;
            if (dueDate.Date < today) return DangerRed;      // Overdue
            if (dueDate.Date == today) return TodayPriorityColor; // Due today
            if (dueDate.Date <= today.AddDays(3)) return HighPriorityColor; // Due soon
            
            return DataBlue; // Future dates
        }
    }
}