# usb-formatter

A Linux Bash utility that wipes and reformats a USB stick for Windows (NTFS, default) or exFAT. Built for the common case of reclaiming a USB stick after using it as a bootable Ubuntu installer, where the stick ends up as ISO9660 plus an EFI system partition plus a tiny ext4 "writable" partition and behaves as read-only on Windows. One command restores it to a single full-size NTFS or exFAT partition.

## Website

- [English](https://cocodedk.github.io/usb-formatter/)
- [فارسی (Persian)](https://cocodedk.github.io/usb-formatter/fa/)

## Features

- `--dry-run` previews every destructive command without root and without touching the disk
- `--diagnose` mode prints `lsblk`, `mount`, `fuser`, `pvs`, `lvs` to identify what is holding the device
- Refuses any device not flagged `removable` in `/sys/block/*/removable`
- Refuses if a partition is mounted at `/`, `/home`, `/boot`, or is active swap
- Cooperative unmount via `udisksctl unmount -b` so udisks2 does not auto-remount mid-format
- Auto-runs the diagnostic when `wipefs` fails with a busy device
- NTFS (default) or exFAT
- GPT partition table, single full-size partition, type `0700` (Microsoft basic data)
- Fast format paths (`mkfs.ntfs -f`, `mkfs.exfat`)

## Install

```bash
curl -O https://raw.githubusercontent.com/cocodedk/usb-formatter/main/format-usb.sh
chmod +x format-usb.sh
```

Or clone the repo:

```bash
git clone https://github.com/cocodedk/usb-formatter.git
cd usb-formatter
```

## Usage

```bash
./format-usb.sh --help
```

Typical flow — preview first, then run for real:

```bash
./format-usb.sh /dev/sdX KINGSTON --dry-run
sudo ./format-usb.sh /dev/sdX KINGSTON
sudo ./format-usb.sh /dev/sdX --diagnose
sudo ./format-usb.sh /dev/sdX MYSTICK --exfat
```

Replace `/dev/sdX` with the actual block device. Confirm the device path with `lsblk` before running.

## Requirements

- Linux (tested on Ubuntu, Debian, Fedora, Arch)
- Root for live runs (dry-run and diagnose do not need root for most checks)
- Packages:
  - `util-linux` — `wipefs`, `lsblk`, `mount`, `umount`
  - `gdisk` — `sgdisk`
  - `parted` — `partprobe`
  - `ntfs-3g` — `mkfs.ntfs` (for NTFS)
  - `exfatprogs` — `mkfs.exfat` (for exFAT)
- `udisksctl` from `udisks2` is optional but recommended for cooperative unmount

Distro install hints:

```bash
# Debian / Ubuntu
sudo apt install util-linux gdisk parted ntfs-3g exfatprogs udisks2

# Fedora
sudo dnf install util-linux gdisk parted ntfs-3g exfatprogs udisks2

# Arch
sudo pacman -S util-linux gptfdisk parted ntfs-3g exfatprogs udisks2
```

## Safety

This tool is destructive by design — it erases the entire target device. The guards are there to make sure the target is the one you meant:

- The device must be flagged removable in the kernel. Internal disks fail this check.
- If any partition on the device is currently mounted at `/`, `/home`, or `/boot`, the script aborts.
- If any partition is active swap, the script aborts.
- In live mode the script asks for the literal string `YES`. Anything else aborts.
- Before wiping, the script verifies that nothing on the device is still mounted after the unmount loop. If something is, it runs the diagnostic and exits.
- `--dry-run` runs the entire pipeline as a print-only preview. Use it first.

## Build / verify

For contributors:

```bash
shellcheck format-usb.sh
bash -n format-usb.sh
```

CI runs both on every pull request.

## Author

**Babak Bandpey** — [cocode.dk](https://cocode.dk) | [LinkedIn](https://linkedin.com/in/babakbandpey) | [GitHub](https://github.com/cocodedk)

## License

Apache-2.0 | © 2026 [Cocode](https://cocode.dk) | Created by [Babak Bandpey](https://linkedin.com/in/babakbandpey)
