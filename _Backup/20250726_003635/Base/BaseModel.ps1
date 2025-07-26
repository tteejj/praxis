# BaseModel.ps1 - Base class for all data models to standardize common properties

class BaseModel {
    [string]$Id
    [DateTime]$CreatedAt
    [DateTime]$UpdatedAt
    [bool]$Deleted = $false
    
    BaseModel() {
        $this.Id = [guid]::NewGuid().ToString()
        $this.CreatedAt = Get-Date
        $this.UpdatedAt = $this.CreatedAt
    }
    
    BaseModel([string]$id) {
        $this.Id = $id
        $this.CreatedAt = Get-Date
        $this.UpdatedAt = $this.CreatedAt
    }
    
    # Method to update the UpdatedAt timestamp when model is modified
    [void] MarkAsUpdated() {
        $this.UpdatedAt = Get-Date
    }
    
    # Method to soft delete the model
    [void] SoftDelete() {
        $this.Deleted = $true
        $this.MarkAsUpdated()
    }
    
    # Method to restore a soft deleted model
    [void] Restore() {
        $this.Deleted = $false
        $this.MarkAsUpdated()
    }
    
    # Helper method to check if model is active (not deleted)
    [bool] IsActive() {
        return -not $this.Deleted
    }
    
    # Helper method to get age of the model
    [TimeSpan] GetAge() {
        return (Get-Date) - $this.CreatedAt
    }
    
    # Helper method to get time since last update
    [TimeSpan] GetTimeSinceUpdate() {
        return (Get-Date) - $this.UpdatedAt
    }
}