#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
cp "$repo_root/home/dot_finicky.js" "$tmp/finicky.mjs"

# Run the actual Finicky callbacks, without opening applications or web pages.
node --input-type=module - "$tmp/finicky.mjs" <<'JS'
import assert from 'node:assert/strict';
import { pathToFileURL } from 'node:url';
const { default: config } = await import(pathToFileURL(process.argv[2]));
const route = (href) => {
  const url = new URL(href);
  return config.handlers.find((handler) => handler.match(url, { opener: null }))?.browser ?? config.defaultBrowser;
};
assert.equal(route('mailto:hello@example.com?subject=Hello'), 'Mimestream');
assert.equal(route('https://open.spotify.com/track/123'), 'Spotify');
assert.equal(route('https://open.spotify.com.evil.example/track/123'), 'Dia');
assert.equal(route('https://example.com/?url=open.spotify.com'), 'Dia');
assert.equal(route('https://example.com/'), 'Dia');
assert.equal(route('https://youtube.com/watch?v=123'), 'Dia');
assert.equal(route('https://facebook.com/'), 'Dia');
assert.equal(route('https://x.com/example'), 'Dia');
assert.equal(config.rewrite, undefined);
JS

# Exercise native mail-default reconciliation through a mock JXA bridge.
# macOS LaunchServices is never called by these tests.
mkdir -p "$tmp/bin"
cat >"$tmp/bin/osascript" <<'JS'
#!/usr/bin/env node
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
assert.deepEqual(process.argv.slice(2), ['-l', 'JavaScript']);
const statePath = process.env.MAIL_STATE;
const state = JSON.parse(fs.readFileSync(statePath, 'utf8'));
const $ = (value) => value;
$.LSCopyDefaultHandlerForURLScheme = (scheme) => ({ value: state[scheme] });
$.LSSetDefaultHandlerForURLScheme = (scheme, bundleId) => {
  assert.equal(scheme, 'mailto');
  assert.equal(bundleId, 'com.mimestream.Mimestream');
  const status = Number(process.env.MAIL_STATUS || 0);
  if (status === 0) {
    state[scheme] = bundleId;
    state.writes++;
    fs.writeFileSync(statePath, JSON.stringify(state));
  }
  return status;
};
vm.runInNewContext(fs.readFileSync(0, 'utf8'), {
  ObjC: {
    import: (name) => assert.equal(name, 'CoreServices'),
    castRefToObject: (ref) => ref.value,
    unwrap: (value) => value,
  },
  $,
});
JS
chmod +x "$tmp/bin/osascript"
template="$repo_root/home/.chezmoiscripts/darwin/run_after_configure-default-mail.sh.tmpl"
chezmoi execute-template --source "$repo_root" \
  --override-data '{"personal":true,"headless":false,"chezmoi":{"os":"darwin"}}' \
  <"$template" >"$tmp/mail.sh"
export MAIL_STATE="$tmp/mail.json"
printf '{"mailto":"com.apple.mail","https":"other.browser","writes":0}\n' >"$MAIL_STATE"
PATH="$tmp/bin:$PATH" bash "$tmp/mail.sh"
cp "$MAIL_STATE" "$tmp/after-first.json"
PATH="$tmp/bin:$PATH" bash "$tmp/mail.sh"
cmp "$MAIL_STATE" "$tmp/after-first.json"
node -e 'const assert = require("node:assert/strict"); const state = require(process.env.MAIL_STATE); assert.deepEqual(state, {mailto: "com.mimestream.Mimestream", https: "other.browser", writes: 1});'

# Surface native failures rather than silently claiming the default was changed.
printf '{"mailto":"com.apple.mail","writes":0}\n' >"$MAIL_STATE"
cp "$MAIL_STATE" "$tmp/before-failure.json"
if MAIL_STATUS=-10814 PATH="$tmp/bin:$PATH" bash "$tmp/mail.sh" >"$tmp/error.log" 2>&1; then
  echo 'mail handler failure must fail apply' >&2
  exit 1
fi
grep -Fq 'Could not set Mimestream as the default email reader: -10814' "$tmp/error.log"
cmp "$MAIL_STATE" "$tmp/before-failure.json"

for data in \
  '{"personal":false,"headless":false,"chezmoi":{"os":"darwin"}}' \
  '{"personal":true,"headless":true,"chezmoi":{"os":"darwin"}}' \
  '{"personal":true,"headless":false,"chezmoi":{"os":"linux"}}' \
  '{"personal":true,"headless":false,"chezmoi":{"os":"windows"}}'; do
  [[ -z $(chezmoi execute-template --source "$repo_root" --override-data "$data" <"$template") ]]
done

echo 'Finicky routing and scoped, idempotent native mail defaults ok'
