# Dotfiles Repo Review and Remediation Plan

## Context

This repository is a declarative `chezmoi` setup used across personal, work, homelab, and ephemeral systems, with role-based rendering and cross-platform application.

---

## What Works Well

- Strong CI coverage for a dotfiles repo:
  - template render checks
  - dry-run apply on Linux and macOS
  - shell/yaml/toml/plist linting
  - Reference: `.github/workflows/ci.yml:12`
- Solid role-scoping architecture with centralized machine context:
  - Reference: `.chezmoi.toml.tmpl:5`
  - Reference: `docs/scoping.md:1`
- Reusable declarative data model (`defaults.yml`, package maps, theme registry):
  - Reference: `.chezmoidata/defaults.yml:1`
  - Reference: `.chezmoidata/packages-darwin.yml:1`
  - Reference: `.chezmoidata/themes.yml:1`
- Good use of shared templates for role merges:
  - Reference: `.chezmoitemplates/merge-by-role.tmpl:1`
- Good documentation hygiene and operational docs:
  - Reference: `README.md:21`
  - Reference: `docs/testing.md:1`

---

## Worth Refining

### Maintainability

- `CHEZMOI_ROLE=ephemeral` is documented but not parsed in role env parsing logic.
  - Parsing currently handles: personal/work/homelab/headless
  - Reference: `.chezmoi.toml.tmpl:25`
  - Reference: `docs/scoping.md:31`
- Default values are duplicated across config/data and can drift (`code_dir`, fonts).
  - Reference: `.chezmoidata/defaults.yml:1`
  - Reference: `.chezmoi.toml.tmpl:108`
- `merge-by-role` supports only base/personal/work; no homelab path in merge helper.
  - Reference: `.chezmoitemplates/merge-by-role.tmpl:10`

### Code Quality and Patterns

- Inconsistent shell strict mode style in Darwin scripts (`set -eufo pipefail`).
  - Reference: `.chezmoiscripts/darwin/run_onchange_after_configure-defaults.sh:3`
  - Reference: `.chezmoiscripts/darwin/run_onchange_after_configure-desktop.sh:3`
  - Reference: `.chezmoiscripts/darwin/run_onchange_after_configure-dock.sh:3`
  - Reference: `.chezmoiscripts/darwin/run_once_after_install-rosetta.sh:3`
- Potentially unused template artifact should be verified (`install-tmux-plugins`).
  - Reference: `.chezmoitemplates/install-tmux-plugins.sh.tmpl:1`

### Efficiency and Scalability

- Some shell helpers use repeated `find` traversal in interactive commands; this can degrade as directories grow.
  - Reference: `dot_zshrc.tmpl:178`
- Hardcoded host/user assumptions reduce portability for broader reuse.
  - Reference: `.chezmoi.toml.tmpl:35`
  - Reference: `dot_config/kanata/xbxd.kanata.plist:12`

### Security

- Multiple `curl | sh` bootstrap paths increase supply-chain risk surface.
  - Reference: `install.sh:9`
  - Reference: `.chezmoiscripts/run_once_install_mise.sh.tmpl:14`
- Floating CI action ref (`@master`) should be pinned.
  - Reference: `.github/workflows/ci.yml:18`
- Global `sudo` alias changes privilege semantics in non-obvious ways.
  - Reference: `dot_config/zsh/exact_aliases.d/general.zsh.tmpl:5`
- Secret handling alias with `chmod 777` is too permissive.
  - Reference: `dot_config/zsh/exact_aliases.d/docker.zsh.tmpl:17`
- Broad token export in interactive shell should be narrowed where possible.
  - Reference: `dot_zshrc.tmpl:19`

---

## What to Reconsider or Abandon

- Reconsider global alias override for `sudo`.
  - Replace with explicit helper command(s).
- Abandon `dp777` pattern for secrets/env editing.
  - Use `sudoedit`, temporary root-owned workflow, or strict 600/700 transitions only.
- Reconsider mutable tracked defaults for runtime theme switching.
  - Current approach edits tracked data directly.
  - Reference: `dot_local/bin/executable_theme:112`

---

## Prioritized Remediation Plan

## P0 (Immediate: security and correctness)

1. Parse `ephemeral` from `CHEZMOI_ROLE` in `.chezmoi.toml.tmpl`.
2. Remove global `sudo` alias; add explicit safe helper(s).
3. Remove `dp777` and enforce secure secret-permission workflow.
4. Pin floating action refs and reduce unverified bootstrap scripts.
5. Harden token export behavior and avoid unguarded env propagation.

Target files:
- `.chezmoi.toml.tmpl`
- `dot_config/zsh/exact_aliases.d/general.zsh.tmpl`
- `dot_config/zsh/exact_aliases.d/docker.zsh.tmpl`
- `.github/workflows/ci.yml`
- `.chezmoiscripts/run_once_install_mise.sh.tmpl`
- `install.sh`
- `dot_zshrc.tmpl`

## P1 (Near-term: consistency and maintainability)

1. Standardize shell strict mode (`set -euo pipefail`) in Darwin scripts.
2. Consolidate duplicated defaults into a single source of truth.
3. Extend `merge-by-role` to support `homelab` (and optionally `ephemeral`) role overlays.
4. Replace heavy `find` usage with `fd`-first fallbacks in interactive helpers.
5. Add CI guard checks for banned patterns (`chmod 777`, floating refs, unsafe curl pipes).

Target files:
- `.chezmoiscripts/darwin/*.sh`
- `.chezmoidata/defaults.yml`
- `.chezmoi.toml.tmpl`
- `.chezmoitemplates/merge-by-role.tmpl`
- `dot_zshrc.tmpl`
- `.github/workflows/ci.yml`

## P2 (Backlog: architecture and portability)

1. Decouple privileged daemon config from hardcoded user-home paths.
2. Move theme runtime override to host-local state/override file instead of mutating tracked defaults.
3. Prune unused templates/scripts or wire them explicitly.

Target files:
- `dot_config/kanata/xbxd.kanata.plist`
- `dot_config/kanata/scripts/executable_setup-mac-service.sh`
- `dot_local/bin/executable_theme`
- `.chezmoitemplates/install-tmux-plugins.sh.tmpl`

---

## Suggested Delivery Slices

- PR 1: P0 security hardening (`sudo`, `dp777`, token export, role parse fix)
- PR 2: P0 supply-chain hardening (pin refs, bootstrap hardening)
- PR 3: P1 consistency and template/data refactor
- PR 4: P2 daemon/theme architecture cleanup

---

## Success Criteria

- Role behavior and docs are aligned (including `ephemeral`).
- No world-writable secret flows remain.
- No floating action refs in CI.
- Bootstrap and install paths are more deterministic/verifiable.
- Reduced config drift risk from duplicate defaults.
- Improved portability across usernames/hosts.
