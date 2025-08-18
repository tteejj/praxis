using System;
using System.Collections.Generic;
using System.Linq;
using TaskPro.Core;
using TaskPro.Data;

namespace TaskPro.UI
{
    /// <summary>
    /// RETRO CYBERPUNK ASCII RENDERER - Pure 80s hacker terminal aesthetic
    /// No Unicode! Only ASCII + background highlights for that authentic retro feel
    /// Think Blade Runner, Matrix, WarGames - pure terminal power
    /// </summary>
    public class TaskListRendererRetro
    {
        // CYBERPUNK RETRO COLOR PALETTE - Authentic 80s terminal colors
        public ConsoleColor CyberpunkGreen { get; set; } = ConsoleColor.Green;      // Matrix green
        public ConsoleColor CyberpunkCyan { get; set; } = ConsoleColor.Cyan;       // Neon cyan
        public ConsoleColor CyberpunkMagenta { get; set; } = ConsoleColor.Magenta; // Hot pink
        public ConsoleColor CyberpunkYellow { get; set; } = ConsoleColor.Yellow;   // Warning amber
        public ConsoleColor CyberpunkRed { get; set; } = ConsoleColor.Red;         // Danger red
        public ConsoleColor CyberpunkWhite { get; set; } = ConsoleColor.White;     // Terminal white
        public ConsoleColor CyberpunkGray { get; set; } = ConsoleColor.Gray;       // Dim text
        public ConsoleColor CyberpunkBlack { get; set; } = ConsoleColor.Black;     // Terminal black
        public ConsoleColor CyberpunkBlue { get; set; } = ConsoleColor.Blue;       // Data blue
        
        // SELECTION BACKGROUNDS - Retro highlight colors
        public ConsoleColor SelectionBg { get; set; } = ConsoleColor.DarkBlue;     // Selected row
        public ConsoleColor HeaderBg { get; set; } = ConsoleColor.DarkGray;        // Header background (FIXED)
        public ConsoleColor CriticalBg { get; set; } = ConsoleColor.DarkRed;       // Critical task
        public ConsoleColor SystemBg { get; set; } = ConsoleColor.DarkGray;        // System info (FIXED)
        
        // ROW BACKGROUND - Uniform grey for all fields in a row
        public ConsoleColor RowFieldBg { get; set; } = ConsoleColor.DarkGray;      // All fields same grey background
        public ConsoleColor RowTextColor { get; set; } = ConsoleColor.Green;       // Bright green text
        
        // ASCII ART COMPONENTS - Pure terminal aesthetic
        private const char HORIZONTAL_LINE = '-';
        private const char VERTICAL_LINE = '|';
        private const char CORNER_CHAR = '+';
        private const char EQUALS_LINE = '=';
        private const char SELECTION_LEFT = '>';
        private const char SELECTION_RIGHT = '<';
        private const char BRACKET_LEFT = '[';
        private const char BRACKET_RIGHT = ']';
        
        /// <summary>
        /// Render complete retro cyberpunk interface with ASCII + background highlights
        /// </summary>
        public void RenderRetroInterface(ScreenBuffer screen, Rectangle bounds, string titleText,
            FilterCriteria currentFilter, List<TaskListItem> items, int selectedIndex)
        {
            // Clear screen with terminal black
            ClearScreen(screen, bounds);
            
            // Render sections in pure ASCII glory
            RenderRetroHeader(screen, bounds, titleText, currentFilter);
            RenderRetroColumnHeaders(screen, bounds);
            RenderRetroDataRows(screen, bounds, items, selectedIndex);
            RenderRetroStatusBar(screen, bounds, items);
        }
        
        /// <summary>
        /// Clear screen with authentic terminal black background
        /// </summary>
        private void ClearScreen(ScreenBuffer screen, Rectangle bounds)
        {
            for (int y = 0; y < bounds.Height; y++)
            {
                for (int x = 0; x < bounds.Width; x++)
                {
                    screen.WriteAt(x, y, " ", CyberpunkWhite, CyberpunkBlack);
                }
            }
        }
        
