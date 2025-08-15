using System;

namespace TaskPro.Core
{
    /// <summary>
    /// Rectangle structure for UI layout and bounds
    /// </summary>
    public struct Rectangle
    {
        public int X { get; set; }
        public int Y { get; set; }
        public int Width { get; set; }
        public int Height { get; set; }
        
        public int Right => X + Width;
        public int Bottom => Y + Height;
        
        public Rectangle(int x, int y, int width, int height)
        {
            X = x;
            Y = y;
            Width = width;
            Height = height;
        }
        
        public bool Contains(int x, int y)
        {
            return x >= X && x < Right && y >= Y && y < Bottom;
        }
        
        public bool Intersects(Rectangle other)
        {
            return X < other.Right && Right > other.X && Y < other.Bottom && Bottom > other.Y;
        }
        
        public override string ToString()
        {
            return $"Rectangle(X={X}, Y={Y}, Width={Width}, Height={Height})";
        }
    }
}