# SimpleShortcutHandler.ps1 - Direct keyboard shortcuts via EventBus

class SimpleShortcutHandler {
    hidden [EventBus]$EventBus
    hidden [Logger]$Logger
    
    [void] Initialize([ServiceContainer]$container) {
        $this.EventBus = $container.GetService('EventBus')
        $this.Logger = $container.GetService('Logger')
    }
    
    [bool] HandleKeyPress([System.ConsoleKeyInfo]$keyInfo, [string]$currentScreen) {
        # Only handle character keys when no modifiers are pressed
        if ($keyInfo.Modifiers -ne [System.ConsoleModifiers]::None) {
            return $false
        }
        
        $char = [char]::ToLower($keyInfo.KeyChar)
        
        # Handle shortcuts based on current screen
        switch ($currentScreen) {
            "ProjectsScreen" {
                switch ($char) {
                    'n' {
                        $this.PublishCommand('NewProject', 'ProjectsScreen')
                        return $true
                    }
                    'e' {
                        $this.PublishCommand('EditProject', 'ProjectsScreen')
                        return $true
                    }
                    'd' {
                        $this.PublishCommand('DeleteProject', 'ProjectsScreen')
                        return $true
                    }
                    'r' {
                        $this.PublishCommand('RefreshProjects', 'ProjectsScreen')
                        return $true
                    }
                    'v' {
                        $this.PublishCommand('ViewProject', 'ProjectsScreen')
                        return $true
                    }
                }
            }
            "TaskScreen" {
                switch ($char) {
                    'n' {
                        $this.PublishCommand('NewTask', 'TaskScreen')
                        return $true
                    }
                    'e' {
                        $this.PublishCommand('EditTask', 'TaskScreen')
                        return $true
                    }
                    'd' {
                        $this.PublishCommand('DeleteTask', 'TaskScreen')
                        return $true
                    }
                    'r' {
                        $this.PublishCommand('RefreshTasks', 'TaskScreen')
                        return $true
                    }
                }
            }
        }
        
        return $false
    }
    
    hidden [void] PublishCommand([string]$command, [string]$target) {
        if ($this.Logger) {
            $this.Logger.Debug("SimpleShortcutHandler: Publishing command $command for $target")
        }
        
        if ($this.EventBus) {
            $this.EventBus.Publish([EventNames]::CommandExecuted, @{
                Command = $command
                Target = $target
            })
        }
    }
}