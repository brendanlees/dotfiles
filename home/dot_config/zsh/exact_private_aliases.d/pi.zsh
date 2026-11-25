# ------------------------------------------
# .aliases/pi
# ------------------------------------------

# Pi in coordinator mode: you talk to one agent, a crew of subagents does the work.
# Plain `pi` is unchanged. Extra arguments pass through.
pic() {
    pi --append-system-prompt "Coordinator mode is on for this session. Before your first reply, read $HOME/.pi/agent/skills/pi-coordinator/SKILL.md and follow it for the rest of the session." "$@"
}

# Coordinator mode for Steady Digital work: board-aware from the first turn,
# without the homelab-only MCP servers.
pi-sd() {
    pic --append-system-prompt "This is a Steady Digital work session. Before your first reply, also read $HOME/.agents/skills/steady-coding-agent/SKILL.md and $HOME/.agents/skills/brendans-notion-conventions/SKILL.md. Work is tracked on the Notion Agent Board; follow the coordinator section of steady-coding-agent." \
        --exclude-tools 'mcp__home_assistant__*,mcp__unifi_network__*,mcp__unifi_protect__*' "$@"
}
