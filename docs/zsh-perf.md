# zsh performance

`home/dot_zshrc.tmpl` caches tool initialization to reduce shell startup work. Measure first visible prompt, first usable command line, and recurring command latency separately: an early placeholder improves only the first. Process costs vary with the machine and current load.

## changes vs. a default zshrc

| change                         | why                                                                                       |
| ------------------------------ | ----------------------------------------------------------------------------------------- |
| `_cached_eval` helper          | caches `tool init zsh` output to disk; reruns only when binary is newer                   |
| daily-only `compinit -u`       | full `$fpath` security scan once per 24h, `-C` fast path otherwise                        |
| `zsh-syntax-highlighting` last | must be sourced after all other widget-defining plugins or it silently fails to hook them |
| opt-in `zprof` profiler        | `ZPROF=1 zsh -ic exit` enables timing without polluting normal sessions                   |

## `_cached_eval`

```sh
_cached_eval <tag> <bin> <init-cmd…>
```

Writes `<init-cmd>` output to `$XDG_CACHE_HOME/zsh/init/<tag>.zsh` and sources it. The cache is invalidated when the resolved binary is newer than the cache. This does not track changed arguments, config files, or binary replacements preserving older timestamps. Generated code can still run subprocesses when sourced.

Atuin's generated init includes tmux/AI/PTY-proxy settings. Refresh its specific cache after changing those settings. The isolated trial below uses fresh caches, so no live-cache migration is needed. FTL maintains its own Starship cache when enabled; the ordinary Starship cache remains the fallback.

currently wraps: `mise`, `starship`, `fzf`, `atuin`, `carapace`, `wt`, `zoxide`.

### force a rebuild

Remove only the relevant generated init file, then open a new shell. For example, after an approved live Atuin configuration change:

```sh
rm -f -- "${XDG_CACHE_HOME:-$HOME/.cache}/zsh/init/atuin.zsh"
```

Do not clear live caches for the worktree-only trial.

## profiling

```sh
STARSHIP_FTL=0 ZPROF=1 zsh -ic exit 2>&1 | head -40
```

Shows initialization-function timing. Opting out of FTL keeps the report visible in a shell that exits before the first prompt. This does not measure terminal first paint or normal command latency. Run inside the disposable shell below to avoid using live history.

## Worktree-only Starship-FTL trial

For Brendan testing the prompt without applying this branch. The trial is limited to personal, non-headless macOS shells. `STARSHIP_FTL=0` opts out; missing-plugin, failed-initialization and unsuitable-terminal paths fall back to ordinary Starship. Transient prompts are not enabled.

From this worktree, prepare a disposable environment:

```sh
python3 tests/manual/starship-ftl-trial.py prepare --baseline-ref main
```

Requires the existing installed Zsh/tools and Zsh plugins. It downloads only the pinned FTL archive, renders baseline and trial configs, copies the installed plugins, and creates a 500-file Git fixture plus synthetic Atuin/Zsh history. Copy the printed `Prepared:` path:

```sh
trial=/private/tmp/starship-ftl-trial-REPLACE_WITH_PRINTED_SUFFIX
python3 tests/manual/starship-ftl-trial.py shell "$trial" --mode ftl
```

Use `exit` to return. To compare:

```sh
python3 tests/manual/starship-ftl-trial.py shell "$trial" --mode off
python3 tests/manual/starship-ftl-trial.py shell "$trial" --mode baseline
```

- `baseline`: templates/config from the captured baseline commit.
- `off`: this worktree's three tuning changes, FTL disabled.
- `ftl`: this worktree with FTL and all three tuning changes.

Each has its own HOME, init caches, history databases and daemon socket. Atuin sync/update checks are disabled and its sandbox daemon is stopped on normal launcher exit. User aliases, credentials/token lookup, login files, inherited tool-manager state, TMUX and terminal-specific integration are deliberately omitted. Do not run sensitive commands, import real history, use `chezmoi apply`, or source the live `.zshrc` for this trial. Preparation snapshots the templates; prepare again after editing them.

### Personal checks

In the `ftl` shell:

1. Watch the early `❯`, then the right prompt. Type a short command immediately on launch: input should be retained, not executed before the shell is ready.
2. Run `false`, then `echo $?`: expect the error character and status `1`. Press Escape / `i` to check the vi command/insert characters; try Ctrl-C and a multiline command.
3. Type `echo trial-local` for a local-history suggestion; clear it and type `echo trial-atuin` for the seeded Atuin fallback. Ctrl-R and Up should open Atuin inline; cancel and check the prompt/buffer.
4. Check the effective choices and bindings:
   ```zsh
   print -rl -- $ZSH_AUTOSUGGEST_STRATEGY
   print -r -- "popup=${ATUIN_TMUX_POPUP:-default}"
   bindkey -M viins '^R'
   bindkey -M viins '^[[A'
   ```
   Expect `history` then `atuin`, `popup=false`, and Atuin widgets.
5. Check Tab/fzf-tab, suggestions and syntax highlighting. Resize a narrow window; try a long wrapped command, a cancelled search and fast Enter/Ctrl-C sequences. Repeat the launcher in Ghostty and Herdr. No actual tmux-popup transport is exercised because the launcher does not inherit TMUX.
6. Compare with `off`. If flicker, lost input, duplicate prompts or broken widgets appear only with FTL, retain the tuning changes but leave FTL disabled. Do not merely judge the time until the right prompt fills in.

### Reproducible warm benchmark

Run serially, ideally with the machine otherwise quiet:

```sh
python3 tests/manual/starship-ftl-trial.py benchmark "$trial" --runs 20
```

The benchmark warms each mode, then interleaves samples. It reports median/p95 first-glyph bytes, the line-editor-ready marker, and `:`-to-next-prompt latency (median of three commands per shell). No artificial startup sleep is inserted. Raw samples are in `$trial/benchmarks.json`; terminal byte logs sit alongside it. A run can take several minutes under load.

This is a controlled comparison of rendered startup code, not exact live-shell timing, optical flicker verification, or performance with your full Atuin history. High p95 or varying readiness warrants a quieter rerun, not a speedup claim. A fresh `prepare` gives fresh caches for manually observing first-run behaviour without deleting live caches.

### Automated contract checks

```sh
bash tests/chezmoi/test-starship-shell-integration.sh
bash tests/chezmoi/test-atuin-shell-integration.sh
```

The Starship owner covers provisioning/activation scope, the early Mise PATH dependency, theme colour, native fallback and submodule policy. The Atuin owner covers inline configuration, post-init strategy order and retained Ctrl-R/Up ownership. Their controlled fixtures do not replace real-terminal checks.

## Not done intentionally

- Broad deferred loading: introduces partially ready widgets and plugin initialization-order risks.
- Replacing Mise activation with shims: changes environment-injection semantics.
- Blanket `.zshrc` compilation: adds cache invalidation work without an evidenced need.
- Generic init-cache refactoring: outside this pilot; the invalidation limits above still apply.
