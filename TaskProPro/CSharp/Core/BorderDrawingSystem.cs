using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;

namespace TaskPro.Core
{
    /// <summary>
    /// Professional Unicode box drawing system with perfect connections
    /// Calculates every junction and line segment mathematically
    /// </summary>
    public class BorderDrawingSystem
    {
        // Unicode box drawing characters
        private const char HORIZONTAL = '─';
        private const char VERTICAL = '║';
        private const char TOP_LEFT = '╔';
        private const char TOP_RIGHT = '╗';
        private const char BOTTOM_LEFT = '╚';
        private const char BOTTOM_RIGHT = '╝';
        private const char CROSS = '╬';
        private const char T_UP = '╩';
        private const char T_DOWN = '╦';
        private const char T_LEFT = '╣';
        private const char T_RIGHT = '╠';
        
        // Column separator characters
        private const char COL_VERTICAL = '│';
        private const char COL_HORIZONTAL = '─';
        private const char COL_CROSS = '┼';
        private const char COL_T_UP = '┴';
        private const char COL_T_DOWN = '┬';
        private const char COL_T_LEFT = '┤';
        private const char COL_T_RIGHT = '├';
        
        // Border connection points
        private const char BORDER_COL_T_DOWN = '╤';  // Border horizontal line with column separator down
        private const char BORDER_COL_T_UP = '╧';    // Border horizontal line with column separator up
        private const char BORDER_COL_CROSS = '╪';   // Border horizontal with column vertical crossing
        
        private readonly Dictionary<(int x, int y), BorderCell> borderGrid = new();
        private int gridWidth;
        private int gridHeight;
        
        /// <summary>
        /// Initialize border system for given dimensions
        /// </summary>
        public void Initialize(int width, int height)
        {
            gridWidth = width;
            gridHeight = height;
            borderGrid.Clear();
        }
        
        /// <summary>
        /// Add a complete rectangular border
        /// </summary>
        public void AddRectangle(int x, int y, int width, int height, BorderLineType borderType = BorderLineType.Heavy)
        {
            // Top and bottom horizontal lines
            for (int i = 0; i < width; i++)
            {
                SetCell(x + i, y, BorderDirection.Horizontal, borderType);
                SetCell(x + i, y + height - 1, BorderDirection.Horizontal, borderType);
            }
            
            // Left and right vertical lines
            for (int i = 0; i < height; i++)
            {
                SetCell(x, y + i, BorderDirection.Vertical, borderType);
                SetCell(x + width - 1, y + i, BorderDirection.Vertical, borderType);
            }
        }
        
        /// <summary>
        /// Add column separator lines at specific positions
        /// </summary>
        public void AddColumnSeparators(int[] columnPositions, int startY, int endY)
        {
            foreach (var x in columnPositions)
            {
                for (int y = startY; y <= endY; y++)
                {
                    SetCell(x, y, BorderDirection.Vertical, BorderLineType.Light);
                }
            }
        }
        
        /// <summary>
        /// Add horizontal separator line
        /// </summary>
        public void AddHorizontalSeparator(int y, int startX, int endX, BorderLineType borderType = BorderLineType.Heavy)
        {
            for (int x = startX; x <= endX; x++)
            {
                SetCell(x, y, BorderDirection.Horizontal, borderType);
            }
        }
        
        /// <summary>
        /// Set border cell with direction and type
        /// </summary>
        private void SetCell(int x, int y, BorderDirection direction, BorderLineType borderType)
        {
            var key = (x, y);
            if (!borderGrid.ContainsKey(key))
            {
                borderGrid[key] = new BorderCell();
            }
            
            var cell = borderGrid[key];
            
            switch (direction)
            {
                case BorderDirection.Horizontal:
                    if (borderType == BorderLineType.Heavy)
                        cell.HasHeavyHorizontal = true;
                    else
                        cell.HasLightHorizontal = true;
                    break;
                    
                case BorderDirection.Vertical:
                    if (borderType == BorderLineType.Heavy)
                        cell.HasHeavyVertical = true;
                    else
                        cell.HasLightVertical = true;
                    break;
            }
        }
        
