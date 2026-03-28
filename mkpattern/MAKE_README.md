# Makefile Pattern Overview

This repo uses a small, modular make pattern you can re‑use across projects.

## Files

- `makefile` (root): Core targets and module includes. Small, reusable, non‑project specific.
- `project.mk` (optional): Project configuration only (variables, not targets).
- `makefile-semv.mk` (optional): semv integration (versioning, sync, bump). Auto‑gated.
- `makefile-bug.mk` (optional): Bug mode lock and guard.
- `makefile-project.mk` (optional): Project‑specific extra targets (only for this repo).
- `mkpattern/` (templates): Copies of the above you can port to other repos.

## Include Order

1. `project.mk` — sets variables (e.g., INSTALL_DIR, SEMV_*), overrides defaults.
2. `makefile-bug.mk` — adds bug mode (on/off/status) and guard.
3. `makefile-semv.mk` — adds semv targets if semv is available and compatible.
4. `makefile-project.mk` — adds repo‑specific targets if present.

All includes are `-include`, so missing files are fine.

## Core Targets (always present)

- `lint-sh`: Lint shell scripts (`bash -n`; `shellcheck` if installed)
- `lint`: Alias for `lint-sh`
- `test`: List available tests via `bin/test.sh`
- `deploy`: Delegate to `bin/deploy.sh`
- `deploy-tag`: Deploy from a specific tag: `make deploy-tag TAG=vX.Y.Z`
  - Enforces current HEAD matches the tag and working tree is clean by default
  - Override with `ENFORCE_TAG=0` and/or `ALLOW_DIRTY=1` if needed
- `install`: Alias for `deploy`
- `help`: Print available targets and show which modules are active

## Bug Lock Module (makefile-bug.mk)

Provides a simple deployment lock that persists via a state file.

- `bug:on` / `bug:off` / `bug:status` — enable/disable/check bug mode
- `guard:bug-off` — prerequisite that fails when bug mode is ON
- Config: `BUG_STATE_FILE ?= .bugmode` (override in `project.mk`)
- Core `deploy` target is guarded by `guard:bug-off`

## semv Module (makefile-semv.mk)

Gates all semv functionality behind one detection step per make run.

- Detection: `semv.detect` writes `.semv.cache` with:
  - `SEMV_UNAVAIL=0/1` and `SEMV_VERSION=x.y.z`
  - Compatibility policy via vars: `SEMV_MIN_SUPPORT`, `SEMV_COMPAT=major|min|exact`
- Init: `semv.init` runs `semv new` only when `SEMV_AUTO_INIT=1`
- Version ops:
  - `version`, `version.next`, `version.tag`, `version.pend`, `version.file`
  - `version.sync` consolidates version sources (`semv sync`)
  - `version.get.bash`, `version.set.bash VER=…`, `version.sync.bash` support script headers
  - `publish` — cut/tag a version via `semv bump` then run `make deploy`
    - Knobs: `DRY=1` to add `--dry-run`; `DEV=1` to add `--dev`
    - Guarded by bug lock if available

Configure in `project.mk`:

```
# semv knobs
SEMV_MIN_SUPPORT := 1.0.0
SEMV_COMPAT := major         # or min / exact
SEMV_AUTO_INIT := 0          # set to 1 to allow auto semv new
SEMV_BASH_FILES := bin/deploy.sh
```

## Typical Workflows

- Lint: `make lint`
- Tests: `make test`
- Version status: `make version` (requires semv module active)
- Sync versions: `make version:sync` (requires semv)
- Show bash script versions: `make version:get:bash` (set `SEMV_BASH_FILES`)
- Publish (cut + deploy): `make publish` (with `DRY=1` to preview)
- Deploy from tag: `make deploy-tag TAG=vX.Y.Z`

## Reusing in Other Repos

- Copy files from `mkpattern/`:
  - `makefile`, `makefile-semv.mk`, `makefile-bug.mk` and optionally `project.mk.example` → rename to `project.mk`
  - If you need repo‑specific targets, add `makefile-project.mk`
- Adjust `project.mk` variables for your repo.
- Done. The core remains the same across repos.

## Notes

- All modules are optional; base targets work without semv or project files.
- `semv` detection runs once per make invocation; other semv targets read `.semv.cache`.
- You can expand the pattern with additional modules using the same include/gate approach.

## CI Considerations

- Suggested order: `make lint` → `make test` → `make bug.status` → `make version` (if semv available).
- Use `make publish DRY=1` on non-main branches for preview; only run real publish on main/protected branches.
- For releasing from tags: checkout the tag and run `make deploy-tag TAG=vX.Y.Z`.
- Ensure `semv` is installed on the runner; otherwise semv targets no-op and `publish` is disabled.
- Fetch tags in CI: `git fetch --tags` (publish also runs `semv fetch`).
- Env knobs: `DRY=1`, `DEV=1`, `SEMV_AUTO_INIT=1`, `ENFORCE_TAG=0`, `ALLOW_DIRTY=1` as needed.
- No need to cache `.semv.cache`; it’s regenerated per run.
