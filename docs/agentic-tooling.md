# agentic tooling

## headroom

custom config and aliases for headroom proxy/compression wrapper under `dot_config/headroom/`.

also has some local helpers for tmux orchestration and custom proxy shimming to support codex sub api endpoint.

### commands

| command | purpose |
| --- | --- |
| `hr-status` | show proxy, codex proxy, shim state, workspace, and savings state |
| `hr-proxy-pi` | start the pi stack: openrouter api proxy, codex proxy, codex shim, and stats pane |
| `hr-proxy-claude` | start the claude/anthropic api proxy |
| `hr-proxy-codex` | start only the codex responses api proxy |
| `hr-codex-shim` | start only the local pi/codex shim |
| `hr-pi` | run pi through the openrouter headroom provider |
| `hr-pix` | run pi through the codex oauth/subscription path and local shim |
| `hr-claude` / `hr-codex` | run claude code or codex through headroom |
| `hr-stats` / `hr-watch-stats` | show or watch `headroom perf` |

### routing

`hr-proxy-pi` is the normal launcher when using both pi paths:

```text
hr-pi  -> 127.0.0.1:8787 -> headroom primary proxy -> openrouter
hr-pix -> 127.0.0.1:8788 -> local codex shim -> 127.0.0.1:8789 -> headroom codex proxy
```

`hr-pi` targets openrouter, while `hr-pix` uses the codex responses/oauth path.


### port reference

```text
proxy:        http://127.0.0.1:8787
codex proxy: http://127.0.0.1:8789
codex shim:  http://127.0.0.1:8788
```

### troubleshooting

the codex proxy defaults to passthrough because pi times out if sse headers are delayed:
```sh
HEADROOM_CODEX_PROXY_OPTIMIZE=off
```

- run `hr-status` first; it reports missing proxies, shim state, ports, and codex optimize mode.
- if tmux panes are stale or ports are unhealthy, re-run `hr-proxy-pi` or `hr-proxy-claude` from tmux to recreate them.
- if `hr-pix` reports `Codex SSE response headers timed out after 10000ms`, ensure `hr-status` shows `codex optimize: off`, then restart without `HEADROOM_CODEX_PROXY_OPTIMIZE=on`.
