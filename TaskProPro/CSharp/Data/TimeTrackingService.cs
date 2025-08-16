using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text.Json;
using TaskPro.Core;

namespace TaskPro.Data {
    public class TimeTrackingService {
        private string dataPath;
        private List<SimpleTimeEntry> timeEntries;
        private DateTime currentWeekFriday;
        
        public List<SimpleTimeEntry> TimeEntries => timeEntries;
        public DateTime CurrentWeekFriday => currentWeekFriday;
        
        public TimeTrackingService(string dataDirectory = null) {
            dataPath = dataDirectory ?? Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "Data");
            timeEntries = new List<SimpleTimeEntry>();
            currentWeekFriday = GetCurrentWeekFriday();
            InitializeDataDirectory();
            LoadTimeEntries();
        }
        
        private void InitializeDataDirectory() {
            if (!Directory.Exists(dataPath)) {
                Directory.CreateDirectory(dataPath);
            }
            
            // Create backups directory
            var backupPath = Path.Combine(dataPath, "backups");
            if (!Directory.Exists(backupPath)) {
                Directory.CreateDirectory(backupPath);
            }
        }
        
        public void LoadTimeEntries() {
            var filePath = Path.Combine(dataPath, "timeentries.json");
            
            if (File.Exists(filePath)) {
                try {
                    var jsonContent = File.ReadAllText(filePath);
                    var data = JsonSerializer.Deserialize<List<SimpleTimeEntry>>(jsonContent);
                    
                    timeEntries = data ?? new List<SimpleTimeEntry>();
                    
                    // Recalculate totals and fix fiscal years
                    foreach (var entry in timeEntries) {
                        entry.CalculateTotal();
                        if (string.IsNullOrEmpty(entry.FiscalYear)) {
                            entry.FiscalYear = entry.CalculateFiscalYear();
                        }
                    }
                }
                catch (Exception ex) {
                    throw new TaskProException($"Error loading time entries: {ex.Message}", ex);
                }
            } else {
                // Create sample data for testing
                CreateSampleData();
            }
        }
        
        public void SaveTimeEntries() {
            try {
                // Create backup first
                CreateBackup();
                
                // Save to JSON
                var filePath = Path.Combine(dataPath, "timeentries.json");
                var options = new JsonSerializerOptions {
                    WriteIndented = true,
                    PropertyNamingPolicy = JsonNamingPolicy.CamelCase
                };
                
                var jsonContent = JsonSerializer.Serialize(timeEntries, options);
                File.WriteAllText(filePath, jsonContent);
            }
            catch (Exception ex) {
                throw new DataPersistenceException($"Error saving time entries: {ex.Message}", ex);
            }
        }
        
        private void CreateBackup() {
            var filePath = Path.Combine(dataPath, "timeentries.json");
            if (File.Exists(filePath)) {
                var timestamp = DateTime.Now.ToString("yyyyMMdd_HHmmss");
                var backupPath = Path.Combine(dataPath, "backups", $"timeentries_backup_{timestamp}.json");
                File.Copy(filePath, backupPath);
            }
        }
        
        private void CreateSampleData() {
            // Create some sample time entries for the current week
            var currentWeek = GetCurrentWeekFriday().ToString("yyyyMMdd");
            
            // Sample project entries
            var project1 = new SimpleTimeEntry(currentWeek, "PRJ001") {
                Description = "TaskProPro Development",
                Monday = 8.0m,
                Tuesday = 7.5m,
                Wednesday = 8.0m,
                IsProjectEntry = true
            };
            project1.CalculateTotal();
            
            var project2 = new SimpleTimeEntry(currentWeek, "PRJ002") {
                Description = "Code Review and Testing",
                Thursday = 4.0m,
                Friday = 6.0m,
                IsProjectEntry = true
            };
            project2.CalculateTotal();
            
            // Sample time code entries
            var vacation = new SimpleTimeEntry(currentWeek, "VAC") {
                Description = "Vacation",
                Friday = 2.0m,
                IsProjectEntry = false
            };
            vacation.CalculateTotal();
            
            timeEntries = new List<SimpleTimeEntry> { project1, project2, vacation };
            SaveTimeEntries();
        }
        