        /// <summary>
        /// Render retro cyberpunk header with ASCII art
        /// </summary>
        private void RenderRetroHeader(ScreenBuffer screen, Rectangle bounds, string titleText, FilterCriteria currentFilter)
        {
            int y = 0;
            
            // Top border with equals signs - classic terminal style
            var topBorder = " " + new string(EQUALS_LINE, bounds.Width - 2) + " ";
            screen.WriteAt(0, y++, topBorder, CyberpunkCyan, CyberpunkBlack);
            
            // System title with retro brackets
            var filterText = currentFilter?.GetDisplayText() ?? "ALL";
            var systemTitle = $"===== {titleText.ToUpper()} ===== [MATRIX MODE] =====";
            var centeredTitle = CenterText(systemTitle, bounds.Width);
            screen.WriteAt(0, y++, centeredTitle, CyberpunkGreen, HeaderBg);
            
            // System status line - pure cyberpunk
            var systemStatus = " [SYS:ONLINE] [MODE:TASK_MGMT] [FILTER:" + filterText.ToUpper() + "] [NEURAL_LINK:ACTIVE] ";
            var centeredStatus = CenterText(systemStatus, bounds.Width);
            screen.WriteAt(0, y++, centeredStatus, CyberpunkCyan, SystemBg);
            
            // Separator line
            var separator = " " + new string(HORIZONTAL_LINE, bounds.Width - 2) + " ";
            screen.WriteAt(0, y++, separator, CyberpunkGreen, CyberpunkBlack);
        }
        
        /// <summary>
        /// Render column headers with new layout
        /// ID1 | ID2 | Created | Due | Sub | Detail | Tags (with space separators)
        /// </summary>
        private void RenderRetroColumnHeaders(ScreenBuffer screen, Rectangle bounds)
        {
            int y = 4; // Start after header
            
            // Calculate column widths with space separators
            var id1Width = 4;
            var id2Width = 12;
            var createdWidth = 10;  // 2025-01-01
            var dueWidth = 10;      // 2025-01-01
            var subWidth = 1;       // S or space
            var tagsWidth = 15;
            var spacers = 6;        // 6 spaces between 7 fields
            var detailWidth = Math.Max(10, bounds.Width - 2 - id1Width - id2Width - createdWidth - dueWidth - subWidth - tagsWidth - spacers);
            
            // Build header line
            var headerLine = " " + // Left border
                "ID1".PadRight(id1Width) + " " +
                "ID2".PadRight(id2Width) + " " +
                "CREATED".PadRight(createdWidth) + " " +
                "DUE".PadRight(dueWidth) + " " +
                "S".PadRight(subWidth) + " " +
                "DETAIL".PadRight(detailWidth) + " " +
                "TAGS".PadRight(tagsWidth) +
                " "; // Right border
                
            // Ensure exact width
            if (headerLine.Length < bounds.Width)
                headerLine = headerLine.PadRight(bounds.Width);
            else if (headerLine.Length > bounds.Width)
                headerLine = headerLine.Substring(0, bounds.Width);
                
            screen.WriteAt(0, y++, headerLine, CyberpunkYellow, CyberpunkBlack);
            
            // Header underline with dashes
            var underline = " " + new string(HORIZONTAL_LINE, bounds.Width - 2) + " ";
            screen.WriteAt(0, y++, underline, CyberpunkYellow, CyberpunkBlack);
        }
        
        /// <summary>
        /// Format field text with background highlighting
        /// </summary>
        private string FormatFieldWithBackground(string text, int width, ConsoleColor fieldBg)
        {
            // For now, just return formatted text - we'll handle backgrounds in main render
            if (text.Length > width)
                text = text.Substring(0, width);
            return text.PadRight(width);
        }
        
