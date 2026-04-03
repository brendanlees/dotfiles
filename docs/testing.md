# testing

## apply a branch before merging

fetch and apply a specific branch without changing the local source directory:

```sh
chezmoi init --apply --branch <branch-name> brendanlees
```

to test a remote branch on a target machine, ssh in and run:

```sh
chezmoi init --apply --branch <branch-name> brendanlees
```

chezmoi will re-initialise from the branch. previously cached state means `run_once` scripts
will only re-run if their content has changed.

to force re-run of once scripts (e.g. to re-test cleanup):

```sh
chezmoi state delete-bucket --bucket=scriptState
chezmoi apply
```

to return to tracking `main`:

```sh
chezmoi init --apply brendanlees
```
