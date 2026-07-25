# CI and Test Modernization Design

## Context

The repository currently has one GitHub Actions workflow at `.github/workflows/ci.yml`. It runs shell linting, template rendering, Linux and macOS dry-runs, YAML/TOML linting, banned-pattern checks, and plist linting. Recent successful runs complete in roughly 15 seconds.

The repository also has 30 standalone shell tests under `tests/chezmoi/`, but CI does not invoke them. A local baseline from `main` produced 14 passes and 16 failures in 45 seconds. Investigation found that the failures primarily represent test drift and undeclared runtime contracts:

- SketchyBar tests predate later item, order, color, and border changes.
- Tests still reference two deliberately deleted production files.
- Role and instruction fixtures lag current required data.
- Herdr tests assume Python 3.11 or newer for `tomllib`, while that dependency is undocumented.
- The SSH test can invoke macOS Bash 3 despite using syntax that requires modern Bash.

A concurrent branch, `feat/add-terminal-themes`, already contains several relevant test-repair commits. Implementation of this design must start after that branch is merged, or after the implementation branch is rebased onto it, to avoid duplicating or reverting its work.

## Goals

- Make every maintained repository test a required CI check.
- Restore a trustworthy green baseline by reconciling tests with current intended behavior.
- Add focused coverage for workflows, rendered data, roles, and Windows PowerShell.
- Reduce duplicated inline workflow logic and make CI checks locally runnable.
- Pin actions and tools sufficiently for reproducible, reviewable updates.
- Preserve fast, easy-to-diagnose feedback across Linux, macOS, and focused Windows checks.
- Keep CI documentation synchronized with actual behavior.

## Non-goals

- Rewriting the shell suite into a third-party test framework.
- Achieving equivalent test matrices on every operating system.
- Adding coverage percentages, broad security platforms, test sharding, or caches without a measured need.
- Testing real secrets, contacting Bitwarden, or applying dotfiles to a real user home.
- Refactoring unrelated production configuration.

## Workflow architecture

Retain one workflow, `.github/workflows/ci.yml`, with five bounded jobs.

### 1. Policy and lint

This Ubuntu job performs checks that do not require a rendered chezmoi source:

- Validate GitHub Actions syntax and expressions with `actionlint`.
- Run ShellCheck over tracked static shell files.
- Lint tracked YAML and TOML files.
- Parse tracked JSON files.
- Run the banned-pattern policy checks.
- Reject every `uses:` reference that is not a full commit SHA, while permitting a human-readable version comment.

The job must not install chezmoi merely to run static checks.

### 2. Repository tests

This Ubuntu job installs the declared runtime dependencies once and invokes a shared runner for every maintained `tests/chezmoi/test-*.sh` script. The environment must provide modern Bash, Python 3.11 or newer, chezmoi, jq, and any other dependency explicitly discovered while restoring the suite.

The runner executes tests serially in sorted order, continues after failures, records durations, prints an aggregate summary, and exits nonzero if any test fails. It may accept an explicit list of tests for focused local runs. Parallel execution is excluded until test isolation and runtime justify it.

### 3. Template smoke

This Ubuntu job owns the complete rendered-template validation path:

- Initialize a noninteractive `ephemeral,headless` chezmoi configuration.
- Render the supported template inventory once.
- Keep init-only template exclusions in one explicit, documented list.
- Require nonempty rendered shell templates to begin with a shebang.
- ShellCheck rendered shell output.
- Lint rendered YAML and TOML output.
- Parse rendered JSON output.

Repository-owned scripts under `tests/ci/` hold substantial discovery, rendering, and validation logic so the same behavior can run locally. Workflow YAML remains responsible for orchestration and environment setup.

### 4. Apply dry-run

Preserve the Ubuntu and macOS matrix. Each matrix leg initializes the same noninteractive role and runs `chezmoi apply --dry-run --verbose --exclude=externals` against an isolated runner home.

This remains separate from template smoke because it validates chezmoi target-state behavior on both supported Unix platforms.

### 5. Focused Windows

Add a Windows job that:

- Parses tracked static PowerShell files with PowerShell's built-in AST parser.
- Renders relevant `.ps1.tmpl` files using explicit Windows and representative role data.
- Parses each nonempty rendered result with the same AST parser.
- Runs focused Windows target-selection or ignore-routing assertions where they can execute natively without duplicating the complete Unix suite.

