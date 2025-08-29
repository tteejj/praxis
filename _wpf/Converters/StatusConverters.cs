using System;
using System.Globalization;
using System.Windows.Data;
using System.Windows.Media;
using PraxisWpf.Services;

namespace PraxisWpf.Services
{
    public class StatusTypeToColorConverter : IValueConverter
    {
        public object Convert(object value, Type targetType, object parameter, CultureInfo culture)
        {
            if (value is StatusType statusType)
            {
                return statusType switch
                {
                    StatusType.Info => new SolidColorBrush(Colors.CornflowerBlue),
                    StatusType.Success => new SolidColorBrush(Colors.LimeGreen),
                    StatusType.Warning => new SolidColorBrush(Colors.Gold),
                    StatusType.Error => new SolidColorBrush(Colors.OrangeRed),
                    StatusType.Progress => new SolidColorBrush(Colors.DeepSkyBlue),
                    _ => new SolidColorBrush(Colors.White)
                };
            }
            return new SolidColorBrush(Colors.White);
        }

        public object ConvertBack(object value, Type targetType, object parameter, CultureInfo culture)
        {
            throw new NotImplementedException();
        }
    }

    public class StatusTypeToIconConverter : IValueConverter
    {
        public object Convert(object value, Type targetType, object parameter, CultureInfo culture)
        {
            if (value is StatusType statusType)
            {
                return statusType switch
                {
                    StatusType.Info => "ℹ",
                    StatusType.Success => "✓",
                    StatusType.Warning => "⚠",
                    StatusType.Error => "✗",
                    StatusType.Progress => "⟳",
                    _ => "●"
                };
            }
            return "●";
        }

        public object ConvertBack(object value, Type targetType, object parameter, CultureInfo culture)
        {
            throw new NotImplementedException();
        }
    }
}