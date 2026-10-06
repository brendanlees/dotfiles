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
const mailto = new URL('mailto:hello@example.com?subject=Hello');
assert.equal(config.handlers.some((handler) => handler.match(mailto, { opener: null })), false);
assert.equal(route('https://open.spotify.com/track/123'), 'Spotify');
assert.equal(route('https://open.spotify.com.evil.example/track/123'), 'Dia');
assert.equal(route('https://example.com/?url=open.spotify.com'), 'Dia');
assert.equal(route('https://example.com/'), 'Dia');
assert.equal(route('https://youtube.com/watch?v=123'), 'Dia');
assert.equal(route('https://facebook.com/'), 'Dia');
assert.equal(route('https://x.com/example'), 'Dia');
assert.equal(config.rewrite, undefined);
JS

echo 'Finicky routing ok'
