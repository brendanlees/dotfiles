#!/usr/bin/env bash
set -euo pipefail
export PYTHONDONTWRITEBYTECODE=1

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="$ROOT/home/Library/Application Support/private_Syncthing/private_executable_check-health.py"
PLIST="$ROOT/home/Library/LaunchAgents/private_com.brendan.syncthing-health.plist.tmpl"
TMPDIR="${TMPDIR:-/tmp}/sync-health-monitor-test-$$"
FAKE_MUTAGEN="$TMPDIR/mutagen"
mkdir -p "$TMPDIR"
trap 'rm -rf "$TMPDIR"' EXIT

python3 - "$SCRIPT" <<'PY'
import ast
import sys
from pathlib import Path
ast.parse(Path(sys.argv[1]).read_text())
PY

grep -q '{{ .chezmoi.homeDir }}/Library/Application Support/Syncthing/check-health.py' "$PLIST"
if grep -q '/Users/' "$PLIST"; then
  echo 'LaunchAgent template contains a hard-coded user home' >&2
  exit 1
fi

write_healthy_mutagen() {
  cat > "$FAKE_MUTAGEN" <<'SH'
#!/usr/bin/env bash
cat <<'EOF'
vault-ro-study|Watching|false|true|true|0|0|false|0|0|0|0|0|0|0|0
vault-ro-daily-2026|Watching|false|true|true|0|0|false|0|0|0|0|0|0|0|0
vault-hermes-overlay|Watching|false|true|true|0|0|false|0|0|0|0|0|0|0|0
EOF
SH
  chmod +x "$FAKE_MUTAGEN"
}

write_paused_mutagen() {
  cat > "$FAKE_MUTAGEN" <<'SH'
#!/usr/bin/env bash
cat <<'EOF'
vault-ro-study|Watching|false|true|true|0|0|false|0|0|0|0|0|0|0|0
vault-ro-daily-2026|Watching|false|true|true|0|0|false|0|0|0|0|0|0|0|0
vault-hermes-overlay|Disconnected|true|false|false|-1|-1|false|-1|-1|-1|-1|-1|-1|-1|-1
EOF
SH
  chmod +x "$FAKE_MUTAGEN"
}

write_healthy_mutagen
python3 - "$SCRIPT" "$FAKE_MUTAGEN" healthy <<'PY'
import importlib.util
import sys
from pathlib import Path

script, fake_mutagen, scenario = sys.argv[1:]
spec = importlib.util.spec_from_file_location("sync_health", script)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
module.MUTAGEN = Path(fake_mutagen)
problems, count = module.check_mutagen_health()
assert count == 3, (scenario, count)
assert problems == [], (scenario, problems)
PY

write_paused_mutagen
python3 - "$SCRIPT" "$FAKE_MUTAGEN" paused <<'PY'
import importlib.util
import sys
from pathlib import Path

script, fake_mutagen, scenario = sys.argv[1:]
spec = importlib.util.spec_from_file_location("sync_health", script)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
module.MUTAGEN = Path(fake_mutagen)
problems, count = module.check_mutagen_health()
assert count == 3, (scenario, count)
assert "Mutagen vault-hermes-overlay: paused" in problems, (scenario, problems)
assert "Mutagen vault-hermes-overlay: endpoint disconnected" in problems, (scenario, problems)
PY
