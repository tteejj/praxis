using System;
using System.Linq;
using System.Windows;
using System.Windows.Controls;
using PraxisWpf.Interfaces;
using PraxisWpf.Models;
using PraxisWpf.Services;

namespace PraxisWpf.Behaviors
{
    public static class ResponsiveColumnBehavior
    {
        #region EnableResponsiveColumns

        public static readonly DependencyProperty EnableResponsiveColumnsProperty =
            DependencyProperty.RegisterAttached(
                "EnableResponsiveColumns",
                typeof(bool),
                typeof(ResponsiveColumnBehavior),
                new PropertyMetadata(false, OnEnableResponsiveColumnsChanged));

        public static bool GetEnableResponsiveColumns(DependencyObject obj)
        {
            return (bool)obj.GetValue(EnableResponsiveColumnsProperty);
        }

        public static void SetEnableResponsiveColumns(DependencyObject obj, bool value)
        {
            obj.SetValue(EnableResponsiveColumnsProperty, value);
        }

        private static void OnEnableResponsiveColumnsChanged(DependencyObject sender, DependencyPropertyChangedEventArgs e)
        {
            if (sender is Grid grid)
            {
                if ((bool)e.NewValue)
                {
                    grid.SizeChanged += OnGridSizeChanged;
                    grid.Loaded += OnGridLoaded;
                }
                else
                {
                    grid.SizeChanged -= OnGridSizeChanged;
                    grid.Loaded -= OnGridLoaded;
                }
            }
        }

        #endregion

        #region MinColumnWidth

        public static readonly DependencyProperty MinColumnWidthProperty =
            DependencyProperty.RegisterAttached(
                "MinColumnWidth",
                typeof(double),
                typeof(ResponsiveColumnBehavior),
                new PropertyMetadata(50.0));

        public static double GetMinColumnWidth(DependencyObject obj)
        {
            return (double)obj.GetValue(MinColumnWidthProperty);
        }

        public static void SetMinColumnWidth(DependencyObject obj, double value)
        {
            obj.SetValue(MinColumnWidthProperty, value);
        }

        #endregion

        #region MaxColumnWidth

        public static readonly DependencyProperty MaxColumnWidthProperty =
            DependencyProperty.RegisterAttached(
                "MaxColumnWidth",
                typeof(double),
                typeof(ResponsiveColumnBehavior),
                new PropertyMetadata(300.0));

        public static double GetMaxColumnWidth(DependencyObject obj)
        {
            return (double)obj.GetValue(MaxColumnWidthProperty);
        }

        public static void SetMaxColumnWidth(DependencyObject obj, double value)
        {
            obj.SetValue(MaxColumnWidthProperty, value);
        }

        #endregion

        #region Event Handlers

        private static void OnGridLoaded(object sender, RoutedEventArgs e)
        {
            if (sender is Grid grid)
            {
                ApplyResponsiveLayout(grid);
            }
        }

        private static void OnGridSizeChanged(object sender, SizeChangedEventArgs e)
        {
            if (sender is Grid grid && e.WidthChanged)
            {
                ApplyResponsiveLayout(grid);
            }
        }

        #endregion

        #region Layout Logic

        private static void ApplyResponsiveLayout(Grid grid)
        {
            try
            {
                var availableWidth = grid.ActualWidth;
                if (availableWidth <= 0) return;

                var preferencesService = GetPreferencesService();
                if (preferencesService == null)
                {
                    ApplyDefaultLayout(grid, availableWidth);
                    return;
                }

                var preferences = preferencesService.LoadPreferences();
                ApplyPreferencesBasedLayout(grid, preferences.Columns, availableWidth);
            }
            catch (Exception ex)
            {
                Logger.Error("ResponsiveColumnBehavior", "Error applying responsive layout", ex);
                ApplyDefaultLayout(grid, grid.ActualWidth);
            }
        }

