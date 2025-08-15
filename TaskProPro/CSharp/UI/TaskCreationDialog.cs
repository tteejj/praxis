using System;
using System.Collections.Generic;
using System.Linq;
using TaskPro.Core;
using TaskPro.Data;

namespace TaskPro.UI
{
    /// <summary>
    /// Professional task creation dialog with full property setting
    /// Improved C# version of standalone PowerShell CreateNewTask
    /// </summary>
    public class TaskCreationDialog
    {
        // Configuration
        public ConsoleColor DialogColor { get; set; } = ConsoleColor.Cyan;
        public ConsoleColor FieldColor { get; set; } = ConsoleColor.White;
        public ConsoleColor HighlightColor { get; set; } = ConsoleColor.Yellow;
        public ConsoleColor ErrorColor { get; set; } = ConsoleColor.Red;
        public ConsoleColor HintColor { get; set; } = ConsoleColor.DarkGray;
        
        // State
        private bool isActive = false;
        private int currentField = 0;
        private string[] fieldNames = { "Title", "Priority", "Due Date", "Tags", "Notes" };
        private Dictionary<string, object> fieldValues = new Dictionary<string, object>();
        private string errorMessage = "";
        private DateTime errorExpiry = DateTime.MinValue;
        
        // Text input fields
        private TextInputField titleField = new TextInputField();
        private TextInputField dueDateField = new TextInputField();
        private TextInputField tagsField = new TextInputField();
        private TextInputField notesField = new TextInputField();
        
        // Priority selector
        private Priority selectedPriority = Priority.Medium;
        
        // Events
        public event Action<SimpleTask> TaskCreated;
        public event Action DialogCancelled;
        public event Action<string> StatusMessage;
        
        public bool IsActive => isActive;
        public SimpleTask CreatedTask { get; private set; }
        
        public TaskCreationDialog()
        {
            // Configure text fields
            titleField.Placeholder = "Enter task title...";
            titleField.MaxLength = 200;
            
            dueDateField.Placeholder = "yyyy-mm-dd or 'today', 'tomorrow'";
            dueDateField.MaxLength = 20;
            
            tagsField.Placeholder = "tag1, tag2, tag3...";
            tagsField.MaxLength = 100;
            
            notesField.Placeholder = "Optional notes...";
            notesField.MaxLength = 1000;
            
            // Set up field events
            titleField.EnterPressed += (text) => MoveToNextField();
            dueDateField.EnterPressed += (text) => MoveToNextField();
            tagsField.EnterPressed += (text) => MoveToNextField();
            notesField.EnterPressed += (text) => CreateTask();
            
            titleField.EscapePressed += () => CancelDialog();
            dueDateField.EscapePressed += () => CancelDialog();
            tagsField.EscapePressed += () => CancelDialog();
            notesField.EscapePressed += () => CancelDialog();
        }
        
        /// <summary>
        /// Start the task creation dialog
        /// </summary>
        public void StartDialog()
        {
            isActive = true;
            currentField = 0;
            
            // Reset all fields
            titleField.Text = "";
            dueDateField.Text = "";
            tagsField.Text = "";
            notesField.Text = "";
            selectedPriority = Priority.Medium;
            errorMessage = "";
            
            // Focus first field
            SetFieldFocus();
            
            StatusMessage?.Invoke("Creating new task - Tab to move between fields, Enter to save, Esc to cancel");
        }
        
        /// <summary>
        /// Handle input for the dialog
        /// </summary>
        public bool HandleInput(InputEvent input)
        {
            if (!isActive) return false;
            
            // Clear error message after timeout
            if (DateTime.Now > errorExpiry)
            {
                errorMessage = "";
            }
            
            // Global shortcuts
            if (input.IsEscape)
            {
                CancelDialog();
                return true;
            }
            
            if (input.IsTab)
            {
                MoveToNextField();
                return true;
            }
            
            if (input.IsShiftTab)
            {
                MoveToPreviousField();
                return true;
            }
            
            if (input.IsCtrlEnter)
            {
                CreateTask();
                return true;
            }
            
            // Handle field-specific input
            switch (currentField)
            {
                case 0: // Title
                    return titleField.HandleInput(input);
                    
                case 1: // Priority
                    return HandlePriorityInput(input);
                    
                case 2: // Due Date
                    return dueDateField.HandleInput(input);
                    
                case 3: // Tags
                    return tagsField.HandleInput(input);
                    
                case 4: // Notes
                    return notesField.HandleInput(input);
                    
                default:
                    return false;
            }
        }
        
