# Neovim Black Metal Theme Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Neovim load the dedicated Black Metal colorscheme selected by the chezmoi global theme registry, including Bathory and every other currently registered band variant.

**Architecture:** Chezmoi remains the source of truth and renders the selected Neovim colorscheme into `~/.config/chezmoi-theme/active.lua`. The separate AstroNvim config installs `metalelf0/black-metal-theme-neovim`, allowing AstroUI and lazy.nvim to resolve the rendered band name directly without local translation or palette duplication.

**Tech Stack:** chezmoi templates/data, YAML, Bash/Python test harness, AstroNvim 5, lazy.nvim, Lua, `metalelf0/black-metal-theme-neovim`

## Global Constraints

- Work in isolated branches/worktrees for both repositories. Never modify `main` directly.
- Dotfiles repository: `/Users/brendan/.local/share/chezmoi`; existing feature worktree: `/tmp/chezmoi-nvim-black-metal-theme`; branch: `fix/nvim-black-metal-theme`.
- Neovim repository: `/Users/brendan/.config/nvim`; create an isolated worktree from `main` at execution time.
- Chezmoi must remain the single source of truth for theme selection.
- Map generic `black-metal` to `bathory`.
- Map every currently registered band-specific Black Metal theme to the plugin's corresponding colorscheme name.
- Do not add Neovim-side theme translation, custom palette overrides, or another fallback path.
- Preserve AstroUI's existing `tokyonight-night` fallback and the current live-reload mechanism.
- The Neovim repository is a chezmoi archive external sourced from its `main` branch, so merge the Neovim change before relying on a fresh `chezmoi apply` from the dotfiles repository.

---

### Task 1: Make Black Metal mappings explicit in the chezmoi registry

**Files:**
- Modify: `/tmp/chezmoi-nvim-black-metal-theme/tests/chezmoi/test-theme-registry.sh`
- Modify: `/tmp/chezmoi-nvim-black-metal-theme/.chezmoidata/themes.yml`
- Verify unchanged template: `/tmp/chezmoi-nvim-black-metal-theme/dot_config/chezmoi-theme/active.lua.tmpl`

**Interfaces:**
- Consumes: `.themes[theme].apps.nvim` from chezmoi's merged data.
- Produces: `apps.nvim` values `bathory`, `burzum`, `dark-funeral`, `gorgoroth`, `immortal`, `khold`, `marduk`, `mayhem`, `nile`, and `venom`; the existing bridge template renders the selected value as `colorscheme`.

- [ ] **Step 1: Add a failing registry contract test**

In the Python heredoc in `tests/chezmoi/test-theme-registry.sh`, add this block after the per-theme schema loop and before the Ghostty directory checks:

```python
expected_black_metal_nvim = {
    "black-metal": "bathory",
    "black-metal-bathory": "bathory",
    "black-metal-burzum": "burzum",
    "black-metal-dark-funeral": "dark-funeral",
    "black-metal-gorgoroth": "gorgoroth",
    "black-metal-immortal": "immortal",
    "black-metal-khold": "khold",
    "black-metal-marduk": "marduk",
    "black-metal-mayhem": "mayhem",
    "black-metal-nile": "nile",
    "black-metal-venom": "venom",
}
for key, expected in expected_black_metal_nvim.items():
    actual = themes[key]["apps"]["nvim"]
    if actual != expected:
        raise SystemExit(
            f"{key}: expected Neovim colorscheme {expected!r}, got {actual!r}"
        )
```

After the Python heredoc, add a bridge-rendering assertion:

```bash
rendered_bridge=$(
  chezmoi execute-template \
    --source "$repo_root" \
    --override-data '{"theme":"black-metal-bathory"}' \
    --file "$repo_root/dot_config/chezmoi-theme/active.lua.tmpl"
)
if ! grep -Fq 'colorscheme = "bathory"' <<<"$rendered_bridge"; then
  echo 'black-metal-bathory bridge did not render colorscheme = "bathory"' >&2
  exit 1
fi
```

- [ ] **Step 2: Run the focused test and confirm the current approximation fails**

Run:

```bash
bash /tmp/chezmoi-nvim-black-metal-theme/tests/chezmoi/test-theme-registry.sh
```

Expected: FAIL with `black-metal: expected Neovim colorscheme 'bathory', got 'monokai-pro'`.

- [ ] **Step 3: Replace only the Black Metal Neovim mappings**

In `.chezmoidata/themes.yml`, change the eleven `apps.nvim` values as follows while leaving their palettes and all other application mappings untouched:

```yaml
black-metal:
  apps:
    nvim: "bathory"
black-metal-bathory:
  apps:
    nvim: "bathory"
black-metal-burzum:
  apps:
    nvim: "burzum"
black-metal-dark-funeral:
  apps:
    nvim: "dark-funeral"
black-metal-gorgoroth:
  apps:
    nvim: "gorgoroth"
black-metal-immortal:
  apps:
    nvim: "immortal"
black-metal-khold:
  apps:
    nvim: "khold"
black-metal-marduk:
  apps:
    nvim: "marduk"
black-metal-mayhem:
  apps:
    nvim: "mayhem"
black-metal-nile:
  apps:
    nvim: "nile"
black-metal-venom:
  apps:
    nvim: "venom"
```

