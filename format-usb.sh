#!/usr/bin/env bash
# Wipe a USB stick and format it for Windows (NTFS by default, exFAT optional).

set -euo pipefail

die() { echo "error: $*" >&2; exit 1; }

usage() {
    cat <<'EOF'
Usage: sudo format-usb.sh <device> [label] [options]

Wipe a USB stick and reformat it. Defaults to NTFS (Windows-friendly),
GPT partition table, single full-size partition.

Arguments:
  <device>        Block device to wipe, e.g. /dev/sdb (must be removable).
  [label]         Volume label. Default: USB

Options:
  --ntfs          Format as NTFS (default).
  --exfat         Format as exFAT instead.
  -n, --dry-run   Show what would happen — do not modify anything.
                  Does not require root.
  -d, --diagnose  Inspect the device (mounts, holders, LVM) and exit.
                  Useful when a wipe/format fails with "device busy".
                  Some checks (fuser, pvs, lvs) need root.
  -h, --help      Show this help and exit.

Examples:
  sudo format-usb.sh /dev/sdb KINGSTON
  sudo format-usb.sh /dev/sdb MYSTICK --exfat
  ./format-usb.sh   /dev/sdb KINGSTON --dry-run
  sudo format-usb.sh /dev/sdb --diagnose

Safety:
  - Refuses any device not flagged 'removable' in /sys/block.
  - Refuses if a partition is mounted as /, /home, /boot, or active swap.
  - Requires typing YES to confirm (skipped in --dry-run).
EOF
}

