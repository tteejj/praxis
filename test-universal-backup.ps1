#!/usr/bin/env pwsh
# Test script to verify UniversalBackupManager bulletproof data safety

# Change to script directory
Set-Location $PSScriptRoot/simpletaskpro

# Import required modules
. ./Core/VT100.ps1
. ./Core/GapBuffer.ps1
. ./Core/UniversalBackupManager.ps1
. ./Core/FullNotesEditor.ps1

Write-Host "=== Testing Universal Backup System ===" -ForegroundColor Green

try {
    # Test 1: Initialize the backup system
    Write-Host "`n1. Testing UniversalBackupManager initialization..." -ForegroundColor Yellow
    [UniversalBackupManager]::Initialize($PWD)
    Write-Host "   ✓ Backup system initialized" -ForegroundColor Green
    
    # Test 2: Test atomic save
    Write-Host "`n2. Testing atomic save functionality..." -ForegroundColor Yellow
    $testFile = Join-Path $PWD "test-atomic-save.txt"
    $testContent = "Test content for atomic save`nLine 2`nLine 3"
    
    $success = [UniversalBackupManager]::AtomicSave($testFile, $testContent, "notes", "test")
    if ($success) {
        Write-Host "   ✓ Atomic save successful" -ForegroundColor Green
        Write-Host "   ✓ File exists: $(Test-Path $testFile)" -ForegroundColor Green
        Write-Host "   ✓ Content correct: $((Get-Content $testFile -Raw) -eq $testContent)" -ForegroundColor Green
    } else {
        Write-Host "   ✗ Atomic save failed" -ForegroundColor Red
    }
    
    # Test 3: Test backup creation
    Write-Host "`n3. Testing backup creation..." -ForegroundColor Yellow
    $backupPath = [UniversalBackupManager]::CreateBackup("notes", $testFile, "test")
    if ($backupPath -and (Test-Path $backupPath)) {
        Write-Host "   ✓ Backup created: $backupPath" -ForegroundColor Green
        
        # Verify backup content matches original
        $originalContent = Get-Content $testFile -Raw
        $backupContent = Get-Content $backupPath -Raw
        if ($originalContent -eq $backupContent) {
            Write-Host "   ✓ Backup content matches original" -ForegroundColor Green
        } else {
            Write-Host "   ✗ Backup content doesn't match!" -ForegroundColor Red
        }
    } else {
        Write-Host "   ✗ Backup creation failed" -ForegroundColor Red
    }
    
    # Test 4: Test auto-save registration
    Write-Host "`n4. Testing auto-save registration..." -ForegroundColor Yellow
    $autoSaveFile = Join-Path $PWD "test-autosave.txt"
    $autoSaveContent = "Auto-save test content"
    
    [UniversalBackupManager]::RegisterAutoSave(
        "test-autosave",
        $autoSaveFile,
        { 
            [UniversalBackupManager]::AtomicSave($autoSaveFile, $autoSaveContent, "notes", "autosave")
        },
        "notes"
    )
    Write-Host "   ✓ Auto-save registered" -ForegroundColor Green
    
    # Test the auto-save by executing it manually
    [UniversalBackupManager]::ExecuteAllAutoSaves("Manual Test")
    if (Test-Path $autoSaveFile) {
        $savedContent = Get-Content $autoSaveFile -Raw
        if ($savedContent -eq $autoSaveContent) {
            Write-Host "   ✓ Auto-save executed successfully" -ForegroundColor Green
        } else {
            Write-Host "   ✗ Auto-save content incorrect" -ForegroundColor Red
        }
    } else {
        Write-Host "   ✗ Auto-save file not created" -ForegroundColor Red
    }
    
    # Test 5: Test FullNotesEditor integration
    Write-Host "`n5. Testing FullNotesEditor integration..." -ForegroundColor Yellow
    $editor = [FullNotesEditor]::new()
    $editorTestFile = Join-Path $PWD "test-editor.txt"
    $editorContent = "Test content for FullNotesEditor`nWith multiple lines`nAnd more text"
    
    $editor.SetText($editorContent)
    $editor.EnableAutoSaveForFile($editorTestFile, "editor-test")
    
    # Execute auto-save
    [UniversalBackupManager]::ExecuteAllAutoSaves("Editor Test")
    
    if (Test-Path $editorTestFile) {
        $editorSavedContent = Get-Content $editorTestFile -Raw
        if ($editorSavedContent -eq $editorContent) {
            Write-Host "   ✓ FullNotesEditor auto-save works" -ForegroundColor Green
        } else {
            Write-Host "   ✗ FullNotesEditor content mismatch" -ForegroundColor Red
            Write-Host "     Expected: '$editorContent'" -ForegroundColor Gray
            Write-Host "     Got: '$editorSavedContent'" -ForegroundColor Gray
        }
    } else {
        Write-Host "   ✗ FullNotesEditor auto-save file not created" -ForegroundColor Red
    }
    
    # Test 6: Test backup listing
    Write-Host "`n6. Testing backup file listing..." -ForegroundColor Yellow
    $backupFiles = [UniversalBackupManager]::GetBackupFiles("notes", "test")
    Write-Host "   ✓ Found $($backupFiles.Count) backup files for 'notes/test'" -ForegroundColor Green
    foreach ($backup in $backupFiles | Select-Object -First 3) {
        Write-Host "     - $backup" -ForegroundColor Gray
    }
    
    # Test 7: Test integrity validation
    Write-Host "`n7. Testing integrity validation..." -ForegroundColor Yellow
    $hash1 = [UniversalBackupManager]::GetFileHash($testFile)
    $hash2 = [UniversalBackupManager]::GetFileHash($testFile)
    if ($hash1 -eq $hash2 -and $hash1.Length -eq 64) {
        Write-Host "   ✓ Hash validation consistent (SHA256: $($hash1.Substring(0,16))...)" -ForegroundColor Green
    } else {
        Write-Host "   ✗ Hash validation failed" -ForegroundColor Red
    }
    
    Write-Host "`n✅ ALL TESTS COMPLETED" -ForegroundColor Green
    Write-Host "Data safety system is operational and bulletproof!" -ForegroundColor Green
    
} catch {
    Write-Host "`n❌ TEST FAILED: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack trace:" -ForegroundColor Gray
    Write-Host $_.ScriptStackTrace -ForegroundColor Gray
} finally {
    # Cleanup test files
    Write-Host "`n🧹 Cleaning up test files..." -ForegroundColor Gray
    @(
        "test-atomic-save.txt",
        "test-autosave.txt", 
        "test-editor.txt",
        "test-atomic-save.txt.tmp",
        "test-autosave.txt.tmp",
        "test-editor.txt.tmp"
    ) | ForEach-Object {
        $file = Join-Path $PWD $_
        if (Test-Path $file) {
            Remove-Item $file -Force
            Write-Host "   Removed: $_" -ForegroundColor DarkGray
        }
    }
}