using System;
using System.Collections.Generic;
using System.Linq;
using TaskPro.Core;
using TaskPro.Data;

namespace TaskPro.UI
{
    /// <summary>
    /// Specialized edit mode manager for task list inline editing
    /// Handles field editing, validation, and state transitions
    /// </summary>
    public class TaskListEditMode
    {
        // Dependencies
        public TaskManager TaskManager { get; set; }
        public StatusBar StatusBar { get; set; }
        
        // Edit state
        private bool isEditMode = false;
        private string editingTaskId = "";
        private EditField currentField = EditField.None;
        private string editBuffer = "";
        private SimpleTask editingTask = null;
        private SimpleTask originalTask = null; // Backup for cancellation
        
        // Field validation
        private readonly Dictionary<EditField, int> maxLengths = new()
        {
            [EditField.Title] = 100,
            [EditField.ID1] = 20,
            [EditField.ID2] = 20,
            [EditField.Description] = 200
        };
        
        public bool IsEditMode => isEditMode;
        public EditField CurrentField => currentField;
        public string EditBuffer => editBuffer;
        public string EditingTaskId => editingTaskId;
        
        /// <summary>
        /// Start editing a specific field of a task
        /// </summary>
        public bool StartEdit(SimpleTask task, EditField field)
        {
            if (task == null || field == EditField.None) return false;
            
            // Save current state
            isEditMode = true;
            editingTaskId = task.Id;
            currentField = field;
            editingTask = task;
            originalTask = task.DeepCopy(); // Create backup
            
            // Initialize edit buffer with current value
            editBuffer = GetFieldValue(task, field);
            
            if (StatusBar != null) StatusBar.ShowMessage($"Editing {field} - Enter=Save, Esc=Cancel, Tab=Next Field");
            return true;
        }
        
        /// <summary>
        /// Handle input during edit mode
        /// </summary>
        public bool HandleEditInput(InputEvent input)
        {
            if (!isEditMode) return false;
            
            // SAVE CHANGES
            if (input.IsEnter)
            {
                return SaveEdit();
            }
            
            // CANCEL EDIT
            if (input.IsEscape)
            {
                CancelEdit();
                return true;
            }
            
            // NEXT FIELD
            if (input.IsTab)
            {
                SaveCurrentField();
                MoveToNextField();
                return true;
            }
            
            // PREVIOUS FIELD
            if (input.IsShiftTab)
            {
                SaveCurrentField();
                MoveToPreviousField();
                return true;
            }
            
            // BACKSPACE
            if (input.IsBackspace)
            {
                if (editBuffer.Length > 0)
                {
                    editBuffer = editBuffer.Substring(0, editBuffer.Length - 1);
                    ApplyBufferToTask();
                }
                return true;
            }
            
            // DELETE
            if (input.IsDelete)
            {
                editBuffer = "";
                ApplyBufferToTask();
                return true;
            }
            
            // PRINTABLE CHARACTERS
            if (input.IsPrintableChar)
            {
                var maxLength = maxLengths.GetValueOrDefault(currentField, 100);
                if (editBuffer.Length < maxLength)
                {
                    editBuffer += input.Char;
                    ApplyBufferToTask();
                }
                else
                {
                    StatusBar?.ShowWarning($"Maximum length ({maxLength}) reached for {currentField}");
                }
                return true;
            }
            
            return false;
        }
        
        /// <summary>
        /// Save current edit and exit edit mode
        /// </summary>
        private bool SaveEdit()
        {
            if (editingTask == null) return false;
            
            // Validate the task
            if (!ValidateTask(editingTask, out var errors))
            {
                StatusBar?.ShowError($"Validation failed: {string.Join(", ", errors)}");
                return false;
            }
            
            // Save current field
            SaveCurrentField();
            
            // Update task
            editingTask.Touch();
            TaskManager?.UpdateTask(editingTask);
            
            StatusBar?.ShowSuccess($"Task updated: {editingTask.Title}");
            ExitEditMode();
            return true;
        }
        
        /// <summary>
        /// Cancel edit and restore original values
        /// </summary>
        private void CancelEdit()
        {
            if (editingTask != null && originalTask != null)
            {
                // Restore original values
                editingTask.CopyFrom(originalTask);
            }
            
            if (StatusBar != null) StatusBar.ShowMessage("Edit cancelled");
            ExitEditMode();
        }
        
        /// <summary>
        /// Exit edit mode and clean up state
        /// </summary>
        private void ExitEditMode()
        {
            isEditMode = false;
            editingTaskId = "";
            currentField = EditField.None;
            editBuffer = "";
            editingTask = null;
            originalTask = null;
        }
        
        /// <summary>
        /// Save current field value from buffer
        /// </summary>
        private void SaveCurrentField()
        {
            if (editingTask != null)
            {
                SetFieldValue(editingTask, currentField, editBuffer);
            }
        }
        