        /// <summary>
        /// Render data rows with new layout
        /// ID1 | ID2 | Created | Due | Sub | Detail | Tags (with space separators)
        /// </summary>
        private void RenderRetroDataRows(ScreenBuffer screen, Rectangle bounds, List<TaskListItem> items, int selectedIndex)
        {
            int startY = 6; // Start after headers
            int maxRows = bounds.Height - 10; // Reserve space for status
            
            for (int i = 0; i < Math.Min(items.Count, maxRows); i++)
            {
                var item = items[i];
                var task = item.Task;
                var y = startY + (i * 2); // Add spacing between rows
                var isSelected = (i == selectedIndex);
                
                // Skip if we're past screen bounds
                if (y >= bounds.Height - 4) break;
                
                // Render with uniform grey background and bright green text
                RenderTaskRowWithUniformBackground(screen, y, task, isSelected, bounds.Width);
                
                // Fill the spacing row below with same background (if not last item)
                if (i < Math.Min(items.Count, maxRows) - 1 && y + 1 < bounds.Height - 4)
                {
                    var spacerLine = new string(' ', bounds.Width);
                    var spacerBg = isSelected ? SelectionBg : RowFieldBg;
                    screen.WriteAt(0, y + 1, spacerLine, RowTextColor, spacerBg);
                }
            }
        }
        
        /// <summary>
        /// Render single task row with individual field backgrounds
        /// Fields have grey background, spaces between fields have black background
        /// </summary>
        private void RenderTaskRowWithUniformBackground(ScreenBuffer screen, int y, SimpleTask task, bool isSelected, int screenWidth)
        {
            // Calculate column widths (same as header)
            var id1Width = 4;
            var id2Width = 12;
            var createdWidth = 10;
            var dueWidth = 10;
            var subWidth = 1;
            var tagsWidth = 15;
            var spacers = 6;
            var detailWidth = Math.Max(10, screenWidth - 2 - id1Width - id2Width - createdWidth - dueWidth - subWidth - tagsWidth - spacers);
            
            // Colors for fields and spaces
            var fieldTextColor = isSelected ? CyberpunkYellow : RowTextColor; // Bright green or yellow if selected
            var fieldBg = isSelected ? SelectionBg : RowFieldBg;  // Selection blue or grey for FIELDS
            var spaceBg = isSelected ? SelectionBg : CyberpunkBlack; // Selection blue or BLACK for SPACES
            
            // Format data fields
            var id1 = FormatField(task.ID1 ?? "", id1Width);
            var id2 = FormatField(task.ID2 ?? "", id2Width);
            var created = FormatDate(task.CreatedDate, createdWidth);
            var due = FormatDate(task.DueDate, dueWidth);
            var subtaskIndicator = GetSubtaskIndicator(task);
            var detail = FormatField(task.Title ?? "", detailWidth);
            var tags = FormatField(string.Join(",", task.Tags.Take(3)), tagsWidth);
            
            // Render each field individually with correct backgrounds
            int x = 0;
            
            // Left border space
            screen.WriteAt(x++, y, " ", fieldTextColor, spaceBg);
            
            // ID1 field
            screen.WriteAt(x, y, id1, fieldTextColor, fieldBg);
            x += id1Width;
            
            // Space between ID1 and ID2
            screen.WriteAt(x++, y, " ", fieldTextColor, spaceBg);
            
            // ID2 field
            screen.WriteAt(x, y, id2, fieldTextColor, fieldBg);
            x += id2Width;
            
            // Space between ID2 and Created
            screen.WriteAt(x++, y, " ", fieldTextColor, spaceBg);
            
            // Created field
            screen.WriteAt(x, y, created, fieldTextColor, fieldBg);
            x += createdWidth;
            
            // Space between Created and Due
            screen.WriteAt(x++, y, " ", fieldTextColor, spaceBg);
            
            // Due field
            screen.WriteAt(x, y, due, fieldTextColor, fieldBg);
            x += dueWidth;
            
            // Space between Due and Sub
            screen.WriteAt(x++, y, " ", fieldTextColor, spaceBg);
            
            // Subtask indicator field
            screen.WriteAt(x, y, subtaskIndicator, fieldTextColor, fieldBg);
            x += subWidth;
            
            // Space between Sub and Detail
            screen.WriteAt(x++, y, " ", fieldTextColor, spaceBg);
            
            // Detail field
            screen.WriteAt(x, y, detail, fieldTextColor, fieldBg);
            x += detailWidth;
            
            // Space between Detail and Tags
            screen.WriteAt(x++, y, " ", fieldTextColor, spaceBg);
            
            // Tags field
            screen.WriteAt(x, y, tags, fieldTextColor, fieldBg);
            x += tagsWidth;
            
            // Right border space and fill remainder
            while (x < screenWidth)
            {
                screen.WriteAt(x++, y, " ", fieldTextColor, spaceBg);
            }
        }
        
