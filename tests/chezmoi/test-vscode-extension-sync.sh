#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)

rendered_shell=$(chezmoi execute-template --source="$repo_root" < "$repo_root/.chezmoiscripts/run_onchange_after_configure-vscode.sh.tmpl")
grep -Fq 'installed="$(code --list-extensions 2>/dev/null || true)"' <<<"$rendered_shell"
grep -Fq "if ! grep -Fxq 'co6x0.vscode-wp-block-html' <<<\"\$installed\"; then" <<<"$rendered_shell"
grep -Fq 'code --force --install-extension co6x0.vscode-wp-block-html' <<<"$rendered_shell"

rendered_ps=$(chezmoi execute-template --source="$repo_root" < "$repo_root/.chezmoiscripts/windows/run_onchange_after_configure-vscode.ps1.tmpl")
grep -Fq '$installed = @(code --list-extensions)' <<<"$rendered_ps"
grep -Fq "if (\$installed -notcontains 'co6x0.vscode-wp-block-html') {" <<<"$rendered_ps"
grep -Fq 'code --force --install-extension co6x0.vscode-wp-block-html' <<<"$rendered_ps"

echo "vscode extension sync guards ok"
