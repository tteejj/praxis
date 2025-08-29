using System;
using System.Collections.Generic;
using System.ComponentModel;

namespace PraxisWpf.Services
{
    public interface IUndoableAction
    {
        string Description { get; }
        void Execute();
        void Undo();
        bool CanExecute { get; }
        bool CanUndo { get; }
    }

    public class UndoRedoManager : INotifyPropertyChanged
    {
        private readonly Stack<IUndoableAction> _undoStack = new();
        private readonly Stack<IUndoableAction> _redoStack = new();
        private readonly int _maxHistorySize;
        private bool _isExecuting = false;

        public event PropertyChangedEventHandler? PropertyChanged;
        public event Action<IUndoableAction>? ActionExecuted;
        public event Action<IUndoableAction>? ActionUndone;
        public event Action<IUndoableAction>? ActionRedone;

        public bool CanUndo => _undoStack.Count > 0 && !_isExecuting;
        public bool CanRedo => _redoStack.Count > 0 && !_isExecuting;
        
        public string? NextUndoDescription => _undoStack.Count > 0 ? _undoStack.Peek().Description : null;
        public string? NextRedoDescription => _redoStack.Count > 0 ? _redoStack.Peek().Description : null;
        
        public int UndoStackCount => _undoStack.Count;
        public int RedoStackCount => _redoStack.Count;

        public UndoRedoManager(int maxHistorySize = 50)
        {
            _maxHistorySize = Math.Max(1, maxHistorySize);
            Logger.Debug("UndoRedoManager", $"Initialized with max history size: {_maxHistorySize}");
        }

        public void ExecuteAction(IUndoableAction action)
        {
            if (action == null)
                throw new ArgumentNullException(nameof(action));

            if (!action.CanExecute)
            {
                Logger.Warning("UndoRedoManager", $"Cannot execute action: {action.Description}");
                return;
            }

            try
            {
                _isExecuting = true;

                // Execute the action
                action.Execute();
                
                // Add to undo stack
                _undoStack.Push(action);
                
                // Clear redo stack (new action invalidates redo history)
                _redoStack.Clear();
                
                // Maintain size limit
                TrimHistoryIfNeeded();
                
                Logger.Debug("UndoRedoManager", $"Executed: {action.Description}");
                ActionExecuted?.Invoke(action);
                NotifyPropertiesChanged();
            }
            catch (Exception ex)
            {
                Logger.Error("UndoRedoManager", $"Failed to execute action: {action.Description}", ex);
                throw;
            }
            finally
            {
                _isExecuting = false;
            }
        }

        public void Undo()
        {
            if (!CanUndo)
            {
                Logger.Warning("UndoRedoManager", "Cannot undo - no actions available");
                return;
            }

            var action = _undoStack.Pop();
            
            if (!action.CanUndo)
            {
                Logger.Warning("UndoRedoManager", $"Cannot undo action: {action.Description}");
                _undoStack.Push(action); // Put it back
                return;
            }

            try
            {
                _isExecuting = true;
                
                action.Undo();
                _redoStack.Push(action);
                
                Logger.Debug("UndoRedoManager", $"Undone: {action.Description}");
                ActionUndone?.Invoke(action);
                NotifyPropertiesChanged();
            }
            catch (Exception ex)
            {
                Logger.Error("UndoRedoManager", $"Failed to undo action: {action.Description}", ex);
                _undoStack.Push(action); // Put it back on error
                throw;
            }
            finally
            {
                _isExecuting = false;
            }
        }

        public void Redo()
        {
            if (!CanRedo)
            {
                Logger.Warning("UndoRedoManager", "Cannot redo - no actions available");
                return;
            }

            var action = _redoStack.Pop();
            
            if (!action.CanExecute)
            {
                Logger.Warning("UndoRedoManager", $"Cannot redo action: {action.Description}");
                _redoStack.Push(action); // Put it back
                return;
            }

            try
            {
                _isExecuting = true;
                
                action.Execute();
                _undoStack.Push(action);
                
                Logger.Debug("UndoRedoManager", $"Redone: {action.Description}");
                ActionRedone?.Invoke(action);
                NotifyPropertiesChanged();
            }
            catch (Exception ex)
            {
                Logger.Error("UndoRedoManager", $"Failed to redo action: {action.Description}", ex);
                _redoStack.Push(action); // Put it back on error
                throw;
            }
            finally
            {
                _isExecuting = false;
            }
        }

