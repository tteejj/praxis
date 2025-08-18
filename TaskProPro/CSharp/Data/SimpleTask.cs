using System;
using System.Collections.Generic;
using System.Linq;

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
        public string CustomColor { get; set; } = "";  // RGB hex color for individual task coloring
        
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
        
        // CYBERPUNK UI METHODS - Professional terminal interface
        public string GetStatusIcon() {
            return Completed ? "[✓]" : "[ ]";
        }
        
        public string GetCyberpunkPriority() {
            return Priority switch {
                Priority.Today => "[!T!]",    // Urgent today marker
                Priority.High => "[H]",       // High priority bracket
                Priority.Medium => "[M]",     // Medium priority bracket
                Priority.Low => "[L]",        // Low priority bracket
                _ => "[M]"                    // Default to medium
            };
        }
        
        public ConsoleColor GetPriorityColor() {
            return Priority switch {
                Priority.Today => ConsoleColor.Red,      // Critical today tasks
                Priority.High => ConsoleColor.Yellow,    // High priority amber
                Priority.Medium => ConsoleColor.Cyan,    // Medium priority cyan
                Priority.Low => ConsoleColor.Green,      // Low priority green
                _ => ConsoleColor.Yellow                 // Default amber
            };
        }
        
        public string GetCyberpunkDate() {
            if (DueDate == DateTime.MinValue) return "--:--:--   ";
            
            var today = DateTime.Today;
            var daysDiff = (DueDate.Date - today).Days;
            
            return daysDiff switch {
                0 => "[TODAY]   ",
                1 => "[TOM]     ",
                -1 => "[YEST]    ",
                < -1 => $"[{Math.Abs(daysDiff)}d AGO] ",
                <= 7 => $"[+{daysDiff}d]    ",
                _ => DueDate.ToString("MMdd.yy   ")
            };
        }
        
        public ConsoleColor GetDateColor() {
            if (DueDate == DateTime.MinValue) return ConsoleColor.DarkGray;
            
            var today = DateTime.Today;
            var daysDiff = (DueDate.Date - today).Days;
            
            if (daysDiff < 0) return ConsoleColor.Red;      // Overdue
            if (daysDiff == 0) return ConsoleColor.Yellow;  // Today
            if (daysDiff <= 7) return ConsoleColor.Cyan;    // This week
            return ConsoleColor.Green;                      // Future
        }
        
        public string GetProjectDisplay() {
            var parts = new List<string>();
            if (!string.IsNullOrEmpty(ID1)) parts.Add($"P1:{ID1}");
            if (!string.IsNullOrEmpty(ID2)) parts.Add($"P2:{ID2}");
            return parts.Any() ? $"[{string.Join("|", parts)}]" : "";
        }
        
        // REQUIRED METHODS FOR TaskListEditMode
        public SimpleTask DeepCopy() {
            return new SimpleTask {
                Id = this.Id,
                Title = this.Title,
                Notes = this.Notes,
                Completed = this.Completed,
                CreatedDate = this.CreatedDate,
                ModifiedDate = this.ModifiedDate,
                DueDate = this.DueDate,
                Priority = this.Priority,
                Tags = new List<string>(this.Tags),
                ColorTheme = this.ColorTheme,
                CustomColor = this.CustomColor,
                ParentId = this.ParentId,
                Subtasks = new List<SimpleTask>(this.Subtasks),
                SubtasksCollapsed = this.SubtasksCollapsed,
                SortOrder = this.SortOrder,
                ID1 = this.ID1,
                ID2 = this.ID2
            };
        }
        
        public void CopyFrom(SimpleTask other) {
            if (other == null) return;
            
            this.Id = other.Id;
            this.Title = other.Title;
            this.Notes = other.Notes;
            this.Completed = other.Completed;
            this.CreatedDate = other.CreatedDate;
            this.ModifiedDate = other.ModifiedDate;
            this.DueDate = other.DueDate;
            this.Priority = other.Priority;
            this.Tags = new List<string>(other.Tags);
            this.ColorTheme = other.ColorTheme;
            this.CustomColor = other.CustomColor;
            this.ParentId = other.ParentId;
            this.Subtasks = new List<SimpleTask>(other.Subtasks);
            this.SubtasksCollapsed = other.SubtasksCollapsed;
            this.SortOrder = other.SortOrder;
            this.ID1 = other.ID1;
            this.ID2 = other.ID2;
        }
    }
    
    public enum Priority {
        Today = 0,    // Highest priority - gold color
        High = 1,     // Red color
        Medium = 2,   // Orange color  
        Low = 3       // Green color
    }
}