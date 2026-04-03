# usage

## updating

pull the latest dotfiles and re-apply:

```sh
chezmoi update
```

or manually:

```sh
chezmoi git pull && chezmoi apply
```

## re-installing on a new machine

**macos:**
```sh
brew install chezmoi
chezmoi init --apply brendanlees
```

**linux:**
```sh
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply brendanlees
```

on first run, chezmoi will prompt you to configure the machine type (see [scoping](./scoping.md)).
