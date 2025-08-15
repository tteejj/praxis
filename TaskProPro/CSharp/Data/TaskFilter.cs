using System;
using System.Collections.Generic;
using System.Linq;

namespace TaskPro.Data {
    public class TaskFilter {
        public List<SimpleTask> ApplyFilters(List<SimpleTask> tasks, FilterCriteria criteria) {
            var filtered = tasks.AsEnumerable();
            
            // Priority filter
            if (criteria.Priority != Priority.Medium) {
                filtered = filtered.Where(t => t.Priority == criteria.Priority);
            }
            
            // Tag filter
            if (!string.IsNullOrEmpty(criteria.TagFilter)) {
                filtered = filtered.Where(t => 
                    t.Tags.Any(tag => tag.Contains(criteria.TagFilter, StringComparison.OrdinalIgnoreCase)));
            }
            
            // Search filter (title and notes)
            if (!string.IsNullOrEmpty(criteria.SearchText)) {
                var searchLower = criteria.SearchText.ToLower();
                filtered = filtered.Where(t => 
                    t.Title.ToLower().Contains(searchLower) ||
                    t.Notes.ToLower().Contains(searchLower));
            }
            
            // Today filter
            if (criteria.ShowOnlyToday) {
                var today = DateTime.Today;
                filtered = filtered.Where(t => 
                    t.Priority == Priority.Today ||
                    t.DueDate.Date == today);
            }
            
            // Completed filter
            if (!criteria.ShowCompleted) {
                filtered = filtered.Where(t => !t.Completed);
            }
            
            return filtered.ToList();
        }
        
        public bool MatchesFilter(SimpleTask task, FilterCriteria criteria) {
            return ApplyFilters(new List<SimpleTask> { task }, criteria).Any();
        }
    }
}