        // Data Access Methods
        public List<SimpleTimeEntry> GetCurrentWeekEntries() {
            var currentWeek = currentWeekFriday.ToString("yyyyMMdd");
            return timeEntries.Where(e => e.WeekEndingFriday == currentWeek).ToList();
        }
        
        public List<SimpleTimeEntry> GetWeekEntries(string weekEndingFriday) {
            return timeEntries.Where(e => e.WeekEndingFriday == weekEndingFriday).ToList();
        }
        
        public List<SimpleTimeEntry> GetAllEntries() {
            return new List<SimpleTimeEntry>(timeEntries);
        }
        
        public void AddTimeEntry(SimpleTimeEntry entry) {
            if (entry == null) throw new ArgumentNullException(nameof(entry));
            
            // Ensure unique ID
            if (timeEntries.Any(e => e.Id == entry.Id)) {
                entry.Id = Guid.NewGuid().ToString();
            }
            
            entry.CalculateTotal();
            entry.Touch();
            timeEntries.Add(entry);
            SaveTimeEntries();
        }
        
        public void UpdateTimeEntry(SimpleTimeEntry entry) {
            if (entry == null) throw new ArgumentNullException(nameof(entry));
            
            var index = timeEntries.FindIndex(e => e.Id == entry.Id);
            if (index >= 0) {
                entry.CalculateTotal();
                entry.Touch();
                timeEntries[index] = entry;
                SaveTimeEntries();
            } else {
                throw new ArgumentException($"Time entry with ID {entry.Id} not found");
            }
        }
        
        public void DeleteTimeEntry(string id) {
            var index = timeEntries.FindIndex(e => e.Id == id);
            if (index >= 0) {
                timeEntries.RemoveAt(index);
                SaveTimeEntries();
            }
        }
        
        public SimpleTimeEntry GetTimeEntry(string id) {
            return timeEntries.FirstOrDefault(e => e.Id == id);
        }
        
        // Week Navigation Methods
        public DateTime GetCurrentWeekFriday() {
            var today = DateTime.Today;
            var daysUntilFriday = ((int)DayOfWeek.Friday - (int)today.DayOfWeek + 7) % 7;
            if (daysUntilFriday == 0 && today.DayOfWeek != DayOfWeek.Friday) {
                daysUntilFriday = 7;
            }
            
            return today.AddDays(daysUntilFriday);
        }
        
        public void NavigateToWeek(DateTime weekEndingFriday) {
            currentWeekFriday = weekEndingFriday;
        }
        
        public void NavigateToCurrentWeek() {
            currentWeekFriday = GetCurrentWeekFriday();
        }
        
        public void NavigateToPreviousWeek() {
            currentWeekFriday = currentWeekFriday.AddDays(-7);
        }
        
        public void NavigateToNextWeek() {
            currentWeekFriday = currentWeekFriday.AddDays(7);
        }
        
        public string GetWeekDisplayString() {
            var mondayDate = currentWeekFriday.AddDays(-4);
            return $"{mondayDate:MMM dd} - {currentWeekFriday:MMM dd, yyyy}";
        }
        
        public bool IsCurrentWeek() {
            var actualCurrentFriday = GetCurrentWeekFriday();
            return currentWeekFriday.Date == actualCurrentFriday.Date;
        }
        
        // Statistics and Summary Methods
        public decimal GetWeekTotal(string weekEndingFriday) {
            var weekEntries = GetWeekEntries(weekEndingFriday);
            return weekEntries.Sum(e => e.Total);
        }
        
