using System;
using System.Text;

namespace TaskPro.Core
{
    /// <summary>
    /// High-performance gap buffer implementation for optimal text editing
    /// C# implementation with better performance than PowerShell version
    /// </summary>
    public class GapBuffer
    {
        // Internal buffer with gap
        private char[] buffer;
        private int gapStart;
        private int gapEnd;
        private int capacity;
        
        // Buffer growth parameters
        private const int INITIAL_CAPACITY = 1024;
        private const double GROWTH_FACTOR = 1.5;
        private const int MIN_GAP_SIZE = 128;
        
        // Statistics for debugging/optimization
        public int InsertCount { get; private set; } = 0;
        public int DeleteCount { get; private set; } = 0;
        public int MoveCount { get; private set; } = 0;
        public int GrowCount { get; private set; } = 0;
        
        // Properties
        public int Length => capacity - (gapEnd - gapStart);
        public int Capacity => capacity;
        public int GapSize => gapEnd - gapStart;
        
        // Constructors
        public GapBuffer() : this(INITIAL_CAPACITY) { }
        
        public GapBuffer(int initialCapacity)
        {
            capacity = Math.Max(initialCapacity, MIN_GAP_SIZE);
            buffer = new char[capacity];
            gapStart = 0;
            gapEnd = capacity;
        }
        
        public GapBuffer(string text) : this()
        {
            if (!string.IsNullOrEmpty(text))
            {
                int textLength = text.Length;
                capacity = Math.Max(textLength + MIN_GAP_SIZE, INITIAL_CAPACITY);
                buffer = new char[capacity];
                
                // Copy text to buffer
                text.CopyTo(0, buffer, 0, textLength);
                
                gapStart = textLength;
                gapEnd = capacity;
            }
        }
        
        /// <summary>
        /// Move gap to specified position for optimal insertion/deletion
        /// </summary>
        public void MoveGapTo(int position)
        {
            if (position < 0 || position > Length)
                throw new ArgumentOutOfRangeException(nameof(position), $"Position {position} is out of range (0-{Length})");
            
            if (position == gapStart)
                return; // Gap is already at correct position
            
            MoveCount++;
            
            if (position < gapStart)
            {
                // Move gap left - shift text right
                int moveSize = gapStart - position;
                int sourceStart = position;
                int destStart = gapEnd - moveSize;
                
                Array.Copy(buffer, sourceStart, buffer, destStart, moveSize);
                
                gapStart = position;
                gapEnd -= moveSize;
            }
            else
            {
                // Move gap right - shift text left
                int moveSize = position - gapStart;
                int sourceStart = gapEnd;
                int destStart = gapStart;
                
                Array.Copy(buffer, sourceStart, buffer, destStart, moveSize);
                
                gapStart = position;
                gapEnd += moveSize;
            }
        }
        
        /// <summary>
        /// Ensure gap has minimum size, growing buffer if necessary
        /// </summary>
        private void EnsureGapSize(int minSize)
        {
            if (GapSize >= minSize)
                return;
            
            GrowCount++;
            
            // Calculate new capacity
            int currentLength = Length;
            int newCapacity = Math.Max(
                (int)(capacity * GROWTH_FACTOR),
                currentLength + minSize + MIN_GAP_SIZE
            );
            
            // Create new buffer
            var newBuffer = new char[newCapacity];
            
            // Copy text before gap
            if (gapStart > 0)
                Array.Copy(buffer, 0, newBuffer, 0, gapStart);
            
            // Copy text after gap
            int afterGapSize = capacity - gapEnd;
            if (afterGapSize > 0)
            {
                int newGapEnd = newCapacity - afterGapSize;
                Array.Copy(buffer, gapEnd, newBuffer, newGapEnd, afterGapSize);
                gapEnd = newGapEnd;
            }
            else
            {
                gapEnd = newCapacity;
            }
            
            buffer = newBuffer;
            capacity = newCapacity;
        }
        
        /// <summary>
        /// Insert character at current gap position
        /// </summary>
        public void Insert(char ch)
        {
            EnsureGapSize(1);
            buffer[gapStart] = ch;
            gapStart++;
            InsertCount++;
        }
        