        /// <summary>
        /// Render the dialog
        /// </summary>
        public void Render(ScreenBuffer screen, Rectangle bounds)
        {
            if (!isActive) return;
            
            int dialogWidth = Math.Min(80, bounds.Width - 4);
            int dialogHeight = 18;
            int dialogX = (bounds.Width - dialogWidth) / 2;
            int dialogY = (bounds.Height - dialogHeight) / 2;
            
            // Dialog background
            screen.FillRect(dialogX, dialogY, dialogWidth, dialogHeight, ' ', 
                           ConsoleColor.White, ConsoleColor.DarkBlue);
            
            // Border
            screen.DrawBox(dialogX, dialogY, dialogWidth, dialogHeight, DialogColor);
            
            // Title
            var title = "Create New Task";
            screen.WriteAt(dialogX + (dialogWidth - title.Length) / 2, dialogY, 
                          title, DialogColor);
            
            int y = dialogY + 2;
            
            // Title field
            RenderField(screen, dialogX, y, dialogWidth, "Title:", titleField, 0);
            y += 2;
            
            // Priority field
            RenderPriorityField(screen, dialogX, y, dialogWidth);
            y += 2;
            
            // Due Date field
            RenderField(screen, dialogX, y, dialogWidth, "Due Date:", dueDateField, 2);
            y += 2;
            
            // Tags field
            RenderField(screen, dialogX, y, dialogWidth, "Tags:", tagsField, 3);
            y += 2;
            
            // Notes field
            RenderField(screen, dialogX, y, dialogWidth, "Notes:", notesField, 4);
            y += 2;
            
            // Error message
            if (!string.IsNullOrEmpty(errorMessage))
            {
                var errorY = dialogY + dialogHeight - 3;
                screen.WriteAt(dialogX + 2, errorY, errorMessage, ErrorColor);
            }
            
            // Help text
            var helpText = "Tab: Next field | Shift+Tab: Previous | Ctrl+Enter: Create | Esc: Cancel";
            var helpY = dialogY + dialogHeight - 2;
            if (helpText.Length <= dialogWidth - 4)
            {
                screen.WriteAt(dialogX + 2, helpY, helpText, HintColor);
            }
        }
        
        /// <summary>
        /// Render a text input field
        /// </summary>
        private void RenderField(ScreenBuffer screen, int x, int y, int width, string label, 
                                TextInputField field, int fieldIndex)
        {
            // Label
            var labelColor = (currentField == fieldIndex) ? HighlightColor : FieldColor;
            screen.WriteAt(x + 2, y, label, labelColor);
            
            // Field background
            var fieldX = x + 12;
            var fieldWidth = width - 14;
            var fieldColor = (currentField == fieldIndex) ? ConsoleColor.Yellow : ConsoleColor.White;
            var fieldBg = (currentField == fieldIndex) ? ConsoleColor.DarkBlue : ConsoleColor.Black;
            
            field.IsFocused = (currentField == fieldIndex);
            var fieldBounds = new Rectangle(fieldX, y, fieldWidth, 1);
            field.Render(screen, fieldBounds, fieldColor);
        }
        
        /// <summary>
        /// Render the priority selection field
        /// </summary>
        private void RenderPriorityField(ScreenBuffer screen, int x, int y, int width)
        {
            // Label
            var labelColor = (currentField == 1) ? HighlightColor : FieldColor;
            screen.WriteAt(x + 2, y, "Priority:", labelColor);
            
            // Priority options
            var fieldX = x + 12;
            var priorities = new[] { Priority.Today, Priority.High, Priority.Medium, Priority.Low };
            var priorityNames = new[] { "Today", "High", "Medium", "Low" };
            var priorityColors = new[] { ConsoleColor.Magenta, ConsoleColor.Red, ConsoleColor.Yellow, ConsoleColor.Green };
            
            int optionX = fieldX;
            for (int i = 0; i < priorities.Length; i++)
            {
                var isSelected = (selectedPriority == priorities[i]);
                var isFocused = (currentField == 1);
                
                var color = isSelected ? priorityColors[i] : ConsoleColor.DarkGray;
                var bg = (isSelected && isFocused) ? ConsoleColor.White : ConsoleColor.Black;
                
                var prefix = isSelected ? "[" : " ";
                var suffix = isSelected ? "]" : " ";
                var text = $"{prefix}{priorityNames[i]}{suffix}";
                
                screen.WriteAt(optionX, y, text, color, bg);
                optionX += text.Length + 1;
            }
        }
        
