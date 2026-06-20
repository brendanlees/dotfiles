# Headroom

This repo manages a small Headroom wrapper layer under `dot_config/headroom/` plus two local helper executables:

- `~/.local/bin/headroom-tmux`
- `~/.local/bin/headroom-codex-shim`

The public shell commands intentionally use the `hr-*` prefix only. Legacy `h*` commands were removed to avoid ambiguous routing.

## Commands

| Command | Purpose |
| --- | --- |
| `hr-status` | Show proxy, Codex proxy, shim, workspace, and savings state. |
| `hr-proxy-claude` | Start the Claude/Anthropic Headroom proxy on `HEADROOM_PORT` (`8787`). |
| `hr-proxy-pi` | Start the full Pi stack for `hr-pi` + `hr-pix`: primary OpenRouter proxy, Codex proxy, Codex shim, and stats pane. |
| `hr-proxy-codex` | Start only the Codex Responses proxy on `HEADROOM_CODEX_PROXY_PORT` (`8789`). Defaults to passthrough. |
| `hr-codex-shim` | Start the Pi/Codex shim on `HEADROOM_CODEX_SHIM_PORT` (`8788`). |
| `hr-claude` | Run Claude Code through the Claude/Anthropic proxy. |
| `hr-codex` | Run Codex through the Codex proxy. |
| `hr-pi` | Run Pi through the OpenRouter Headroom provider. |
| `hr-pix` | Run Pi through the bespoke Codex OAuth/subscription provider and local shim. |
| `hr-stats` | Run `headroom perf`. |
| `hr-watch-stats` | Watch `hr-stats` periodically. |

## Routing

`hr-proxy-pi` is the recommended launcher when using both Pi paths side-by-side:

```text
hr-pi
  -> Pi provider headroom-openrouter
  -> http://127.0.0.1:8787/v1
  -> Headroom primary proxy
  -> OpenRouter

hr-pix
  -> Pi provider headroom-codex-oauth
  -> http://127.0.0.1:8788/v1/codex/responses
  -> local Codex shim
  -> http://127.0.0.1:8789/v1/responses
  -> Headroom Codex proxy
  -> OpenAI Codex OAuth/subscription path
```

The split proxies are intentional. A single OpenAI-compatible Headroom proxy cannot simultaneously target OpenRouter for `hr-pi` and the Codex Responses/OAuth path for `hr-pix`.

## Codex SSE timeout behavior

Pi's Codex Responses provider times out if SSE response headers are not received within 10 seconds. Headroom optimization can delay upstream response headers, so the Codex proxy defaults to passthrough:

```sh
HEADROOM_CODEX_PROXY_OPTIMIZE=off
```

`hr-status` shows this as:

```text
codex optimize: off
```

Keep this off for stability. To experiment with Codex optimization despite the timeout risk:

```sh
HEADROOM_CODEX_PROXY_OPTIMIZE=on hr-proxy-codex
```

## Basic usage

Apply the dotfiles and reload the shell aliases:

```sh
chezmoi apply
source ~/.config/zsh/aliases.d/headroom.zsh
```

Start the Pi stack:

```sh
hr-proxy-pi
```

Check the expected state:

```sh
hr-status
```

Expected ports:

```text
proxy:        http://127.0.0.1:8787
codex proxy: http://127.0.0.1:8789
codex shim:  http://127.0.0.1:8788
```

Then test the two Pi paths:

```sh
hr-pi --no-session -p "Respond with exactly OK"
hr-pix --no-session -p "Respond with exactly OK"
```

For Claude Code only:

```sh
hr-proxy-claude
hr-claude
```

## Troubleshooting

If a wrapper reports that a proxy is missing, run:

```sh
hr-status
```

If a stale `headroom` tmux window exists but ports are unhealthy, starting `hr-proxy-pi` or `hr-proxy-claude` from tmux should remove the stale window and recreate the panes.

If `hr-pix` reports `Codex SSE response headers timed out after 10000ms`, verify that the Codex proxy is in passthrough mode:

```sh
hr-status | grep 'codex optimize'
```

If it says `on`, restart the Codex proxy without the override:

```sh
unset HEADROOM_CODEX_PROXY_OPTIMIZE
hr-proxy-pi
```
