@echo -off
cls
echo "=============================================================="
echo "          UEFI HARDWARE / FIRMWARE SCANNER"
echo "          Scanner 0.1.0 / Report Format 1"
echo "=============================================================="
echo " "
echo "Locating the USB filesystem containing startup.nsh..."
echo " "

for %a in 0 1 2 3 4 5 6 7 8 9 A B C D E F
  if exist FS%a:\startup.nsh then
    set -v ScanFS FS%a:
    goto FOUND_USB
  endif
endfor

echo "ERROR: Could not locate the filesystem containing startup.nsh."
echo " "
map -v
echo " "
pause
goto END

:FOUND_USB
%ScanFS%
echo "Scanner USB found at %ScanFS%"
echo " "

if not exist SCANS then
  mkdir SCANS
endif

for %n in 1 2 3 4 5 6 7 8 9
  if not exist SCANS\SCAN_%n then
    set -v ScanDir SCANS\SCAN_%n
    mkdir %ScanDir%
    goto HAVE_DIR
  endif
endfor

echo "ERROR: SCANS\SCAN_1 through SCANS\SCAN_9 already exist."
pause
goto END

:HAVE_DIR
mkdir %ScanDir%\00_SUMMARY
mkdir %ScanDir%\01_UEFI
mkdir %ScanDir%\02_HARDWARE
mkdir %ScanDir%\03_STORAGE
mkdir %ScanDir%\04_MEMORY
mkdir %ScanDir%\05_SMBIOS
mkdir %ScanDir%\06_BOOT
mkdir %ScanDir%\07_DRIVERS
mkdir %ScanDir%\08_ENVIRONMENT
mkdir %ScanDir%\10_ACPI
mkdir %ScanDir%\11_SECURITY
mkdir %ScanDir%\12_ESP
mkdir %ScanDir%\99_RAW

echo "Results directory:"
echo "%ScanFS%\%ScanDir%"
echo " "

echo "Collecting UEFI / firmware information..."
ver > %ScanDir%\01_UEFI\shell_version.txt
mode > %ScanDir%\01_UEFI\console_mode.txt
map -v > %ScanDir%\01_UEFI\mapping_verbose.txt
dmpstore > %ScanDir%\01_UEFI\uefi_variables.txt

echo "Collecting hardware / device information..."
devices > %ScanDir%\02_HARDWARE\devices.txt
devtree -d > %ScanDir%\02_HARDWARE\device_tree.txt
dh -d -v > %ScanDir%\02_HARDWARE\handles_verbose.txt
pci > %ScanDir%\02_HARDWARE\pci.txt

echo "Collecting storage information..."
map -r > %ScanDir%\03_STORAGE\filesystem_map_refresh.txt
map -v > %ScanDir%\03_STORAGE\filesystem_map.txt
devices > %ScanDir%\03_STORAGE\storage_device_candidates.txt

echo "Collecting memory information..."
memmap > %ScanDir%\04_MEMORY\memory_map.txt

echo "Collecting SMBIOS information..."
smbiosview > %ScanDir%\05_SMBIOS\smbios.txt

echo "Collecting boot information..."
bcfg boot dump > %ScanDir%\06_BOOT\boot_configuration.txt
dmpstore BootOrder > %ScanDir%\06_BOOT\BootOrder.txt
dmpstore BootNext > %ScanDir%\06_BOOT\BootNext.txt
dmpstore BootCurrent > %ScanDir%\06_BOOT\BootCurrent.txt

echo "Collecting UEFI driver information..."
drivers > %ScanDir%\07_DRIVERS\drivers.txt
devices > %ScanDir%\07_DRIVERS\driver_devices.txt

echo "Collecting shell environment..."
set > %ScanDir%\08_ENVIRONMENT\environment.txt
alias > %ScanDir%\08_ENVIRONMENT\aliases.txt
help > %ScanDir%\08_ENVIRONMENT\available_commands.txt

