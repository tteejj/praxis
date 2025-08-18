using System;
using System.Collections.Generic;
using System.Linq;
using TaskPro.Core;
using TaskPro.Data;

namespace TaskPro.UI
{
    /// <summary>
    /// Specialized column manager for task list Excel-style layout
    /// Handles column sizing, alignment, and responsive layout
    /// </summary>
    public class TaskListColumnManager
    {
        // EXCEL-STYLE COLUMN DEFINITIONS
        public ColumnDefinition[] Columns { get; private set; }
        
        // Layout configuration
        public int MinimumWidth { get; set; } = 80;
        public int MaximumWidth { get; set; } = 200;
        public bool AutoResize { get; set; } = true;
        
        public TaskListColumnManager()
        {
            InitializeColumns();
        }
        
        /// <summary>
        /// Initialize Excel-style column layout
        /// </summary>
        private void InitializeColumns()
        {
            Columns = new ColumnDefinition[]
            {
                new() { 
                    Name = "Priority", 
                    Key = "PRI", 
                    Width = 3, 
                    MinWidth = 3, 
                    MaxWidth = 3,
                    Alignment = ColumnAlignment.Center,
                    IsResizable = false,
                    HeaderText = "PRI"
                },
                new() { 
                    Name = "DueDate", 
                    Key = "DUE", 
                    Width = 10, 
                    MinWidth = 8, 
                    MaxWidth = 12,
                    Alignment = ColumnAlignment.Center,
                    IsResizable = true,
                    HeaderText = "DUE DATE"
                },
                new() { 
                    Name = "ID1", 
                    Key = "ID1", 
                    Width = 4, 
                    MinWidth = 4, 
                    MaxWidth = 8,
                    Alignment = ColumnAlignment.Left,
                    IsResizable = true,
                    HeaderText = "ID1"
                },
                new() { 
                    Name = "ID2", 
                    Key = "ID2", 
                    Width = 12, 
                    MinWidth = 8, 
                    MaxWidth = 16,
                    Alignment = ColumnAlignment.Left,
                    IsResizable = true,
                    HeaderText = "ID2"
                },
                new() { 
                    Name = "Title", 
                    Key = "TITLE", 
                    Width = 30, 
                    MinWidth = 20, 
                    MaxWidth = 60,
                    Alignment = ColumnAlignment.Left,
                    IsResizable = true,
                    IsFlexible = true, // Takes remaining space
                    HeaderText = "TASK TITLE"
                },
                new() { 
                    Name = "Tags", 
                    Key = "TAGS", 
                    Width = 15, 
                    MinWidth = 10, 
                    MaxWidth = 25,
                    Alignment = ColumnAlignment.Left,
                    IsResizable = true,
                    HeaderText = "TAGS"
                }
            };
        }
        
        /// <summary>
        /// Calculate optimal column widths for given screen width
        /// </summary>
        public void CalculateLayout(int availableWidth)
        {
            if (availableWidth < MinimumWidth) return;
            
            // Reserve space for borders and separators
            var usableWidth = availableWidth - (Columns.Length + 1); // +1 for borders
            
            // Phase 1: Set all columns to minimum width
            var totalMinWidth = Columns.Sum(c => c.MinWidth);
            if (usableWidth < totalMinWidth)
            {
                // Extremely narrow - use minimum layout
                foreach (var col in Columns)
                {
                    col.Width = col.MinWidth;
                }
                return;
            }
            
            // Phase 2: Allocate fixed-width columns
            var remainingWidth = usableWidth;
            var flexibleColumns = new List<ColumnDefinition>();
            
            foreach (var col in Columns)
            {
                if (col.IsFlexible)
                {
                    flexibleColumns.Add(col);
                    col.Width = col.MinWidth; // Start with minimum
                }
                else
                {
                    col.Width = Math.Min(col.MaxWidth, Math.Max(col.MinWidth, col.Width));
                    remainingWidth -= col.Width;
                }
            }
            
            // Phase 3: Distribute remaining width to flexible columns
            if (flexibleColumns.Count > 0 && remainingWidth > 0)
            {
                var extraPerColumn = remainingWidth / flexibleColumns.Count;
                var leftover = remainingWidth % flexibleColumns.Count;
                
                foreach (var col in flexibleColumns)
                {
                    var additionalWidth = extraPerColumn + (leftover > 0 ? 1 : 0);
                    col.Width = Math.Min(col.MaxWidth, col.MinWidth + additionalWidth);
                    leftover--;
                }
            }
        }
        
