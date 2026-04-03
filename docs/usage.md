# Usage

## Updating

Pull the latest dotfiles and re-apply:

```sh
chezmoi update
```

Or manually:

```sh
chezmoi git pull && chezmoi apply
```

## Re-installing on a new machine

**macOS:**
```sh
brew install chezmoi
chezmoi init --apply brendanlees
```

**Linux:**
```sh
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply brendanlees
```

On first run, chezmoi will prompt you to configure the machine type (see [scoping](./scoping.md)).
