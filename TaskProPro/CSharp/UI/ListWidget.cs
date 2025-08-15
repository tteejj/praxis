using System;
using System.Collections.Generic;
using System.Linq;
using TaskPro.Core;

namespace TaskPro.UI
{
    /// <summary>
    /// Professional list widget with smooth navigation and rich formatting
    /// </summary>
    public class ListWidget<T>
    {
        private List<T> items = new List<T>();
        private List<T> filteredItems = new List<T>();
        private int selectedIndex = 0;
        private int scrollTop = 0;
        private string searchFilter = "";
        
        public List<T> Items 
        { 
            get => items; 
            set 
            { 
                items = value ?? new List<T>(); 
                ApplyFilter();
                EnsureValidSelection();
            } 
        }
        
        public T SelectedItem => HasSelection ? filteredItems[selectedIndex] : default(T);
        public int SelectedIndex => selectedIndex;
        public int TotalItems => filteredItems.Count;
        public bool HasSelection => selectedIndex >= 0 && selectedIndex < filteredItems.Count;
        public bool IsFocused { get; set; } = true;
        
        // Display configuration
        public Func<T, string> ItemFormatter { get; set; } = item => item?.ToString() ?? "";
        public Func<T, ConsoleColor> ItemColorProvider { get; set; } = item => ConsoleColor.White;
        public Func<T, ConsoleColor> ItemBackgroundProvider { get; set; } = item => ConsoleColor.Black;
        public Func<T, bool> ItemHighlightProvider { get; set; } = item => false;
        public Func<T, string> ItemPrefixProvider { get; set; } = item => "";
        
        // Selection configuration
        public ConsoleColor SelectionColor { get; set; } = ConsoleColor.Black;
        public ConsoleColor SelectionBackground { get; set; } = ConsoleColor.White;
        public bool ShowPillboxSelection { get; set; } = true;
        public bool ShowLineNumbers { get; set; } = false;
        public bool ShowScrollIndicators { get; set; } = true;
        
        // Events
        public event Action<T> ItemSelected;
        public event Action<T> ItemActivated;
        public event Action<string> SearchChanged;
        
        /// <summary>
        /// Handle input and return true if consumed
        /// </summary>
        public bool HandleInput(InputEvent input)
        {
            if (!IsFocused) return false;
            
            // Navigation
            if (input.IsArrowUp)
            {
                MoveTo(selectedIndex - 1);
                return true;
            }
            
            if (input.IsArrowDown)
            {
                MoveTo(selectedIndex + 1);
                return true;
            }
            
            if (input.IsPageUp)
            {
                MoveTo(selectedIndex - 10); // Page size
                return true;
            }
            
            if (input.IsPageDown)
            {
                MoveTo(selectedIndex + 10);
                return true;
            }
            
            if (input.IsHome)
            {
                MoveTo(0);
                return true;
            }
            
            if (input.IsEnd)
            {
                MoveTo(filteredItems.Count - 1);
                return true;
            }
            
            // Quick search by typing
            if (input.IsPrintableChar && !input.Ctrl && !input.Alt)
            {
                searchFilter += input.Char;
                ApplyFilter();
                SearchChanged?.Invoke(searchFilter);
                return true;
            }
            
            // Clear search
            if (input.IsEscape && !string.IsNullOrEmpty(searchFilter))
            {
                ClearSearch();
                return true;
            }
            
            // Selection/activation
            if (input.IsEnter && HasSelection)
            {
                ItemActivated?.Invoke(SelectedItem);
                return true;
            }
            
            return false;
        }
        
        /// <summary>
        /// Render the list to screen buffer
        /// </summary>
        public void Render(ScreenBuffer screen, Rectangle bounds)
        {
            if (bounds.Width < 1 || bounds.Height < 1) return;
            
            // Clear the area
            screen.ClearArea(bounds.X, bounds.Y, bounds.Width, bounds.Height);
            
            // Calculate visible items
            var visibleHeight = bounds.Height;
            var maxVisible = Math.Min(visibleHeight, filteredItems.Count);
            
            // Ensure selected item is visible
            EnsureVisible(bounds.Height);
            
            // Render items
            for (int i = 0; i < maxVisible; i++)
            {
                var itemIndex = scrollTop + i;
                if (itemIndex >= filteredItems.Count) break;
                
                var item = filteredItems[itemIndex];
                var isSelected = (itemIndex == selectedIndex) && IsFocused;
                var y = bounds.Y + i;
                
                RenderItem(screen, item, bounds.X, y, bounds.Width, isSelected, itemIndex);
            }
            
            // Render scroll indicators
            if (ShowScrollIndicators && filteredItems.Count > bounds.Height)
            {
                RenderScrollIndicators(screen, bounds);
            }
            
            // Render search indicator
            if (!string.IsNullOrEmpty(searchFilter))
            {
                var searchText = $"Search: {searchFilter}";
                screen.WriteAt(bounds.X, bounds.Y + bounds.Height - 1, 
                             searchText.PadRight(Math.Min(searchText.Length, bounds.Width)), 
                             ConsoleColor.Yellow, ConsoleColor.DarkRed);
            }
        }
        
