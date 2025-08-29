using System.Collections.ObjectModel;
using PraxisWpf.Models;

namespace PraxisWpf.Interfaces
{
    public interface IDataService
    {
        ObservableCollection<TaskItem> LoadItems();
        void SaveItems(ObservableCollection<TaskItem> items);
    }
}