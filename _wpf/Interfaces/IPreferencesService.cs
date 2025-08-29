using PraxisWpf.Models;

namespace PraxisWpf.Interfaces
{
    public interface IPreferencesService
    {
        UserPreferences LoadPreferences();
        void SavePreferences(UserPreferences preferences);
        T GetValue<T>(string key, T defaultValue);
        void SetValue<T>(string key, T value);
        void ResetToDefaults();
        bool HasChanges { get; }
        event System.Action<UserPreferences>? PreferencesChanged;
    }
}