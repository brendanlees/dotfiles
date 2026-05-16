# zsh startup performance

`dot_zshrc.tmpl` is tuned to minimize subprocess forks on shell startup. each fork on macOS costs ~20–80 ms; a vanilla "eval $(tool init zsh)" stack adds up to a noticeable lag.

## changes vs. a default zshrc

| change                           | why                                                              |
| -------------------------------- | ---------------------------------------------------------------- |
| `_cached_eval` helper            | caches `tool init zsh` output to disk; reruns only when binary is newer |
| daily-only `compinit -u`         | full `$fpath` security scan once per 24h, `-C` fast path otherwise |
| `zsh-syntax-highlighting` last   | must be sourced after all other widget-defining plugins or it silently fails to hook them |
| opt-in `zprof` profiler          | `ZPROF=1 zsh -ic exit` enables timing without polluting normal sessions |

## `_cached_eval`

```sh
_cached_eval <tag> <bin> <init-cmd…>
```

writes `<init-cmd>` output to `$XDG_CACHE_HOME/zsh/init/<tag>.zsh` and sources it. cache is invalidated when `$commands[<bin>]` (the resolved binary path) is newer than the cache file — so a `brew upgrade` or `mise install` triggers a regen on the next shell.

currently wraps: `mise`, `starship`, `fzf`, `carapace`, `wt`, `zoxide`.

### force a rebuild

```sh
rm -rf "$XDG_CACHE_HOME/zsh/init"
```

or delete just one tag, e.g. `rm "$XDG_CACHE_HOME/zsh/init/starship.zsh"`.

## profiling

```sh
ZPROF=1 zsh -ic exit 2>&1 | head -40
```

prints the top 40 functions by self-time. use this before/after any change to verify a regression or speedup. produces no output in normal shells.

## benchmarking

```sh
for i in {1..10}; do time zsh -ic exit; done
```

run cold (after `rm -rf "$XDG_CACHE_HOME/zsh/init"`) vs. warm to see the cache effect. expect a 150–300 ms drop on warm runs.

## not done (intentionally)

- **`zsh-defer` / async loading** — meaningful gain but adds a dep and delays autosuggestions for ~50 ms of the first interactive shell.
- **`mise activate --shims`** — faster but breaks `mise use` env-injection ergonomics.
- **`zcompile` of `.zshrc`** — <5 ms gain, staleness footgun.
