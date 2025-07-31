# Enhanced Form Example - Complete application demonstrating all new features
# Shows how to build a practical application with the enhanced SpeedTUI

# Load the enhanced components
. "$PSScriptRoot/../Core/Internal/PerformanceCore.ps1"
. "$PSScriptRoot/../Services/EnhancedThemeManager.ps1" 
. "$PSScriptRoot/../Core/EnhancedComponent.ps1"
. "$PSScriptRoot/../Core/EventManager.ps1"
. "$PSScriptRoot/../Utils/DevHelpers.ps1"

<#
.SYNOPSIS
Complete form application using enhanced SpeedTUI

.DESCRIPTION
This example demonstrates:
- Building a complete user registration form
- Theme switching and customization
- Event-driven form validation
- Automatic layout management
- Performance monitoring
- Error handling and user feedback
- Development and debugging tools

.EXAMPLE
./EnhancedFormExample.ps1
#>

# Application state
$global:FormData = @{
    FirstName = ""
    LastName = ""
    Email = ""
    Theme = "default"
    IsValid = $false
}

$global:ValidationErrors = @{}

function Initialize-Application {
    Write-Host "=== Enhanced SpeedTUI Form Application ===" -ForegroundColor Cyan
    Write-Host "Complete user registration form with validation" -ForegroundColor Green
    Write-Host ""
    
    # Start performance monitoring
    Start-SpeedTUIPerformanceMonitoring
    
    # Set initial theme
    Set-SpeedTUITheme "amber"
    
    # Initialize event system
    Setup-EventHandlers
    
    Write-Host "Application initialized successfully!" -ForegroundColor Green
}

function Setup-EventHandlers {
    $events = Get-EventManager
    
    # Form submission event
    $events.On("form.submit") { param($eventData)
        Write-Host "`nForm submission received..." -ForegroundColor Yellow
        
        $formData = $eventData.Get("FormData")
        if (Validate-Form $formData) {
            Process-Registration $formData
        } else {
            Show-ValidationErrors
        }
    }
    
    # Theme change event
    $events.On("theme.changed") { param($eventData)
        $newTheme = $eventData.Get("Theme")
        Write-Host "Theme changed to: $newTheme" -ForegroundColor Magenta
        Set-SpeedTUITheme $newTheme
        Fire-Event "ui.refresh" @{ Reason = "ThemeChanged" }
    }
    
    # Field validation events
    $events.On("field.changed") { param($eventData)
        $fieldName = $eventData.Get("FieldName")
        $value = $eventData.Get("Value")
        
        Validate-Field $fieldName $value
        Update-FormState
    }
    
    # UI refresh event
    $events.On("ui.refresh") { param($eventData)
        $reason = $eventData.Get("Reason")
        Write-Host "UI refresh requested: $reason" -ForegroundColor Blue
        Refresh-FormDisplay
    }
    
    Write-Host "Event handlers configured" -ForegroundColor Gray
}

