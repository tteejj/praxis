using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.ComponentModel;
using System.Linq;
using System.Threading;
using System.Windows.Input;
using PraxisWpf.Interfaces;
using PraxisWpf.Models;
using PraxisWpf.Services;

namespace PraxisWpf.Features.TaskViewer
{
    public class TaskViewModel : INotifyPropertyChanged
    {
        private readonly IDataService _dataService;
        private readonly IDialogService _dialogService;
        private TaskItem? _selectedItem;

        public ObservableCollection<TaskItem> Items { get; private set; }

        public TaskItem? SelectedItem
        {
            get => _selectedItem;
            set
            {
                if (_selectedItem != value)
                {
                    _selectedItem = value;
                    OnPropertyChanged(nameof(SelectedItem));
                }
            }
        }

        public ICommand NewCommand { get; }
        public ICommand EditCommand { get; }
        public ICommand DeleteCommand { get; }
        public ICommand SaveCommand { get; }
        public ICommand ExpandCommand { get; }
        public ICommand CollapseCommand { get; }
        public ICommand ExpandAllCommand { get; }
        public ICommand CollapseAllCommand { get; }

        public TaskViewModel() : this(ServiceContainer.GetDataService(), ServiceContainer.GetDialogService())
        {
            // Default constructor using registered services
        }

        public TaskViewModel(IDataService dataService, IDialogService dialogService)
        {
            _dataService = dataService;
            _dialogService = dialogService;
            Items = _dataService.LoadItems();
            Logger.Info("TaskViewModel", $"Loaded {Items.Count} tasks");

            // Auto-select first item if available
            if (Items.Count > 0)
            {
                SelectedItem = Items[0];
            }

            // Initialize commands
            NewCommand = new RelayCommand(ExecuteNew, CanExecuteNew);
            EditCommand = new RelayCommand(ExecuteEdit, CanExecuteEdit);
            DeleteCommand = new RelayCommand(ExecuteDelete, CanExecuteDelete);
            SaveCommand = new RelayCommand(ExecuteSave);
            ExpandCommand = new RelayCommand(ExecuteExpand, CanExecuteExpand);
            CollapseCommand = new RelayCommand(ExecuteCollapse, CanExecuteCollapse);
            ExpandAllCommand = new RelayCommand(ExecuteExpandAll);
            CollapseAllCommand = new RelayCommand(ExecuteCollapseAll);
        }

        private void ExecuteNew()
        {
            var nextId = GetNextId1();
            var newTask = new TaskItem
            {
                Id1 = nextId,
                Id2 = 1,
                Name = "New Task",
                IsInEditMode = true,
                Priority = PriorityType.Medium,
                AssignedDate = DateTime.Now,
                DueDate = DateTime.Today.AddDays(7),
                BringForwardDate = DateTime.Today.AddDays(1)
            };

            // Validate the new task
            var validation = ValidationService.ValidateTaskItem(newTask);
            if (!validation.IsValid)
            {
                Logger.Warning("TaskViewModel", $"New task validation failed: {validation.ErrorMessage}");
                // Continue anyway for new tasks - user can fix in edit mode
            }

            if (SelectedItem != null)
            {
                // Validate hierarchy
                var hierarchyValidation = ValidationService.ValidateTaskHierarchy(SelectedItem, newTask);
                if (!hierarchyValidation.IsValid)
                {
                    Logger.Error("TaskViewModel", $"Cannot add task to hierarchy: {hierarchyValidation.ErrorMessage}");
                    return;
                }

                SelectedItem.Children.Add(newTask);
                SelectedItem.IsExpanded = true;
            }
            else
            {
                Items.Add(newTask);
            }

            SelectedItem = newTask;
            Logger.Info("TaskViewModel", $"New task created: '{newTask.Name}'");
        }

        private bool CanExecuteNew()
        {
            return true;
        }

        private void ExecuteEdit()
        {
            if (SelectedItem != null)
            {
                SelectedItem.IsInEditMode = !SelectedItem.IsInEditMode;
            }
        }

