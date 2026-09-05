# Contributing and Reporting Results

Reports from additional x86-64 UEFI machines are valuable, including failures.
Please open a GitHub issue with the smallest amount of information needed to
reproduce or understand the behavior.

## Suggested report

```text
Scanner version:
Report format:
Machine or motherboard model (optional):
Firmware vendor and UEFI version:
UEFI Shell release or source:
Did the USB boot?:
Did the scanner reach SCAN COMPLETE?:
Output file containing the problem:
Observed behavior or reviewed error excerpt:
Expected behavior:
```

## Protect identifying information

Do not attach an entire raw scan by default. Before sharing any output, review
and redact:

- serial numbers, UUIDs, and asset tags
- network and storage identifiers
- NVRAM values and boot configuration
- Secure Boot key databases and certificate material
- identifying paths or filenames from EFI System Partition listings

The scanner intentionally captures low-level diagnostic information, so a
complete report should be treated as potentially identifying.

## Changes

Keep changes compatible with standard EDK2-derived UEFI Shell scripting where
possible. Clearly identify commands or flags that require a particular shell
release. A change should not write to firmware configuration, NVRAM, partition
tables, or target disks.