        /// <summary>
        /// Get formatted header row
        /// </summary>
        public string GetHeaderRow()
        {
            var sb = RenderOptimizer.GetStringBuilder();
            
            for (int i = 0; i < Columns.Length; i++)
            {
                var col = Columns[i];
                var headerText = FormatColumnText(col.HeaderText, col.Width, col.Alignment);
                sb.Append(headerText);
                
                if (i < Columns.Length - 1)
                {
                    sb.Append('│');
                }
            }
            
            return sb.ToString();
        }
        
        /// <summary>
        /// Get formatted header row WITHOUT separators for BorderDrawingSystem
        /// </summary>
        public string GetHeaderRowWithoutSeparators()
        {
            var sb = RenderOptimizer.GetStringBuilder();
            
            for (int i = 0; i < Columns.Length; i++)
            {
                var col = Columns[i];
                var headerText = FormatColumnText(col.HeaderText, col.Width, col.Alignment);
                sb.Append(headerText);
                
                // Add separator characters that BorderDrawingSystem will use to split
                if (i < Columns.Length - 1)
                {
                    sb.Append('│');
                }
            }
            
            return sb.ToString();
        }
        
        /// <summary>
        /// Get formatted separator row
        /// </summary>
        public string GetSeparatorRow()
        {
            var sb = RenderOptimizer.GetStringBuilder();
            
            for (int i = 0; i < Columns.Length; i++)
            {
                var col = Columns[i];
                sb.Append('─', col.Width);
                
                if (i < Columns.Length - 1)
                {
                    sb.Append('┼');
                }
            }
            
            return sb.ToString();
        }
        
        /// <summary>
        /// Get formatted separator row WITHOUT junction characters for BorderDrawingSystem
        /// </summary>
        public string GetSeparatorRowWithoutSeparators()
        {
            var sb = RenderOptimizer.GetStringBuilder();
            
            for (int i = 0; i < Columns.Length; i++)
            {
                var col = Columns[i];
                sb.Append('─', col.Width);
                
                // Add separator characters that BorderDrawingSystem will use to split
                if (i < Columns.Length - 1)
                {
                    sb.Append('│');
                }
            }
            
            return sb.ToString();
        }
        
        /// <summary>
        /// Format a task row according to column layout
        /// </summary>
        public string FormatTaskRow(SimpleTask task)
        {
            var sb = RenderOptimizer.GetStringBuilder();
            
            for (int i = 0; i < Columns.Length; i++)
            {
                var col = Columns[i];
                var cellValue = GetTaskCellValue(task, col.Key);
                var formattedCell = FormatColumnText(cellValue, col.Width, col.Alignment);
                sb.Append(formattedCell);
                
                if (i < Columns.Length - 1)
                {
                    sb.Append('│');
                }
            }
            
            return sb.ToString();
        }
        
        /// <summary>
        /// Format a task row with Excel-style column separators
        /// </summary>
        public string FormatTaskRowWithSeparators(SimpleTask task)
        {
            var sb = RenderOptimizer.GetStringBuilder();
            
            for (int i = 0; i < Columns.Length; i++)
            {
                var col = Columns[i];
                var cellValue = GetTaskCellValue(task, col.Key);
                var formattedCell = FormatColumnText(cellValue, col.Width, col.Alignment);
                sb.Append(formattedCell);
                
                if (i < Columns.Length - 1)
                {
                    sb.Append('│');
                }
            }
            
            return sb.ToString();
        }
        
        /// <summary>
        /// Format a task row WITHOUT separators for BorderDrawingSystem
        /// </summary>
        public string FormatTaskRowWithoutSeparators(SimpleTask task)
        {
            var sb = RenderOptimizer.GetStringBuilder();
            
            for (int i = 0; i < Columns.Length; i++)
            {
                var col = Columns[i];
                var cellValue = GetTaskCellValue(task, col.Key);
                var formattedCell = FormatColumnText(cellValue, col.Width, col.Alignment);
                sb.Append(formattedCell);
                
                // Add separator characters that BorderDrawingSystem will use to split
                if (i < Columns.Length - 1)
                {
                    sb.Append('│');
                }
            }
            
            return sb.ToString();
        }
        
