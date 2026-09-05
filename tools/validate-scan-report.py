#!/usr/bin/env python3
"""Validate scanner metadata and FILE_REPORT path/size entries."""

from __future__ import annotations

import argparse
import configparser
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
RELEASE_METADATA = ROOT / "release.ini"

# A 64-byte floor catches empty/truncated UTF-16 output while allowing the short
# "table not found" and unprovisioned-variable responses seen on UEFI systems.
DEFAULT_MIN_BYTES = 64

EXPECTED_OUTPUTS = {
    "00_SUMMARY/FILE_REPORT.txt",
    "01_UEFI/shell_version.txt",
    "01_UEFI/console_mode.txt",
    "01_UEFI/mapping_verbose.txt",
    "01_UEFI/uefi_variables.txt",
    "02_HARDWARE/devices.txt",
    "02_HARDWARE/device_tree.txt",
    "02_HARDWARE/handles_verbose.txt",
    "02_HARDWARE/pci.txt",
    "03_STORAGE/filesystem_map_refresh.txt",
    "03_STORAGE/filesystem_map.txt",
    "03_STORAGE/storage_device_candidates.txt",
    "04_MEMORY/memory_map.txt",
    "05_SMBIOS/smbios.txt",
    "06_BOOT/boot_configuration.txt",
    "06_BOOT/BootOrder.txt",
    "06_BOOT/BootNext.txt",
    "06_BOOT/BootCurrent.txt",
    "07_DRIVERS/drivers.txt",
    "07_DRIVERS/driver_devices.txt",
    "08_ENVIRONMENT/environment.txt",
    "08_ENVIRONMENT/aliases.txt",
    "08_ENVIRONMENT/available_commands.txt",
    "10_ACPI/acpiview_usage.txt",
    "10_ACPI/acpi_tables.txt",
    "10_ACPI/acpiview_table_list.txt",
    *{
        f"10_ACPI/{table}.txt"
        for table in (
            "RSDP",
            "XSDT",
            "FACP",
            "APIC",
            "MCFG",
            "DSDT",
            "SSDT",
            "BGRT",
            "DBG2",
            "SPCR",
            "TPM2",
            "WPBT",
        )
    },
    "11_SECURITY/SecureBoot.txt",
    "11_SECURITY/SetupMode.txt",
    "11_SECURITY/PK.txt",
    "11_SECURITY/KEK.txt",
    "11_SECURITY/db.txt",
    "11_SECURITY/dbx.txt",
    "99_RAW/map.txt",
    "99_RAW/devices.txt",
    "99_RAW/devtree.txt",
    "99_RAW/dh.txt",
    "99_RAW/drivers.txt",
    "99_RAW/pci.txt",
    "99_RAW/memmap.txt",
    "99_RAW/dmpstore.txt",
    "99_RAW/smbiosview.txt",
}


def load_release_metadata(path: Path = RELEASE_METADATA) -> tuple[str, str]:
    config = configparser.ConfigParser(interpolation=None)
    try:
        with path.open(encoding="utf-8") as metadata_file:
            config.read_file(metadata_file)
        scanner_version = config["release"]["scanner_version"].strip()
        report_format = config["release"]["report_format"].strip()
    except (OSError, configparser.Error, KeyError) as exc:
        raise ValueError(f"cannot load release metadata from {path}: {exc}") from exc

    if not scanner_version:
        raise ValueError(f"release metadata has an empty scanner_version: {path}")
    if not report_format:
        raise ValueError(f"release metadata has an empty report_format: {path}")
    return scanner_version, report_format

FIELD_RE = re.compile(r"^\s*(Scanner version|Report format):\s*(.*?)\s*$", re.I)
DIR_RE = re.compile(r"^\s*Directory of:\s*(.*?)\s*$", re.I)
FILE_RE = re.compile(
    r"^\s*\S+\s+\S+\s+(?!<DIR>)([\d,]+)\s+(.+?)\s*$", re.I
)


def read_uefi_text(path: Path) -> str:
    data = path.read_bytes()
    if data.startswith((b"\xff\xfe", b"\xfe\xff")):
        return data.decode("utf-16")
    if b"\x00" in data[:256]:
        # Common UEFI shells emit UTF-16LE without a byte-order mark.
        return data.decode("utf-16-le")
    return data.decode("utf-8-sig")


