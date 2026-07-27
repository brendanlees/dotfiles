# Herdr recognition for containerized Hermes

## Problem

The remote Herdr server sees `docker exec` as the foreground pane process while Hermes runs inside the `hermes` container. Herdr therefore classifies the pane as a terminal rather than a Hermes agent. Remote attach itself is healthy and supported.

## Design

Update the chezmoi-managed `hermes` zsh function so `HERDR_AGENT=hermes` is set only on the host-visible `docker exec` process:

```zsh
hermes() { HERDR_AGENT=hermes docker exec -u hermes -it hermes /opt/hermes/.venv/bin/hermes "$@"; }
```

This follows Herdr's documented wrapper-hint mechanism. Outside Herdr the variable is inert and remains scoped to the one child process. The change does not expose the Herdr API socket to the container, install a container plugin, or alter Docker services.

## Delivery

Implement on an isolated dotfiles branch. Render and syntax-check the managed zsh template, then run focused repository tests. Apply the branch to `hermes-prod` through the documented command:

```sh
chezmoi init --apply --branch fix/herdr-hermes-wrapper-detection brendanlees
```

The existing interactive Hermes TUI must be exited and relaunched so the new wrapper process receives the hint. No gateway or container restart is required.

## Verification

After relaunch:

1. Confirm the remote named Herdr session lists a Hermes agent.
2. Use `herdr agent explain` to confirm the Hermes screen manifest is active.
3. Confirm the gateway and existing containers remain running.

The repository baseline currently has one unrelated failure in `test-theme-registry.sh` because removed themes remain in its expected inventory. Verification will record that pre-existing failure separately.

## Rollback

Apply the dotfiles `main` branch on `hermes-prod`, then relaunch the interactive Hermes TUI. This removes the wrapper hint without restarting any Docker service.