echo "Collecting ACPI table information..."
help acpiview -verbose > %ScanDir%\10_ACPI\acpiview_usage.txt
acpiview > %ScanDir%\10_ACPI\acpi_tables.txt
acpiview -l > %ScanDir%\10_ACPI\acpiview_table_list.txt
for %t in RSDP XSDT FACP APIC MCFG DSDT SSDT BGRT DBG2 SPCR TPM2 WPBT
  acpiview -s %t > %ScanDir%\10_ACPI\%t.txt
endfor

echo "Collecting Secure Boot state..."
dmpstore SecureBoot > %ScanDir%\11_SECURITY\SecureBoot.txt
dmpstore SetupMode > %ScanDir%\11_SECURITY\SetupMode.txt
dmpstore PK > %ScanDir%\11_SECURITY\PK.txt
dmpstore KEK > %ScanDir%\11_SECURITY\KEK.txt
dmpstore -guid d719b2cb-3d3a-4596-a3bc-dad00e67656f db > %ScanDir%\11_SECURITY\db.txt
dmpstore -guid d719b2cb-3d3a-4596-a3bc-dad00e67656f dbx > %ScanDir%\11_SECURITY\dbx.txt

echo "Collecting EFI System Partition file listings..."
for %e in 0 1 2 3 4 5 6 7 8 9 A B C D E F
  if exist FS%e:\EFI then
    map FS%e: > %ScanDir%\12_ESP\FS%e_EFI_listing.txt
    ls -a -r FS%e:\EFI >> %ScanDir%\12_ESP\FS%e_EFI_listing.txt
  endif
endfor

echo "Preserving raw diagnostic output..."
map -v > %ScanDir%\99_RAW\map.txt
devices > %ScanDir%\99_RAW\devices.txt
devtree -d > %ScanDir%\99_RAW\devtree.txt
dh -d -v > %ScanDir%\99_RAW\dh.txt
drivers > %ScanDir%\99_RAW\drivers.txt
pci > %ScanDir%\99_RAW\pci.txt
memmap > %ScanDir%\99_RAW\memmap.txt
dmpstore > %ScanDir%\99_RAW\dmpstore.txt
smbiosview > %ScanDir%\99_RAW\smbiosview.txt

echo "Generating file report..."
ls -r %ScanDir% > %ScanDir%\00_SUMMARY\FILE_REPORT.txt

