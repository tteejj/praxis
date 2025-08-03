# TestProfileSystem.ps1 - Test the export profile system functionality

# Load required classes
. "$PSScriptRoot\Services\ConfigurationService.ps1"
. "$PSScriptRoot\Services\ExportProfileService.ps1"

function Test-ProfileSystem {
    Write-Host "Testing Export Profile System..." -ForegroundColor Yellow
    Write-Host "=================================" -ForegroundColor Yellow
    Write-Host ""
    
    # Initialize services
    $configService = [ConfigurationService]::new()
    $profileService = [ExportProfileService]::new($configService)
    
    try {
        # Test 1: Create test profiles
        Write-Host "Test 1: Creating test profiles..." -ForegroundColor Cyan
        
        $testFields1 = @("RequestDate", "SiteName", "TPName")
        $result1 = $profileService.SaveProfile("Test Basic", $testFields1, "CSV", "Basic information for testing")
        Write-Host "  ✓ Created 'Test Basic' profile: $($result1.Success)" -ForegroundColor Green
        
        $testFields2 = @("SiteName", "SiteAddress", "SiteCity", "SiteState")
        $result2 = $profileService.SaveProfile("Test Location", $testFields2, "JSON", "Location data for testing")
        Write-Host "  ✓ Created 'Test Location' profile: $($result2.Success)" -ForegroundColor Green
        
        # Test 2: List profiles
        Write-Host ""
        Write-Host "Test 2: Listing profiles..." -ForegroundColor Cyan
        
        $profiles = $profileService.GetAllProfiles()
        $profileNames = $profileService.GetProfileNames($true)
        
        Write-Host "  Found $($profiles.Count) profiles:" -ForegroundColor White
        foreach ($name in $profileNames) {
            $profile = $profiles[$name]
            Write-Host "    • $name ($($profile.SelectedFields.Count) fields, $($profile.ExportFormat))" -ForegroundColor Gray
        }
        
        # Test 3: Load and use profile
        Write-Host ""
        Write-Host "Test 3: Loading profile..." -ForegroundColor Cyan
        
        $loadResult = $profileService.LoadProfile("Test Basic")
        if ($loadResult.Success) {
            $profile = $loadResult.Profile
            Write-Host "  ✓ Loaded profile successfully" -ForegroundColor Green
            Write-Host "    Fields: $($profile.SelectedFields -join ', ')" -ForegroundColor Gray
            Write-Host "    Format: $($profile.ExportFormat)" -ForegroundColor Gray
            Write-Host "    Use count: $($profile.UseCount)" -ForegroundColor Gray
        } else {
            Write-Host "  ✗ Failed to load profile: $($loadResult.Message)" -ForegroundColor Red
        }
        
        # Test 4: Profile info
        Write-Host ""
        Write-Host "Test 4: Getting profile info..." -ForegroundColor Cyan
        
        $infoResult = $profileService.GetProfileInfo("Test Location")
        if ($infoResult.Success) {
            Write-Host "  ✓ Profile info retrieved" -ForegroundColor Green
            Write-Host "    Name: $($infoResult.Name)" -ForegroundColor Gray
            Write-Host "    Field count: $($infoResult.FieldCount)" -ForegroundColor Gray
            Write-Host "    Created: $($infoResult.CreatedDate)" -ForegroundColor Gray
        } else {
            Write-Host "  ✗ Failed to get profile info: $($infoResult.Message)" -ForegroundColor Red
        }
        
        # Test 5: Create default profiles
        Write-Host ""
        Write-Host "Test 5: Creating default profiles..." -ForegroundColor Cyan
        
        $availableFields = @(
            "RequestDate", "SiteName", "TPName", "AuditorName", "AuditType",
            "TPEmailAddress", "TPPhoneNumber", "CorporateContact", "CorporateContactEmail",
            "SiteAddress", "SiteCity", "SiteState", "SiteZip", "SiteCountry",
            "CASNumber", "AssetName", "SerialNumber", "ModelNumber", "ManufacturerName",
            "ComplianceDate", "NextInspectionDate", "CertificationNumber", "InspectorName"
        )
        
        $profileService.CreateDefaultProfiles($availableFields)
        
        $newProfileCount = $profileService.GetProfileNames($false).Count
        Write-Host "  ✓ Default profiles created. Total profiles: $newProfileCount" -ForegroundColor Green
        
        # Test 6: Export/Import profiles
        Write-Host ""
        Write-Host "Test 6: Testing export/import..." -ForegroundColor Cyan
        
        $exportPath = Join-Path $PSScriptRoot "_Config\test_profiles_export.json"
        $exportResult = $profileService.ExportProfilesToFile($exportPath)
        
        if ($exportResult.Success) {
            Write-Host "  ✓ Profiles exported to: $exportPath" -ForegroundColor Green
            
            # Test import (with new instance to simulate fresh start)
            $newConfigService = [ConfigurationService]::new()
            $newProfileService = [ExportProfileService]::new($newConfigService)
            
            $importResult = $newProfileService.ImportProfilesFromFile($exportPath, $true)
            if ($importResult.Success) {
                Write-Host "  ✓ Profiles imported successfully" -ForegroundColor Green
                Write-Host "    Imported: $($importResult.ImportedCount), Skipped: $($importResult.SkippedCount)" -ForegroundColor Gray
            } else {
                Write-Host "  ✗ Import failed: $($importResult.Message)" -ForegroundColor Red
            }
            
            # Clean up test file
            if (Test-Path $exportPath) {
                Remove-Item $exportPath -Force
                Write-Host "  ✓ Cleaned up test export file" -ForegroundColor Green
            }
        } else {
            Write-Host "  ✗ Export failed: $($exportResult.Message)" -ForegroundColor Red
        }
        
        # Test 7: Delete test profiles
        Write-Host ""
        Write-Host "Test 7: Cleaning up test profiles..." -ForegroundColor Cyan
        
        $deleteResult1 = $profileService.DeleteProfile("Test Basic")
        $deleteResult2 = $profileService.DeleteProfile("Test Location")
        
        Write-Host "  ✓ Deleted 'Test Basic': $($deleteResult1.Success)" -ForegroundColor Green
        Write-Host "  ✓ Deleted 'Test Location': $($deleteResult2.Success)" -ForegroundColor Green
        
        # Final profile count
        $finalCount = $profileService.GetProfileNames($false).Count
        Write-Host "  Final profile count: $finalCount" -ForegroundColor Gray
        
        Write-Host ""
        Write-Host "All tests completed successfully!" -ForegroundColor Green
        return $true
        
    } catch {
        Write-Host ""
        Write-Host "Test failed with error: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "Stack trace: $($_.ScriptStackTrace)" -ForegroundColor Red
        return $false
    }
}