Do not replace whole theme blocks with this abbreviated example. Edit only each existing `nvim:` line.

- [ ] **Step 4: Run the focused test and confirm registry and bridge behavior**

Run:

```bash
bash /tmp/chezmoi-nvim-black-metal-theme/tests/chezmoi/test-theme-registry.sh
```

Expected: PASS and output ending with `theme registry ok`.

- [ ] **Step 5: Commit the chezmoi mapping change**

```bash
git -C /tmp/chezmoi-nvim-black-metal-theme add \
  .chezmoidata/themes.yml \
  tests/chezmoi/test-theme-registry.sh
git -C /tmp/chezmoi-nvim-black-metal-theme commit \
  -m "feat(theme): map Black Metal schemes for Neovim"
```

### Task 2: Install the dedicated Neovim colorscheme plugin

**Files:**
- Modify: `/tmp/nvim-black-metal-theme/lua/community.lua`
- Runtime-generated and ignored: `/tmp/nvim-black-metal-theme/lazy-lock.json`

**Interfaces:**
- Consumes: `colorscheme` names emitted by `~/.config/chezmoi-theme/active.lua` and passed through `lua/plugins/astroui.lua`.
- Produces: lazy.nvim colorscheme loaders for `bathory`, `burzum`, `dark-funeral`, `gorgoroth`, `immortal`, `khold`, `marduk`, `mayhem`, `nile`, and `venom`.

- [ ] **Step 1: Create an isolated Neovim worktree**

Use the `superpowers:using-git-worktrees` skill. Create branch `fix/black-metal-theme` from `main` at `/tmp/nvim-black-metal-theme`. Verify it begins clean:

```bash
git -C /tmp/nvim-black-metal-theme status --short --branch
```

Expected: branch `fix/black-metal-theme` with no changed files.

- [ ] **Step 2: Reproduce the missing colorscheme through a temporary Neovim home**

Use `/tmp/nvim-black-metal-theme-test-home` as an isolated home while reusing the existing plugin data directory:

```bash
rm -rf /tmp/nvim-black-metal-theme-test-home
mkdir -p \
  /tmp/nvim-black-metal-theme-test-home/.config/chezmoi-theme \
  /tmp/nvim-black-metal-theme-test-home/.local/state \
  /tmp/nvim-black-metal-theme-test-home/.cache
ln -s /tmp/nvim-black-metal-theme \
  /tmp/nvim-black-metal-theme-test-home/.config/nvim
cat >/tmp/nvim-black-metal-theme-test-home/.config/chezmoi-theme/active.lua <<'LUA'
return {
  theme = "black-metal-bathory",
  colorscheme = "bathory",
  background = "dark",
}
LUA
HOME=/tmp/nvim-black-metal-theme-test-home \
XDG_CONFIG_HOME=/tmp/nvim-black-metal-theme-test-home/.config \
XDG_DATA_HOME=/Users/brendan/.local/share \
XDG_STATE_HOME=/tmp/nvim-black-metal-theme-test-home/.local/state \
XDG_CACHE_HOME=/tmp/nvim-black-metal-theme-test-home/.cache \
nvim --headless \
  "+lua assert(vim.g.colors_name == 'bathory', 'expected bathory, got '..tostring(vim.g.colors_name))" \
  +qa
```

Expected: FAIL because `bathory` is not supplied by any declared plugin. Keep `/tmp/nvim-black-metal-theme-test-home` for the passing check.

- [ ] **Step 3: Declare the official Black Metal plugin**

In `lua/community.lua`, add the plugin beside the other colorscheme declarations, immediately after the existing `guts.nvim` entry:

```lua
  { "metalelf0/black-metal-theme-neovim", lazy = true },
```

Do not add a `config` block. Each plugin-provided band colorscheme file calls `require("black-metal").setup({})` and loads its matching band.

- [ ] **Step 4: Install the declared plugin in the test data directory**

```bash
HOME=/tmp/nvim-black-metal-theme-test-home \
XDG_CONFIG_HOME=/tmp/nvim-black-metal-theme-test-home/.config \
XDG_DATA_HOME=/Users/brendan/.local/share \
XDG_STATE_HOME=/tmp/nvim-black-metal-theme-test-home/.local/state \
XDG_CACHE_HOME=/tmp/nvim-black-metal-theme-test-home/.cache \
nvim --headless "+Lazy! sync" +qa
```

Expected: lazy.nvim installs `black-metal-theme-neovim` without errors. `lazy-lock.json` may appear as an ignored runtime file and must not be committed.

- [ ] **Step 5: Verify Bathory loads with its black background**

