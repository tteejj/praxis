using System;
using System.Windows.Controls;
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
                if (DataContext is TaskViewModel viewModel && e.NewValue is IDisplayableItem selectedItem)
                {
                    Logger.Info("TaskView", $"TreeView selection changed to: {selectedItem.DisplayName}");
                    viewModel.SelectedItem = selectedItem;
                    Logger.Debug("TaskView", "ViewModel.SelectedItem updated");
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
    }
}