function Create-FormComponents {
    Write-Host "Creating form components..." -ForegroundColor Yellow
    
    # Create form title
    $title = [EnhancedComponent]::new()
    $title.Id = "title"
    $title.SetPosition(2, 1)
    $title.SetSize(50, 1)
    $title.SetTheme("amber")
    $title.SetColor("primary")
    
    # Create input labels and fields
    $firstNameLabel = [EnhancedComponent]::new()
    $firstNameLabel.Id = "firstNameLabel"
    $firstNameLabel.SetPosition(5, 4)
    $firstNameLabel.SetSize(15, 1)
    $firstNameLabel.SetTheme("amber")
    $firstNameLabel.SetColor("text")
    
    $firstNameInput = [EnhancedComponent]::new()
    $firstNameInput.Id = "firstNameInput"
    $firstNameInput.SetPosition(20, 4)
    $firstNameInput.SetSize(25, 1)
    $firstNameInput.SetTheme("amber")
    $firstNameInput.SetColor("primary")
    $firstNameInput.SetSizeConstraints(10, 1, 50, 1)
    
    $lastNameLabel = [EnhancedComponent]::new()
    $lastNameLabel.Id = "lastNameLabel"
    $lastNameLabel.SetPosition(5, 6)
    $lastNameLabel.SetSize(15, 1)
    $lastNameLabel.SetTheme("amber")
    $lastNameLabel.SetColor("text")
    
    $lastNameInput = [EnhancedComponent]::new()
    $lastNameInput.Id = "lastNameInput"
    $lastNameInput.SetPosition(20, 6)
    $lastNameInput.SetSize(25, 1)
    $lastNameInput.SetTheme("amber")
    $lastNameInput.SetColor("primary")
    $lastNameInput.SetSizeConstraints(10, 1, 50, 1)
    
    $emailLabel = [EnhancedComponent]::new()
    $emailLabel.Id = "emailLabel"
    $emailLabel.SetPosition(5, 8)
    $emailLabel.SetSize(15, 1)
    $emailLabel.SetTheme("amber")
    $emailLabel.SetColor("text")
    
    $emailInput = [EnhancedComponent]::new()
    $emailInput.Id = "emailInput"
    $emailInput.SetPosition(20, 8)
    $emailInput.SetSize(30, 1)
    $emailInput.SetTheme("amber")
    $emailInput.SetColor("primary")
    $emailInput.SetSizeConstraints(15, 1, 60, 1)
    
    # Create theme selection buttons
    $matrixThemeBtn = [EnhancedComponent]::new()
    $matrixThemeBtn.Id = "themeMatrix"
    $matrixThemeBtn.SetPosition(5, 11)
    $matrixThemeBtn.SetSize(12, 3)
    $matrixThemeBtn.SetTheme("matrix")
    $matrixThemeBtn.SetColor("primary")
    
    $amberThemeBtn = [EnhancedComponent]::new()
    $amberThemeBtn.Id = "themeAmber"
    $amberThemeBtn.SetPosition(20, 11)
    $amberThemeBtn.SetSize(12, 3)
    $amberThemeBtn.SetTheme("amber")
    $amberThemeBtn.SetColor("primary")
    
    $electricThemeBtn = [EnhancedComponent]::new()
    $electricThemeBtn.Id = "themeElectric"
    $electricThemeBtn.SetPosition(35, 11)
    $electricThemeBtn.SetSize(12, 3)
    $electricThemeBtn.SetTheme("electric")
    $electricThemeBtn.SetColor("primary")
    
    # Create action buttons
    $submitBtn = [EnhancedComponent]::new()
    $submitBtn.Id = "submitBtn"
    $submitBtn.SetSize(15, 3)
    $submitBtn.SetTheme("amber")
    $submitBtn.SetColor("success")
    
    $clearBtn = [EnhancedComponent]::new()
    $clearBtn.Id = "clearBtn"
    $clearBtn.SetSize(15, 3)
    $clearBtn.SetTheme("amber")
    $clearBtn.SetColor("warning")
    
    $debugBtn = [EnhancedComponent]::new()
    $debugBtn.Id = "debugBtn"
    $debugBtn.SetSize(15, 3)
    $debugBtn.SetTheme("amber")
    $debugBtn.SetColor("info")
    
    # Arrange action buttons horizontally
    @($submitBtn, $clearBtn, $debugBtn) | Arrange-Horizontally -StartX 5 -StartY 16 -Spacing 5
    
    # Store components globally for access
    $global:FormComponents = @{
        Title = $title
        FirstNameLabel = $firstNameLabel
        FirstNameInput = $firstNameInput
        LastNameLabel = $lastNameLabel
        LastNameInput = $lastNameInput
        EmailLabel = $emailLabel
        EmailInput = $emailInput
        MatrixTheme = $matrixThemeBtn
        AmberTheme = $amberThemeBtn
        ElectricTheme = $electricThemeBtn
        Submit = $submitBtn
        Clear = $clearBtn
        Debug = $debugBtn
    }
    
    Write-Host "Form components created and arranged" -ForegroundColor Green
}

function Simulate-FormInteraction {
    Write-Host "`nSimulating form interaction..." -ForegroundColor Yellow
    
    # Simulate user input
    Write-Host "Simulating user typing in form fields..." -ForegroundColor Gray
    
    # First name input
    Fire-Event "field.changed" @{
        FieldName = "FirstName"
        Value = "John"
        ComponentId = "firstNameInput"
    }
    
    Start-Sleep -Milliseconds 500
    
    # Last name input
    Fire-Event "field.changed" @{
        FieldName = "LastName"
        Value = "Doe"
        ComponentId = "lastNameInput"
    }
    
    Start-Sleep -Milliseconds 500
    
    # Email input (invalid first)
    Fire-Event "field.changed" @{
        FieldName = "Email"
        Value = "john.invalid"
        ComponentId = "emailInput"
    }
    
    Start-Sleep -Milliseconds 500
    
    # Correct email
    Fire-Event "field.changed" @{
        FieldName = "Email"
        Value = "john.doe@example.com"
        ComponentId = "emailInput"
    }
    
    # Theme changes
    Write-Host "Simulating theme changes..." -ForegroundColor Gray
    Start-Sleep -Milliseconds 1000
    
    Fire-Event "theme.changed" @{ Theme = "matrix"; Source = "themeMatrix" }
    Start-Sleep -Milliseconds 1000
    
    Fire-Event "theme.changed" @{ Theme = "electric"; Source = "themeElectric" }
    Start-Sleep -Milliseconds 1000
    
    Fire-Event "theme.changed" @{ Theme = "amber"; Source = "themeAmber" }
    
    # Form submission
    Write-Host "Simulating form submission..." -ForegroundColor Gray
    Start-Sleep -Milliseconds 1000
    
    Fire-Event "form.submit" @{
        FormData = $global:FormData
        Source = "submitBtn"
    }
}