```bash
HOME=/tmp/nvim-black-metal-theme-test-home \
XDG_CONFIG_HOME=/tmp/nvim-black-metal-theme-test-home/.config \
XDG_DATA_HOME=/Users/brendan/.local/share \
XDG_STATE_HOME=/tmp/nvim-black-metal-theme-test-home/.local/state \
XDG_CACHE_HOME=/tmp/nvim-black-metal-theme-test-home/.cache \
nvim --headless \
  "+lua local normal=vim.api.nvim_get_hl(0,{name='Normal',link=false}); assert(vim.g.colors_name == 'bathory', 'expected bathory, got '..tostring(vim.g.colors_name)); assert(normal.bg == 0, 'expected #000000 Normal background, got '..vim.inspect(normal.bg))" \
  +qa
```

Expected: exit 0 with no assertion failure.

- [ ] **Step 6: Check Lua formatting and repository diff**

```bash
stylua --check /tmp/nvim-black-metal-theme/lua/community.lua
git -C /tmp/nvim-black-metal-theme diff --check
git -C /tmp/nvim-black-metal-theme status --short
```

Expected: formatting and diff checks pass; only `lua/community.lua` is tracked as modified.

- [ ] **Step 7: Commit the Neovim plugin declaration**

```bash
git -C /tmp/nvim-black-metal-theme add lua/community.lua
git -C /tmp/nvim-black-metal-theme commit \
  -m "feat(theme): add Black Metal colorschemes"
```

### Task 3: Run integrated verification and record merge order

**Files:**
- Verify: `/tmp/chezmoi-nvim-black-metal-theme/.chezmoidata/themes.yml`
- Verify: `/tmp/chezmoi-nvim-black-metal-theme/dot_config/chezmoi-theme/active.lua.tmpl`
- Verify: `/tmp/nvim-black-metal-theme/lua/community.lua`

**Interfaces:**
- Consumes: committed outputs from Tasks 1 and 2.
- Produces: evidence that the rendered Bathory selection resolves to the installed dedicated plugin without changing existing theme infrastructure.

- [ ] **Step 1: Run the relevant chezmoi theme test set**

```bash
bash /tmp/chezmoi-nvim-black-metal-theme/tests/ci/run-chezmoi-tests.sh \
  /tmp/chezmoi-nvim-black-metal-theme/tests/chezmoi/test-theme-registry.sh \
  /tmp/chezmoi-nvim-black-metal-theme/tests/chezmoi/test-pi-theme-template.sh
```

Expected: `SUMMARY: 2 passed, 0 failed`.

- [ ] **Step 2: Render Bathory's bridge into the temporary Neovim home**

```bash
chezmoi execute-template \
  --source /tmp/chezmoi-nvim-black-metal-theme \
  --override-data '{"theme":"black-metal-bathory"}' \
  --file /tmp/chezmoi-nvim-black-metal-theme/dot_config/chezmoi-theme/active.lua.tmpl \
  >/tmp/nvim-black-metal-theme-test-home/.config/chezmoi-theme/active.lua
grep -F 'colorscheme = "bathory"' \
  /tmp/nvim-black-metal-theme-test-home/.config/chezmoi-theme/active.lua
```

Expected: grep prints `colorscheme = "bathory",`.

- [ ] **Step 3: Run the end-to-end headless assertion against the rendered bridge**

```bash
HOME=/tmp/nvim-black-metal-theme-test-home \
XDG_CONFIG_HOME=/tmp/nvim-black-metal-theme-test-home/.config \
XDG_DATA_HOME=/Users/brendan/.local/share \
XDG_STATE_HOME=/tmp/nvim-black-metal-theme-test-home/.local/state \
XDG_CACHE_HOME=/tmp/nvim-black-metal-theme-test-home/.cache \
nvim --headless \
  "+lua local bridge=dofile(vim.fn.expand('~/.config/chezmoi-theme/active.lua')); local normal=vim.api.nvim_get_hl(0,{name='Normal',link=false}); assert(bridge.theme == 'black-metal-bathory'); assert(bridge.colorscheme == 'bathory'); assert(vim.g.colors_name == bridge.colorscheme); assert(normal.bg == 0)" \
  +qa
```

Expected: exit 0 with no assertion failure.

- [ ] **Step 4: Verify both worktrees are clean and inspect their commits**

```bash
git -C /tmp/chezmoi-nvim-black-metal-theme status --short --branch
git -C /tmp/chezmoi-nvim-black-metal-theme log -3 --oneline
git -C /tmp/nvim-black-metal-theme status --short --branch
git -C /tmp/nvim-black-metal-theme log -2 --oneline
```

Expected: both feature branches are clean. The dotfiles branch contains the design, plan, and registry commits; the Neovim branch contains the plugin declaration commit.

- [ ] **Step 5: Preserve deployment order in the handoff**

Report these merge/deployment requirements without pushing or merging automatically:

1. Merge the Neovim `fix/black-metal-theme` branch first so the chezmoi archive external can fetch the plugin declaration from Neovim `main`.
2. Merge the dotfiles `fix/nvim-black-metal-theme` branch second.
3. Run `theme black-metal-bathory`, or `chezmoi apply` if Bathory remains selected, to regenerate the bridge and install the refreshed Neovim external.
4. Restart Neovim if no live instance receives the theme script's socket reload.
