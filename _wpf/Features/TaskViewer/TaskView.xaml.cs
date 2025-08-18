using System;
using System.Windows.Controls;
using System.Windows.Input;
using PraxisWpf.Interfaces;
using PraxisWpf.Services;

namespace PraxisWpf.Features.TaskViewer
{
    public partial class TaskView : UserControl
    {
        public TaskView()
        {
            Logger.TraceEnter();
            try
            {
                using var perfTracker = Logger.TracePerformance("TaskView Constructor");
                
                Logger.Debug("TaskView", "Initializing XAML components");
                InitializeComponent();
                
                Logger.Info("TaskView", "TaskView initialized successfully");
                Logger.TraceExit();
            }
            catch (Exception ex)
            {
                Logger.Critical("TaskView", "Failed to initialize TaskView", ex);
                Logger.TraceExit();
                throw;
            }
        }

        private void TaskTreeView_SelectedItemChanged(object sender, System.Windows.RoutedPropertyChangedEventArgs<object> e)
        {
            Logger.TraceEnter(parameters: new object[] { 
                e.OldValue?.ToString() ?? "null", 
                e.NewValue?.ToString() ?? "null" 
            });

            try
            {
                var viewModel = DataContext as TaskViewModel;
                if (viewModel != null && e.NewValue is IDisplayableItem selectedItem)
                {
                    Logger.Info("TaskView", $"TreeView selection changed to: {selectedItem.DisplayName}");
                    viewModel.SelectedItem = selectedItem;
                    Logger.Debug("TaskView", "ViewModel.SelectedItem updated");
                    
                    // Ensure TreeView has focus for keyboard navigation
                    if (!TaskTreeView.IsFocused)
                    {
                        TaskTreeView.Focus();
                        Logger.Debug("TaskView", "TreeView focused for keyboard navigation");
                    }
                }
                else if (e.NewValue == null && viewModel != null)
                {
                    // Handle deselection
                    viewModel.SelectedItem = null;
                    Logger.Debug("TaskView", "Selection cleared");
                }
                else
                {
                    Logger.Warning("TaskView", "Selection change ignored", 
                        $"DataContext is TaskViewModel: {DataContext is TaskViewModel}, " +
                        $"NewValue is IDisplayableItem: {e.NewValue is IDisplayableItem}");
                }
                
                Logger.TraceExit();
            }
            catch (Exception ex)
            {
                Logger.Error("TaskView", "Error handling selection change", ex);
                Logger.TraceExit();
            }
        }

        public override void OnApplyTemplate()
        {
            base.OnApplyTemplate();
            
            // Ensure TreeView gets initial focus
            Logger.Debug("TaskView", "Applying template and setting initial focus");
            TaskTreeView.Focus();
        }

        private void TaskTreeView_KeyDown(object sender, KeyEventArgs e)
        {
            Logger.TraceEnter(parameters: new object[] { e.Key.ToString() });

            try
            {
                var viewModel = DataContext as TaskViewModel;
                if (viewModel == null) return;

                switch (e.Key)
                {
                    case Key.Enter:
                        // Enter key should toggle edit mode
                        if (viewModel.EditCommand.CanExecute(null))
                        {
                            Logger.Info("TaskView", "Enter key pressed - toggling edit mode");
                            viewModel.EditCommand.Execute(null);
                            e.Handled = true;
                        }
                        break;

                    case Key.Space:
                        // Space key should also toggle edit mode
                        if (viewModel.EditCommand.CanExecute(null))
                        {
                            Logger.Info("TaskView", "Space key pressed - toggling edit mode");
                            viewModel.EditCommand.Execute(null);
                            e.Handled = true;
                        }
                        break;

                    case Key.F2:
                        // F2 is standard for rename/edit
                        if (viewModel.EditCommand.CanExecute(null))
                        {
                            Logger.Info("TaskView", "F2 key pressed - entering edit mode");
                            viewModel.EditCommand.Execute(null);
                            e.Handled = true;
                        }
                        break;

                    case Key.Right:
                        // Right arrow should expand if collapsed
                        if (viewModel.SelectedItem != null && 
                            viewModel.SelectedItem.Children.Count > 0 && 
                            !viewModel.SelectedItem.IsExpanded)
                        {
                            Logger.Info("TaskView", "Right arrow pressed - expanding item");
                            viewModel.SelectedItem.IsExpanded = true;
                            e.Handled = true;
                        }
                        break;

                    case Key.Left:
                        // Left arrow should collapse if expanded
                        if (viewModel.SelectedItem != null && 
                            viewModel.SelectedItem.Children.Count > 0 && 
                            viewModel.SelectedItem.IsExpanded)
                        {
                            Logger.Info("TaskView", "Left arrow pressed - collapsing item");
                            viewModel.SelectedItem.IsExpanded = false;
                            e.Handled = true;
                        }
                        break;
                }

                Logger.TraceExit();
            }
            catch (Exception ex)
            {
                Logger.Error("TaskView", "Error handling key down", ex);
                Logger.TraceExit();
            }
        }

        private void EditTextBox_KeyDown(object sender, KeyEventArgs e)
        {
            Logger.TraceEnter(parameters: new object[] { e.Key.ToString() });

            try
            {
                var textBox = sender as TextBox;
                var viewModel = DataContext as TaskViewModel;
                if (textBox == null || viewModel == null) return;

                switch (e.Key)
                {
                    case Key.Enter:
                        // Enter confirms the edit and exits edit mode
                        Logger.Info("TaskView", "Enter pressed in TextBox - confirming edit");
                        if (viewModel.SelectedItem != null)
                        {
                            viewModel.SelectedItem.IsInEditMode = false;
                            TaskTreeView.Focus(); // Return focus to TreeView
                        }
                        e.Handled = true;
                        break;

                    case Key.Escape:
                        // Escape cancels the edit and exits edit mode
                        Logger.Info("TaskView", "Escape pressed in TextBox - canceling edit");
                        if (viewModel.SelectedItem != null)
                        {
                            viewModel.SelectedItem.IsInEditMode = false;
                            TaskTreeView.Focus(); // Return focus to TreeView
                            // TODO: Revert changes if needed
                        }
                        e.Handled = true;
                        break;
                }

                Logger.TraceExit();
            }
            catch (Exception ex)
            {
                Logger.Error("TaskView", "Error handling TextBox key down", ex);
                Logger.TraceExit();
            }
        }
    }
}