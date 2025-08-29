using System;
using System.ComponentModel;
using System.Windows;
using PraxisWpf.Features.TaskViewer;
using PraxisWpf.Interfaces;
using PraxisWpf.Services;

namespace PraxisWpf
{
    public partial class MainWindow : Window, INotifyPropertyChanged
    {
        private MainWindowViewModel? _mainViewModel;
        private readonly IPreferencesService _preferencesService;
        private readonly IStatusService _statusService;
        
        public IStatusService StatusService => _statusService;
        public MainWindowViewModel? TaskViewModel => _mainViewModel;
        
        public event PropertyChangedEventHandler? PropertyChanged;

        public MainWindow()
        {
            try
            {
                // Get services from DI container
                var container = DIContainer.Instance;
                _preferencesService = container.Resolve<IPreferencesService>();
                _statusService = container.Resolve<IStatusService>();
                
                InitializeComponent();
                
                // Initialize ViewModel with services
                _mainViewModel = new MainWindowViewModel(
                    container.Resolve<IDataService>(), 
                    container.Resolve<IDialogService>(),
                    _statusService,
                    container.Resolve<IEditorService>(),
                    container.Resolve<UndoRedoManager>());
                    
                DataContext = this; // Set this as DataContext to expose StatusService and TaskViewModel
                
                // Load and apply preferences
                LoadWindowPreferences();
                
                Logger.Info("MainWindow", "Application initialized with full service integration");
                _statusService.ShowStatus("Praxis Task Manager ready", StatusType.Success);
            }
            catch (Exception ex)
            {
                Logger.Critical("MainWindow", "Failed to initialize application", ex);
                throw;
            }
        }

        protected override void OnSourceInitialized(EventArgs e)
        {
            try
            {
                base.OnSourceInitialized(e);
            }
            catch (Exception ex)
            {
                Logger.Error("MainWindow", "Error during source initialization", ex);
                throw;
            }
        }

        protected override void OnActivated(EventArgs e)
        {
            base.OnActivated(e);
        }

        protected override void OnDeactivated(EventArgs e)
        {
            base.OnDeactivated(e);
        }

        protected override void OnClosed(EventArgs e)
        {
            try
            {
                SaveWindowPreferences();
                _statusService.ShowStatus("Application closing...", StatusType.Info);
                base.OnClosed(e);
                Logger.Info("MainWindow", "Application closing");
            }
            catch (Exception ex)
            {
                Logger.Error("MainWindow", "Error during close", ex);
            }
        }
        
        private void LoadWindowPreferences()
        {
            try
            {
                var preferences = _preferencesService.LoadPreferences();
                var windowSettings = preferences.Window;
                
                if (windowSettings.Width > 0 && windowSettings.Height > 0)
                {
                    Width = windowSettings.Width;
                    Height = windowSettings.Height;
                }
                
                if (windowSettings.Left > 0 && windowSettings.Top > 0)
                {
                    Left = windowSettings.Left;
                    Top = windowSettings.Top;
                    WindowStartupLocation = WindowStartupLocation.Manual;
                }
                
                if (windowSettings.IsMaximized)
                {
                    WindowState = WindowState.Maximized;
                }
                
                Logger.Debug("MainWindow", "Window preferences loaded");
            }
            catch (Exception ex)
            {
                Logger.Error("MainWindow", "Error loading window preferences", ex);
            }
        }
        
        private void SaveWindowPreferences()
        {
            try
            {
                var preferences = _preferencesService.LoadPreferences();
                var windowSettings = preferences.Window;
                
                if (WindowState == WindowState.Normal)
                {
                    windowSettings.Width = Width;
                    windowSettings.Height = Height;
                    windowSettings.Left = Left;
                    windowSettings.Top = Top;
                }
                
                windowSettings.IsMaximized = WindowState == WindowState.Maximized;
                
                _preferencesService.SavePreferences(preferences);
                Logger.Debug("MainWindow", "Window preferences saved");
            }
            catch (Exception ex)
            {
                Logger.Error("MainWindow", "Error saving window preferences", ex);
            }
        }
        
        protected virtual void OnPropertyChanged(string propertyName)
        {
            PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(propertyName));
        }
    }
}