        /// <summary>
        /// Apply edit buffer to task in real-time
        /// </summary>
        private void ApplyBufferToTask()
        {
            if (editingTask != null)
            {
                SetFieldValue(editingTask, currentField, editBuffer);
            }
        }
        
        /// <summary>
        /// Move to next editable field
        /// </summary>
        private void MoveToNextField()
        {
            currentField = currentField switch
            {
                EditField.Title => EditField.ID1,
                EditField.ID1 => EditField.ID2,
                EditField.ID2 => EditField.Description,
                EditField.Description => EditField.Title,
                _ => EditField.Title
            };
            
            editBuffer = GetFieldValue(editingTask, currentField);
            if (StatusBar != null) StatusBar.ShowMessage($"Editing {currentField} - Enter=Save, Esc=Cancel, Tab=Next");
        }
        
        /// <summary>
        /// Move to previous editable field
        /// </summary>
        private void MoveToPreviousField()
        {
            currentField = currentField switch
            {
                EditField.Title => EditField.Description,
                EditField.ID1 => EditField.Title,
                EditField.ID2 => EditField.ID1,
                EditField.Description => EditField.ID2,
                _ => EditField.Description
            };
            
            editBuffer = GetFieldValue(editingTask, currentField);
            if (StatusBar != null) StatusBar.ShowMessage($"Editing {currentField} - Enter=Save, Esc=Cancel, Shift+Tab=Previous");
        }
        
        /// <summary>
        /// Get field value from task
        /// </summary>
        private string GetFieldValue(SimpleTask task, EditField field)
        {
            if (task == null) return "";
            
            return field switch
            {
                EditField.Title => task.Title ?? "",
                EditField.ID1 => task.ID1 ?? "",
                EditField.ID2 => task.ID2 ?? "",
                EditField.Description => task.Notes ?? "",
                _ => ""
            };
        }
        
        /// <summary>
        /// Set field value on task
        /// </summary>
        private void SetFieldValue(SimpleTask task, EditField field, string value)
        {
            if (task == null) return;
            
            switch (field)
            {
                case EditField.Title:
                    task.Title = value;
                    break;
                case EditField.ID1:
                    task.ID1 = value;
                    break;
                case EditField.ID2:
                    task.ID2 = value;
                    break;
                case EditField.Description:
                    task.Notes = value;
                    break;
            }
        }
        
        /// <summary>
        /// Validate task data
        /// </summary>
        private bool ValidateTask(SimpleTask task, out List<string> errors)
        {
            errors = new List<string>();
            
            if (string.IsNullOrWhiteSpace(task.Title))
            {
                errors.Add("Title is required");
            }
            
            if (task.Title?.Length > maxLengths[EditField.Title])
            {
                errors.Add($"Title must be {maxLengths[EditField.Title]} characters or less");
            }
            
            if (task.ID1?.Length > maxLengths[EditField.ID1])
            {
                errors.Add($"ID1 must be {maxLengths[EditField.ID1]} characters or less");
            }
            
            if (task.ID2?.Length > maxLengths[EditField.ID2])
            {
                errors.Add($"ID2 must be {maxLengths[EditField.ID2]} characters or less");
            }
            
            if (task.Notes?.Length > maxLengths[EditField.Description])
            {
                errors.Add($"Description must be {maxLengths[EditField.Description]} characters or less");
            }
            
            return errors.Count == 0;
        }
        
        /// <summary>
        /// Get visual edit cursor for field rendering
        /// </summary>
        public string GetEditCursor(EditField field)
        {
            if (!isEditMode || currentField != field) return "";
            return "_"; // Simple cursor
        }
        
        /// <summary>
        /// Check if a specific field is being edited
        /// </summary>
        public bool IsFieldBeingEdited(string taskId, EditField field)
        {
            return isEditMode && editingTaskId == taskId && currentField == field;
        }
        
        /// <summary>
        /// Get edit progress info for status display
        /// </summary>
        public string GetEditProgress()
        {
            if (!isEditMode) return "";
            
            var fieldIndex = currentField switch
            {
                EditField.Title => 1,
                EditField.ID1 => 2,
                EditField.ID2 => 3,
                EditField.Description => 4,
                _ => 0
            };
            
            return $"Field {fieldIndex}/4 - {currentField}";
        }
        
        /// <summary>
        /// Force exit edit mode (for cleanup)
        /// </summary>
        public void ForceExit()
        {
            if (isEditMode)
            {
                CancelEdit();
            }
        }
    }
    
    /// <summary>
    /// Editable fields in task list
    /// </summary>
    public enum EditField
    {
        None,
        Title,
        ID1,
        ID2,
        Description
    }
}