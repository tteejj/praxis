using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Runtime.CompilerServices;

namespace PraxisWpf.Services
{
    public abstract class BaseViewModel : INotifyPropertyChanged, IDisposable
    {
        private readonly Dictionary<string, object?> _propertyValues = new();
        private bool _disposed = false;

        public event PropertyChangedEventHandler? PropertyChanged;

        protected virtual void OnPropertyChanged([CallerMemberName] string? propertyName = null)
        {
            if (Logger.ShouldLog(LogLevel.Trace))
            {
                Logger.TraceProperty(propertyName ?? "Unknown", 
                    _propertyValues.GetValueOrDefault(propertyName), 
                    GetType().Name);
            }
            
            PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(propertyName));
        }

        protected bool SetProperty<T>(T value, [CallerMemberName] string? propertyName = null)
        {
            if (propertyName == null) return false;

            var oldValue = _propertyValues.GetValueOrDefault(propertyName);
            
            if (EqualityComparer<T>.Default.Equals((T?)oldValue, value))
                return false;

            _propertyValues[propertyName] = value;
            OnPropertyChanged(propertyName);
            return true;
        }

        protected T? GetProperty<T>([CallerMemberName] string? propertyName = null)
        {
            if (propertyName == null) return default;
            
            return _propertyValues.TryGetValue(propertyName, out var value) 
                ? (T?)value 
                : default;
        }

        protected RelayCommand CreateCommand(Action execute, Func<bool>? canExecute = null)
        {
            return new RelayCommand(execute, canExecute);
        }

        protected RelayCommand<T> CreateCommand<T>(Action<T?> execute, Func<T?, bool>? canExecute = null)
        {
            return new RelayCommand<T>(execute, canExecute);
        }

        protected AsyncRelayCommand CreateAsyncCommand(Func<System.Threading.Tasks.Task> execute, Func<bool>? canExecute = null)
        {
            return new AsyncRelayCommand(execute, canExecute);
        }

        protected AsyncRelayCommand<T> CreateAsyncCommand<T>(Func<T?, System.Threading.Tasks.Task> execute, Func<T?, bool>? canExecute = null)
        {
            return new AsyncRelayCommand<T>(execute, canExecute);
        }

        public virtual void Dispose()
        {
            if (!_disposed)
            {
                OnDisposing();
                _disposed = true;
            }
            GC.SuppressFinalize(this);
        }

        protected virtual void OnDisposing()
        {
            // Override in derived classes for cleanup
        }
    }
}