function Validate-Field($fieldName, $value) {
    $global:ValidationErrors.Remove($fieldName)  # Clear previous error
    
    switch ($fieldName) {
        "FirstName" {
            $global:FormData.FirstName = $value
            if ([string]::IsNullOrWhiteSpace($value)) {
                $global:ValidationErrors[$fieldName] = "First name is required"
            } elseif ($value.Length -lt 2) {
                $global:ValidationErrors[$fieldName] = "First name must be at least 2 characters"
            }
        }
        "LastName" {
            $global:FormData.LastName = $value
            if ([string]::IsNullOrWhiteSpace($value)) {
                $global:ValidationErrors[$fieldName] = "Last name is required"
            } elseif ($value.Length -lt 2) {
                $global:ValidationErrors[$fieldName] = "Last name must be at least 2 characters"
            }
        }
        "Email" {
            $global:FormData.Email = $value
            if ([string]::IsNullOrWhiteSpace($value)) {
                $global:ValidationErrors[$fieldName] = "Email is required"
            } elseif ($value -notmatch "^[^@]+@[^@]+\.[^@]+$") {
                $global:ValidationErrors[$fieldName] = "Please enter a valid email address"
            }
        }
    }
    
    # Show validation result
    if ($global:ValidationErrors.ContainsKey($fieldName)) {
        Write-Host "  ❌ $fieldName`: $($global:ValidationErrors[$fieldName])" -ForegroundColor Red
    } else {
        Write-Host "  ✅ $fieldName`: Valid" -ForegroundColor Green
    }
}

function Validate-Form($formData) {
    # Validate all fields
    Validate-Field "FirstName" $formData.FirstName
    Validate-Field "LastName" $formData.LastName
    Validate-Field "Email" $formData.Email
    
    return $global:ValidationErrors.Count -eq 0
}

function Update-FormState {
    $global:FormData.IsValid = $global:ValidationErrors.Count -eq 0
    
    if ($global:FormData.IsValid) {
        Write-Host "  ✅ Form is valid and ready for submission" -ForegroundColor Green
    } else {
        Write-Host "  ❌ Form has validation errors" -ForegroundColor Red
    }
}

function Show-ValidationErrors {
    if ($global:ValidationErrors.Count -gt 0) {
        Write-Host "`nValidation Errors:" -ForegroundColor Red
        foreach ($error in $global:ValidationErrors.GetEnumerator()) {
            Write-Host "  • $($error.Key): $($error.Value)" -ForegroundColor Yellow
        }
    }
}

function Process-Registration($formData) {
    Write-Host "`n🎉 Registration Successful!" -ForegroundColor Green
    Write-Host "Name: $($formData.FirstName) $($formData.LastName)" -ForegroundColor Cyan
    Write-Host "Email: $($formData.Email)" -ForegroundColor Cyan
    Write-Host "Theme: $($formData.Theme)" -ForegroundColor Cyan
    
    # Fire success event
    Fire-Event "registration.success" @{
        User = $formData
        Timestamp = [DateTime]::Now
    }
}

function Refresh-FormDisplay {
    Write-Host "Refreshing form display..." -ForegroundColor Blue
    # In a real application, this would update the visual display
    # For demo purposes, we'll just show the current state
    
    Write-Host "`nCurrent Form State:" -ForegroundColor Magenta
    Write-Host "  First Name: '$($global:FormData.FirstName)'" -ForegroundColor Gray
    Write-Host "  Last Name: '$($global:FormData.LastName)'" -ForegroundColor Gray
    Write-Host "  Email: '$($global:FormData.Email)'" -ForegroundColor Gray
    Write-Host "  Theme: '$($global:FormData.Theme)'" -ForegroundColor Gray
    Write-Host "  Valid: $($global:FormData.IsValid)" -ForegroundColor Gray
}

function Show-ComponentLayout {
    Write-Host "`n=== Form Layout Visualization ===" -ForegroundColor Cyan
    
    # Show ASCII representation of the form
    Write-Host @"
┌─────────────────────────────────────────────────────────┐
│                Registration Form                        │
├─────────────────────────────────────────────────────────┤
│                                                         │
│    First Name: [____________________]                   │
│                                                         │  
│    Last Name:  [____________________]                   │
│                                                         │
│    Email:      [_________________________]              │
│                                                         │
│                                                         │
│    [Matrix]    [Amber]     [Electric]                   │
│                                                         │
│                                                         │
│    [Submit]    [Clear]     [Debug]                      │
│                                                         │
└─────────────────────────────────────────────────────────┘
"@ -ForegroundColor Green
    
    Write-Host "`nComponent Positions:" -ForegroundColor Yellow
    foreach ($comp in $global:FormComponents.GetEnumerator()) {
        $component = $comp.Value
        Write-Host "  $($comp.Key): $($component.X),$($component.Y) (${($component.Width)}x$($component.Height)) - Theme: $($component.ThemeName)" -ForegroundColor Gray
    }
}