echo "Writing scan summary..."
echo "UEFI Diagnostic Scan" > %ScanDir%\00_SUMMARY\SCAN_SUMMARY.txt
echo "===================" >> %ScanDir%\00_SUMMARY\SCAN_SUMMARY.txt
echo " " >> %ScanDir%\00_SUMMARY\SCAN_SUMMARY.txt
echo "Scanner version: 0.1.0" >> %ScanDir%\00_SUMMARY\SCAN_SUMMARY.txt
echo "Report format: 1" >> %ScanDir%\00_SUMMARY\SCAN_SUMMARY.txt
echo " " >> %ScanDir%\00_SUMMARY\SCAN_SUMMARY.txt
echo "Scan run at:" >> %ScanDir%\00_SUMMARY\SCAN_SUMMARY.txt
date >> %ScanDir%\00_SUMMARY\SCAN_SUMMARY.txt
time >> %ScanDir%\00_SUMMARY\SCAN_SUMMARY.txt
echo " " >> %ScanDir%\00_SUMMARY\SCAN_SUMMARY.txt
echo "Shell version:" >> %ScanDir%\00_SUMMARY\SCAN_SUMMARY.txt
ver >> %ScanDir%\00_SUMMARY\SCAN_SUMMARY.txt
echo " " >> %ScanDir%\00_SUMMARY\SCAN_SUMMARY.txt
echo "Scanner filesystem: %ScanFS%" >> %ScanDir%\00_SUMMARY\SCAN_SUMMARY.txt
echo "Results directory: %ScanFS%\%ScanDir%" >> %ScanDir%\00_SUMMARY\SCAN_SUMMARY.txt
echo " " >> %ScanDir%\00_SUMMARY\SCAN_SUMMARY.txt
echo "Native UEFI collections attempted:" >> %ScanDir%\00_SUMMARY\SCAN_SUMMARY.txt
echo "  UEFI variables / NVRAM" >> %ScanDir%\00_SUMMARY\SCAN_SUMMARY.txt
echo "  Filesystem mappings" >> %ScanDir%\00_SUMMARY\SCAN_SUMMARY.txt
echo "  UEFI device handles" >> %ScanDir%\00_SUMMARY\SCAN_SUMMARY.txt
echo "  Device tree" >> %ScanDir%\00_SUMMARY\SCAN_SUMMARY.txt
echo "  PCI enumeration" >> %ScanDir%\00_SUMMARY\SCAN_SUMMARY.txt
echo "  Memory map" >> %ScanDir%\00_SUMMARY\SCAN_SUMMARY.txt
echo "  SMBIOS" >> %ScanDir%\00_SUMMARY\SCAN_SUMMARY.txt
echo "  ACPI tables (full dump + per-table breakdown, acpiview --" >> %ScanDir%\00_SUMMARY\SCAN_SUMMARY.txt
echo "  not present on every shell build)" >> %ScanDir%\00_SUMMARY\SCAN_SUMMARY.txt
echo "  Secure Boot state (SecureBoot/SetupMode/PK/KEK/db/dbx)" >> %ScanDir%\00_SUMMARY\SCAN_SUMMARY.txt
echo "  EFI System Partition file listing (per filesystem with \EFI)" >> %ScanDir%\00_SUMMARY\SCAN_SUMMARY.txt
echo "  Boot configuration" >> %ScanDir%\00_SUMMARY\SCAN_SUMMARY.txt
echo "  UEFI drivers" >> %ScanDir%\00_SUMMARY\SCAN_SUMMARY.txt
echo "  Shell environment / command inventory" >> %ScanDir%\00_SUMMARY\SCAN_SUMMARY.txt
echo " " >> %ScanDir%\00_SUMMARY\SCAN_SUMMARY.txt
echo "File report (directory tree + sizes):" >> %ScanDir%\00_SUMMARY\SCAN_SUMMARY.txt
echo "  %ScanFS%\%ScanDir%\00_SUMMARY\FILE_REPORT.txt" >> %ScanDir%\00_SUMMARY\SCAN_SUMMARY.txt
echo "  Review this first -- files that are 0 bytes or only a" >> %ScanDir%\00_SUMMARY\SCAN_SUMMARY.txt
echo "  handful of KB usually mean the command errored out on" >> %ScanDir%\00_SUMMARY\SCAN_SUMMARY.txt
echo "  this firmware rather than having no data to report." >> %ScanDir%\00_SUMMARY\SCAN_SUMMARY.txt
echo " " >> %ScanDir%\00_SUMMARY\SCAN_SUMMARY.txt
echo "Some firmware may not implement every command or protocol." >> %ScanDir%\00_SUMMARY\SCAN_SUMMARY.txt
echo "Individual command errors are retained in the corresponding files." >> %ScanDir%\00_SUMMARY\SCAN_SUMMARY.txt
echo " " >> %ScanDir%\00_SUMMARY\SCAN_SUMMARY.txt
echo "Note: 'devices' output appears in 02_HARDWARE, 03_STORAGE," >> %ScanDir%\00_SUMMARY\SCAN_SUMMARY.txt
echo "07_DRIVERS, and 99_RAW. This is the same full device list each" >> %ScanDir%\00_SUMMARY\SCAN_SUMMARY.txt
echo "time, organized by folder for workflow convenience -- it is not" >> %ScanDir%\00_SUMMARY\SCAN_SUMMARY.txt
echo "filtered per category." >> %ScanDir%\00_SUMMARY\SCAN_SUMMARY.txt

echo " "
echo "=============================================================="
echo "SCAN COMPLETE"
echo "=============================================================="
echo " "
echo "Results:"
echo "%ScanFS%\%ScanDir%"
echo " "
echo "Press any key to return to the UEFI Shell."
pause

:END