def summary_fields(text: str) -> dict[str, str]:
    fields: dict[str, str] = {}
    for line in text.splitlines():
        match = FIELD_RE.match(line.strip('"'))
        if match:
            fields[match.group(1).lower()] = match.group(2).strip('"')
    return fields


def relative_directory(raw_directory: str) -> str | None:
    normalized = raw_directory.replace("\\", "/").rstrip("/")
    match = re.search(r"(?:^|/)SCANS/SCAN_[^/]+(?:/(.*))?$", normalized, re.I)
    if not match:
        return None
    return (match.group(1) or "").strip("/")


def report_entries(text: str) -> dict[str, int]:
    entries: dict[str, int] = {}
    directory: str | None = None
    for line in text.splitlines():
        directory_match = DIR_RE.match(line)
        if directory_match:
            directory = relative_directory(directory_match.group(1))
            continue
        file_match = FILE_RE.match(line)
        if file_match and directory is not None:
            name = file_match.group(2).strip()
            path = f"{directory}/{name}" if directory else name
            entries[path.lower()] = int(file_match.group(1).replace(",", ""))
    return entries


def validate(
    summary_path: Path,
    report_path: Path,
    scanner_version: str | None = None,
    report_format: str | None = None,
) -> list[str]:
    if scanner_version is None or report_format is None:
        scanner_version, report_format = load_release_metadata()

    errors: list[str] = []
    try:
        fields = summary_fields(read_uefi_text(summary_path))
    except (OSError, UnicodeError) as exc:
        return [f"cannot read SCAN_SUMMARY.txt: {exc}"]

    expected_fields = {
        "scanner version": scanner_version,
        "report format": report_format,
    }
    for field, expected in expected_fields.items():
        actual = fields.get(field)
        if actual is None:
            errors.append(f"SCAN_SUMMARY.txt is missing '{field.title()}:'")
        elif actual != expected:
            errors.append(
                f"unexpected {field}: expected {expected!r}, found {actual!r}"
            )

    try:
        entries = report_entries(read_uefi_text(report_path))
    except (OSError, UnicodeError) as exc:
        return errors + [f"cannot read FILE_REPORT.txt: {exc}"]

    if not entries:
        errors.append("FILE_REPORT.txt contains no recognizable file entries")
        return errors

    for expected_path in sorted(EXPECTED_OUTPUTS):
        size = entries.get(expected_path.lower())
        if size is None:
            errors.append(f"missing expected output: {expected_path}")
        elif size == 0:
            errors.append(f"zero-byte output: {expected_path}")
        elif size < DEFAULT_MIN_BYTES:
            errors.append(
                f"suspiciously small output ({size} bytes, minimum "
                f"{DEFAULT_MIN_BYTES}): {expected_path}"
            )

    # ESP listings are conditional: no filesystem is required to expose an EFI
    # directory, but any listing that was produced must not be empty/truncated.
    for path, size in sorted(entries.items()):
        if re.fullmatch(r"12_esp/fs[0-9a-f]_efi_listing\.txt", path, re.I):
            if size == 0:
                errors.append(f"zero-byte output: {path}")
            elif size < DEFAULT_MIN_BYTES:
                errors.append(
                    f"suspiciously small output ({size} bytes, minimum "
                    f"{DEFAULT_MIN_BYTES}): {path}"
                )
    return errors


def main() -> int:
    parser = argparse.ArgumentParser(
        description=(
            "Validate version fields and output path/size metadata from a "
            "completed UEFI scanner run."
        )
    )
    parser.add_argument("scan_summary", type=Path, help="path to SCAN_SUMMARY.txt")
    parser.add_argument("file_report", type=Path, help="path to FILE_REPORT.txt")
    args = parser.parse_args()

    try:
        scanner_version, report_format = load_release_metadata()
    except ValueError as exc:
        print(f"FAIL: {exc}", file=sys.stderr)
        return 1

    errors = validate(
        args.scan_summary,
        args.file_report,
        scanner_version,
        report_format,
    )
    if errors:
        for error in errors:
            print(f"FAIL: {error}", file=sys.stderr)
        print(f"Scan report validation failed with {len(errors)} issue(s).", file=sys.stderr)
        return 1

    print(
        f"OK: scanner {scanner_version}, report format {report_format}; "
        f"all {len(EXPECTED_OUTPUTS)} required outputs are present and plausible"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())