        private bool CanExecuteEdit()
        {
            return SelectedItem != null;
        }

        private void ExecuteDelete()
        {
            if (SelectedItem == null) return;

            var taskName = SelectedItem.Name;
            var hasChildren = SelectedItem.Children.Count > 0;
            var childCount = GetTotalChildrenCount(SelectedItem);

            // Build confirmation message
            var message = $"Are you sure you want to delete the task '{taskName}'?";
            var details = "";

            if (hasChildren)
            {
                details = $"This task has {childCount} subtask(s) that will also be deleted.\nThis action cannot be undone.";
            }
            else
            {
                details = "This action cannot be undone.";
            }

            // Show confirmation dialog
            if (_dialogService.ShowConfirmationDialog("Delete Task", message, details))
            {
                // Find and remove from parent collection
                if (RemoveFromCollection(Items, SelectedItem))
                {
                    Logger.Info("TaskViewModel", $"Deleted task '{taskName}' with {childCount} children");
                    SelectedItem = null;
                }
            }
            else
            {
                Logger.Debug("TaskViewModel", $"Delete cancelled for task '{taskName}'");
            }
        }

        private bool CanExecuteDelete()
        {
            return SelectedItem != null;
        }

        private void ExecuteSave()
        {
            try
            {
                // Validate all tasks before saving
                var invalidTasks = ValidateAllTasks();
                if (invalidTasks.Any())
                {
                    Logger.Warning("TaskViewModel", $"Found {invalidTasks.Count} tasks with validation issues");
                    // Continue with save but log the issues
                }

                _dataService.SaveItems(Items);
                Logger.Info("TaskViewModel", "Data saved successfully");
            }
            catch (Exception ex)
            {
                Logger.Error("TaskViewModel", "Save operation failed", ex);
                // Data service handles user notification
            }
        }

        private List<(TaskItem task, ValidationResult validation)> ValidateAllTasks()
        {
            var invalidTasks = new List<(TaskItem, ValidationResult)>();
            using var cts = new CancellationTokenSource(TimeSpan.FromSeconds(30)); // 30 second timeout
            
            try
            {
                ValidateTaskCollection(Items, invalidTasks, 0, cts.Token);
            }
            catch (OperationCanceledException)
            {
                Logger.Warning("TaskViewModel", "Task validation cancelled due to timeout");
                // Return what we have so far
            }
            
            return invalidTasks;
        }

        private void ValidateTaskCollection(ObservableCollection<TaskItem> tasks, List<(TaskItem, ValidationResult)> invalidTasks, 
            int depth = 0, CancellationToken cancellationToken = default)
        {
            if (depth > 50) return; // Prevent stack overflow
            
            foreach (var task in tasks)
            {
                cancellationToken.ThrowIfCancellationRequested();
                
                var validation = ValidationService.ValidateTaskItem(task);
                if (!validation.IsValid)
                {
                    invalidTasks.Add((task, validation));
                    Logger.Debug("TaskViewModel", $"Task '{task.Name}' validation: {validation.ErrorMessage}");
                }

                // Recursively validate children
                if (task.Children.Any())
                {
                    ValidateTaskCollection(task.Children, invalidTasks, depth + 1, cancellationToken);
                }
            }
        }

        private void ExecuteExpand()
        {
            if (SelectedItem != null)
            {
                SelectedItem.IsExpanded = true;
            }
        }

        private bool CanExecuteExpand()
        {
            return SelectedItem != null && SelectedItem.Children.Count > 0 && !SelectedItem.IsExpanded;
        }

        private void ExecuteCollapse()
        {
            if (SelectedItem != null)
            {
                SelectedItem.IsExpanded = false;
            }
        }

        private bool CanExecuteCollapse()
        {
            return SelectedItem != null && SelectedItem.Children.Count > 0 && SelectedItem.IsExpanded;
        }

