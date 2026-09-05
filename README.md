# UEFI Scanner Tool

**Current release:** Scanner 0.1.0 · Report format 1 · Public beta

This project packages a no-OS UEFI Shell scanner for hardware and firmware
inspection. Boot a FAT32 USB into an x86-64 UEFI Shell and the scanner writes a
structured snapshot back to that same USB.

The scanner is useful for hardware troubleshooting, pre-purchase or pre-sale
inspection, comparing machines, and creating a record before or after firmware,
memory, or driver changes.

The scanner is an independent companion tool. It is not affiliated with or
endorsed by the EDK2 project or third-party UEFI Shell distributors.

## Project layout

```text
scanner-bundle/                 USB root; copy its contents to a FAT32 drive
├── startup.nsh                 auto-run UEFI Shell script
└── EFI/
    └── BOOT/
        └── PUT_SHELLX64_EFI_HERE.txt

tools/
├── validate-bundle.sh           safe local layout and command check
└── validate-scan-report.py      completed-scan path and size check

release.ini                      canonical scanner and report-format versions
```

The `bootx64.efi` file is intentionally not included. It is a firmware-facing
binary whose source, architecture, and integrity should be verified separately.
Place a compatible `shellx64.efi` in `scanner-bundle/EFI/BOOT/` and rename it to
`bootx64.efi` before copying the bundle to a USB drive.

## Obtain a UEFI Shell

Users must provide their own x86-64 UEFI Shell. One source of transparent,
prebuilt EDK2 stable images is:

- https://github.com/pbatard/UEFI-Shell/releases

Choose the individual x64 shell binary appropriate for your machine, verify it
using the checksums and build information published by its distributor, and
then follow the placement instructions below. This project does not mirror or
redistribute third-party shell binaries, so users can obtain current releases
from their original source.

## Requirements

- FAT32-formatted USB drive
- x86-64 UEFI Shell binary, commonly named `shellx64.efi`
- Target machine with a UEFI Shell available through its firmware or boot menu

No operating system, network connection, or installed driver is required while
the scan runs.

## Prepare the USB

1. Format the USB as FAT32.
2. Copy the contents of `scanner-bundle/` to the root of the USB.
3. Copy the UEFI Shell binary to `EFI/BOOT/`.
4. Rename that binary to `bootx64.efi`.
5. Confirm the final layout is:

   ```text
   USB:\
   ├── startup.nsh
   ├── EFI\
   │   └── BOOT\
   │       └── bootx64.efi
   └── SCANS\              (created automatically)
   ```

Run the local check before copying:

```sh
sh tools/validate-bundle.sh
```

Run the release metadata regression test with:

```sh
pnpm test
```

The same `pnpm test` command runs in GitHub Actions for every pull request and
push to `main`. Both the workflow and its package-script entry point require
owner review. A release metadata mismatch fails that required CI check and must
be corrected before the change can merge.

### Main branch protection

GitHub branch protection requires the `pnpm test` status check on `main` and
requires the pull request branch to be up to date before merging. A pull request
cannot merge while that check is pending or failing.

The rule is enforced for repository administrators. Maintainers cannot bypass
the required check; they must correct the failure or wait for the check to
complete successfully.

The active rule is represented by `.github/main-branch-protection.json`. A
repository administrator can apply and verify that exact policy with GitHub CLI:

```sh
sh tools/configure-main-branch-protection.sh
```

The sanitized response captured from the authenticated GitHub branch-protection
API when the rule was applied is recorded in
`.github/main-branch-protection.evidence.json`.

### Release-safety ownership

Pull requests that change the workflow, branch-protection policy, package test
entry point, release test driver, bundle validator, report validator, policy
configuration helper, or `.github/CODEOWNERS` itself require approval from the
designated owner listed in `.github/CODEOWNERS`. These exact paths are enumerated
there so every executable layer of the release-safety gate is owned. This
applies even when all automated checks pass. New commits dismiss stale
approvals, so the owner must approve the final reviewed revision before it can
merge.

Contributors should explain why a release-safety control is changing and must
not remove or narrow an ownership entry to avoid review. The `pnpm test`
regression suite verifies the protected paths, rejects a fixture with any
required ownership entry removed, and checks the branch-protection policy
recorded in the repository.

`release.ini` is the single source for release version metadata. When preparing a
release, update it and the version text in `startup.nsh` and this README together.
The local check fails clearly if either consumer is out of sync. The check does
not emulate UEFI and does not replace a real boot test.

After a physical scan completes, validate its summary and recursive file report:

```sh
python3 tools/validate-scan-report.py \
  path/to/SCAN_SUMMARY.txt path/to/FILE_REPORT.txt
```

The checker accepts UTF-8 and the UTF-16 text produced by common UEFI Shell
builds. It verifies scanner `0.1.0` and report format `1`, then checks that every
expected static output appears in `FILE_REPORT.txt` with a plausible size.
Conditional `12_ESP` listings are checked when present because a machine may
legitimately expose no filesystem containing an `EFI` directory.

The checker reads only version fields from `SCAN_SUMMARY.txt` and path/byte-count
metadata from `FILE_REPORT.txt`; it does not copy or inspect raw SMBIOS, NVRAM,
or other captured hardware contents. A passing result catches incomplete scan
artifacts, but it does **not** replace the physical USB boot test or review of
individual command errors on the target hardware.

