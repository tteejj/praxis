namespace PraxisWpf.Interfaces
{
    public interface IDisplayableItem
    {
        string DisplayName { get; }
        bool IsExpanded { get; set; }
        bool IsInEditMode { get; set; }
    }
}