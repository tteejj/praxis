using System;
using System.IO;
using System.Text.Json;
using PraxisWpf.Interfaces;
using PraxisWpf.Models;

namespace PraxisWpf.Services
{
    public class PreferencesService : IPreferencesService
    {
        private readonly string _preferencesPath;
        private readonly JsonSerializerOptions _jsonOptions;
        private UserPreferences _currentPreferences;
        private bool _hasChanges;

        public event Action<UserPreferences>? PreferencesChanged;

        public bool HasChanges
        {
            get => _hasChanges;
            private set
            {
                if (_hasChanges != value)
                {
                    _hasChanges = value;
                    Logger.Debug("PreferencesService", $"HasChanges set to {value}");
                }
            }
        }

        public PreferencesService(string preferencesPath = "preferences.json")
        {
            _preferencesPath = preferencesPath;
            _jsonOptions = new JsonSerializerOptions
            {
                WriteIndented = true,
                PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
                AllowTrailingCommas = true,
                ReadCommentHandling = JsonCommentHandling.Skip
            };

            _currentPreferences = LoadPreferences();
            Logger.Debug("PreferencesService", $"Initialized with preferences file: {_preferencesPath}");
        }

        public UserPreferences LoadPreferences()
        {
            try
            {
                if (!File.Exists(_preferencesPath))
                {
                    Logger.Info("PreferencesService", "Preferences file not found, creating default preferences");
                    var defaultPrefs = CreateDefaultPreferences();
                    SavePreferences(defaultPrefs);
                    return defaultPrefs;
                }

                var json = File.ReadAllText(_preferencesPath);
                if (string.IsNullOrWhiteSpace(json))
                {
                    Logger.Warning("PreferencesService", "Preferences file is empty, using defaults");
                    return CreateDefaultPreferences();
                }

                var preferences = JsonSerializer.Deserialize<UserPreferences>(json, _jsonOptions);
                if (preferences == null)
                {
                    Logger.Warning("PreferencesService", "Failed to deserialize preferences, using defaults");
                    return CreateDefaultPreferences();
                }

                // Validate and migrate if necessary
                preferences = ValidateAndMigratePreferences(preferences);
                _currentPreferences = preferences;
                HasChanges = false;

                Logger.Info("PreferencesService", "Preferences loaded successfully");
                return preferences;
            }
            catch (JsonException jsonEx)
            {
                Logger.Error("PreferencesService", "Invalid JSON in preferences file, using defaults", jsonEx);
                return CreateDefaultPreferences();
            }
            catch (Exception ex)
            {
                Logger.Error("PreferencesService", "Failed to load preferences, using defaults", ex);
                return CreateDefaultPreferences();
            }
        }

        public void SavePreferences(UserPreferences preferences)
        {
            try
            {
                // Update metadata
                preferences.LastModified = DateTime.UtcNow;

                // Create backup if file exists
                CreateBackupIfNeeded();

                // Serialize and save
                var json = JsonSerializer.Serialize(preferences, _jsonOptions);
                
                // Atomic save using temp file
                var tempPath = _preferencesPath + ".tmp";
                File.WriteAllText(tempPath, json);
                
                if (File.Exists(_preferencesPath))
                {
                    File.Replace(tempPath, _preferencesPath, null);
                }
                else
                {
                    File.Move(tempPath, _preferencesPath);
                }

                _currentPreferences = preferences;
                HasChanges = false;
                
                Logger.Info("PreferencesService", "Preferences saved successfully");
                PreferencesChanged?.Invoke(preferences);
            }
            catch (Exception ex)
            {
                Logger.Error("PreferencesService", "Failed to save preferences", ex);
                throw;
            }
        }

        public T GetValue<T>(string key, T defaultValue)
        {
            try
            {
                // Use reflection to navigate the preference object tree
                var value = GetNestedValue(_currentPreferences, key);
                
                if (value != null && value is T typedValue)
                {
                    return typedValue;
                }

                Logger.Debug("PreferencesService", $"Key '{key}' not found or wrong type, using default");
                return defaultValue;
            }
            catch (Exception ex)
            {
                Logger.Error("PreferencesService", $"Error getting value for key '{key}'", ex);
                return defaultValue;
            }
        }

        public void SetValue<T>(string key, T value)
        {
            try
            {
                // Use reflection to set nested values
                SetNestedValue(_currentPreferences, key, value);
                HasChanges = true;
                Logger.Debug("PreferencesService", $"Set '{key}' to '{value}'");
            }
            catch (Exception ex)
            {
                Logger.Error("PreferencesService", $"Error setting value for key '{key}'", ex);
                throw;
            }
        }

        public void ResetToDefaults()
        {
            _currentPreferences = CreateDefaultPreferences();
            HasChanges = true;
            Logger.Info("PreferencesService", "Preferences reset to defaults");
        }

        private UserPreferences CreateDefaultPreferences()
        {
            return new UserPreferences();
        }

        private UserPreferences ValidateAndMigratePreferences(UserPreferences preferences)
        {
            // Validate window settings
            if (preferences.Window.Width <= 0) preferences.Window.Width = 800;
            if (preferences.Window.Height <= 0) preferences.Window.Height = 600;
            
            // Validate theme settings
            if (preferences.Theme.FontSize <= 0) preferences.Theme.FontSize = 12;
            if (string.IsNullOrEmpty(preferences.Theme.FontFamily))
                preferences.Theme.FontFamily = "Consolas, Courier New, monospace";

            // Ensure column definitions exist
            if (preferences.Columns.Columns?.Count == 0)
            {
                preferences.Columns = new ColumnSettings();
            }

            // Validate editor settings
            if (preferences.Editor.AutoSaveIntervalSeconds <= 0)
                preferences.Editor.AutoSaveIntervalSeconds = 30;

            // Validate general settings
            if (preferences.General.MaxRecentFiles <= 0)
                preferences.General.MaxRecentFiles = 10;

            return preferences;
        }

        private void CreateBackupIfNeeded()
        {
            if (File.Exists(_preferencesPath))
            {
                try
                {
                    var backupPath = $"{_preferencesPath}.backup";
                    File.Copy(_preferencesPath, backupPath, overwrite: true);
                    Logger.Debug("PreferencesService", $"Backup created: {backupPath}");
                }
                catch (Exception ex)
                {
                    Logger.Warning("PreferencesService", "Failed to create backup", ex);
                    // Continue anyway - backup failure shouldn't prevent saving
                }
            }
        }

        private object? GetNestedValue(object obj, string path)
        {
            var parts = path.Split('.');
            var current = obj;

            foreach (var part in parts)
            {
                if (current == null) return null;
                
                var property = current.GetType().GetProperty(part);
                if (property == null) return null;
                
                current = property.GetValue(current);
            }

            return current;
        }

        private void SetNestedValue(object obj, string path, object? value)
        {
            var parts = path.Split('.');
            var current = obj;

            // Navigate to the parent object
            for (int i = 0; i < parts.Length - 1; i++)
            {
                var property = current.GetType().GetProperty(parts[i]);
                if (property == null)
                    throw new ArgumentException($"Property '{parts[i]}' not found");

                current = property.GetValue(current);
                if (current == null)
                    throw new ArgumentException($"Property '{parts[i]}' is null");
            }

            // Set the final property
            var finalProperty = current.GetType().GetProperty(parts[^1]);
            if (finalProperty == null)
                throw new ArgumentException($"Property '{parts[^1]}' not found");

            finalProperty.SetValue(current, value);
        }
    }
}