        public void Clear()
        {
            _undoStack.Clear();
            _redoStack.Clear();
            Logger.Debug("UndoRedoManager", "History cleared");
            NotifyPropertiesChanged();
        }

        public IEnumerable<string> GetUndoHistory()
        {
            var history = new List<string>();
            foreach (var action in _undoStack)
            {
                history.Add(action.Description);
            }
            return history;
        }

        public IEnumerable<string> GetRedoHistory()
        {
            var history = new List<string>();
            foreach (var action in _redoStack)
            {
                history.Add(action.Description);
            }
            return history;
        }

        private void TrimHistoryIfNeeded()
        {
            while (_undoStack.Count > _maxHistorySize)
            {
                // Remove the oldest action
                var temp = new Stack<IUndoableAction>();
                while (_undoStack.Count > 0)
                {
                    temp.Push(_undoStack.Pop());
                }
                temp.Pop(); // Remove the oldest
                while (temp.Count > 0)
                {
                    _undoStack.Push(temp.Pop());
                }
            }
        }

        private void NotifyPropertiesChanged()
        {
            PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(nameof(CanUndo)));
            PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(nameof(CanRedo)));
            PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(nameof(NextUndoDescription)));
            PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(nameof(NextRedoDescription)));
            PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(nameof(UndoStackCount)));
            PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(nameof(RedoStackCount)));
        }
    }

    #region Concrete Action Implementations

    public class PropertyChangeAction<T> : IUndoableAction
    {
        private readonly object _target;
        private readonly string _propertyName;
        private readonly T _oldValue;
        private readonly T _newValue;
        private readonly Action<T> _setter;

        public string Description { get; }
        public bool CanExecute => true;
        public bool CanUndo => true;

        public PropertyChangeAction(string description, object target, string propertyName, T oldValue, T newValue, Action<T> setter)
        {
            Description = description;
            _target = target;
            _propertyName = propertyName;
            _oldValue = oldValue;
            _newValue = newValue;
            _setter = setter;
        }

        public void Execute()
        {
            _setter(_newValue);
        }

        public void Undo()
        {
            _setter(_oldValue);
        }
    }

    public class DelegateAction : IUndoableAction
    {
        private readonly Action _executeAction;
        private readonly Action _undoAction;
        private readonly Func<bool>? _canExecute;
        private readonly Func<bool>? _canUndo;

        public string Description { get; }
        public bool CanExecute => _canExecute?.Invoke() ?? true;
        public bool CanUndo => _canUndo?.Invoke() ?? true;

        public DelegateAction(string description, Action executeAction, Action undoAction, Func<bool>? canExecute = null, Func<bool>? canUndo = null)
        {
            Description = description;
            _executeAction = executeAction;
            _undoAction = undoAction;
            _canExecute = canExecute;
            _canUndo = canUndo;
        }

        public void Execute()
        {
            _executeAction();
        }

        public void Undo()
        {
            _undoAction();
        }
    }

    public class CompositeAction : IUndoableAction
    {
        private readonly List<IUndoableAction> _actions = new();

        public string Description { get; }
        public bool CanExecute => _actions.TrueForAll(a => a.CanExecute);
        public bool CanUndo => _actions.TrueForAll(a => a.CanUndo);

        public CompositeAction(string description)
        {
            Description = description;
        }

        public void AddAction(IUndoableAction action)
        {
            _actions.Add(action);
        }

        public void Execute()
        {
            foreach (var action in _actions)
            {
                action.Execute();
            }
        }

        public void Undo()
        {
            // Undo in reverse order
            for (int i = _actions.Count - 1; i >= 0; i--)
            {
                _actions[i].Undo();
            }
        }
    }

    #endregion
}