        private static void ApplyPreferencesBasedLayout(Grid grid, ColumnSettings columnSettings, double availableWidth)
        {
            if (!columnSettings.AutoResizeColumns)
            {
                ApplyFixedLayout(grid, columnSettings);
                return;
            }

            var minWidth = GetMinColumnWidth(grid);
            var maxWidth = GetMaxColumnWidth(grid);
            
            // Calculate responsive widths
            var visibleColumns = columnSettings.Columns.Where(c => c.Visible).OrderBy(c => c.Order).ToList();
            if (visibleColumns.Count == 0) return;

            // Reserve space for margins and borders (approximate)
            var usableWidth = Math.Max(availableWidth - 50, 200);
            
            // Find columns with fixed widths and star columns
            var fixedColumns = visibleColumns.Where(c => c.Width > 0).ToList();
            var starColumns = visibleColumns.Where(c => c.Width <= 0).ToList();
            
            var fixedWidthUsed = fixedColumns.Sum(c => Math.Max(minWidth, Math.Min(c.Width, maxWidth)));
            var remainingWidth = Math.Max(usableWidth - fixedWidthUsed, 0);
            
            // Distribute remaining width among star columns
            var widthPerStarColumn = starColumns.Count > 0 ? remainingWidth / starColumns.Count : 0;
            widthPerStarColumn = Math.Max(minWidth, Math.Min(widthPerStarColumn, maxWidth));

            // Apply calculated widths
            grid.ColumnDefinitions.Clear();
            
            foreach (var column in visibleColumns)
            {
                var columnDef = new System.Windows.Controls.ColumnDefinition();
                
                if (column.Width > 0)
                {
                    // Fixed width column
                    var width = Math.Max(minWidth, Math.Min(column.Width, maxWidth));
                    columnDef.Width = new GridLength(width, GridUnitType.Pixel);
                }
                else
                {
                    // Star column
                    if (widthPerStarColumn >= minWidth)
                    {
                        columnDef.Width = new GridLength(widthPerStarColumn, GridUnitType.Pixel);
                    }
                    else
                    {
                        columnDef.Width = new GridLength(1, GridUnitType.Star);
                    }
                }
                
                columnDef.MinWidth = minWidth;
                
                if (column.Resizable && maxWidth > 0)
                {
                    columnDef.MaxWidth = maxWidth;
                }
                
                grid.ColumnDefinitions.Add(columnDef);
            }

            Logger.Debug("ResponsiveColumnBehavior", $"Applied responsive layout: {visibleColumns.Count} columns, {usableWidth:F0}px available");
        }

        private static void ApplyFixedLayout(Grid grid, ColumnSettings columnSettings)
        {
            var visibleColumns = columnSettings.Columns.Where(c => c.Visible).OrderBy(c => c.Order).ToList();
            
            grid.ColumnDefinitions.Clear();
            
            foreach (var column in visibleColumns)
            {
                var columnDef = new System.Windows.Controls.ColumnDefinition();
                
                if (column.Width > 0)
                {
                    columnDef.Width = new GridLength(column.Width, GridUnitType.Pixel);
                }
                else
                {
                    columnDef.Width = new GridLength(1, GridUnitType.Star);
                }
                
                if (column.Resizable)
                {
                    columnDef.MinWidth = columnSettings.MinColumnWidth;
                    if (columnSettings.MaxColumnWidth > 0)
                    {
                        columnDef.MaxWidth = columnSettings.MaxColumnWidth;
                    }
                }
                
                grid.ColumnDefinitions.Add(columnDef);
            }

            Logger.Debug("ResponsiveColumnBehavior", $"Applied fixed layout: {visibleColumns.Count} columns");
        }

        private static void ApplyDefaultLayout(Grid grid, double availableWidth)
        {
            // Default responsive behavior without preferences
            var columnCount = grid.ColumnDefinitions.Count;
            if (columnCount == 0) return;

            var minWidth = GetMinColumnWidth(grid);
            var maxWidth = GetMaxColumnWidth(grid);
            var usableWidth = Math.Max(availableWidth - 50, 200);
            
            // Simple equal distribution with constraints
            var idealWidth = usableWidth / columnCount;
            var actualWidth = Math.Max(minWidth, Math.Min(idealWidth, maxWidth));
            
            // If the last column should fill remaining space, handle it specially
            for (int i = 0; i < columnCount; i++)
            {
                var columnDef = grid.ColumnDefinitions[i];
                
                if (i == columnCount - 1) // Last column fills remaining space
                {
                    columnDef.Width = new GridLength(1, GridUnitType.Star);
                }
                else
                {
                    columnDef.Width = new GridLength(actualWidth, GridUnitType.Pixel);
                }
                
                columnDef.MinWidth = minWidth;
                if (maxWidth > 0)
                {
                    columnDef.MaxWidth = maxWidth;
                }
            }

            Logger.Debug("ResponsiveColumnBehavior", $"Applied default responsive layout: {columnCount} columns, {actualWidth:F0}px each");
        }

        private static IPreferencesService? GetPreferencesService()
        {
            try
            {
                return DIContainer.Instance.TryResolve<IPreferencesService>();
            }
            catch
            {
                return null;
            }
        }

        #endregion
    }
}