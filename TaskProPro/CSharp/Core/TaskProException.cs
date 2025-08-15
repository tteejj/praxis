using System;

namespace TaskPro.Core
{
    /// <summary>
    /// Base exception for TaskProPro application errors
    /// </summary>
    public class TaskProException : Exception
    {
        public TaskProException(string message) : base(message) { }
        public TaskProException(string message, Exception innerException) : base(message, innerException) { }
    }
    
    /// <summary>
    /// Exception for data persistence operations
    /// </summary>
    public class DataPersistenceException : TaskProException
    {
        public DataPersistenceException(string message) : base($"Data persistence error: {message}") { }
        public DataPersistenceException(string message, Exception innerException) : base($"Data persistence error: {message}", innerException) { }
    }
    
    /// <summary>
    /// Exception for task validation errors
    /// </summary>
    public class TaskValidationException : TaskProException
    {
        public TaskValidationException(string message) : base($"Task validation error: {message}") { }
    }
    
    /// <summary>
    /// Exception for UI rendering errors
    /// </summary>
    public class RenderingException : TaskProException
    {
        public RenderingException(string message) : base($"Rendering error: {message}") { }
        public RenderingException(string message, Exception innerException) : base($"Rendering error: {message}", innerException) { }
    }
    
    /// <summary>
    /// Exception for input handling errors
    /// </summary>
    public class InputHandlingException : TaskProException
    {
        public InputHandlingException(string message) : base($"Input handling error: {message}") { }
        public InputHandlingException(string message, Exception innerException) : base($"Input handling error: {message}", innerException) { }
    }
}