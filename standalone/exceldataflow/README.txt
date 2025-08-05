EXCEL DATA FLOW MAPPING TOOL
============================

WHAT IT DOES:
- Maps 40 Excel fields between source and destination files
- Simple menu-driven interface
- Saves/loads configuration to JSON
- No complex UI, just works

HOW TO USE:
1. Run: pwsh -File ExcelMappingTool.ps1
2. Choose menu options:
   - 1: Set source/destination Excel files
   - 2: Map source cells (W23, H17, etc.)
   - 3: Map destination cells (A1, A2, etc.)
   - 4: View current mappings
   - 5: Save configuration
   - 6: Load saved configuration

FIELDS INCLUDED (40 total):
RequestDate, AuditType, AuditorName, TPName, TPEmailAddress, 
TPPhoneNumber, CorporateContact, CorporateContactEmail, 
CorporateContactPhone, SiteName, SiteAddress, SiteCity, 
SiteState, SiteZip, SiteCountry, AttentionContact, 
AttentionContactEmail, AttentionContactPhone, TaxID, DUNS, 
CASNumber, AssetName, SerialNumber, ModelNumber, 
ManufacturerName, InstallDate, Capacity, CapacityUnit, 
TankType, Product, LeakDetection, Piping, Monitoring, 
Status, Comments, ComplianceDate, NextInspectionDate, 
CertificationNumber, InspectorName, InspectorLicense

DEFAULT SOURCE CELLS:
RequestDate=W23, AuditType=W78, AuditorName=W10, etc.

CONFIGURATION SAVED TO:
_Config/excel_mapping.json

SIMPLE. WORKS. DONE.