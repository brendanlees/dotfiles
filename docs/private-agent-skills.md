# Private agent skills

This runbook is for operators of authorized personal macOS and Windows machines. The public repository contains only the integration mechanism. Keep the real remote, checkout path, skill names, inventory, content, credentials, and audit findings in machine-local or private records.

## Validated rollout scope

Initial live acceptance covers authorized personal macOS integration with Pi and Codex. Automated CI additionally covers the synthetic POSIX lifecycle, native Windows parsing, and the Windows junction lifecycle.

Claude Code live discovery and live Windows SSH bootstrap are deferred follow-up scope. The implementation remains available on Windows, but operators must complete the platform checklist below before treating it as live-validated. These deferred checks do not block the initial macOS rollout.

## Eligibility and layout

Integration is active only when all of these are true:

- Chezmoi data has `personal = true`.
- The operating system is macOS or Windows.
- Both machine-local configuration fields are present and valid.
- The repository remote uses SSH, either `ssh://...` or `user@host:path` form.
- The checkout path is absolute, has an existing parent, and is outside the public Chezmoi source tree and `~/.agents`.

The private repository has this direct layout:

```text
<private-checkout>/
  skills/
    <skill-name>/
      SKILL.md
```

Only direct directories containing `SKILL.md` are deployed. Put drafts and nested material elsewhere. A private skill name must not collide with any public or unmanaged entry under `~/.agents/skills`.

The integration creates direct directory symlinks on macOS and directory junctions on Windows. It does not change the existing `~/.agents` symlink or public skill ownership.

## Configure

### Interactive initialization

On an eligible personal machine, run:

```sh
chezmoi init
```

Enter the SSH clone remote and absolute checkout path when prompted. Leaving the remote blank disables integration. The values are cached only in the machine's Chezmoi configuration.

### Noninteractive initialization

Add the following machine-local section to the Chezmoi configuration before initialization or apply. Never add real values to the public source repository.

```toml
[data.private_agent_skills]
remote = "<SSH-REMOTE>"
checkout = "<ABSOLUTE-CHECKOUT-PATH>"
```

Then run:

```sh
chezmoi init --no-tty
chezmoi apply
```

On Windows, use the same TOML section and run the commands from PowerShell. Escape backslashes as required by TOML or use a fully qualified path with forward slashes.

A missing checkout is cloned once through SSH into a temporary sibling and moved into place. Every later apply validates and reconciles it without fetching, pulling, resetting, cleaning, switching branches, or rewriting the remote.

## Author and synchronize

The private checkout is the canonical Git worktree. Editing through either the checkout or `~/.agents/skills/<name>` changes the same private files.

Use ordinary Git from the private checkout:

```sh
cd "<PRIVATE-CHECKOUT>"
git status --short --branch
git pull --ff-only
# edit and run skill-specific tests or evals
git diff --check
git diff --stat
git add skills/<SKILL-NAME>
git commit -m "<CONVENTIONAL-COMMIT>"
git push
```

After adding or removing a direct skill, run `chezmoi apply` to reconcile discovery entries. Content-only edits need no reconciliation. Before committing, confirm the repository root is the private checkout:

```sh
git rev-parse --show-toplevel
git status --short --branch
```

Public Git should remain clean:

```sh
chezmoi cd
git status --short --branch
```

## Audit with SkillSpector

Scan the private checkout directly, not the unified linked surface:

```sh
skillspector scan "<PRIVATE-CHECKOUT>" --recursive --no-llm
```

Run a scan for every new or imported skill and after substantive changes to instructions, scripts, dependencies, or bundled resources. Cosmetic-only edits do not require a scan. Keep real reports and findings out of public logs and artifacts.

## Warnings and recovery

Private integration warnings do not fail unrelated Chezmoi work. The integration fails closed and preserves source content.

- **Authentication or clone failure:** unlock Bitwarden, confirm its SSH agent is available, refresh the existing SSH manifest with `cz-ssh-refresh`, verify the configured SSH alias, then apply again. There is no HTTPS, token, alternate-key, or credential-helper fallback.
- **Existing remote unavailable:** local discovery and editing continue. Recover SSH before an explicit fetch, pull, or push.
- **Invalid checkout or remote mismatch:** inspect `git rev-parse --show-toplevel` and `git remote get-url origin`. The helper never rewrites the remote.
- **Interrupted merge, rebase, cherry-pick, revert, bisect, or sequencer operation:** recover with ordinary Git, then apply again. Composition remains unchanged while recovery is pending.
- **Name collision or uncertain ownership:** inspect the reported destination. Move or remove only the unmanaged collision after proving its ownership. The helper never adopts, backs up, replaces, or deletes unexpected entries.
- **Malformed ownership state:** inspect or remove `agents/state/private-agent-skills.json` only after manually removing any generated links or junctions and exact local excludes. Do not guess ownership.
- **Broken owned entry:** apply again. A ledger-proven missing or broken entry is repaired when its source remains valid.

## Deactivate, roll back, and reactivate

Deactivate before returning Chezmoi to a branch that lacks this implementation.

macOS:

```sh
cz-private-agent-skills deactivate
```

Windows:

```powershell
cz-private-agent-skills.ps1 deactivate
```

Deactivation removes only ledger-proven links or junctions and exact local excludes. It preserves the private checkout and machine-local configuration, and records decommissioning as pending.

Verify public skills and Git status, then roll the source branch back if needed. To reactivate before permanent deletion, keep or restore the eligible configuration and run `chezmoi apply`.

### Permanent deauthorization

First deactivate. Synchronize or explicitly export every private change you intend to keep. Finalization permanently deletes the recorded checkout, clears the machine-local configuration section, and removes disposable state.

macOS:

```sh
cz-private-agent-skills finalize --confirm-delete
```

Windows:

```powershell
cz-private-agent-skills.ps1 finalize --confirm-delete
```

Finalization refuses to run without completed deactivation, exact confirmation, checkout identity proof, and absence of integration destinations and excludes. It never creates an automatic plaintext backup.

## Automated checks

From the public repository:

```sh
bash tests/ci/run-chezmoi-tests.sh tests/chezmoi/test-private-agent-skills.sh
bash tests/ci/run-chezmoi-tests.sh tests/chezmoi/test-role-routing.sh tests/chezmoi/test-agents-home.sh
bash tests/ci/check-static.sh
bash tests/ci/run-chezmoi-tests.sh
```

Windows CI additionally runs:

```powershell
pwsh -NoProfile -File tests/chezmoi/test-private-agent-skills-windows.ps1
```

See [testing](testing.md) for template render and dry-run commands.

## Sanitized live validation checklist

Record only OS and tool versions, commands, and pass/fail outcomes. Do not record real identities, paths, skill names, content, credentials, or findings.

For each newly authorized platform or agent harness:

1. Capture clean public Git, current direct skill entries, and local-exclude baselines.
2. Apply the current source and verify SSH bootstrap.
3. Apply a second time and verify idempotence.
4. Invoke a benign private probe through every in-scope agent harness.
5. Edit through the unified path and verify only private Git becomes dirty.
6. Scan the private checkout directly with SkillSpector and review results privately.
7. Disable remote authentication and verify local discovery still works while explicit remote Git fails with no fallback.
8. Deactivate and reactivate. Verify source content remains intact.
9. On Windows, explicitly verify junction creation and removal preserves private files.
10. Confirm public Git and tracked inventory remain clean.

Automated contracts and an authorized macOS canary with Pi and Codex form the initial acceptance scope. Do not claim Claude Code or live Windows validation until the applicable checklist passes. Deploying private skills to homelab devices remains separate work.
