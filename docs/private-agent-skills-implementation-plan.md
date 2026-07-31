# Private agent skills implementation plan

Status: active implementation coordination for `feat/private-agent-skills`.

The canonical architecture remains [issue 27](https://github.com/brendanlees/dotfiles/issues/27) and its closed decision tickets. This plan sequences implementation without restating those decisions. Remove this plan after rollout handoff is complete; the issue map and operator documentation remain authoritative.

## Current progress

- Steps 1 through 7 are implemented on `feat/private-agent-skills` with synthetic POSIX and Windows contracts.
- Step 8 passes locally and in pull request CI, including the focused POSIX suite, routing and agent-home regressions, static checks, template rendering, full repository suite, macOS dry-run, native Windows parsing, and the Windows junction lifecycle contract.
- Steps 9 and 10 remain pending and require sanitized live macOS and Windows canaries on authorized machines.
- The merge and rollout gate remains closed until both live canaries pass.

## Safety boundaries

- Use generated sentinel remotes, paths, skill names, and content in all public tests and logs.
- Never add the real private host, repository, checkout path, inventory, content, credentials, or audit findings to this repository, Git history, CI output, or public issue comments.
- Keep the existing `~/.agents` symlink and public skill ownership unchanged.
- Treat the private checkout as source data. Treat generated links, junctions, exact local excludes, and the ownership ledger as disposable integration state.
- Make all private integration failures non-fatal to unrelated Chezmoi work.
- Do not merge or start multi-machine rollout until the automated contracts and both live platform gates pass.

## Planned implementation surface

Use the existing per-apply helper pattern rather than a daemon or Git updater.

| Area | Planned files |
| --- | --- |
| Machine-local input | `.chezmoi.toml.tmpl` |
| Platform routing | `.chezmoiignore` |
| macOS lifecycle helper | `dot_local/bin/executable_cz-private-agent-skills.tmpl` |
| Windows lifecycle helper | `dot_local/bin/executable_cz-private-agent-skills.ps1.tmpl` |
| Per-apply invocation | `.chezmoiscripts/darwin/run_after_reconcile-private-agent-skills.sh.tmpl`, `.chezmoiscripts/windows/run_after_reconcile-private-agent-skills.ps1.tmpl` |
| Disposable ownership state | `agents/state/private-agent-skills.json` at runtime, already excluded from public Git |
| Synthetic contracts | `tests/chezmoi/test-private-agent-skills.sh`, `tests/chezmoi/test-private-agent-skills-windows.ps1`, focused confidentiality and routing assertions where separation improves failure diagnosis |
| Windows CI execution | `.github/workflows/ci.yml` and `tests/ci/check-powershell.ps1` only as needed |
| Operator documentation | `docs/private-agent-skills.md`, `README.md` |

The lifecycle helpers expose only the integration operations needed by [issues 31](https://github.com/brendanlees/dotfiles/issues/31), [33](https://github.com/brendanlees/dotfiles/issues/33), and [36](https://github.com/brendanlees/dotfiles/issues/36): reconcile, deactivate, and explicitly confirmed finalize. They do not wrap normal private Git authoring or remote maintenance.

## Implementation sequence

### 1. Pin synthetic confidentiality and eligibility contracts

Authority: [cross-platform acceptance contract](https://github.com/brendanlees/dotfiles/issues/34).

1. Add a sentinel fixture that creates isolated public and private Git repositories, a temporary home, machine-local Chezmoi data, and an unrelated target file.
2. Generate all confidentiality sentinels at runtime so their values are absent from tracked test source.
3. Add the negative eligibility matrix first:
   - blank configuration;
   - `personal=false` on macOS and Windows;
   - `personal=true` on unsupported Linux, including a homelab-shaped fixture.
4. Assert that negative cases create no checkout, composition entry, local exclude, prompt-derived value, or ownership state.
5. Add public-boundary assertions covering tracked files, current Git history, public Git cleanliness, exact-only `.git/info/exclude` records, and absence of sentinel content from generated public inventory and test output.
6. Add the Windows test entry point to the Windows CI job so junction behavior is executed, not merely parsed.

Gate: the contracts fail only because lifecycle behavior is not implemented, while the fixture itself leaves no sentinel values or artifacts outside its temporary directory.

### 2. Add machine-local configuration inputs

Authority: [personal-scope bootstrap](https://github.com/brendanlees/dotfiles/issues/31) and [Gitea authentication](https://github.com/brendanlees/dotfiles/issues/30).

1. Add optional generic fields for the SSH remote and absolute checkout path to `.chezmoi.toml.tmpl`.
2. Prompt only during eligible interactive personal initialization on macOS or Windows. A blank remote leaves the integration unconfigured.
3. Accept the same fields from noninteractive Chezmoi data without introducing a second authorization flag.
4. Validate in the platform helper, before mutation:
   - eligible personal scope and supported OS;
   - both fields present;
   - SSH-only repository addressing;
   - normalized absolute checkout path;
   - checkout outside the public Chezmoi source tree and unified agent home.
5. Update `.chezmoiignore` so each platform receives only its own helper and per-apply script.

Gate: focused render tests prove values remain machine-local and every negative eligibility case is a no-op.

### 3. Implement minimal non-authoritative ownership state

Authority: [composition topology](https://github.com/brendanlees/dotfiles/issues/29), [failure and recovery](https://github.com/brendanlees/dotfiles/issues/33), and [rollout](https://github.com/brendanlees/dotfiles/issues/36).

1. Store a versioned JSON ledger at runtime under `agents/state/`.
2. Record only what is required to prove ownership and recover deactivation:
   - schema version;
   - generated destination and expected source target for each entry;
   - exact local exclude line owned for each entry;
   - decommission-pending status and recorded checkout only when required for two-phase finalization.
3. Write the ledger atomically through a same-directory temporary file and rename.
4. Reject an unknown schema or malformed ledger without changing links, junctions, excludes, or checkout content.
5. Never use the ledger as authorization, inventory truth, or a backup. Current direct private inventory remains authoritative when reconciliation is safe.

Gate: tests cover first write, unchanged second write, malformed state, stale state, and ownership proof without exposing sentinel values in public Git status.

### 4. Implement macOS per-apply reconciliation

Authority: [issues 29](https://github.com/brendanlees/dotfiles/issues/29), [31](https://github.com/brendanlees/dotfiles/issues/31), and [33](https://github.com/brendanlees/dotfiles/issues/33).

1. Render a macOS helper with generic machine-local values and a `run_after` script that invokes reconcile on every apply.
2. For an absent checkout, clone the configured SSH remote into a unique temporary sibling, validate it, then atomically rename it into place. Remove only the temporary sibling after failure.
3. For an existing checkout, verify Git worktree identity and configured remote without fetching, pulling, resetting, cleaning, switching, or rewriting the remote.
4. Detect interrupted Git operations and preserve current composition unchanged.
5. Inventory only direct `skills/<name>/SKILL.md` directories. Validate names and preflight every destination before any mutation.
6. Create direct directory symlinks, then add only exact generated paths to `.git/info/exclude` and update the ledger.
7. Preserve correct owned entries, repair missing or broken owned entries, and remove stale proven-owned links and excludes without following targets.
8. On collision, remote mismatch, invalid checkout, uncertain ownership, or clone failure, emit an actionable warning and return success to the wider apply.

Gate: the focused POSIX suite passes bootstrap, idempotence, non-maintenance, inventory, dirty-worktree, interrupted-operation, collision, repair, stale cleanup, clone-failure, and unrelated-apply scenarios.

### 5. Implement Windows per-apply reconciliation

Authority: the same lifecycle decisions plus the Windows requirements in [issue 34](https://github.com/brendanlees/dotfiles/issues/34).

1. Implement the PowerShell helper with behavior equivalent to the macOS contract.
2. Use directory junctions for direct skill entries and inspect reparse-point ownership without traversing or deleting the target.
3. Use temporary-sibling clone and atomic move behavior appropriate to the configured Windows volume.
4. Preserve PowerShell native-command failures as integration warnings while allowing the wider apply to continue.
5. Execute the synthetic Windows lifecycle suite on `windows-2025`, including junction creation, ownership checks, safe removal, and target preservation.

Gate: Windows functional tests pass on the hosted Windows runner, and static plus rendered PowerShell parsing remains green.

### 6. Complete failure, repair, deactivation, and finalization paths

Authority: [failure and recovery](https://github.com/brendanlees/dotfiles/issues/33) and [rollout and rollback](https://github.com/brendanlees/dotfiles/issues/36).

1. Make `reconcile` fail closed within the integration while returning success to automatic per-apply callers. Provide a fail-hard test mode only if required for deterministic focused tests.
2. Make `deactivate` remove only ledger-proven links or junctions and exact excludes, preserve the checkout and configuration, and persist decommission-pending state.
3. Allow reactivation before purge by validating configuration and rebuilding current direct inventory.
4. Make `finalize` refuse to delete anything unless:
   - deactivation is complete and pending;
   - the recorded checkout still passes path and identity checks;
   - the operator supplies the documented explicit confirmation;
   - no unexpected integration destinations remain.
5. On confirmed finalization, delete only the recorded checkout, then clear machine-local private configuration and disposable state. If clearing configuration cannot be completed safely, report deauthorization as incomplete.
6. Add tests for remote unavailability, ordinary dirty state, interrupted Git state, malformed checkout, remote mismatch, uncertain ownership, deactivation reversal, rejected finalization, confirmed finalization, and partial-failure recovery.

Gate: every lifecycle scenario in issue 34 has a synthetic assertion on each applicable platform, and checkout content is unchanged by every path except confirmed finalization.

### 7. Add operator documentation

Authority: [authoring and audit workflow](https://github.com/brendanlees/dotfiles/issues/32), [failure and recovery](https://github.com/brendanlees/dotfiles/issues/33), and [rollout](https://github.com/brendanlees/dotfiles/issues/36).

Create `docs/private-agent-skills.md` with placeholders only and link it from `README.md`. Include:

- eligibility, direct `skills/` layout, SSH-only remote, and checkout-path rules;
- interactive and noninteractive setup;
- explicit private Git edit, status, pull, commit, and push workflow;
- direct-checkout SkillSpector commands and scan triggers;
- collision, authentication, invalid-checkout, and interrupted-Git recovery;
- deactivation, implementation rollback, reactivation, and confirmed permanent deauthorization;
- automated checks and sanitized macOS and Windows canary checklists;
- the explicit exclusion of the first real private skill and homelab deployment.

Gate: commands are exercised against sentinel fixtures where possible, links resolve, and documentation contains no real private values.

### 8. Run focused and full repository verification

Run in this order and record exact results:

```sh
bash tests/ci/run-chezmoi-tests.sh tests/chezmoi/test-private-agent-skills.sh
bash tests/ci/run-chezmoi-tests.sh tests/chezmoi/test-role-routing.sh tests/chezmoi/test-agents-home.sh
bash tests/ci/check-static.sh
bash tests/ci/run-chezmoi-tests.sh
```

Also run the documented template render/lint command from `docs/testing.md`, the Windows functional test in Windows CI, and the existing macOS dry-run job. Finish with:

```sh
git diff --check
git status --short --branch
```

Gate: all public CI jobs pass with no private data or unexpected generated files.

### 9. Run the live macOS branch canary

Authority: live gate in [issue 34](https://github.com/brendanlees/dotfiles/issues/34).

1. Capture the clean public checkout, skill-entry, and local-exclude baseline.
2. Apply `feat/private-agent-skills` with machine-local real values.
3. Complete the full macOS live gate, including two applies, Pi/Codex/Claude discovery, edit ownership, direct-checkout SkillSpector, and fail-closed remote authentication.
4. Exercise deactivation and reactivation. Preserve the real checkout.
5. Record only sanitized OS/tool versions, commands, and pass/fail outcomes. Keep identities, paths, skill names, content, and findings private.

Gate: every macOS live scenario passes. Any behavioral fix returns to focused and full automated verification before repeating affected live scenarios.

### 10. Run the live Windows branch canary

Authority: live gate in [issue 34](https://github.com/brendanlees/dotfiles/issues/34).

1. Repeat the clean baseline and branch apply on one authorized Windows machine.
2. Complete the full Windows live gate at the configured path.
3. Explicitly prove real directory-junction discovery and safe removal while private files remain intact.
4. Record only sanitized evidence using the same restrictions as macOS.

Gate: every Windows live scenario passes. Do not merge until both platform gates and all automated checks are green.

## Merge and rollout gate

After both canaries pass:

1. Review the branch for sentinel-only public content and confirm no private identity entered any commit.
2. Deactivate any canary integration before a branch rollback. Never revert implementation first.
3. Merge only the generic mechanism, tests, and operator documentation.
4. Activate one authorized personal machine at a time and repeat the documented per-machine checks.
5. Keep the first real private skill and all homelab-device deployment as separate work.