        private void RenderItem(ScreenBuffer screen, T item, int x, int y, int width, bool isSelected, int itemIndex)
        {
            var text = ItemFormatter(item);
            var prefix = ItemPrefixProvider(item);
            var fullText = prefix + text;
            
            // Truncate if too long
            if (fullText.Length > width)
            {
                fullText = fullText.Substring(0, width - 3) + "...";
            }
            
            // Get colors
            ConsoleColor fg, bg;
            if (isSelected)
            {
                if (ShowPillboxSelection)
                {
                    // Render pillbox selection (like your TaskPro design)
                    if (y > 0) // Space for top border
                    {
                        screen.DrawPillbox(x, y - 1, width, fullText, SelectionBackground);
                        return; // Pillbox handles the rendering
                    }
                }
                
                fg = SelectionColor;
                bg = SelectionBackground;
            }
            else
            {
                fg = ItemColorProvider(item);
                bg = ItemBackgroundProvider(item);
                
                // Apply highlight if specified
                if (ItemHighlightProvider(item))
                {
                    bg = ConsoleColor.DarkYellow;
                }
            }
            
            // Line numbers
            if (ShowLineNumbers)
            {
                var lineNum = (itemIndex + 1).ToString().PadLeft(3);
                screen.WriteAt(x, y, lineNum + " ", ConsoleColor.DarkGray);
                x += 4;
                width -= 4;
            }
            
            // Render text
            var displayText = fullText.PadRight(width);
            screen.WriteAt(x, y, displayText, fg, bg);
        }
        
        private void RenderScrollIndicators(ScreenBuffer screen, Rectangle bounds)
        {
            var x = bounds.X + bounds.Width - 1;
            
            // Up arrow if not at top
            if (scrollTop > 0)
            {
                screen.WriteAt(x, bounds.Y, "▲", ConsoleColor.Cyan);
            }
            
            // Down arrow if not at bottom
            if (scrollTop + bounds.Height < filteredItems.Count)
            {
                screen.WriteAt(x, bounds.Y + bounds.Height - 1, "▼", ConsoleColor.Cyan);
            }
            
            // Scroll position indicator
            if (filteredItems.Count > 0)
            {
                var scrollPercentage = (double)scrollTop / (filteredItems.Count - bounds.Height + 1);
                var indicatorY = bounds.Y + 1 + (int)((bounds.Height - 3) * scrollPercentage);
                screen.WriteAt(x, indicatorY, "█", ConsoleColor.Gray);
            }
        }
        
        private void MoveTo(int newIndex)
        {
            var oldIndex = selectedIndex;
            selectedIndex = Math.Max(0, Math.Min(filteredItems.Count - 1, newIndex));
            
            if (oldIndex != selectedIndex && HasSelection)
            {
                ItemSelected?.Invoke(SelectedItem);
            }
        }
        
        private void EnsureVisible(int visibleHeight)
        {
            if (!HasSelection) return;
            
            // Scroll up if selection is above visible area
            if (selectedIndex < scrollTop)
            {
                scrollTop = selectedIndex;
            }
            // Scroll down if selection is below visible area
            else if (selectedIndex >= scrollTop + visibleHeight)
            {
                scrollTop = selectedIndex - visibleHeight + 1;
            }
            
            // Ensure scroll doesn't go negative or beyond content
            scrollTop = Math.Max(0, Math.Min(scrollTop, Math.Max(0, filteredItems.Count - visibleHeight)));
        }
        
        private void ApplyFilter()
        {
            if (string.IsNullOrEmpty(searchFilter))
            {
                filteredItems = new List<T>(items);
            }
            else
            {
                filteredItems = items.Where(item => 
                    ItemFormatter(item).Contains(searchFilter, StringComparison.OrdinalIgnoreCase))
                    .ToList();
            }
            
            EnsureValidSelection();
        }
        
        private void EnsureValidSelection()
        {
            if (filteredItems.Count == 0)
            {
                selectedIndex = -1;
            }
            else
            {
                selectedIndex = Math.Max(0, Math.Min(selectedIndex, filteredItems.Count - 1));
            }
            
            scrollTop = Math.Max(0, Math.Min(scrollTop, Math.Max(0, filteredItems.Count - 1)));
        }
        
        public void ClearSearch()
        {
            searchFilter = "";
            ApplyFilter();
            SearchChanged?.Invoke(searchFilter);
        }
        
        public void SetFilter(string filter)
        {
            searchFilter = filter ?? "";
            ApplyFilter();
            SearchChanged?.Invoke(searchFilter);
        }
        
        public void SelectItem(T item)
        {
            var index = filteredItems.IndexOf(item);
            if (index >= 0)
            {
                MoveTo(index);
            }
        }
        
        public void SelectItemByPredicate(Func<T, bool> predicate)
        {
            var index = filteredItems.FindIndex(item => predicate(item));
            if (index >= 0)
            {
                MoveTo(index);
            }
        }
        
        public void Refresh()
        {
            ApplyFilter();
        }
    }
}