        /// <summary>
        /// Handle priority selection input
        /// </summary>
        private bool HandlePriorityInput(InputEvent input)
        {
            if (input.IsArrowLeft || input.Key == ConsoleKey.H)
            {
                var priorities = new[] { Priority.Today, Priority.High, Priority.Medium, Priority.Low };
                var currentIndex = Array.IndexOf(priorities, selectedPriority);
                if (currentIndex > 0)
                {
                    selectedPriority = priorities[currentIndex - 1];
                }
                return true;
            }
            
            if (input.IsArrowRight || input.Key == ConsoleKey.L)
            {
                var priorities = new[] { Priority.Today, Priority.High, Priority.Medium, Priority.Low };
                var currentIndex = Array.IndexOf(priorities, selectedPriority);
                if (currentIndex < priorities.Length - 1)
                {
                    selectedPriority = priorities[currentIndex + 1];
                }
                return true;
            }
            
            if (input.IsEnter)
            {
                MoveToNextField();
                return true;
            }
            
            // Number shortcuts
            if (input.Key >= ConsoleKey.D1 && input.Key <= ConsoleKey.D4)
            {
                var priorities = new[] { Priority.Today, Priority.High, Priority.Medium, Priority.Low };
                var index = (int)input.Key - (int)ConsoleKey.D1;
                if (index < priorities.Length)
                {
                    selectedPriority = priorities[index];
                }
                return true;
            }
            
            return false;
        }
        
        /// <summary>
        /// Move to next field
        /// </summary>
        private void MoveToNextField()
        {
            currentField = (currentField + 1) % fieldNames.Length;
            SetFieldFocus();
        }
        
        /// <summary>
        /// Move to previous field
        /// </summary>
        private void MoveToPreviousField()
        {
            currentField = (currentField - 1 + fieldNames.Length) % fieldNames.Length;
            SetFieldFocus();
        }
        
        /// <summary>
        /// Set focus to current field
        /// </summary>
        private void SetFieldFocus()
        {
            // Clear all field focus
            titleField.IsFocused = false;
            dueDateField.IsFocused = false;
            tagsField.IsFocused = false;
            notesField.IsFocused = false;
            
            // Set current field focus
            switch (currentField)
            {
                case 0: titleField.IsFocused = true; break;
                case 2: dueDateField.IsFocused = true; break;
                case 3: tagsField.IsFocused = true; break;
                case 4: notesField.IsFocused = true; break;
            }
        }
        
        /// <summary>
        /// Create the task with current field values
        /// </summary>
        private void CreateTask()
        {
            // Validate required fields
            if (string.IsNullOrWhiteSpace(titleField.Text))
            {
                ShowError("Task title is required");
                currentField = 0;
                SetFieldFocus();
                return;
            }
            
            try
            {
                // Create new task
                var task = new SimpleTask();
                task.Title = titleField.Text.Trim();
                task.Priority = selectedPriority;
                task.Notes = notesField.Text.Trim();
                
                // Parse due date
                if (!string.IsNullOrWhiteSpace(dueDateField.Text))
                {
                    task.DueDate = ParseDueDate(dueDateField.Text.Trim());
                }
                
                // Parse tags
                if (!string.IsNullOrWhiteSpace(tagsField.Text))
                {
                    var tagStrings = tagsField.Text.Split(',')
                        .Select(t => t.Trim())
                        .Where(t => !string.IsNullOrEmpty(t))
                        .Distinct();
                    
                    foreach (var tag in tagStrings)
                    {
                        task.Tags.Add(tag);
                    }
                }
                
                CreatedTask = task;
                isActive = false;
                
                TaskCreated?.Invoke(task);
                StatusMessage?.Invoke($"Created task: {task.Title}");
            }
            catch (Exception ex)
            {
                ShowError($"Error creating task: {ex.Message}");
            }
        }
        
        /// <summary>
        /// Cancel the dialog
        /// </summary>
        private void CancelDialog()
        {
            isActive = false;
            CreatedTask = null;
            DialogCancelled?.Invoke();
            StatusMessage?.Invoke("Task creation cancelled");
        }
        
        /// <summary>
        /// Show error message with timeout
        /// </summary>
        private void ShowError(string message)
        {
            errorMessage = message;
            errorExpiry = DateTime.Now.AddSeconds(3);
        }
        
        /// <summary>
        /// Parse due date from user input
        /// </summary>
        private DateTime ParseDueDate(string input)
        {
            if (string.IsNullOrWhiteSpace(input))
                return DateTime.MinValue;
            
            // Handle relative dates
            switch (input.ToLower())
            {
                case "today":
                    return DateTime.Today;
                case "tomorrow":
                    return DateTime.Today.AddDays(1);
                case "yesterday":
                    return DateTime.Today.AddDays(-1);
            }
            
            // Handle relative day names (this week)
            var dayNames = new[] { "sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday" };
            var dayIndex = Array.FindIndex(dayNames, d => d.StartsWith(input.ToLower()));
            if (dayIndex >= 0)
            {
                var today = DateTime.Today;
                var daysUntilTarget = ((int)DayOfWeek.Sunday + dayIndex - (int)today.DayOfWeek) % 7;
                if (daysUntilTarget == 0 && dayIndex != (int)today.DayOfWeek)
                    daysUntilTarget = 7; // Next week if same day
                return today.AddDays(daysUntilTarget);
            }
            
            // Try parsing as date
            if (DateTime.TryParse(input, out var date))
            {
                return date;
            }
            
            throw new ArgumentException($"Invalid date format: {input}");
        }
    }
}