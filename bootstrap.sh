#!/usr/bin/env bash
# Symlink these dotfiles into place. Safe to re-run: an existing real file is
# moved aside to <name>.pre-dotfiles before the symlink replaces it, and a
# symlink already pointing at the right target is left alone.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

link() {
  local src="$REPO/$1" dst="$HOME/$2"
  [ -e "$src" ] || { printf 'skip   %s (not in repo)\n' "$2"; return; }
  mkdir -p "$(dirname "$dst")"
  if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
    printf 'ok     %s\n' "$2"; return
  fi
  if [ -e "$dst" ] || [ -L "$dst" ]; then
    mv "$dst" "$dst.pre-dotfiles"
    printf 'backup %s -> %s.pre-dotfiles\n' "$2" "$2"
  fi
  ln -s "$src" "$dst"
  printf 'link   %s\n' "$2"
}

link zsh/zshrc                 .zshrc
link zsh/zprofile              .zprofile
link git/gitconfig             .gitconfig
link ghostty/config            .config/ghostty/config
link herdr/config.toml         .config/herdr/config.toml
link herdr/shell.zsh           .config/herdr/shell.zsh
link ghost-complete/config.toml .config/ghost-complete/config.toml
link aerospace/aerospace.toml  .aerospace.toml
link claude/settings.json      .claude/settings.json
link quill/config.json         .config/quill/config.json

# Git identity is per-machine and never committed.
if [ ! -f "$HOME/.gitconfig.local" ]; then
  cat > "$HOME/.gitconfig.local" <<'LOCAL'
[user]
	name =
	email =
LOCAL
  printf 'create ~/.gitconfig.local — fill in name and email\n'
fi

# Managed installers (endpoint security, corp CLIs) append to ~/.zshrc; this
# file is where those blocks belong so the committed one stays portable.
touch "$HOME/.zshrc.local" "$HOME/.zprofile.local"

cat <<'NEXT'

Done. Remaining manual steps:

  1. brew bundle --file Brewfile
  2. ghost-complete doctor          # only run `ghost-complete install` if the
                                   # managed block is reported missing — it
                                   # rewrites the block with absolute paths
  3. herdr integration install claude # regenerates ~/.claude/hooks/herdr-agent-state.sh
  4. gh auth login
  5. fill in ~/.gitconfig.local
  6. ./quill/install.sh              # builds quill from source (~2 min)
NEXT