        private void ExecuteExpandAll()
        {
            using var cts = new CancellationTokenSource(TimeSpan.FromSeconds(10)); // 10 second timeout
            
            try
            {
                var expandedCount = ExpandAllItems(Items, 0, cts.Token);
                if (expandedCount > 0)
                {
                    Logger.Info("TaskViewModel", $"Expanded {expandedCount} items");
                }
            }
            catch (OperationCanceledException)
            {
                Logger.Warning("TaskViewModel", "Expand all operation cancelled due to timeout");
                _dialogService.ShowWarningDialog("Operation Timeout", "The expand all operation took too long and was cancelled.");
            }
        }

        private void ExecuteCollapseAll()
        {
            using var cts = new CancellationTokenSource(TimeSpan.FromSeconds(10)); // 10 second timeout
            
            try
            {
                var collapsedCount = CollapseAllItems(Items, 0, cts.Token);
                if (collapsedCount > 0)
                {
                    Logger.Info("TaskViewModel", $"Collapsed {collapsedCount} items");
                }
            }
            catch (OperationCanceledException)
            {
                Logger.Warning("TaskViewModel", "Collapse all operation cancelled due to timeout");
                _dialogService.ShowWarningDialog("Operation Timeout", "The collapse all operation took too long and was cancelled.");
            }
        }

        private int ExpandAllItems(ObservableCollection<TaskItem> items, int depth = 0, CancellationToken cancellationToken = default)
        {
            if (depth > 50) return 0; // Prevent stack overflow
            
            int count = 0;
            foreach (var item in items)
            {
                cancellationToken.ThrowIfCancellationRequested();
                
                if (item.Children.Count > 0 && !item.IsExpanded)
                {
                    item.IsExpanded = true;
                    count++;
                }
                count += ExpandAllItems(item.Children, depth + 1, cancellationToken);
            }
            return count;
        }

        private int CollapseAllItems(ObservableCollection<TaskItem> items, int depth = 0, CancellationToken cancellationToken = default)
        {
            if (depth > 50) return 0; // Prevent stack overflow
            
            int count = 0;
            foreach (var item in items)
            {
                cancellationToken.ThrowIfCancellationRequested();
                
                if (item.Children.Count > 0 && item.IsExpanded)
                {
                    item.IsExpanded = false;
                    count++;
                }
                count += CollapseAllItems(item.Children, depth + 1, cancellationToken);
            }
            return count;
        }

        private bool RemoveFromCollection(ObservableCollection<TaskItem> collection, TaskItem itemToRemove)
        {
            if (collection.Contains(itemToRemove))
            {
                collection.Remove(itemToRemove);
                return true;
            }

            foreach (var item in collection)
            {
                if (RemoveFromCollection(item.Children, itemToRemove))
                {
                    return true;
                }
            }

            return false;
        }

        private int GetNextId1()
        {
            var maxId = GetMaxId1(Items);
            return maxId + 1;
        }

        private int GetMaxId1(ObservableCollection<TaskItem> items, int depth = 0, CancellationToken cancellationToken = default)
        {
            if (depth > 50) return 0; // Prevent stack overflow
            
            int max = 0;
            foreach (var item in items)
            {
                cancellationToken.ThrowIfCancellationRequested();
                
                if (item.Id1 > max) max = item.Id1;
                var childMax = GetMaxId1(item.Children, depth + 1, cancellationToken);
                if (childMax > max) max = childMax;
            }
            return max;
        }

        private int GetTotalChildrenCount(TaskItem item, int depth = 0)
        {
            if (depth > 50) return 0; // Prevent stack overflow
            
            int count = item.Children.Count;
            foreach (var child in item.Children)
            {
                count += GetTotalChildrenCount(child, depth + 1);
            }
            return count;
        }

        public event PropertyChangedEventHandler? PropertyChanged;

        protected virtual void OnPropertyChanged(string propertyName)
        {
            PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(propertyName));
        }
    }

}