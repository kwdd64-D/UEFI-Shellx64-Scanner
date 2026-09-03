# UEFI Diagnostic USB - Native Scanner - Version 1

FORMAT
----

a USB Drive using FAT32

Create the following folders

EFI
|
BOOT



INSTALL
------- 
use the : [sha256:4ea080ddd576117cd04f5c02d16712ea5d9249c0752214d8e4055e460d7b11e0](https://github.com/pbatard/UEFI-Shell/releases) shellx64.efi

Rename it to:

    EFI\BOOT\BOOTX64.EFI

Copy:
    startup.nsh

to the ROOT of the USB.

Final layout:
    USB:\
      EFI\
        BOOT\
          BOOTX64.EFI
      startup.nsh
      SCANS\
      SCRIPTS\

BOOT
----
Boot the USB into the UEFI Shell. The shell will automatically locate
startup.nsh according to the UEFI Shell startup rules.

The script then searches filesystem mappings FS0 through FSF for the
filesystem that contains startup.nsh. This avoids assuming the USB is
FS0.

WHY THIS VERSION IS DIFFERENT
-----------------------------
The previous script used CMD/Windows-style assumptions in several places.
UEFI Shell scripting is similar to batch scripting but is NOT Windows CMD.

In particular:
  - echo messages containing switch-like text should be quoted.
  - empty echo lines are avoided.
  - FOR loops use "for %x in ... then", followed by "endfor".
  - index variables are referenced as %x, not %x%.
  - UEFI Shell's set command syntax is used directly.

OUTPUT
------
Each run creates:
    SCANS\SCAN_1\
    SCANS\SCAN_2\
    ...

with:
    00_SUMMARY
    01_UEFI
    02_HARDWARE
    03_STORAGE
    04_MEMORY
    05_SMBIOS
    06_BOOT
    07_DRIVERS
    08_ENVIRONMENT
    09_RAW

The scanner is read-only with respect to disks, partitions, and firmware
configuration. It does not intentionally modify NVRAM or storage.

NOTE
----
Some commands can be unavailable or return errors depending on the
firmware implementation. Those failures should remain visible in the
corresponding output files. Deeper EFI utilities will be added in the
next phase.
