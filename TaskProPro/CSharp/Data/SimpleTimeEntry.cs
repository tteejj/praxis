using System;
using System.Collections.Generic;
using System.Linq;
using System.Text.Json.Serialization;

namespace TaskPro.Data {
    public class SimpleTimeEntry {
        // Core Properties
        public string Id { get; set; } = Guid.NewGuid().ToString();
        public string WeekEndingFriday { get; set; } = "";  // Format: yyyyMMdd
        public string ID1 { get; set; } = "";               // Generic time code allocation (MEET, TRAIN, PROJ, etc.)
        public string ID2 { get; set; } = "";               // Specific project identifier (links to tasks)
        public string Description { get; set; } = "";       // Auto-filled from task or manual entry
        
        // Daily Hours (Monday to Friday)
        public decimal Monday { get; set; } = 0m;
        public decimal Tuesday { get; set; } = 0m;
        public decimal Wednesday { get; set; } = 0m;
        public decimal Thursday { get; set; } = 0m;
        public decimal Friday { get; set; } = 0m;
        public decimal Total { get; set; } = 0m;
        
        // Metadata
        public string FiscalYear { get; set; } = "";
        public string TaskId { get; set; } = "";         // Links to specific task if selected
        public bool IsLinkedToTask { get; set; } = false; // true if linked to a task, false for manual entry
        public DateTime Created { get; set; } = DateTime.Now;
        public DateTime Modified { get; set; } = DateTime.Now;
        
        // Constructor
        public SimpleTimeEntry() {
            WeekEndingFriday = GetCurrentWeekEndingFriday();
            FiscalYear = CalculateFiscalYear();
            Created = DateTime.Now;
            Modified = DateTime.Now;
        }
        
        public SimpleTimeEntry(string weekEndingFriday, string id1, string id2 = "") {
            Id = Guid.NewGuid().ToString();
            WeekEndingFriday = weekEndingFriday;
            ID1 = id1;
            ID2 = id2;
            FiscalYear = CalculateFiscalYear();
            Created = DateTime.Now;
            Modified = DateTime.Now;
        }
        
        // Business Logic Methods
        public void CalculateTotal() {
            Total = Monday + Tuesday + Wednesday + Thursday + Friday;
            Modified = DateTime.Now;
        }
        
        public string CalculateFiscalYear() {
            DateTime fridayDate;
            if (string.IsNullOrEmpty(WeekEndingFriday)) {
                fridayDate = DateTime.Now;
            } else {
                if (!DateTime.TryParseExact(WeekEndingFriday, "yyyyMMdd", null, 
                    System.Globalization.DateTimeStyles.None, out fridayDate)) {
                    fridayDate = DateTime.Now;
                }
            }
            
            // Fiscal year runs April 1 - March 31
            if (fridayDate.Month >= 4) {
                return $"{fridayDate.Year}-{fridayDate.Year + 1}";
            } else {
                return $"{fridayDate.Year - 1}-{fridayDate.Year}";
            }
        }
        
        public string GetCurrentWeekEndingFriday() {
            var today = DateTime.Now.Date;
            var daysUntilFriday = ((int)DayOfWeek.Friday - (int)today.DayOfWeek + 7) % 7;
            if (daysUntilFriday == 0 && today.DayOfWeek != DayOfWeek.Friday) {
                daysUntilFriday = 7;
            }
            
            var fridayDate = today.AddDays(daysUntilFriday);
            return fridayDate.ToString("yyyyMMdd");
        }
        
        public DateTime GetWeekStartMonday() {
            var fridayDate = DateTime.ParseExact(WeekEndingFriday, "yyyyMMdd", null);
            return fridayDate.AddDays(-4);  // Monday is 4 days before Friday
        }
        
        public string GetWeekDisplayString() {
            var fridayDate = DateTime.ParseExact(WeekEndingFriday, "yyyyMMdd", null);
            var mondayDate = fridayDate.AddDays(-4);
            return $"{mondayDate:MMM dd} - {fridayDate:MMM dd, yyyy}";
        }
        
        public bool IsGenericTimeCode() {
            // Generic time codes typically don't have an ID2 (specific project)
            return string.IsNullOrEmpty(ID2);
        }
        
        public string GetDisplayName() {
            if (IsLinkedToTask && !string.IsNullOrEmpty(ID2)) {
                // Task-linked entry: show ID1/ID2 - Description
                return $"{ID1}/{ID2} - {Description}";
            } else if (!string.IsNullOrEmpty(ID1)) {
                // Generic time code: show ID1 - Description  
                if (!string.IsNullOrEmpty(Description)) {
                    return $"{ID1} - {Description}";
                }
                return ID1;
            } else {
                return Description ?? "Untitled Entry";
            }
        }
        
