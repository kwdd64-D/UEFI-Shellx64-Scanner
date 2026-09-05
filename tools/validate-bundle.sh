#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
BUNDLE="$ROOT/scanner-bundle"
SCRIPT="$BUNDLE/startup.nsh"
BOOT="$BUNDLE/EFI/BOOT/bootx64.efi"
REPORT_CHECKER="$ROOT/tools/validate-scan-report.py"
RELEASE_METADATA="$ROOT/release.ini"
README="$ROOT/README.md"

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

[ -d "$BUNDLE" ] || fail "missing scanner-bundle/"
[ -f "$SCRIPT" ] || fail "missing scanner-bundle/startup.nsh"
[ -d "$BUNDLE/EFI/BOOT" ] || fail "missing scanner-bundle/EFI/BOOT/"
[ -f "$REPORT_CHECKER" ] || fail "missing tools/validate-scan-report.py"
[ -f "$RELEASE_METADATA" ] || fail "missing release.ini"
[ -f "$README" ] || fail "missing README.md"
[ -f "$BUNDLE/EFI/BOOT/PUT_SHELLX64_EFI_HERE.txt" ] ||
  fail "missing shell placement instructions"

first_line=$(sed -n '1p' "$SCRIPT")
[ "$first_line" = '@echo -off' ] ||
  fail "startup.nsh must begin with @echo -off"

scanner_version=$(
  sed -n 's/^[[:space:]]*scanner_version[[:space:]]*=[[:space:]]*//p' \
    "$RELEASE_METADATA"
)
report_format=$(
  sed -n 's/^[[:space:]]*report_format[[:space:]]*=[[:space:]]*//p' \
    "$RELEASE_METADATA"
)
[ -n "$scanner_version" ] ||
  fail "release.ini is missing release.scanner_version"
[ -n "$report_format" ] ||
  fail "release.ini is missing release.report_format"

assert_release_text() {
  file=$1
  description=$2
  expected=$3
  grep -F "$expected" "$file" >/dev/null ||
    fail "$description is out of sync with release.ini; expected: $expected"
}

assert_release_text "$SCRIPT" "startup.nsh banner" \
  "Scanner $scanner_version / Report Format $report_format"
assert_release_text "$SCRIPT" "startup.nsh scanner summary field" \
  "echo \"Scanner version: $scanner_version\" >> %ScanDir%\\00_SUMMARY\\SCAN_SUMMARY.txt"
assert_release_text "$SCRIPT" "startup.nsh report summary field" \
  "echo \"Report format: $report_format\" >> %ScanDir%\\00_SUMMARY\\SCAN_SUMMARY.txt"
assert_release_text "$README" "README release heading" \
  "**Current release:** Scanner $scanner_version · Report format $report_format · Public beta"
assert_release_text "$README" "README checker documentation" \
  "It verifies scanner \`$scanner_version\` and report format \`$report_format\`, then checks that every"

for required in \
  'if exist FS%a:\startup.nsh then' \
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

python3 -m py_compile "$REPORT_CHECKER" ||
  fail "tools/validate-scan-report.py does not compile"

python3 -c '
import pathlib
import runpy
import sys
checker = runpy.run_path(sys.argv[1], run_name="release_validation")
checker["load_release_metadata"](pathlib.Path(sys.argv[2]))
' "$REPORT_CHECKER" "$RELEASE_METADATA" ||
  fail "tools/validate-scan-report.py cannot load release.ini"

if [ -f "$BOOT" ]; then
  printf 'OK: scanner bundle is complete and includes EFI/BOOT/bootx64.efi\n'
else
  printf 'OK: scanner bundle layout and script checks passed\n'
  printf 'WARN: EFI/BOOT/bootx64.efi is not present; add a verified compatible UEFI Shell binary before booting\n'
fi