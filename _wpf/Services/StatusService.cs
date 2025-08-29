using System;
using System.Collections.ObjectModel;
using System.ComponentModel;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;

namespace PraxisWpf.Services
{
    public enum StatusType
    {
        Info,
        Success,
        Warning,
        Error,
        Progress
    }

    public class StatusMessage : INotifyPropertyChanged
    {
        private string _message = "";
        private StatusType _type = StatusType.Info;
        private double _progress = 0;
        private bool _showProgress = false;

        public string Id { get; } = Guid.NewGuid().ToString();
        public DateTime Timestamp { get; } = DateTime.Now;
        
        public string Message
        {
            get => _message;
            set
            {
                if (_message != value)
                {
                    _message = value;
                    OnPropertyChanged(nameof(Message));
                }
            }
        }

        public StatusType Type
        {
            get => _type;
            set
            {
                if (_type != value)
                {
                    _type = value;
                    OnPropertyChanged(nameof(Type));
                }
            }
        }

        public double Progress
        {
            get => _progress;
            set
            {
                var clampedValue = Math.Max(0, Math.Min(100, value));
                if (Math.Abs(_progress - clampedValue) > 0.001)
                {
                    _progress = clampedValue;
                    OnPropertyChanged(nameof(Progress));
                }
            }
        }

        public bool ShowProgress
        {
            get => _showProgress;
            set
            {
                if (_showProgress != value)
                {
                    _showProgress = value;
                    OnPropertyChanged(nameof(ShowProgress));
                }
            }
        }

        public bool IsAutoExpiring { get; set; } = true;
        public TimeSpan AutoExpireAfter { get; set; } = TimeSpan.FromSeconds(5);

        public event PropertyChangedEventHandler? PropertyChanged;