DEV=""
LABEL="USB"
FS="ntfs"
DRY_RUN=0
DIAGNOSE=0
for arg in "$@"; do
    case "$arg" in
        -h|--help)      usage; exit 0 ;;
        -n|--dry-run)   DRY_RUN=1 ;;
        -d|--diagnose)  DIAGNOSE=1 ;;
        --exfat)        FS="exfat" ;;
        --ntfs)         FS="ntfs" ;;
        /dev/*)         DEV="$arg" ;;
        -*)             die "unknown option: $arg (try --help)" ;;
        *)              LABEL="$arg" ;;
    esac
done

[[ -n "$DEV" ]] || { usage; exit 1; }
[[ -b "$DEV" ]] || die "$DEV is not a block device"
[[ $DRY_RUN -eq 1 || $DIAGNOSE -eq 1 || $EUID -eq 0 ]] || die "must run as root (use sudo) — or pass --dry-run / --diagnose"

# diagnose: inspect the device and what may be holding it. Used by --diagnose
# and called automatically if wipefs fails with "busy".
diagnose() {
    echo
    echo "=== diagnostic for $DEV ==="
    echo "--- lsblk ---"
    lsblk -o NAME,SIZE,FSTYPE,LABEL,MOUNTPOINT "$DEV" || true
    echo "--- mount entries ---"
    mount | grep "$DEV" || echo "(no mount entries for $DEV)"
    echo "--- processes holding $DEV* (fuser) ---"
    if [[ $EUID -eq 0 ]]; then
        # shellcheck disable=SC2086
        fuser -v "$DEV"* 2>&1 || echo "(no holders)"
    else
        echo "(skipped — needs root)"
    fi
    echo "--- LVM (pvs / lvs) ---"
    if [[ $EUID -eq 0 ]]; then
        if command -v pvs >/dev/null; then
            pvs 2>&1 || true
            lvs 2>&1 || true
        else
            echo "(LVM tools not installed)"
        fi
    else
        echo "(skipped — needs root)"
    fi
    echo "==="
    echo
}

if [[ $DIAGNOSE -eq 1 ]]; then
    diagnose
    exit 0
fi

# Refuse if device is not removable / is a system disk.
BASE=$(basename "$DEV")
REMOVABLE=$(cat "/sys/block/$BASE/removable" 2>/dev/null || echo 0)
[[ "$REMOVABLE" == "1" ]] || die "$DEV is not flagged removable — refusing for safety"

# Refuse if any partition on $DEV is currently mounted as / or /home or /boot.
if lsblk -no MOUNTPOINT "$DEV" | grep -qE '^(/|/home|/boot)$'; then
    die "$DEV holds a system mountpoint — refusing"
fi
if lsblk -no FSTYPE "$DEV" | grep -q '^swap$' && swapon --show=NAME --noheadings | grep -q "^$DEV"; then
    die "$DEV holds active swap — refusing"
fi

# Check required tools.
need=(wipefs sgdisk partprobe lsblk umount)
case "$FS" in
    ntfs)  need+=(mkfs.ntfs) ;;
    exfat) need+=(mkfs.exfat) ;;
esac
missing=()
for t in "${need[@]}"; do
    command -v "$t" >/dev/null || missing+=("$t")
done
if [[ ${#missing[@]} -gt 0 ]]; then
    msg="missing tools: ${missing[*]}"
    [[ $DRY_RUN -eq 1 ]] && echo "warning: $msg (would fail at run time)" >&2 || die "$msg"
fi

echo
echo "=== target device ==="
lsblk -o NAME,SIZE,MODEL,VENDOR,TRAN,FSTYPE,LABEL,MOUNTPOINT "$DEV"
echo
echo "filesystem: $FS"
echo "label:      $LABEL"
echo "mode:       $([[ $DRY_RUN -eq 1 ]] && echo 'DRY-RUN (no changes)' || echo 'LIVE — will erase data')"
echo

if [[ $DRY_RUN -eq 0 ]]; then
    echo "ALL DATA on $DEV WILL BE DESTROYED."
    read -r -p 'type "YES" to continue: ' ans
    [[ "$ans" == "YES" ]] || die "aborted"
    echo
fi

# run: execute or, in dry-run, just print.
run() {
    if [[ $DRY_RUN -eq 1 ]]; then
        printf '  [dry-run] %s\n' "$*" >&2
    else
        "$@"
    fi
}

echo "[1/5] unmounting any mounted partitions..."
unmount_part() {
    local part="$1"
    findmnt -n "$part" >/dev/null 2>&1 || return 0  # not mounted
    # Prefer udisksctl: it tells udisks2 not to auto-remount.
    if command -v udisksctl >/dev/null \
       && udisksctl unmount -b "$part" --no-user-interaction >/dev/null 2>&1; then
        return 0
    fi
    umount "$part" 2>/dev/null && return 0
    umount -l "$part" 2>/dev/null && return 0  # last resort: lazy
    return 1
}
for p in $(lsblk -ln -o NAME "$DEV" | tail -n +2); do
    part="/dev/$p"
    if [[ $DRY_RUN -eq 1 ]]; then
        printf '  [dry-run] unmount %s\n' "$part" >&2
    else
        unmount_part "$part" || echo "  warning: could not unmount $part" >&2
    fi
done
[[ $DRY_RUN -eq 1 ]] || { command -v udevadm >/dev/null && udevadm settle 2>/dev/null || true; sleep 0.5; }

# Verify nothing is still mounted before we wipe.
if [[ $DRY_RUN -eq 0 ]]; then
    still=$(lsblk -no MOUNTPOINT "$DEV" | awk 'NF' || true)
    if [[ -n "$still" ]]; then
        echo "still mounted after unmount attempts:" >&2
        echo "$still" >&2
        diagnose
        die "could not unmount everything on $DEV — close any file managers and retry"
    fi
fi

echo "[2/5] wiping signatures..."
if [[ $DRY_RUN -eq 1 ]]; then
    run wipefs -a "$DEV" >/dev/null
elif ! wipefs -a "$DEV" >/dev/null 2>&1; then
    echo "wipefs failed — auto-running diagnostics:" >&2
    diagnose
    die "wipefs could not access $DEV (something is holding it — see above)"
fi

echo "[3/5] creating GPT + single partition..."
run sgdisk -Z "$DEV" >/dev/null
run sgdisk -n 1:0:0 -t 1:0700 -c "1:$LABEL" "$DEV" >/dev/null
run partprobe "$DEV"
[[ $DRY_RUN -eq 1 ]] || sleep 1

PART="${DEV}1"
if [[ $DRY_RUN -eq 0 ]]; then
    [[ -b "$PART" ]] || PART="${DEV}p1"
    [[ -b "$PART" ]] || die "could not find new partition node"
fi

echo "[4/5] formatting $PART as $FS..."
case "$FS" in
    ntfs)  run mkfs.ntfs  -f -L "$LABEL" "$PART" >/dev/null ;;
    exfat) run mkfs.exfat    -L "$LABEL" "$PART" >/dev/null ;;
esac

echo "[5/5] done."
if [[ $DRY_RUN -eq 1 ]]; then
    echo "(dry-run — nothing was changed)"
else
    lsblk -f "$DEV"
fi
