# file tracking

## adding existing files

import an existing file or directory into chezmoi:

```sh
chezmoi add ~/.config/tmux
chezmoi add ~/.config/nvim ~/.zshrc
```

chezmoi copies the file into the source directory with the correct naming (`dot_` prefix etc). the target is not modified.

## source vs target

chezmoi manages a **source** (`~/.local/share/chezmoi`) and a **target** (your home dir). they are independent — editing the target directly will cause drift.

check for drift at any time:

```sh
chezmoi status
chezmoi diff
```

## syncing changes back

if you edited the target directly, sync it back into the source:

```sh
chezmoi re-add ~/.config/kanata/config.kbd
```

to re-add all tracked files at once:

```sh
chezmoi re-add
```

this only affects already-tracked files — it won't pull in untracked files.

## editing in source

to avoid re-add friction, edit files via chezmoi directly — it opens the source file and applies on save:

```sh
chezmoi edit ~/.config/kanata/config.kbd
```

## status codes

| code | meaning                                       |
| ---- | --------------------------------------------- |
| `A`  | added (present in source, absent in target)   |
| `D`  | deleted (absent in source, present in target) |
| `M`  | modified (source and target differ)           |
| `R`  | run (script pending execution)                |

## auto-watching (optional)

use `fswatch` to auto-re-add on file change (macOS):

```sh
fswatch -o ~/.config/kanata | xargs -n1 -I{} chezmoi re-add ~/.config/kanata
```

wrap in a launchd plist to run as a background service.