        protected virtual void OnPropertyChanged(string propertyName)
        {
            PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(propertyName));
        }
    }

    public interface IStatusService : INotifyPropertyChanged
    {
        ObservableCollection<StatusMessage> Messages { get; }
        StatusMessage? CurrentMessage { get; }
        bool IsVisible { get; set; }
        
        StatusMessage ShowStatus(string message, StatusType type = StatusType.Info, bool autoExpire = true);
        StatusMessage ShowProgress(string message, double progress = 0);
        void UpdateProgress(string messageId, double progress, string? newMessage = null);
        void CompleteProgress(string messageId, string? successMessage = null);
        void ClearMessage(string messageId);
        void ClearAll();
        void ClearExpiredMessages();
        IDisposable CreateProgressScope(string message);
    }

    public class StatusService : IStatusService
    {
        private readonly Timer _cleanupTimer;
        private bool _isVisible = true;
        private StatusMessage? _currentMessage;

        public ObservableCollection<StatusMessage> Messages { get; } = new();
        
        public StatusMessage? CurrentMessage
        {
            get => _currentMessage;
            private set
            {
                if (_currentMessage != value)
                {
                    _currentMessage = value;
                    OnPropertyChanged(nameof(CurrentMessage));
                }
            }
        }

        public bool IsVisible
        {
            get => _isVisible;
            set
            {
                if (_isVisible != value)
                {
                    _isVisible = value;
                    OnPropertyChanged(nameof(IsVisible));
                }
            }
        }

        public event PropertyChangedEventHandler? PropertyChanged;

        public StatusService()
        {
            // Clean up expired messages every 2 seconds
            _cleanupTimer = new Timer(
                _ => ClearExpiredMessages(),
                null,
                TimeSpan.FromSeconds(2),
                TimeSpan.FromSeconds(2));

            Logger.Debug("StatusService", "StatusService initialized");
        }

        public StatusMessage ShowStatus(string message, StatusType type = StatusType.Info, bool autoExpire = true)
        {
            var statusMessage = new StatusMessage
            {
                Message = message,
                Type = type,
                IsAutoExpiring = autoExpire,
                AutoExpireAfter = type switch
                {
                    StatusType.Error => TimeSpan.FromSeconds(10),
                    StatusType.Warning => TimeSpan.FromSeconds(7),
                    StatusType.Success => TimeSpan.FromSeconds(3),
                    StatusType.Progress => TimeSpan.FromMinutes(5),
                    _ => TimeSpan.FromSeconds(5)
                }
            };

            Messages.Add(statusMessage);
            CurrentMessage = statusMessage;
            
            Logger.Debug("StatusService", $"Status shown: {type} - {message}");
            return statusMessage;
        }

        public StatusMessage ShowProgress(string message, double progress = 0)
        {
            var statusMessage = new StatusMessage
            {
                Message = message,
                Type = StatusType.Progress,
                Progress = progress,
                ShowProgress = true,
                IsAutoExpiring = false // Progress messages don't auto-expire
            };

            Messages.Add(statusMessage);
            CurrentMessage = statusMessage;
            
            Logger.Debug("StatusService", $"Progress shown: {message} - {progress}%");
            return statusMessage;
        }

        public void UpdateProgress(string messageId, double progress, string? newMessage = null)
        {
            var message = Messages.FirstOrDefault(m => m.Id == messageId);
            if (message != null)
            {
                message.Progress = progress;
                if (!string.IsNullOrEmpty(newMessage))
                {
                    message.Message = newMessage;
                }
                
                Logger.Debug("StatusService", $"Progress updated: {messageId} - {progress}%");
            }
        }

        public void CompleteProgress(string messageId, string? successMessage = null)
        {
            var message = Messages.FirstOrDefault(m => m.Id == messageId);
            if (message != null)
            {
                message.Progress = 100;
                message.Type = StatusType.Success;
                message.ShowProgress = false;
                message.IsAutoExpiring = true;
                message.AutoExpireAfter = TimeSpan.FromSeconds(3);
                
                if (!string.IsNullOrEmpty(successMessage))
                {
                    message.Message = successMessage;
                }
                
                Logger.Debug("StatusService", $"Progress completed: {messageId}");
            }
        }

        public void ClearMessage(string messageId)
        {
            var message = Messages.FirstOrDefault(m => m.Id == messageId);
            if (message != null)
            {
                Messages.Remove(message);
                
                if (CurrentMessage == message)
                {
                    CurrentMessage = Messages.LastOrDefault();
                }
                
                Logger.Debug("StatusService", $"Message cleared: {messageId}");
            }
        }

        public void ClearAll()
        {
            Messages.Clear();
            CurrentMessage = null;
            Logger.Debug("StatusService", "All messages cleared");
        }

        public void ClearExpiredMessages()
        {
            try
            {
                var now = DateTime.Now;
                var expiredMessages = Messages
                    .Where(m => m.IsAutoExpiring && (now - m.Timestamp) > m.AutoExpireAfter)
                    .ToList();

                foreach (var message in expiredMessages)
                {
                    Messages.Remove(message);
                    
                    if (CurrentMessage == message)
                    {
                        CurrentMessage = Messages.LastOrDefault();
                    }
                }

                if (expiredMessages.Count > 0)
                {
                    Logger.Debug("StatusService", $"Cleared {expiredMessages.Count} expired messages");
                }
            }
            catch (Exception ex)
            {
                Logger.Error("StatusService", "Error clearing expired messages", ex);
            }
        }

        public IDisposable CreateProgressScope(string message)
        {
            return new ProgressScope(this, message);
        }

        protected virtual void OnPropertyChanged(string propertyName)
        {
            PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(propertyName));
        }

        public void Dispose()
        {
            _cleanupTimer?.Dispose();
        }
    }

    public class ProgressScope : IDisposable
    {
        private readonly IStatusService _statusService;
        private readonly StatusMessage _progressMessage;
        private bool _disposed = false;

        public string MessageId => _progressMessage.Id;

        public ProgressScope(IStatusService statusService, string message)
        {
            _statusService = statusService;
            _progressMessage = _statusService.ShowProgress(message);
        }

        public void UpdateProgress(double progress, string? message = null)
        {
            if (!_disposed)
            {
                _statusService.UpdateProgress(_progressMessage.Id, progress, message);
            }
        }

        public void Complete(string? successMessage = null)
        {
            if (!_disposed)
            {
                _statusService.CompleteProgress(_progressMessage.Id, successMessage);
                _disposed = true;
            }
        }

        public void Dispose()
        {
            if (!_disposed)
            {
                Complete();
                _disposed = true;
            }
        }
    }
}