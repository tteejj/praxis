using System.Collections.Generic;
using System.Linq;

namespace TaskPro.Data {
    public class FilterCriteria {
        public Priority Priority { get; set; } = Priority.Medium;  // All priorities if null
        public string TagFilter { get; set; } = "";               // Empty = no tag filter
        public string SearchText { get; set; } = "";              // Empty = no search
        public bool ShowOnlyToday { get; set; } = false;          // Today filter
        public bool ShowCompleted { get; set; } = true;           // Include completed tasks
        
        public string GetDisplayText() {
            var parts = new List<string>();
            if (Priority != Priority.Medium) parts.Add(Priority.ToString());
            if (!string.IsNullOrEmpty(TagFilter)) parts.Add($"#{TagFilter}");
            if (!string.IsNullOrEmpty(SearchText)) parts.Add($"\"{SearchText}\"");
            if (ShowOnlyToday) parts.Add("Today");
            return parts.Any() ? string.Join(" ", parts) : "All";
        }
    }
}