        public string GetProjectIdentifier() {
            if (!string.IsNullOrEmpty(ID2)) {
                return $"{ID1}/{ID2}";
            }
            return ID1;
        }
        
        public void SetDayHours(string dayName, decimal hours) {
            if (hours < 0) hours = 0;
            if (hours > 24) hours = 24;
            
            switch (dayName.ToLower()) {
                case "monday":
                    Monday = hours;
                    break;
                case "tuesday":
                    Tuesday = hours;
                    break;
                case "wednesday":
                    Wednesday = hours;
                    break;
                case "thursday":
                    Thursday = hours;
                    break;
                case "friday":
                    Friday = hours;
                    break;
            }
            
            CalculateTotal();
        }
        
        public decimal GetDayHours(string dayName) {
            return dayName.ToLower() switch {
                "monday" => Monday,
                "tuesday" => Tuesday,
                "wednesday" => Wednesday,
                "thursday" => Thursday,
                "friday" => Friday,
                _ => 0m
            };
        }
        
        // CYBERPUNK UI METHODS - Professional terminal interface matching TaskProPro style
        public string GetStatusIcon() {
            return Total > 0 ? "[●]" : "[ ]";
        }
        
        public string GetCyberpunkProjectCode() {
            if (string.IsNullOrEmpty(ID1)) return "[---/---]";
            
            if (IsLinkedToTask && !string.IsNullOrEmpty(ID2)) {
                return $"<{ID1}/{ID2}>";  // Task-linked project in angle brackets
            } else {
                return $"[{ID1}]";        // Generic time code in brackets
            }
        }
        
        public ConsoleColor GetProjectCodeColor() {
            if (string.IsNullOrEmpty(ID1)) return ConsoleColor.DarkGray;
            
            if (IsLinkedToTask && !string.IsNullOrEmpty(ID2)) {
                return ConsoleColor.Cyan;     // Task-linked projects in cyan
            } else {
                return ConsoleColor.Magenta;  // Generic time codes in magenta
            }
        }
        
        public string GetCyberpunkTotal() {
            if (Total == 0) return "---.--";
            return Total.ToString("F1").PadLeft(6);
        }
        
        public ConsoleColor GetTotalColor() {
            if (Total == 0) return ConsoleColor.DarkGray;
            if (Total >= 40) return ConsoleColor.Red;      // Overtime warning
            if (Total >= 35) return ConsoleColor.Yellow;   // Full week
            if (Total >= 20) return ConsoleColor.Green;    // Partial week
            return ConsoleColor.Cyan;                      // Low hours
        }
        
        public string GetCyberpunkHours(decimal hours) {
            if (hours == 0) return "--.-";
            return hours.ToString("F1").PadLeft(4);
        }
        
        public ConsoleColor GetDayHoursColor(decimal hours) {
            if (hours == 0) return ConsoleColor.DarkGray;
            if (hours > 8) return ConsoleColor.Red;        // Overtime
            if (hours == 8) return ConsoleColor.Green;     // Full day
            if (hours >= 4) return ConsoleColor.Yellow;    // Half day+
            return ConsoleColor.Cyan;                      // Partial day
        }
        
        // Methods for task integration
        public void LinkToTask(string taskId, string taskTitle, string taskID1, string taskID2) {
            TaskId = taskId;
            ID1 = taskID1;
            ID2 = taskID2; 
            Description = taskTitle;
            IsLinkedToTask = true;
            Touch();
        }
        
        public void UnlinkFromTask() {
            TaskId = "";
            IsLinkedToTask = false;
            Touch();
        }
        
        public bool IsValidEntry() {
            return !string.IsNullOrEmpty(ID1) && (Total > 0 || IsInCurrentWeek());
        }
        
        public bool IsInCurrentWeek() {
            var currentWeekFriday = DateTime.ParseExact(GetCurrentWeekEndingFriday(), "yyyyMMdd", null);
            return WeekEndingFriday == currentWeekFriday.ToString("yyyyMMdd");
        }
        
        // Current day highlighting for UI
        public bool IsCurrentDay(string dayName) {
            var today = DateTime.Today.DayOfWeek;
            var currentWeekFriday = DateTime.ParseExact(GetCurrentWeekEndingFriday(), "yyyyMMdd", null);
            var isCurrentWeek = WeekEndingFriday == currentWeekFriday.ToString("yyyyMMdd");
            
            if (!isCurrentWeek) return false;
            
            return dayName.ToLower() switch {
                "monday" => today == DayOfWeek.Monday,
                "tuesday" => today == DayOfWeek.Tuesday,
                "wednesday" => today == DayOfWeek.Wednesday,
                "thursday" => today == DayOfWeek.Thursday,
                "friday" => today == DayOfWeek.Friday,
                _ => false
            };
        }
        
        public void Touch() {
            Modified = DateTime.Now;
        }
    }
}