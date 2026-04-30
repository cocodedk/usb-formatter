# Contributing

Thanks for considering a contribution. This project is a single Bash script with strict safety invariants — keep changes small, focused, and tested on a real USB stick where the change touches the wipe/format pipeline.

## Local setup

```bash
git clone https://github.com/cocodedk/usb-formatter.git
cd usb-formatter
sudo apt install shellcheck     # or: dnf install shellcheck / pacman -S shellcheck
./scripts/install-hooks.sh
```

The hook installer wires `.githooks/` into `core.hooksPath` so pre-commit and commit-msg run locally.

## Local git config (recommended)

```bash
git config pull.rebase true
git config core.autocrlf input
git config push.autoSetupRemote true
git config init.defaultBranch main
```

## Verify locally

```bash
shellcheck format-usb.sh && bash -n format-usb.sh
```

For any change that touches the wipe/format pipeline, also run a real `--dry-run` against an actual USB device and confirm every step prints as expected:

```bash
./format-usb.sh /dev/sdX TEST --dry-run
```

## Branch naming

kebab-case after the prefix.

| Prefix      | Use for                                  | Commit type |
|-------------|------------------------------------------|-------------|
| `feature/`  | New flag, new format, new safety check   | `feat`      |
| `fix/`      | Bug fix                                  | `fix`       |
| `chore/`    | Tooling, deps, hooks, repo housekeeping  | `chore`     |
| `docs/`     | README, CLAUDE.md, website copy          | `docs`      |
| `refactor/` | Internal restructure, no behavior change | `refactor`  |
| `ci/`       | GitHub Actions, hooks, release pipeline  | `ci`        |

Examples: `feature/btrfs-support`, `fix/dry-run-still-mounts`, `docs/safety-section`.

## Commit messages

[Conventional Commits](https://www.conventionalcommits.org/) — enforced by the `commit-msg` hook.

Format:

```
<type>(<scope>): <short description>
```

Allowed types: `feat`, `fix`, `chore`, `docs`, `style`, `refactor`, `test`, `ci`, `build`, `perf`, `revert`.

Examples:

```
feat(format): add btrfs option behind --btrfs
fix(unmount): retry udisksctl once before falling back to umount
docs(readme): clarify required packages on Fedora
```

One logical change per commit. If a change has unrelated parts, split the commits.

## Pull request checklist

Before opening a PR, confirm:

- [ ] `shellcheck format-usb.sh && bash -n format-usb.sh` is clean
- [ ] Manual `--dry-run` against a real USB stick passes (mandatory if the wipe/format pipeline changed)
- [ ] No regressions to safety guards (removable check, mount/swap refusal, `YES` confirmation)
- [ ] `format-usb.sh` is still under 200 lines (or the new size is justified in the PR description)
- [ ] No emojis added to script output, code, or markdown
- [ ] Commit messages follow Conventional Commits

## Reporting security issues

Do not open a public issue. See [SECURITY.md](SECURITY.md).