This job is not a full Windows apply parity matrix.

## Test-suite reconciliation

After rebasing onto the concurrent theme branch, run the complete suite again and investigate every remaining failure before changing assertions.

Use these rules:

- Remove a test only when repository history confirms its production feature was deliberately removed.
- Update stale expectations only after comparing them with current intended production behavior.
- Complete fixtures when templates gained required data keys.
- Prefer focused structural and behavioral assertions over exact whole-file snapshots when exact text is not the contract.
- Keep temporary homes, fake executables, and mocked external-service responses isolated.
- Make interpreter and tool requirements explicit rather than relying on the developer machine's defaults.
- Do not suppress a failing test merely to make CI green.

## Additional coverage

Add the following focused coverage because it addresses observed gaps:

- Workflow syntax and expression validation through `actionlint`.
- Static and rendered JSON parsing.
- Native Windows parsing for static and rendered PowerShell.
- Role-routing smoke cases for representative `ephemeral,headless`, `personal`, `work`, and `homelab` data without secret access.
- A small test of the shared runner proving that it reports multiple failures and returns a failing aggregate status.
- A policy test requiring full-SHA action references.

Coverage must remain behavioral and risk-based. New checks should have a clear failure mode and maintenance owner in the repository.

## Dependency and update policy

- Pin GitHub Actions to full commit SHAs and retain version comments.
- Pin downloaded CLI tools to explicit versions near the top of the workflow or installer script.
- Verify release checksums where practical for directly downloaded binaries.
- Avoid `latest` release URLs and unversioned package installs.
- Add weekly grouped Dependabot updates for the `github-actions` ecosystem.
- Document the manual process for updating pinned CLI versions and checksums.

Before implementation, consult current documentation for each action or third-party tool whose API, inputs, or installation method is changed.

## Efficiency and failure handling

- Add workflow concurrency keyed by workflow and pull-request or branch identity, with cancellation of superseded in-progress runs.
- Set an explicit timeout on every job.
- Keep jobs independent so one failure does not hide unrelated results.
- Avoid duplicate template rendering by assigning rendered linting to the template-smoke job only.
- Install test dependencies once in the repository-test job.
- Do not add caching, artifact handoff, path filters, or test sharding unless measured runtime demonstrates a need.
- Emit concise `RUN`, `PASS`, and `FAIL` output with durations.
- Use GitHub error annotations where a specific file can be identified.
- Preserve all failed test names in the aggregate summary rather than stopping at the first failure.

The target is reliable feedback within a few minutes, not optimization below the current 15-second workflow at the cost of complexity.

## Documentation

Update `docs/testing.md` to describe:

- Every CI job and its platform.
- The local commands for static lint, template smoke, the complete test suite, focused tests, and dry-runs.
- Required local runtime versions.
- Template exclusions and why they exist.
- The action and CLI update process.
- The distinction between cross-platform rendering and native Windows validation.

Keep the existing README link to the testing guide rather than duplicating these details.

## Delivery sequence

1. Merge `feat/add-terminal-themes`, or rebase the implementation branch onto it.
2. Re-run and classify the complete baseline.
3. Restore a green maintained test suite using the reconciliation rules.
4. Add and test the shared repository test runner.
5. Extract template and policy logic into focused `tests/ci/` scripts.
6. Refactor the workflow into the five approved jobs.
7. Add focused Windows and additional coverage.
8. Pin dependencies and add grouped GitHub Actions updates.
9. Update documentation.
10. Run all local checks available on the host, validate workflow syntax, and review the final workflow diff before completion.

## Acceptance criteria

- Every maintained `tests/chezmoi/test-*.sh` test runs and passes in CI.
- The shared runner demonstrates aggregate failure reporting and supports focused local execution.
- Static and rendered shell, YAML, TOML, and JSON checks are locally reproducible.
- Ubuntu and macOS dry-runs pass.
- Native Windows PowerShell parsing passes for static and rendered files.
- Representative role-routing smoke cases pass without real secret access.
- `actionlint` passes and all action references use full commit SHAs.
- Tools and actions use explicit versions, with checksum verification for practical direct downloads.
- Superseded runs cancel and every job has a timeout.
- `docs/testing.md` matches the implemented workflow and local commands.
- No cache, sharding, or reusable-workflow layer is added without new runtime evidence.
