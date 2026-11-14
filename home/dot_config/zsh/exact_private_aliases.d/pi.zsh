# ------------------------------------------
# .aliases/pi
# ------------------------------------------

# Pi in coordinator mode: you talk to one agent, a crew of subagents does the work.
# Plain `pi` is unchanged. Extra arguments pass through.
pic() {
    pi --append-system-prompt "Coordinator mode is on for this session. Before your first reply, read $HOME/.pi/agent/skills/pi-coordinator/SKILL.md and follow it for the rest of the session." "$@"
}
