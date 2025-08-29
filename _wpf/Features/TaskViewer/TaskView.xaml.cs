using System;
using System.Windows.Controls;
using PraxisWpf.Services;

namespace PraxisWpf.Features.TaskViewer
{
    /// <summary>
    /// TaskView now uses attached behaviors for MVVM compliance.
    /// All keyboard handling and focus management is handled through behaviors.
    /// </summary>
    public partial class TaskView : UserControl
    {
        public TaskView()
        {
            try
            {
                InitializeComponent();
                Logger.Debug("TaskView", "TaskView initialized with MVVM behaviors");
            }
            catch (Exception ex)
            {
                Logger.Critical("TaskView", "Failed to initialize TaskView", ex);
                throw;
            }
        }
    }
}