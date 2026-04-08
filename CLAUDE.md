# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Repository Is

A macOS-focused personal dotfiles repository. All files under `home/` mirror the user's home directory layout — editing `home/.gitconfig` changes what will be synced to `~/.gitconfig`.

## Setup Commands

```bash
./setup                # Full setup: dotfiles + brew + apps + PHP + MongoDB
./setup-dotfiles.sh    # Sync home/ to ~/ via rsync (prompts for confirmation unless --force)
./setup-brew.sh        # Install Homebrew and all packages from brew/Brewfile
./setup-php.sh         # Install PHP versions and PECL extensions
./setup-mongodb.sh     # Sync mongo-orchestration/ and create ~/.local/bin/mo symlink
```

There are no build, lint, or test commands — this is a configuration-only repository.

## Architecture

### `home/` → `~/` mapping
`setup-dotfiles.sh` uses `rsync` to copy `home/` into `~/.` verbatim. Every file path under `home/` corresponds to the same path under `$HOME`. Editing files here does not automatically apply them — `setup-dotfiles.sh` must be re-run.

### Shell initialization chain
`.zshrc` sources files in this order: `.exports`, `.aliases`, `.functions`, `.extra` (optional local overrides, not tracked). Custom prompt lives in `.zshprompt`.

### Git configuration layering
`.gitconfig` includes conditional configs:
- `~/.gitconfig.private` — always included (author identity, not tracked here)
- `~/.gitconfig.mongodb` — included for paths under `~/Code/10gen`, `~/Code/mongodb`, `~/Code/mongodb-labs`
- `~/.gitconfig.local` — optional machine-local overrides

`core.hooksPath = ~/.githooks` points to `home/.githooks/`. The `post-checkout` hook sources all scripts in `post-checkout.d/` for modular extensibility.

### PHP multi-version setup
`php/` contains one directory per PHP version (e.g. `php/8.2/`), each with `.ini` files and a `pecl.list`. `setup-php.sh` copies the `.ini` files to Homebrew's PHP config directories and installs the listed PECL extensions. The `usephp` shell function (in `.functions`) switches the active PHP version.

### Homebrew package lists
- `brew/Brewfile` — general tools and macOS apps
- `brew/Brewfile-php` — multiple PHP versions via `shivammathur/php` tap

### MongoDB orchestration
`mongo-orchestration/` holds JSON configs for different MongoDB topologies (replica sets, standalone, various auth/SSL scenarios). These are synced to `~/.local/mongo-orchestration` and used via the `mo` CLI.
