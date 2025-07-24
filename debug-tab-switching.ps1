#!/usr/bin/env pwsh
# Debug tab switching - add extra logging

# Backup original files
Copy-Item "Screens/TextEditorScreen.ps1" "Screens/TextEditorScreen.ps1.backup" -Force
Copy-Item "Components/TabContainer.ps1" "Components/TabContainer.ps1.backup" -Force

# Add debug logging to TextEditorScreen
$textEditorContent = Get-Content "Screens/TextEditorScreen.ps1" -Raw
$textEditorContent = $textEditorContent -replace 'return \$false  # Let parent handle 1-6 for tab switching', @'
if ($global:Logger) {
                    $global:Logger.Debug("TextEditorScreen: RETURNING FALSE for key '$($keyInfo.Key)' - should bubble up")
                }
                return $false  # Let parent handle 1-6 for tab switching
'@
Set-Content "Screens/TextEditorScreen.ps1" $textEditorContent

# Add debug logging to TabContainer ActivateTab
$tabContainerContent = Get-Content "Components/TabContainer.ps1" -Raw
$tabContainerContent = $tabContainerContent -replace 'if \(\$global:Logger\) \{[\s\S]*?\$global:Logger\.Debug\("TabContainer\.ActivateTab: Switching from tab \$\(\$this\.ActiveTabIndex\) to tab \$index"\)[\s\S]*?\}', @'
if ($global:Logger) {
            $global:Logger.Debug("TabContainer.ActivateTab: ABOUT TO SWITCH from tab $($this.ActiveTabIndex) to tab $index")
            $global:Logger.Debug("TabContainer.ActivateTab: Current active tab: $($this.Tabs[$this.ActiveTabIndex].Title)")
            $global:Logger.Debug("TabContainer.ActivateTab: Target tab: $($this.Tabs[$index].Title)")
        }
'@
Set-Content "Components/TabContainer.ps1" $tabContainerContent

Write-Host "Added debug logging. Run PRAXIS and test tab switching." -ForegroundColor Green
Write-Host "1. Start PRAXIS" -ForegroundColor Yellow  
Write-Host "2. Press 4 to go to Editor tab" -ForegroundColor Yellow
Write-Host "3. Press ESC to enter command mode" -ForegroundColor Yellow
Write-Host "4. Press 1 to switch tabs" -ForegroundColor Yellow
Write-Host "5. Check the logs to see exactly what happens" -ForegroundColor Yellow
Write-Host ""
Write-Host "To restore original files after testing:" -ForegroundColor Cyan
Write-Host "  Copy-Item 'Screens/TextEditorScreen.ps1.backup' 'Screens/TextEditorScreen.ps1' -Force" -ForegroundColor Cyan
Write-Host "  Copy-Item 'Components/TabContainer.ps1.backup' 'Components/TabContainer.ps1' -Force" -ForegroundColor Cyan