        /// <summary>
        /// Format field to exact width with truncation
        /// </summary>
        private string FormatField(string text, int width)
        {
            if (string.IsNullOrEmpty(text))
                return new string(' ', width);
                
            if (text.Length > width)
                return text.Substring(0, width);
                
            return text.PadRight(width);
        }
        
        /// <summary>
        /// Format date field
        /// </summary>
        private string FormatDate(DateTime date, int width)
        {
            if (date == DateTime.MinValue)
                return new string('-', width);
                
            var dateStr = date.ToString("yyyy-MM-dd");
            return FormatField(dateStr, width);
        }
        
        /// <summary>
        /// Get subtask indicator character
        /// </summary>
        private string GetSubtaskIndicator(SimpleTask task)
        {
            if (task.HasSubtasks())
                return "+"; // Has children
            else if (task.IsSubtask())
                return "-"; // Is a child
            else
                return " "; // Standalone task
        }
        
        /// <summary>
        /// Format single task row with retro cyberpunk styling
        /// </summary>
        private string FormatRetroTaskRow(SimpleTask task, bool isSelected, int width)
        {
            // Selection indicators - pure ASCII
            var leftMarker = isSelected ? SELECTION_LEFT.ToString() : " ";
            var rightMarker = isSelected ? SELECTION_RIGHT.ToString() : " ";
            
            // Priority with retro brackets
            var priority = GetRetroPriority(task.Priority);
            var priorityText = $"{BRACKET_LEFT}{priority}{BRACKET_RIGHT}";
            
            // Due date in retro format
            var dueDate = GetRetroDate(task.DueDate);
            
            // Task ID with leading zeros - classic computer style
            var taskId = (task.ID1 ?? "0").PadLeft(4, '0');
            
            // Task title truncated to fit
            var title = (task.Title ?? "").PadRight(24);
            if (title.Length > 24) title = title.Substring(0, 21) + "...";
            
            // Tags in retro format
            var tags = string.Join(",", task.Tags.Take(2)).PadRight(6);
            if (tags.Length > 6) tags = tags.Substring(0, 6);
            
            // Assemble complete row
            var row = $"{leftMarker} {priorityText} {dueDate} {taskId} {title} {tags} {rightMarker}";
            
            // Ensure exact width
            return row.PadRight(width).Substring(0, Math.Min(row.Length, width));
        }
        
        /// <summary>
        /// Get retro priority indicator
        /// </summary>
        private string GetRetroPriority(Priority priority)
        {
            return priority switch
            {
                Priority.Today => "T",    // Today
                Priority.High => "H",     // High
                Priority.Medium => "M",   // Medium  
                Priority.Low => "L",      // Low
                _ => "?"                  // Unknown
            };
        }
        
        /// <summary>
        /// Get retro date format
        /// </summary>
        private string GetRetroDate(DateTime date)
        {
            if (date == DateTime.MinValue) return "----------";
            if (date.Date == DateTime.Today) return "  TODAY   ";
            return date.ToString("yyyy-MM-dd");
        }
        