        /// <summary>
        /// Generate the complete border character at position
        /// </summary>
        public char GetBorderChar(int x, int y)
        {
            var key = (x, y);
            if (!borderGrid.ContainsKey(key))
                return ' ';
                
            var cell = borderGrid[key];
            
            // Determine what type of junction/line this is
            bool hasHeavyH = cell.HasHeavyHorizontal;
            bool hasLightH = cell.HasLightHorizontal;
            bool hasHeavyV = cell.HasHeavyVertical;
            bool hasLightV = cell.HasLightVertical;
            
            // Heavy border characters (main frame)
            if (hasHeavyH && hasHeavyV)
                return CROSS;
            else if (hasHeavyH && hasLightV)
                return BORDER_COL_CROSS;  // Heavy horizontal with light vertical
            else if (hasHeavyH)
                return HORIZONTAL;
            else if (hasHeavyV)
                return VERTICAL;
            else if (hasLightH && hasLightV)
                return COL_CROSS;
            else if (hasLightH)
                return COL_HORIZONTAL;
            else if (hasLightV)
                return COL_VERTICAL;
                
            return ' ';
        }
        
        /// <summary>
        /// Generate border character with proper corner detection
        /// </summary>
        public char GetCornerChar(int x, int y)
        {
            var key = (x, y);
            if (!borderGrid.ContainsKey(key))
                return ' ';
                
            var cell = borderGrid[key];
            
            // Check surrounding cells for corner detection
            bool hasLeft = HasHorizontalAt(x - 1, y);
            bool hasRight = HasHorizontalAt(x + 1, y);
            bool hasUp = HasVerticalAt(x, y - 1);
            bool hasDown = HasVerticalAt(x, y + 1);
            
            // Corner detection
            if (!hasLeft && !hasUp && hasRight && hasDown)
                return TOP_LEFT;
            else if (!hasRight && !hasUp && hasLeft && hasDown)
                return TOP_RIGHT;
            else if (!hasLeft && !hasDown && hasRight && hasUp)
                return BOTTOM_LEFT;
            else if (!hasRight && !hasDown && hasLeft && hasUp)
                return BOTTOM_RIGHT;
            
            // T-junctions
            else if (hasLeft && hasRight && hasDown && !hasUp)
                return T_DOWN;
            else if (hasLeft && hasRight && hasUp && !hasDown)
                return T_UP;
            else if (hasUp && hasDown && hasRight && !hasLeft)
                return T_RIGHT;
            else if (hasUp && hasDown && hasLeft && !hasRight)
                return T_LEFT;
            
            // Cross junction
            else if (hasLeft && hasRight && hasUp && hasDown)
                return CROSS;
            
            return GetBorderChar(x, y);
        }
        
        /// <summary>
        /// Check if there's a horizontal line at position
        /// </summary>
        private bool HasHorizontalAt(int x, int y)
        {
            var key = (x, y);
            if (!borderGrid.ContainsKey(key))
                return false;
            var cell = borderGrid[key];
            return cell.HasHeavyHorizontal || cell.HasLightHorizontal;
        }
        
        /// <summary>
        /// Check if there's a vertical line at position
        /// </summary>
        private bool HasVerticalAt(int x, int y)
        {
            var key = (x, y);
            if (!borderGrid.ContainsKey(key))
                return false;
            var cell = borderGrid[key];
            return cell.HasHeavyVertical || cell.HasLightVertical;
        }
        
        /// <summary>
        /// Render complete border line at Y position
        /// </summary>
        public string RenderBorderLine(int y)
        {
            var sb = new StringBuilder(gridWidth);
            
            for (int x = 0; x < gridWidth; x++)
            {
                sb.Append(GetCornerChar(x, y));
            }
            
            return sb.ToString();
        }
        
