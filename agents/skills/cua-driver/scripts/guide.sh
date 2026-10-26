#!/bin/sh
# Print the guide bundled with the installed Cua Driver. `cua-driver call get_guide`
# drops the guide text from its output, so read it over the MCP interface instead.
set -eu

topic=${1:-}
if [ -n "$topic" ]; then
  args=$(jq -cn --arg topic "$topic" '{topic: $topic}')
else
  args='{}'
fi

printf '%s\n' \
  '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"cua-guide","version":"1"}}}' \
  '{"jsonrpc":"2.0","method":"notifications/initialized"}' \
  "{\"jsonrpc\":\"2.0\",\"id\":2,\"method\":\"tools/call\",\"params\":{\"name\":\"get_guide\",\"arguments\":$args}}" |
  cua-driver mcp 2>/dev/null |
  jq -r 'select(.id == 2) | .result |
    if .isError then (.content[0].text + "\n" | halt_error(1))
    else (.content[] | select(.type == "text") | .text) end'
