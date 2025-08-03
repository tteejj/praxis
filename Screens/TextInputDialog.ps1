# TextInputDialog.ps1 - Simple dialog for text input using UnifiedDialog

class TextInputDialog : UnifiedDialog {
    [string]$Prompt
    [scriptblock]$OnSubmit = {}
    
    TextInputDialog([string]$prompt) : base("Input", 50, 8) {
        $this.Prompt = $prompt
        $this.InitializeFields("")
    }
    
    TextInputDialog([string]$prompt, [string]$defaultValue) : base("Input", 50, 8) {
        $this.Prompt = $prompt
        $this.InitializeFields($defaultValue)
    }
    
    [void] InitializeFields([string]$defaultValue) {
        # Add a single input field using simplified UnifiedDialog API
        $this.AddField("input", $this.Prompt, $defaultValue)
        
        # Set button labels
        $this.SetButtons("OK", "Cancel")
        
        # Set up submit handler with proper closure
        $dialog = $this
        $this.OnSubmit = { $dialog.SubmitInput() }.GetNewClosure()
    }
    
    [void] SubmitInput() {
        $inputValue = $this.GetFieldValue("input")
        
        # Call the submit callback if set
        if ($this.OnSubmit) {
            & $this.OnSubmit $inputValue
        }
        
        # Close dialog
        $this.Close()
    }
    
    # Helper method for compatibility
    [string] GetValue() {
        return $this.GetFieldValue("input")
    }
}