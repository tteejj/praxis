using System;
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
    public class MainWindowViewModel : BaseViewModel
    {
        private readonly IDataService _dataService;
        private readonly IDialogService _dialogService;
        private readonly IStatusService _statusService;
        private readonly IEditorService _editorService;
        private readonly UndoRedoManager _undoRedoManager;
        private TaskItem? _selectedItem;

        public ObservableCollection<TaskItem> Items { get; private set; }
        public UndoRedoManager UndoRedoManager => _undoRedoManager;

        public TaskItem? SelectedItem
        {
            get => _selectedItem;
            set => SetProperty(value);
        }

        // Commands
        public ICommand NewCommand { get; }
        public ICommand EditCommand { get; }
        public ICommand DeleteCommand { get; }
        public ICommand SaveCommand { get; }
        public ICommand ExpandCommand { get; }
        public ICommand CollapseCommand { get; }
        public ICommand ExpandAllCommand { get; }
        public ICommand CollapseAllCommand { get; }
        public ICommand OpenNotesCommand { get; }
        public ICommand UndoCommand { get; }
        public ICommand RedoCommand { get; }

        public MainWindowViewModel(
            IDataService dataService, 
            IDialogService dialogService,
            IStatusService statusService,
            IEditorService editorService,
            UndoRedoManager undoRedoManager)
        {
            _dataService = dataService;
            _dialogService = dialogService;
            _statusService = statusService;
            _editorService = editorService;
            _undoRedoManager = undoRedoManager;
            
            // Load data
            using (var progress = _statusService.CreateProgressScope("Loading tasks..."))
            {
                Items = _dataService.LoadItems();
                progress.UpdateProgress(100, $"Loaded {Items.Count} tasks");
                Logger.Info("MainWindowViewModel", $"Loaded {Items.Count} tasks");
            }

            // Auto-select first item
            if (Items.Count > 0)
            {
                SelectedItem = Items[0];
            }

            // Initialize commands with enhanced functionality
            NewCommand = CreateCommand(ExecuteNew, CanExecuteNew);
            EditCommand = CreateCommand(ExecuteEdit, CanExecuteEdit);
            DeleteCommand = CreateCommand(ExecuteDelete, CanExecuteDelete);
            SaveCommand = CreateAsyncCommand(ExecuteSaveAsync);
            ExpandCommand = CreateCommand(ExecuteExpand, CanExecuteExpand);
            CollapseCommand = CreateCommand(ExecuteCollapse, CanExecuteCollapse);
            ExpandAllCommand = CreateAsyncCommand(ExecuteExpandAllAsync);
            CollapseAllCommand = CreateAsyncCommand(ExecuteCollapseAllAsync);
            OpenNotesCommand = CreateAsyncCommand(ExecuteOpenNotesAsync, CanExecuteOpenNotes);
            UndoCommand = CreateCommand(() => _undoRedoManager.Undo(), () => _undoRedoManager.CanUndo);
            RedoCommand = CreateCommand(() => _undoRedoManager.Redo(), () => _undoRedoManager.CanRedo);

            // Subscribe to undo/redo events for command refresh
            _undoRedoManager.PropertyChanged += (s, e) =>
            {
                if (e.PropertyName == nameof(UndoRedoManager.CanUndo) || e.PropertyName == nameof(UndoRedoManager.CanRedo))
                {
                    System.Windows.Input.CommandManager.InvalidateRequerySuggested();
                }
            };

            _statusService.ShowStatus("Task manager initialized", StatusType.Success);
        }

        #region Command Implementations

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

            var validation = ValidationService.ValidateTaskItem(newTask);
            if (!validation.IsValid)
            {
                Logger.Warning("MainWindowViewModel", $"New task validation failed: {validation.ErrorMessage}");
            }

            // Create undoable action
            var action = new DelegateAction(
                $"Create task '{newTask.Name}'",
                executeAction: () =>
                {
                    if (SelectedItem != null)
                    {
                        SelectedItem.Children.Add(newTask);
                        SelectedItem.IsExpanded = true;
                    }
                    else
                    {
                        Items.Add(newTask);
                    }
                    SelectedItem = newTask;
                },
                undoAction: () =>
                {
                    if (SelectedItem?.Children.Contains(newTask) == true)
                    {
                        SelectedItem.Children.Remove(newTask);
                    }
                    else
                    {
                        Items.Remove(newTask);
                    }
                });

            _undoRedoManager.ExecuteAction(action);
            _statusService.ShowStatus($"Created new task: {newTask.Name}", StatusType.Success);
            Logger.Info("MainWindowViewModel", $"New task created: '{newTask.Name}'");
        }

        private bool CanExecuteNew() => true;

        private void ExecuteEdit()
        {
            if (SelectedItem != null)
            {
                SelectedItem.IsInEditMode = !SelectedItem.IsInEditMode;
                var mode = SelectedItem.IsInEditMode ? "edit" : "view";
                _statusService.ShowStatus($"Switched to {mode} mode", StatusType.Info);
            }
        }

        private bool CanExecuteEdit() => SelectedItem != null;

        private void ExecuteDelete()
        {
            if (SelectedItem == null) return;

            var taskName = SelectedItem.Name;
            var childCount = GetTotalChildrenCount(SelectedItem);

            var message = $"Are you sure you want to delete the task '{taskName}'?";
            var details = childCount > 0 
                ? $"This task has {childCount} subtask(s) that will also be deleted.\nThis action can be undone."
                : "This action can be undone.";

            if (_dialogService.ShowConfirmationDialog("Delete Task", message, details))
            {
                var taskToDelete = SelectedItem;
                var parentCollection = FindParentCollection(taskToDelete);
                
                if (parentCollection != null)
                {
                    var action = new DelegateAction(
                        $"Delete task '{taskName}' and {childCount} children",
                        executeAction: () =>
                        {
                            parentCollection.Remove(taskToDelete);
                            SelectedItem = null;
                        },
                        undoAction: () =>
                        {
                            parentCollection.Add(taskToDelete);
                            SelectedItem = taskToDelete;
                        });

                    _undoRedoManager.ExecuteAction(action);
                    _statusService.ShowStatus($"Deleted task '{taskName}' with {childCount} children", StatusType.Success);
                    Logger.Info("MainWindowViewModel", $"Deleted task '{taskName}' with {childCount} children");
                }
            }
        }

        private bool CanExecuteDelete() => SelectedItem != null;

        private async System.Threading.Tasks.Task ExecuteSaveAsync()
        {
            using var progress = _statusService.CreateProgressScope("Saving tasks...");
            
            try
            {
                progress.UpdateProgress(25, "Validating tasks...");
                var invalidTasks = await ValidateAllTasksAsync();
                
                if (invalidTasks.Any())
                {
                    progress.UpdateProgress(50, $"Found {invalidTasks.Count} validation issues");
                    Logger.Warning("MainWindowViewModel", $"Found {invalidTasks.Count} tasks with validation issues");
                }

                progress.UpdateProgress(75, "Writing to file...");
                _dataService.SaveItems(Items);
                
                progress.Complete("Tasks saved successfully");
                Logger.Info("MainWindowViewModel", "Data saved successfully");
            }
            catch (Exception ex)
            {
                Logger.Error("MainWindowViewModel", "Save operation failed", ex);
                _statusService.ShowStatus($"Save failed: {ex.Message}", StatusType.Error);
            }
        }

        private void ExecuteExpand()
        {
            if (SelectedItem != null)
            {
                SelectedItem.IsExpanded = true;
                _statusService.ShowStatus("Item expanded", StatusType.Info);
            }
        }

        private bool CanExecuteExpand() => SelectedItem?.Children.Count > 0 && !SelectedItem.IsExpanded;

        private void ExecuteCollapse()
        {
            if (SelectedItem != null)
            {
                SelectedItem.IsExpanded = false;
                _statusService.ShowStatus("Item collapsed", StatusType.Info);
            }
        }

        private bool CanExecuteCollapse() => SelectedItem?.Children.Count > 0 && SelectedItem.IsExpanded;

        private async System.Threading.Tasks.Task ExecuteExpandAllAsync()
        {
            using var progress = _statusService.CreateProgressScope("Expanding all items...");
            using var cts = new CancellationTokenSource(TimeSpan.FromSeconds(10));
            
            try
            {
                var expandedCount = await System.Threading.Tasks.Task.Run(() => 
                    ExpandAllItems(Items, 0, cts.Token), cts.Token);
                    
                progress.Complete($"Expanded {expandedCount} items");
                Logger.Info("MainWindowViewModel", $"Expanded {expandedCount} items");
            }
            catch (OperationCanceledException)
            {
                Logger.Warning("MainWindowViewModel", "Expand all operation cancelled due to timeout");
                _statusService.ShowStatus("Expand all operation timed out", StatusType.Warning);
            }
        }

        private async System.Threading.Tasks.Task ExecuteCollapseAllAsync()
        {
            using var progress = _statusService.CreateProgressScope("Collapsing all items...");
            using var cts = new CancellationTokenSource(TimeSpan.FromSeconds(10));
            
            try
            {
                var collapsedCount = await System.Threading.Tasks.Task.Run(() => 
                    CollapseAllItems(Items, 0, cts.Token), cts.Token);
                    
                progress.Complete($"Collapsed {collapsedCount} items");
                Logger.Info("MainWindowViewModel", $"Collapsed {collapsedCount} items");
            }
            catch (OperationCanceledException)
            {
                Logger.Warning("MainWindowViewModel", "Collapse all operation cancelled due to timeout");
                _statusService.ShowStatus("Collapse all operation timed out", StatusType.Warning);
            }
        }

        private async System.Threading.Tasks.Task ExecuteOpenNotesAsync()
        {
            if (SelectedItem == null) return;

            try
            {
                using var progress = _statusService.CreateProgressScope($"Opening notes for '{SelectedItem.Name}'...");
                
                progress.UpdateProgress(50, "Preparing notes file...");
                var success = await _editorService.OpenNotesAsync(SelectedItem.Name);
                
                if (success)
                {
                    progress.Complete($"Opened notes for '{SelectedItem.Name}'");
                }
                else
                {
                    _statusService.ShowStatus($"Failed to open notes for '{SelectedItem.Name}'", StatusType.Error);
                }
            }
            catch (Exception ex)
            {
                Logger.Error("MainWindowViewModel", $"Failed to open notes for '{SelectedItem?.Name}'", ex);
                _statusService.ShowStatus($"Error opening notes: {ex.Message}", StatusType.Error);
            }
        }

        private bool CanExecuteOpenNotes() => SelectedItem != null;

        #endregion

        #region Helper Methods

        private async System.Threading.Tasks.Task<System.Collections.Generic.List<(TaskItem task, ValidationResult validation)>> ValidateAllTasksAsync()
        {
            return await System.Threading.Tasks.Task.Run(() =>
            {
                var invalidTasks = new System.Collections.Generic.List<(TaskItem, ValidationResult)>();
                using var cts = new CancellationTokenSource(TimeSpan.FromSeconds(30));
                
                try
                {
                    ValidateTaskCollection(Items, invalidTasks, 0, cts.Token);
                }
                catch (OperationCanceledException)
                {
                    Logger.Warning("MainWindowViewModel", "Task validation cancelled due to timeout");
                }
                
                return invalidTasks;
            });
        }

        private void ValidateTaskCollection(ObservableCollection<TaskItem> tasks, 
            System.Collections.Generic.List<(TaskItem, ValidationResult)> invalidTasks, 
            int depth = 0, CancellationToken cancellationToken = default)
        {
            if (depth > 50) return;
            
            foreach (var task in tasks)
            {
                cancellationToken.ThrowIfCancellationRequested();
                
                var validation = ValidationService.ValidateTaskItem(task);
                if (!validation.IsValid)
                {
                    invalidTasks.Add((task, validation));
                }

                if (task.Children.Any())
                {
                    ValidateTaskCollection(task.Children, invalidTasks, depth + 1, cancellationToken);
                }
            }
        }

        private int ExpandAllItems(ObservableCollection<TaskItem> items, int depth = 0, CancellationToken cancellationToken = default)
        {
            if (depth > 50) return 0;
            
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
            if (depth > 50) return 0;
            
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

        private ObservableCollection<TaskItem>? FindParentCollection(TaskItem task)
        {
            if (Items.Contains(task))
                return Items;

            return FindParentCollectionRecursive(Items, task);
        }

        private ObservableCollection<TaskItem>? FindParentCollectionRecursive(ObservableCollection<TaskItem> items, TaskItem targetTask)
        {
            foreach (var item in items)
            {
                if (item.Children.Contains(targetTask))
                    return item.Children;

                var parent = FindParentCollectionRecursive(item.Children, targetTask);
                if (parent != null)
                    return parent;
            }
            return null;
        }

        private int GetNextId1()
        {
            var maxId = GetMaxId1(Items);
            return maxId + 1;
        }

        private int GetMaxId1(ObservableCollection<TaskItem> items, int depth = 0)
        {
            if (depth > 50) return 0;
            
            int max = 0;
            foreach (var item in items)
            {
                if (item.Id1 > max) max = item.Id1;
                var childMax = GetMaxId1(item.Children, depth + 1);
                if (childMax > max) max = childMax;
            }
            return max;
        }

        private int GetTotalChildrenCount(TaskItem item, int depth = 0)
        {
            if (depth > 50) return 0;
            
            int count = item.Children.Count;
            foreach (var child in item.Children)
            {
                count += GetTotalChildrenCount(child, depth + 1);
            }
            return count;
        }

        #endregion

        protected override void OnDisposing()
        {
            _statusService.ShowStatus("Shutting down...", StatusType.Info);
            base.OnDisposing();
        }
    }
}