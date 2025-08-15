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