## Run a scan

1. Insert the USB into the target machine.
2. Open the firmware boot menu, commonly with `F12`, `F11`, `Esc`, or `Del`.
3. Select the USB's UEFI boot entry.
4. `startup.nsh` runs automatically from the filesystem containing the script.
5. When the scan completes, results are in `SCANS\SCAN_N\`.

The script searches `FS0:` through `FSF:` for `startup.nsh` instead of assuming
the USB has a particular firmware-assigned filesystem letter.

The scanner creates `SCAN_1` through `SCAN_9` and never overwrites an existing
scan. After nine runs, copy or remove old scan folders before running again.

## Captured data

Each scan contains:

| Folder | Contents |
| --- | --- |
| `00_SUMMARY` | Run summary and recursive file report |
| `01_UEFI` | Shell version, console mode, filesystem mappings, NVRAM dump |
| `02_HARDWARE` | Devices, device tree, handles/protocols, PCI enumeration |
| `03_STORAGE` | Refreshed and verbose filesystem maps, storage candidates |
| `04_MEMORY` | Firmware memory map |
| `05_SMBIOS` | Motherboard, CPU, memory, serial, and asset information |
| `06_BOOT` | Boot configuration and BootOrder/BootNext/BootCurrent |
| `07_DRIVERS` | Loaded UEFI drivers and device list |
| `08_ENVIRONMENT` | Shell variables, aliases, and available commands |
| `10_ACPI` | ACPI dump, installed table list, and selected table captures |
| `11_SECURITY` | Secure Boot variables including `SecureBoot`, `SetupMode`, `PK`, `KEK`, `db`, and `dbx` |
| `12_ESP` | Recursive `EFI` listings for detected filesystems |
| `99_RAW` | Unfiltered duplicate captures for cross-reference |

## Read results safely

Start with `00_SUMMARY\FILE_REPORT.txt`. A command's output size is a useful
first signal:

- A structured file with meaningful size usually indicates the command returned
  data.
- A zero-byte or very small file often contains a command error caused by a
  missing command or firmware-specific syntax.
- `PK`, `KEK`, `db`, and `dbx` can legitimately be small or absent on systems
  without provisioned Secure Boot keys.
- `12_ESP` sizes depend on how many EFI files are present.

The script intentionally writes each command's output to its own file. A
firmware that lacks a command should leave an error in that file rather than
stopping the rest of the scan.

## ACPI and WPBT

Read `10_ACPI/WPBT.txt` as content, not just as a file-size check. If it says
`Requested ACPI Table not found`, the system did not expose a WPBT table.

If a real WPBT dump is present, it can describe a firmware-registered Windows
binary and its arguments. The scanner only reads firmware data; it does not
modify ACPI tables, NVRAM, or Secure Boot state. To inspect the extracted
Windows-side binary, check `%SystemRoot%\System32\wpbbin.exe` after booting
Windows and review its signature and publisher.

## Known limitations

- UEFI Shell command availability varies by firmware build. `acpiview` may not
  exist at all.
- Command flags are intentionally conservative because syntax differs between
  shell builds.
- Filesystem letters such as `FS0:` are not stable identifiers between boots or
  machines. Cross-reference the mapping files for a specific scan.
- Quoted `echo` output is clean on standard EDK2-derived shells. Some alternate
  shell implementations may display literal quote characters; this affects
  cosmetic console text only.
- The script supports nine scan folders per USB and stops rather than
  overwriting old results.

## Privacy

Do not publish raw scan folders without review. SMBIOS and raw NVRAM captures can
contain serial numbers, UUIDs, asset tags, vendor data, and boot configuration.
ESP listings reveal installed operating systems and boot files. A populated
WPBT capture may reveal a firmware-registered binary and memory address.

Redact identifying values before sharing scan output publicly.

The material under `examples/` is fictional and intentionally contains no scan
from a real machine. Use it to understand the format, not as diagnostic data.

## Feedback and bug reports

Feedback from different firmware vendors and machine generations is welcome.
When opening an issue, include only what you are comfortable publishing:

- computer or motherboard model, if appropriate
- firmware vendor and UEFI version
- UEFI Shell release or source
- whether the USB booted and the scan reached `SCAN COMPLETE`
- the name of any output file containing an error
- the smallest relevant, reviewed excerpt of that error

Do not attach a complete raw scan by default. Review every file first and redact
serial numbers, UUIDs, asset tags, network identifiers, storage identifiers,
NVRAM values, boot configuration, and other identifying data.

See `CONTRIBUTING.md` for a concise report template.

## Verification status

The bundle layout and script contents can be checked locally with
`tools/validate-bundle.sh`. Actual boot behavior must be validated on target
hardware with a compatible UEFI Shell binary; this development environment
cannot emulate firmware or execute `.nsh` scripts.

The current release has been exercised on two x86-64 UEFI machines from
different platform and firmware generations. It should be treated as a public
beta rather than a claim of universal firmware compatibility.

## License

The scanner script, documentation, examples, and validation helper are released
under the MIT License. See `LICENSE`.

Third-party UEFI Shell binaries are not part of this project and remain subject
to their own licenses.