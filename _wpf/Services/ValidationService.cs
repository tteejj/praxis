using System;
using System.Collections.Generic;
using System.Linq;
using PraxisWpf.Models;

namespace PraxisWpf.Services
{
    public static class ValidationService
    {
        public static ValidationResult ValidateTaskName(string? name)
        {
            if (string.IsNullOrWhiteSpace(name))
            {
                return ValidationResult.Error("Task name cannot be empty");
            }

            if (name.Length > 200)
            {
                return ValidationResult.Error("Task name cannot exceed 200 characters");
            }

            // Check for potentially problematic characters
            var invalidChars = new[] { '\n', '\r', '\t' };
            if (name.Any(c => invalidChars.Contains(c)))
            {
                return ValidationResult.Error("Task name cannot contain line breaks or tabs");
            }

            return ValidationResult.Success();
        }

        public static ValidationResult ValidateDateRange(DateTime? assignedDate, DateTime? dueDate, DateTime? bringForwardDate = null)
        {
            var errors = new List<string>();

            // Due date should be after assigned date
            if (assignedDate.HasValue && dueDate.HasValue)
            {
                if (dueDate.Value.Date < assignedDate.Value.Date)
                {
                    errors.Add("Due date cannot be before assigned date");
                }
            }

            // Bring forward date should be between assigned and due date
            if (bringForwardDate.HasValue)
            {
                if (assignedDate.HasValue && bringForwardDate.Value.Date < assignedDate.Value.Date)
                {
                    errors.Add("Bring forward date cannot be before assigned date");
                }

                if (dueDate.HasValue && bringForwardDate.Value.Date > dueDate.Value.Date)
                {
                    errors.Add("Bring forward date cannot be after due date");
                }
            }

            // Warn about very old or very future dates
            var now = DateTime.Now;
            var oneYearAgo = now.AddYears(-1);
            var twoYearsFromNow = now.AddYears(2);

            if (assignedDate.HasValue && assignedDate.Value.Date < oneYearAgo.Date)
            {
                errors.Add("Warning: Assigned date is more than a year old");
            }

            if (dueDate.HasValue && dueDate.Value.Date > twoYearsFromNow.Date)
            {
                errors.Add("Warning: Due date is more than 2 years in the future");
            }

            return errors.Any() ? ValidationResult.Error(string.Join("; ", errors)) : ValidationResult.Success();
        }

        public static ValidationResult ValidateTaskItem(TaskItem task)
        {
            var nameResult = ValidateTaskName(task.Name);
            if (!nameResult.IsValid)
            {
                return nameResult;
            }

            var dateResult = ValidateDateRange(task.AssignedDate, task.DueDate, task.BringForwardDate);
            if (!dateResult.IsValid)
            {
                return dateResult;
            }

            return ValidationResult.Success();
        }

        public static ValidationResult ValidateTaskHierarchy(TaskItem parent, TaskItem child)
        {
            // Prevent circular references (basic check)
            if (parent.Id1 == child.Id1 && parent.Id2 == child.Id2)
            {
                return ValidationResult.Error("Cannot add task as child of itself");
            }

            // Check if child is already in the hierarchy
            if (ContainsTask(parent.Children, child))
            {
                return ValidationResult.Error("Task is already in this hierarchy");
            }

            return ValidationResult.Success();
        }

        private static bool ContainsTask(System.Collections.ObjectModel.ObservableCollection<TaskItem> collection, TaskItem target)
        {
            foreach (var item in collection)
            {
                if (item.Id1 == target.Id1 && item.Id2 == target.Id2)
                {
                    return true;
                }

                if (ContainsTask(item.Children, target))
                {
                    return true;
                }
            }

            return false;
        }
    }

    public class ValidationResult
    {
        public bool IsValid { get; private set; }
        public string ErrorMessage { get; private set; } = string.Empty;
        public bool IsWarning { get; private set; }

        private ValidationResult() { }

        public static ValidationResult Success()
        {
            return new ValidationResult { IsValid = true };
        }

        public static ValidationResult Error(string message)
        {
            return new ValidationResult 
            { 
                IsValid = false, 
                ErrorMessage = message,
                IsWarning = false
            };
        }

        public static ValidationResult Warning(string message)
        {
            return new ValidationResult 
            { 
                IsValid = true, 
                ErrorMessage = message,
                IsWarning = true
            };
        }
    }
}