        /// <summary>
        /// Insert string at current gap position
        /// </summary>
        public void Insert(string text)
        {
            if (string.IsNullOrEmpty(text))
                return;
                
            EnsureGapSize(text.Length);
            
            for (int i = 0; i < text.Length; i++)
            {
                buffer[gapStart + i] = text[i];
            }
            
            gapStart += text.Length;
            InsertCount++;
        }
        
        /// <summary>
        /// Insert character at specified position
        /// </summary>
        public void Insert(int position, char ch)
        {
            MoveGapTo(position);
            Insert(ch);
        }
        
        /// <summary>
        /// Insert string at specified position
        /// </summary>
        public void Insert(int position, string text)
        {
            MoveGapTo(position);
            Insert(text);
        }
        
        /// <summary>
        /// Delete character at current gap position (before gap)
        /// </summary>
        public void DeleteBefore()
        {
            if (gapStart > 0)
            {
                gapStart--;
                DeleteCount++;
            }
        }
        
        /// <summary>
        /// Delete character after current gap position
        /// </summary>
        public void DeleteAfter()
        {
            if (gapEnd < capacity)
            {
                gapEnd++;
                DeleteCount++;
            }
        }
        
        /// <summary>
        /// Delete character at specified position
        /// </summary>
        public void Delete(int position)
        {
            if (position < 0 || position >= Length)
                return;
                
            MoveGapTo(position);
            DeleteAfter();
        }
        
        /// <summary>
        /// Delete range of characters
        /// </summary>
        public void Delete(int position, int count)
        {
            if (position < 0 || position >= Length || count <= 0)
                return;
                
            count = Math.Min(count, Length - position);
            MoveGapTo(position);
            
            gapEnd = Math.Min(capacity, gapEnd + count);
            DeleteCount++;
        }
        
        /// <summary>
        /// Get character at specified position
        /// </summary>
        public char this[int index]
        {
            get
            {
                if (index < 0 || index >= Length)
                    throw new ArgumentOutOfRangeException(nameof(index));
                    
                if (index < gapStart)
                    return buffer[index];
                else
                    return buffer[index + GapSize];
            }
        }
        
        /// <summary>
        /// Get substring from buffer
        /// </summary>
        public string Substring(int startIndex, int length)
        {
            if (startIndex < 0 || startIndex >= Length)
                throw new ArgumentOutOfRangeException(nameof(startIndex));
                
            length = Math.Min(length, Length - startIndex);
            if (length <= 0)
                return string.Empty;
            
            var result = new StringBuilder(length);
            
            for (int i = 0; i < length; i++)
            {
                result.Append(this[startIndex + i]);
            }
            
            return result.ToString();
        }
        
        /// <summary>
        /// Get entire buffer content as string
        /// </summary>
        public override string ToString()
        {
            if (Length == 0)
                return string.Empty;
                
            var result = new StringBuilder(Length);
            
            // Text before gap
            if (gapStart > 0)
            {
                result.Append(buffer, 0, gapStart);
            }
            
            // Text after gap
            int afterGapStart = gapEnd;
            int afterGapLength = capacity - gapEnd;
            if (afterGapLength > 0)
            {
                result.Append(buffer, afterGapStart, afterGapLength);
            }
            
            return result.ToString();
        }
        
        /// <summary>
        /// Clear all content
        /// </summary>
        public void Clear()
        {
            gapStart = 0;
            gapEnd = capacity;
        }
        
        /// <summary>
        /// Find position of substring
        /// </summary>
        public int IndexOf(string value, int startIndex = 0)
        {
            if (string.IsNullOrEmpty(value))
                return -1;
                
            for (int i = startIndex; i <= Length - value.Length; i++)
            {
                bool found = true;
                for (int j = 0; j < value.Length; j++)
                {
                    if (this[i + j] != value[j])
                    {
                        found = false;
                        break;
                    }
                }
                if (found)
                    return i;
            }
            
            return -1;
        }
        
        /// <summary>
        /// Get performance statistics
        /// </summary>
        public string GetStats()
        {
            return $"GapBuffer Stats: Length={Length}, Capacity={Capacity}, " +
                   $"Inserts={InsertCount}, Deletes={DeleteCount}, " +
                   $"Moves={MoveCount}, Grows={GrowCount}";
        }
    }
}