        /// <summary>
        /// Get task colors based on priority and selection
        /// </summary>
        private (ConsoleColor fg, ConsoleColor bg) GetTaskColors(SimpleTask task, bool isSelected)
        {
            // Base background
            var bg = isSelected ? SelectionBg : CyberpunkBlack;
            
            // Priority-based foreground colors
            var fg = task.Priority switch
            {
                Priority.Today => CyberpunkMagenta,  // Hot pink for today
                Priority.High => CyberpunkRed,       // Red for high
                Priority.Medium => CyberpunkYellow,  // Yellow for medium
                Priority.Low => CyberpunkGreen,      // Green for low
                _ => CyberpunkWhite                  // White default
            };
            
            // Critical task background override
            if (task.Priority == Priority.Today && !isSelected)
            {
                bg = CriticalBg;
            }
            
            // Completed task styling
            if (task.Completed)
            {
                fg = CyberpunkGray;
                if (!isSelected) bg = CyberpunkBlack;
            }
            
            return (fg, bg);
        }
        
        /// <summary>
        /// Render retro status bar with ASCII art
        /// </summary>
        private void RenderRetroStatusBar(ScreenBuffer screen, Rectangle bounds, List<TaskListItem> items)
        {
            int statusY = bounds.Height - 4;
            
            // Status separator
            var separator = " " + new string(EQUALS_LINE, bounds.Width - 2) + " ";
            screen.WriteAt(0, statusY++, separator, CyberpunkCyan, CyberpunkBlack);
            
            // Active task info
            var activeTask = items.FirstOrDefault()?.Task;
            var activeText = activeTask != null ? 
                $"ACTIVE: {activeTask.Title}" : "NO TASK SELECTED";
            var completedCount = items.Count(i => i.Task.Completed);
            var statusLine = $" {activeText} ".PadRight(bounds.Width - 20) + 
                           $"STATUS: {completedCount} COMPLETED ";
            screen.WriteAt(0, statusY++, statusLine.PadRight(bounds.Width), 
                         CyberpunkGreen, SystemBg);
            
            // Command shortcuts in retro style
            var shortcuts = " [N]ew [E]dit [ENTER]notes [DEL]ete [T]oggle > NEURAL LINK ACTIVE ";
            var shortcutLine = CenterText(shortcuts, bounds.Width);
            screen.WriteAt(0, statusY++, shortcutLine, CyberpunkCyan, CyberpunkBlack);
            
            // Bottom border
            var bottomBorder = " " + new string(EQUALS_LINE, bounds.Width - 2) + " ";
            screen.WriteAt(0, statusY++, bottomBorder, CyberpunkCyan, CyberpunkBlack);
        }
        
        /// <summary>
        /// Center text within given width
        /// </summary>
        private string CenterText(string text, int width)
        {
            if (text.Length >= width) return text.Substring(0, width);
            
            var padding = width - text.Length;
            var leftPad = padding / 2;
            var rightPad = padding - leftPad;
            
            return new string(' ', leftPad) + text + new string(' ', rightPad);
        }
        
        /// <summary>
        /// Get retro system time for display
        /// </summary>
        private string GetRetroSystemTime()
        {
            return DateTime.Now.ToString("HH:mm:ss");
        }
        
        /// <summary>
        /// Create ASCII art glitch effect for critical tasks
        /// </summary>
        private string CreateGlitchEffect(string text)
        {
            // Simple ASCII glitch - replace some chars with retro symbols
            var glitched = text.ToCharArray();
            var random = new Random();
            
            for (int i = 0; i < glitched.Length; i += 3)
            {
                if (random.Next(10) < 2) // 20% chance
                {
                    glitched[i] = "!@#$%^&*"[random.Next(8)];
                }
            }
            
            return new string(glitched);
        }
    }
}