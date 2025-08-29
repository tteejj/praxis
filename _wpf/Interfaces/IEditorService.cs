using System.Threading.Tasks;

namespace PraxisWpf.Interfaces
{
    public interface IEditorService
    {
        Task<bool> OpenNotesAsync(string projectName, string? existingContent = null);
        Task<bool> OpenFileAsync(string filePath);
        Task<string?> CreateNotesFileAsync(string projectName, string initialContent = "");
        Task<string?> GetNotesContentAsync(string projectName);
        bool IsExternalEditorConfigured();
        bool ValidateEditorConfiguration();
        string GetNotesFilePath(string projectName);
    }
}