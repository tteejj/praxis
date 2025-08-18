using System;
using System.Collections.Generic;
using System.Linq;
using TaskPro.UI;

namespace TaskPro.Data {
    public class TaskManager {
        private TaskPersistence persistence;
        private TaskFilter filter;
        private List<SimpleTask> allTasks;
        
        // Constructor
        public TaskManager(string dataFilePath) {
            persistence = new TaskPersistence(dataFilePath);
            filter = new TaskFilter();
            LoadFromDisk();
        }
        
        // Core Data Operations
        public List<SimpleTask> GetAllTasks() => allTasks.ToList();
        public List<SimpleTask> GetParentTasks() => allTasks.Where(t => t.IsParent()).ToList();
        public SimpleTask GetTask(string id) => allTasks.FirstOrDefault(t => t.Id == id);
        public SimpleTask GetParentTask(string childId) {
            var child = GetTask(childId);
            return child?.IsSubtask() == true ? GetTask(child.ParentId) : null;
        }
        
        // CRUD Operations
        public void AddTask(SimpleTask task) {
            task.Touch();
            allTasks.Add(task);
            SaveToDisk();
        }
        
        public void UpdateTask(SimpleTask task) {
            task.Touch();
            var index = allTasks.FindIndex(t => t.Id == task.Id);
            if (index >= 0) {
                allTasks[index] = task;
                SaveToDisk();
            }
        }
        
        public void DeleteTask(string id) {
            // Delete task and all its subtasks
            var task = GetTask(id);
            if (task != null) {
                if (task.IsParent()) {
                    // Delete all subtasks first
                    var subtasksToDelete = allTasks.Where(t => t.ParentId == id).ToList();
                    foreach (var subtask in subtasksToDelete) {
                        allTasks.Remove(subtask);
                    }
                }
                allTasks.Remove(task);
                SaveToDisk();
            }
        }
        
        public void ToggleComplete(string id) {
            var task = GetTask(id);
            if (task != null) {
                task.Completed = !task.Completed;
                task.Touch();
                SaveToDisk();
            }
        }
        
        // Task Movement
        public void MoveTaskUp(string id) {
            var task = GetTask(id);
            if (task?.IsParent() == true) {
                var parentTasks = GetParentTasks().OrderBy(t => t.SortOrder).ToList();
                var currentIndex = parentTasks.FindIndex(t => t.Id == id);
                if (currentIndex > 0) {
                    // Swap sort orders
                    var temp = parentTasks[currentIndex - 1].SortOrder;
                    parentTasks[currentIndex - 1].SortOrder = task.SortOrder;
                    task.SortOrder = temp;
                    SaveToDisk();
                }
            }
        }
        
        public void MoveTaskDown(string id) {
            var task = GetTask(id);
            if (task?.IsParent() == true) {
                var parentTasks = GetParentTasks().OrderBy(t => t.SortOrder).ToList();
                var currentIndex = parentTasks.FindIndex(t => t.Id == id);
                if (currentIndex < parentTasks.Count - 1) {
                    // Swap sort orders
                    var temp = parentTasks[currentIndex + 1].SortOrder;
                    parentTasks[currentIndex + 1].SortOrder = task.SortOrder;
                    task.SortOrder = temp;
                    SaveToDisk();
                }
            }
        }
        
        // Filtering
        public List<SimpleTask> ApplyFilter(FilterCriteria criteria) {
            return filter.ApplyFilters(GetParentTasks(), criteria);
        }
        
        public List<TaskListItem> BuildFlatList(List<SimpleTask> tasks, bool globalCollapseSubtasks) {
            var flatList = new List<TaskListItem>();
            
            foreach (var task in tasks.OrderBy(t => t.SortOrder)) {
                // Add parent task
                flatList.Add(new TaskListItem {
                    Task = task,
                    Level = 0,
                    IsExpanded = !task.SubtasksCollapsed && !globalCollapseSubtasks,
                    HasChildren = task.HasSubtasks(),
                    ParentTask = null
                });
                
                // Add subtasks if expanded
                if (!task.SubtasksCollapsed && !globalCollapseSubtasks) {
                    var subtasks = task.Subtasks.OrderBy(st => st.SortOrder);
                    foreach (var subtask in subtasks) {
                        flatList.Add(new TaskListItem {
                            Task = subtask,
                            Level = 1,
                            IsExpanded = false,
                            HasChildren = false,
                            ParentTask = task
                        });
                    }
                }
            }
            
            return flatList;
        }
        
        // Persistence
        private void LoadFromDisk() {
            allTasks = persistence.LoadTasks();
        }
        
        private void SaveToDisk() {
            persistence.SaveTasks(allTasks);
        }
        
        // Public save method for UI components
        public void Save() {
            SaveToDisk();
        }
    }
}