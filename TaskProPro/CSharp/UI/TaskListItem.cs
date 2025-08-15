using TaskPro.Data;

namespace TaskPro.UI {
    public class TaskListItem {
        public SimpleTask Task { get; set; }
        public int Level { get; set; }           // 0 = parent, 1 = subtask
        public bool IsLast { get; set; }         // For tree drawing
        public bool IsExpanded { get; set; }     // For hierarchical display
        public bool HasChildren { get; set; }    // Performance optimization
        public SimpleTask ParentTask { get; set; } // Quick access to parent
    }
}