function Test-ComponentsExist {
    Write-Host "Checking required components..." -ForegroundColor Yellow
    Write-Host "===============================" -ForegroundColor Yellow
    Write-Host ""
    
    $components = @(
        "$PSScriptRoot\Services\ExportProfileService.ps1",
        "$PSScriptRoot\Components\SimpleFileTree.ps1", 
        "$PSScriptRoot\Screens\ProfileSelectionDialog.ps1",
        "$PSScriptRoot\RunProfileExport.ps1"
    )
    
    $allExist = $true
    
    foreach ($component in $components) {
        $exists = Test-Path $component
        $status = if ($exists) { "✓" } else { "✗" }
        $color = if ($exists) { "Green" } else { "Red" }
        
        Write-Host "  $status $(Split-Path $component -Leaf)" -ForegroundColor $color
        
        if (-not $exists) {
            $allExist = $false
        }
    }
    
    Write-Host ""
    if ($allExist) {
        Write-Host "All components exist!" -ForegroundColor Green
    } else {
        Write-Host "Some components are missing!" -ForegroundColor Red
    }
    
    return $allExist
}

# Run tests
Write-Host "ExcelDataFlow Profile System Test Suite" -ForegroundColor Magenta
Write-Host "=======================================" -ForegroundColor Magenta
Write-Host ""

$componentsExist = Test-ComponentsExist
Write-Host ""

if ($componentsExist) {
    $profileTestsPass = Test-ProfileSystem
    
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Magenta
    if ($profileTestsPass) {
        Write-Host "  ✅ ALL TESTS PASSED!" -ForegroundColor Green
        Write-Host "  Profile system is ready for use." -ForegroundColor Green
    } else {
        Write-Host "  ❌ SOME TESTS FAILED!" -ForegroundColor Red
        Write-Host "  Check the error messages above." -ForegroundColor Red
    }
    Write-Host "========================================" -ForegroundColor Magenta
} else {
    Write-Host "Cannot run profile tests - missing components!" -ForegroundColor Red
    Write-Host "Make sure all profile system files are created." -ForegroundColor Red
}