        /// <summary>
        /// Render content line with side borders and column separators at exact positions
        /// FIXED: Content goes in between separators, not overlaid
        /// </summary>
        public string RenderContentLine(string content, int[] columnPositions = null)
        {
            var sb = new StringBuilder(gridWidth);
            
            // Add left border
            sb.Append(VERTICAL);
            
            if (columnPositions == null || columnPositions.Length == 0)
            {
                // Simple content line - just borders
                var contentArea = content ?? "";
                if (contentArea.Length > gridWidth - 2)
                {
                    contentArea = contentArea.Substring(0, gridWidth - 2);
                }
                else
                {
                    contentArea = contentArea.PadRight(gridWidth - 2);
                }
                
                sb.Append(contentArea);
            }
            else
            {
                // Column-based content line
                var columns = SplitContentIntoColumns(content, columnPositions);
                RenderColumnsWithSeparators(sb, columns, columnPositions);
            }
            
            // Add right border
            sb.Append(VERTICAL);
            
            return sb.ToString();
        }
        
        /// <summary>
        /// Split content string into column segments
        /// </summary>
        private string[] SplitContentIntoColumns(string content, int[] columnPositions)
        {
            if (string.IsNullOrEmpty(content))
                return new string[columnPositions.Length + 1];
                
            // Split by actual separator characters if they exist
            var parts = content.Split('│', '║', '|');
            
            // Pad array to match expected column count
            var columns = new string[columnPositions.Length + 1];
            for (int i = 0; i < columns.Length; i++)
            {
                columns[i] = i < parts.Length ? parts[i].Trim() : "";
            }
            
            return columns;
        }
        
        /// <summary>
        /// Render columns with proper separators at exact positions
        /// FIXED: Proper space allocation to prevent truncation
        /// </summary>
        private void RenderColumnsWithSeparators(StringBuilder sb, string[] columns, int[] columnPositions)
        {
            int currentPos = 1; // Start after left border
            int contentAreaWidth = gridWidth - 2; // Total space minus left and right borders
            
            for (int i = 0; i < columns.Length; i++)
            {
                // Calculate column width more accurately
                int columnWidth;
                if (i < columnPositions.Length)
                {
                    // Width from current position to next separator
                    columnWidth = columnPositions[i] - currentPos;
                }
                else
                {
                    // Last column gets all remaining space
                    columnWidth = contentAreaWidth - currentPos;
                }
                
                // Ensure positive width and account for minimum space
                if (columnWidth <= 0) 
                {
                    columnWidth = 1;
                }
                
                // Add column content, properly sized
                var columnContent = columns[i] ?? "";
                if (columnContent.Length > columnWidth)
                {
                    columnContent = columnContent.Substring(0, columnWidth);
                }
                else
                {
                    columnContent = columnContent.PadRight(columnWidth);
                }
                
                sb.Append(columnContent);
                currentPos += columnWidth;
                
                // Add separator if not the last column and there's space
                if (i < columnPositions.Length && currentPos < contentAreaWidth)
                {
                    sb.Append(COL_VERTICAL);
                    currentPos++;
                }
            }
            
            // Fill any remaining space to exactly match content area
            int remainingSpace = contentAreaWidth - currentPos;
            if (remainingSpace > 0)
            {
                sb.Append(' ', remainingSpace);
            }
            
            // Ensure exact length
            if (sb.Length > contentAreaWidth)
            {
                sb.Length = contentAreaWidth;
            }
        }
        
        /// <summary>
        /// Render data line with perfect column alignment
        /// FIXED: Proper column separation without double separators
        /// </summary>
        public string RenderDataLine(int y, string content, int[] columnPositions)
        {
            return RenderContentLine(content, columnPositions);
        }
    }
    
    /// <summary>
    /// Represents a single cell in the border grid
    /// </summary>
    public class BorderCell
    {
        public bool HasHeavyHorizontal { get; set; }
        public bool HasLightHorizontal { get; set; }
        public bool HasHeavyVertical { get; set; }
        public bool HasLightVertical { get; set; }
    }
    
    /// <summary>
    /// Border direction enumeration
    /// </summary>
    public enum BorderDirection
    {
        Horizontal,
        Vertical
    }
    
    /// <summary>
    /// Border line type enumeration
    /// </summary>
    public enum BorderLineType
    {
        Light,
        Heavy
    }
}