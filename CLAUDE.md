# CLAUDE.md — usb-formatter

## Project Overview

A single Bash utility (`format-usb.sh`) that wipes and reformats a USB stick on Linux for Windows (NTFS) or exFAT, with safety guards (removable-only, mount/swap refusal, YES confirmation, udisksctl-cooperative unmount, --dry-run, --diagnose).

- **Language / Runtime:** Bash (POSIX-aware where reasonable; uses `[[ ]]` so requires bash, not pure sh)
- **Platform:** Linux only (uses `wipefs`, `sgdisk`, `partprobe`, `mkfs.ntfs`, `mkfs.exfat`, `udisksctl`)
- **License:** Apache-2.0

---

## Required Skills — ALWAYS Invoke These

| Situation | Skill |
|-----------|-------|
| Before any new feature or screen | `superpowers:brainstorming` |
| Planning multi-step changes | `superpowers:writing-plans` |
| Writing or fixing core logic | `superpowers:test-driven-development` |
| First sign of a bug or failure | `superpowers:systematic-debugging` |
| Before completing a feature branch | `superpowers:requesting-code-review` |
| Before claiming any task done | `superpowers:verification-before-completion` |
| Working on UI / frontend (Pages site) | `frontend-design:frontend-design` |
| After implementing — reviewing quality | `simplify` |

---

## Architecture

```
usb-formatter/
├── format-usb.sh           ← the tool itself (single file)
├── .githooks/              ← pre-commit (shellcheck) + commit-msg (conventional)
├── .github/workflows/      ← ci.yml, release.yml, deploy-pages.yml
├── scripts/                ← install-hooks.sh, setup-repo.sh
└── website/                ← bilingual EN+FA Pages site
```

### Invariants

- Every destructive command goes through the `run()` wrapper or an explicit `if $DRY_RUN` branch — never call `wipefs`/`sgdisk`/`mkfs.*` directly from the action body
- The `removable` check on `/sys/block/<dev>/removable` is the primary safety net — never weaken or bypass it
- Always require typed `YES` confirmation in live mode; never auto-confirm
- Prefer `udisksctl unmount -b` over plain `umount` so udisks2 doesn't auto-remount

---

## Coding Conventions

- `set -euo pipefail` at the top of every script
- Use `[[ ]]` not `[ ]` (we depend on bash already)
- All user-visible messages go to stdout for status, stderr for warnings/errors
- Functions are short — extract anything that does more than one thing
- No emojis in script output or in any file
- File size: under 200 lines per file where feasible

---

## Engineering Principles

### File size
- 200-line max per file. If approaching, split (e.g. extract diagnose() to a sourced helper if needed).

### KISS, YAGNI
- This is a tiny utility — resist adding features. Every flag is liability.
- No backwards-compatibility shims for removed flags

### Safety first
- Any change that touches the wipe/format pipeline requires a manual real-USB dry-run before merge
- Any change that weakens the removable check or YES confirmation must be rejected

### Commit hygiene
- Conventional Commits enforced by `commit-msg` hook
- One logical change per commit

---

## Build & Verify Commands

```bash
shellcheck format-usb.sh        # lint
bash -n format-usb.sh           # syntax check
./format-usb.sh --help          # smoke
./format-usb.sh /dev/sdX FOO --dry-run   # full pipeline preview
```

The smoke check used by CI and pre-commit:
```bash
shellcheck format-usb.sh && bash -n format-usb.sh
```

---

## Key Files

| File | Purpose |
|------|---------|
| `format-usb.sh` | The utility itself |
| `CLAUDE.md` | This file |
| `.github/workflows/ci.yml` | Runs shellcheck + bash -n on PR |
| `.github/workflows/release.yml` | workflow_dispatch tagging |
| `.github/workflows/deploy-pages.yml` | Pushes website/ to GitHub Pages |
| `.githooks/pre-commit` | shellcheck + bash -n locally |
| `.githooks/commit-msg` | Conventional Commits enforcement |
| `scripts/install-hooks.sh` | One-time hook installer |
| `scripts/setup-repo.sh` | One-time branch protection + CODEOWNERS |

---

## Starting a New Session

1. Read this file
2. Run `shellcheck format-usb.sh && bash -n format-usb.sh` to confirm clean state
3. Invoke `superpowers:brainstorming` before touching any feature
4. Follow the Required Skills table — every skill is mandatory