function Show-ApplicationStats {
    Write-Host "`n=== Application Statistics ===" -ForegroundColor Cyan
    
    # Event statistics
    $events = Get-EventManager
    $eventStats = $events.GetStats()
    Write-Host "Event System:" -ForegroundColor Yellow
    Write-Host "  Events Fired: $($eventStats.EventsFired)" -ForegroundColor Gray
    Write-Host "  Handlers Executed: $($eventStats.HandlersExecuted)" -ForegroundColor Gray
    Write-Host "  Registered Events: $($eventStats.RegisteredEvents)" -ForegroundColor Gray
    Write-Host "  Total Handlers: $($eventStats.TotalHandlers)" -ForegroundColor Gray
    
    # Theme statistics
    $themeManager = Get-ThemeManager
    $themeStats = $themeManager.GetPerformanceStats()
    Write-Host "`nTheme System:" -ForegroundColor Yellow
    Write-Host "  Available Themes: $($themeStats.RegisteredThemes)" -ForegroundColor Gray
    Write-Host "  Cache Size: $($themeStats.CacheSize)" -ForegroundColor Gray
    Write-Host "  Current Theme: $($themeManager.GetCurrentTheme())" -ForegroundColor Gray
    
    # Component statistics
    Write-Host "`nComponents:" -ForegroundColor Yellow
    Write-Host "  Total Components: $($global:FormComponents.Count)" -ForegroundColor Gray
    
    $totalRenders = 0
    foreach ($comp in $global:FormComponents.Values) {
        $stats = $comp.GetPerformanceStats()
        $totalRenders += $stats.RenderCount
    }
    Write-Host "  Total Renders: $totalRenders" -ForegroundColor Gray
    
    # Show performance report
    Write-Host "`nPerformance Report:" -ForegroundColor Yellow
    Show-SpeedTUIPerformanceReport
}

function Show-DevelopmentHelpers {
    Write-Host "`n=== Development Helper Demonstration ===" -ForegroundColor Cyan
    
    # Show examples
    Write-Host "Available examples:" -ForegroundColor Yellow
    $examples = @("button", "form", "theming", "layout", "events", "debugging")
    foreach ($example in $examples) {
        Write-Host "  Show-SpeedTUIExample '$example'" -ForegroundColor Gray
    }
    
    # Show component inspection
    Write-Host "`nComponent Inspection Example:" -ForegroundColor Yellow
    Write-Host "Inspecting Submit Button..." -ForegroundColor Gray
    $submitBtn = $global:FormComponents.Submit
    $stats = $submitBtn.GetPerformanceStats()
    Write-Host "  ID: $($stats.Id)" -ForegroundColor Gray
    Write-Host "  Type: $($stats.Type)" -ForegroundColor Gray
    Write-Host "  Position: $($stats.Position)" -ForegroundColor Gray
    Write-Host "  Size: $($stats.Size)" -ForegroundColor Gray
    Write-Host "  Theme: $($stats.Theme)" -ForegroundColor Gray
    Write-Host "  Render Count: $($stats.RenderCount)" -ForegroundColor Gray
    
    # Show installation validation
    Write-Host "`nSystem Validation:" -ForegroundColor Yellow
    Write-Host "Run 'Test-SpeedTUIInstallation' to validate your setup" -ForegroundColor Gray
}

# Main execution
function Main {
    try {
        Initialize-Application
        Create-FormComponents
        Show-ComponentLayout
        Simulate-FormInteraction
        Show-ApplicationStats
        Show-DevelopmentHelpers
        
        Write-Host "`n=== Enhanced Form Example Complete ===" -ForegroundColor Cyan
        Write-Host "This example demonstrated:" -ForegroundColor Green
        Write-Host "  ✓ Complete form application with validation" -ForegroundColor Gray
        Write-Host "  ✓ Event-driven architecture" -ForegroundColor Gray
        Write-Host "  ✓ Multiple themes with live switching" -ForegroundColor Gray
        Write-Host "  ✓ Automatic component layout management" -ForegroundColor Gray
        Write-Host "  ✓ Performance monitoring and statistics" -ForegroundColor Gray
        Write-Host "  ✓ Comprehensive development tools" -ForegroundColor Gray
        Write-Host "  ✓ Error handling and validation" -ForegroundColor Gray
        
    } catch {
        Write-Host "Error in application: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "Stack Trace: $($_.ScriptStackTrace)" -ForegroundColor Red
    }
}

# Run the application
Main