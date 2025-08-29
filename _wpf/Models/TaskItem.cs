using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.ComponentModel;
using System.Linq;
using System.Text.Json.Serialization;
using PraxisWpf.Interfaces;
using PraxisWpf.Services;

namespace PraxisWpf.Models
{
    public class TaskItem : IDisplayableItem, INotifyPropertyChanged
    {
        private bool _isExpanded;
        private bool _isInEditMode;
        private string _name = string.Empty;
        private PriorityType _priority = PriorityType.Medium;

        public TaskItem()
        {
            // Collection change logging only for debug builds
            Children.CollectionChanged += (s, e) => {
                if (Logger.ShouldLog(LogLevel.Debug))
                {
                    Logger.Debug("TaskItem", $"Children collection changed: {e.Action}");
                }
            };
        }

        public int Id1 { get; set; }
        public int Id2 { get; set; }
        
        public string Name
        {
            get => _name;
            set
            {
                if (_name != value)
                {
                    _name = value;
                    OnPropertyChanged(nameof(Name));
                    OnPropertyChanged(nameof(DisplayName));
                }
            }
        }

        public DateTime AssignedDate { get; set; } = DateTime.Now;
        public DateTime? DueDate { get; set; }
        public DateTime? BringForwardDate { get; set; }
        
        public PriorityType Priority 
        { 
            get => _priority;
            set
            {
                if (_priority != value)
                {
                    _priority = value;
                    
                    // H=today logic: If priority is set to High and no due date exists, set it to today
                    if (value == PriorityType.High && !DueDate.HasValue)
                    {
                        DueDate = DateTime.Today;
                        Logger.Info("TaskItem", $"High priority task - DueDate set to today for '{Name}'");
                    }
                    
                    OnPropertyChanged(nameof(Priority));
                    OnPropertyChanged(nameof(IsHighPriorityToday));
                }
            }
        }

        public bool IsExpanded
        {
            get => _isExpanded;
            set
            {
                if (_isExpanded != value)
                {
                    _isExpanded = value;
                    OnPropertyChanged(nameof(IsExpanded));
                }
            }
        }

        [JsonIgnore]
        public bool IsInEditMode
        {
            get => _isInEditMode;
            set
            {
                if (_isInEditMode != value)
                {
                    _isInEditMode = value;
                    OnPropertyChanged(nameof(IsInEditMode));
                    if (Logger.ShouldLog(LogLevel.Debug))
                    {
                        Logger.Debug("TaskItem", $"Edit mode: {value} for '{Name}'");
                    }
                }
            }
        }

        public ObservableCollection<TaskItem> Children { get; set; } = new ObservableCollection<TaskItem>();

        [JsonIgnore]
        public string DisplayName => Name;

        [JsonIgnore]
        public bool IsHighPriorityToday => Priority == PriorityType.High && 
                                          DueDate.HasValue && 
                                          DueDate.Value.Date == DateTime.Today;

        public event PropertyChangedEventHandler? PropertyChanged;

        protected virtual void OnPropertyChanged(string propertyName)
        {
            PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(propertyName));
        }
    }
}