        public decimal GetCurrentWeekTotal() {
            return GetWeekTotal(currentWeekFriday.ToString("yyyyMMdd"));
        }
        
        public List<(string ProjectCode, string Description, decimal Total, bool IsProjectEntry)> GetWeekSummary(string weekEndingFriday) {
            var weekEntries = GetWeekEntries(weekEndingFriday);
            return weekEntries.Select(e => (
                ProjectCode: e.ProjectCode,
                Description: e.Description,
                Total: e.Total,
                IsProjectEntry: e.IsProjectEntry
            )).ToList();
        }
        
        // Validation Methods
        public bool ValidateTimeEntry(SimpleTimeEntry entry, out List<string> errors) {
            errors = new List<string>();
            
            if (string.IsNullOrWhiteSpace(entry.ProjectCode)) {
                errors.Add("Project code is required");
            }
            
            if (entry.ProjectCode?.Length > 20) {
                errors.Add("Project code must be 20 characters or less");
            }
            
            if (entry.Description?.Length > 200) {
                errors.Add("Description must be 200 characters or less");
            }
            
            if (entry.Monday < 0 || entry.Monday > 24) {
                errors.Add("Monday hours must be between 0 and 24");
            }
            
            if (entry.Tuesday < 0 || entry.Tuesday > 24) {
                errors.Add("Tuesday hours must be between 0 and 24");
            }
            
            if (entry.Wednesday < 0 || entry.Wednesday > 24) {
                errors.Add("Wednesday hours must be between 0 and 24");
            }
            
            if (entry.Thursday < 0 || entry.Thursday > 24) {
                errors.Add("Thursday hours must be between 0 and 24");
            }
            
            if (entry.Friday < 0 || entry.Friday > 24) {
                errors.Add("Friday hours must be between 0 and 24");
            }
            
            // Check for duplicate project codes in the same week
            var existingEntry = timeEntries.FirstOrDefault(e => 
                e.Id != entry.Id && 
                e.WeekEndingFriday == entry.WeekEndingFriday && 
                e.ProjectCode?.ToUpper() == entry.ProjectCode?.ToUpper());
                
            if (existingEntry != null) {
                errors.Add($"Project code '{entry.ProjectCode}' already exists for this week");
            }
            
            return errors.Count == 0;
        }
        
        // Bulk Operations
        public void ImportTimeEntries(List<SimpleTimeEntry> entries) {
            foreach (var entry in entries) {
                if (ValidateTimeEntry(entry, out var errors)) {
                    AddTimeEntry(entry);
                } else {
                    throw new ArgumentException($"Invalid time entry for {entry.ProjectCode}: {string.Join(", ", errors)}");
                }
            }
        }
        
        public List<SimpleTimeEntry> ExportWeekEntries(string weekEndingFriday) {
            return GetWeekEntries(weekEndingFriday);
        }
        
        // Search and Filter Methods
        public List<SimpleTimeEntry> SearchEntries(string searchTerm) {
            if (string.IsNullOrWhiteSpace(searchTerm)) {
                return new List<SimpleTimeEntry>(timeEntries);
            }
            
            searchTerm = searchTerm.ToLower();
            return timeEntries.Where(e => 
                e.ProjectCode.ToLower().Contains(searchTerm) ||
                e.Description.ToLower().Contains(searchTerm)
            ).ToList();
        }
        
        public List<SimpleTimeEntry> GetProjectEntries() {
            return timeEntries.Where(e => e.IsProjectEntry).ToList();
        }
        
        public List<SimpleTimeEntry> GetTimeCodeEntries() {
            return timeEntries.Where(e => !e.IsProjectEntry).ToList();
        }
        
        public List<string> GetUniqueProjectCodes() {
            return timeEntries.Select(e => e.ProjectCode)
                             .Where(code => !string.IsNullOrEmpty(code))
                             .Distinct()
                             .OrderBy(code => code)
                             .ToList();
        }
    }
}