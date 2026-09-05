#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
BUNDLE="$ROOT/scanner-bundle"
SCRIPT="$BUNDLE/startup.nsh"
BOOT="$BUNDLE/EFI/BOOT/bootx64.efi"

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

[ -d "$BUNDLE" ] || fail "missing scanner-bundle/"
[ -f "$SCRIPT" ] || fail "missing scanner-bundle/startup.nsh"
[ -d "$BUNDLE/EFI/BOOT" ] || fail "missing scanner-bundle/EFI/BOOT/"
[ -f "$BUNDLE/EFI/BOOT/PUT_SHELLX64_EFI_HERE.txt" ] ||
  fail "missing shell placement instructions"

first_line=$(sed -n '1p' "$SCRIPT")
[ "$first_line" = '@echo -off' ] ||
  fail "startup.nsh must begin with @echo -off"

for required in \
  'if exist FS%a:\startup.nsh then' \
  'Scanner 0.1.0 / Report Format 1' \
  'echo "Scanner version: 0.1.0" >> %ScanDir%\00_SUMMARY\SCAN_SUMMARY.txt' \
  'echo "Report format: 1" >> %ScanDir%\00_SUMMARY\SCAN_SUMMARY.txt' \
  'dmpstore > %ScanDir%\01_UEFI\uefi_variables.txt' \
  'smbiosview > %ScanDir%\05_SMBIOS\smbios.txt' \
  'for %t in RSDP XSDT FACP APIC MCFG DSDT SSDT BGRT DBG2 SPCR TPM2 WPBT' \
  'acpiview -s %t > %ScanDir%\10_ACPI\%t.txt' \
  'dmpstore -guid d719b2cb-3d3a-4596-a3bc-dad00e67656f dbx' \
  'ls -r %ScanDir% > %ScanDir%\00_SUMMARY\FILE_REPORT.txt' \
  'pause'
do
  grep -F "$required" "$SCRIPT" >/dev/null ||
    fail "startup.nsh is missing required command: $required"
done

if [ -f "$BOOT" ]; then
  printf 'OK: scanner bundle is complete and includes EFI/BOOT/bootx64.efi\n'
else
  printf 'OK: scanner bundle layout and script checks passed\n'
  printf 'WARN: EFI/BOOT/bootx64.efi is not present; add a verified compatible UEFI Shell binary before booting\n'
fi