        /// <summary>
        /// Get cell value for a task and column
        /// </summary>
        private string GetTaskCellValue(SimpleTask task, string columnKey)
        {
            return columnKey switch
            {
                "PRI" => task.GetCyberpunkPriority(),
                "DUE" => task.GetCyberpunkDate(),
                "ID1" => task.ID1 ?? "",
                "ID2" => task.ID2 ?? "",
                "TITLE" => task.Title ?? "",
                "TAGS" => string.Join(",", task.Tags.Take(3)),
                _ => ""
            };
        }
        
        /// <summary>
        /// Format text according to column width and alignment
        /// </summary>
        private string FormatColumnText(string text, int width, ColumnAlignment alignment)
        {
            if (string.IsNullOrEmpty(text))
            {
                return new string(' ', width);
            }
            
            // Truncate if too long
            if (text.Length > width)
            {
                text = text.Substring(0, Math.Max(0, width - 3)) + "...";
            }
            
            // Apply alignment
            return alignment switch
            {
                ColumnAlignment.Left => text.PadRight(width),
                ColumnAlignment.Right => text.PadLeft(width),
                ColumnAlignment.Center => CenterText(text, width),
                _ => text.PadRight(width)
            };
        }
        
        /// <summary>
        /// Center text within given width
        /// </summary>
        private string CenterText(string text, int width)
        {
            if (text.Length >= width) return text.Substring(0, width);
            
            var totalPadding = width - text.Length;
            var leftPadding = totalPadding / 2;
            var rightPadding = totalPadding - leftPadding;
            
            return new string(' ', leftPadding) + text + new string(' ', rightPadding);
        }
        
        /// <summary>
        /// Get column at screen position
        /// </summary>
        public ColumnDefinition GetColumnAt(int x)
        {
            var currentX = 0;
            
            foreach (var col in Columns)
            {
                if (x >= currentX && x < currentX + col.Width)
                {
                    return col;
                }
                currentX += col.Width + 1; // +1 for separator
            }
            
            return null;
        }
        
        /// <summary>
        /// Get total row width including separators
        /// </summary>
        public int GetTotalWidth()
        {
            return Columns.Sum(c => c.Width) + (Columns.Length - 1);
        }
        
        /// <summary>
        /// Resize column by delta
        /// </summary>
        public bool ResizeColumn(string columnKey, int delta)
        {
            var column = Columns.FirstOrDefault(c => c.Key == columnKey);
            if (column == null || !column.IsResizable) return false;
            
            var newWidth = Math.Max(column.MinWidth, 
                          Math.Min(column.MaxWidth, column.Width + delta));
            
            if (newWidth != column.Width)
            {
                column.Width = newWidth;
                return true;
            }
            
            return false;
        }
        
        /// <summary>
        /// Reset columns to default layout
        /// </summary>
        public void ResetLayout()
        {
            InitializeColumns();
        }
        
        /// <summary>
        /// Get column info for debugging
        /// </summary>
        public string GetLayoutInfo()
        {
            var info = string.Join(" | ", Columns.Select(c => $"{c.Key}:{c.Width}"));
            return $"Layout: {info} (Total: {GetTotalWidth()})";
        }
    }
    
    /// <summary>
    /// Column definition for Excel-style layout
    /// </summary>
    public class ColumnDefinition
    {
        public string Name { get; set; } = "";
        public string Key { get; set; } = "";
        public string HeaderText { get; set; } = "";
        public int Width { get; set; } = 10;
        public int MinWidth { get; set; } = 5;
        public int MaxWidth { get; set; } = 50;
        public ColumnAlignment Alignment { get; set; } = ColumnAlignment.Left;
        public bool IsResizable { get; set; } = true;
        public bool IsFlexible { get; set; } = false; // Takes remaining space
        public bool IsVisible { get; set; } = true;
    }
    
    /// <summary>
    /// Column alignment options
    /// </summary>
    public enum ColumnAlignment
    {
        Left,
        Center,
        Right
    }
}