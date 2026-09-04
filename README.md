# dotfiles

macOS setup for a terminal-first, agent-heavy workflow: Ghostty as the
emulator, [herdr](https://herdr.dev) managing one workspace per repo with
Claude Code running in the panes, ghost-complete for autocomplete, and
AeroSpace tiling it all.

## Install

```sh
git clone https://github.com/gadgetfather/dotfiles.git ~/Documents/projects/dotfiles
cd ~/Documents/projects/dotfiles
brew bundle --file Brewfile
./bootstrap.sh
```

`bootstrap.sh` symlinks everything into place, backing up anything real it
finds to `<name>.pre-dotfiles`. It's safe to re-run.

## What's here

| Path | Goes to | What it configures |
|---|---|---|
| `zsh/zshrc` | `~/.zshrc` | ghost-complete bootstrap, nvm/bun/uv, gcloud, herdr helpers |
| `zsh/zprofile` | `~/.zprofile` | Homebrew shellenv, OrbStack |
| `git/gitconfig` | `~/.gitconfig` | `gh` credential helper, SSH→HTTPS rewrite |
| `ghostty/config` | `~/.config/ghostty/config` | left Option sends Alt, so readline word-motions work |
| `herdr/config.toml` | `~/.config/herdr/config.toml` | `ctrl+g` prefix, agent sidebar sorted as an attention queue |
| `herdr/shell.zsh` | `~/.config/herdr/shell.zsh` | `hd` / `hdc` / `hdl` repo-workspace helpers, fzf bindings |
| `ghost-complete/config.toml` | `~/.config/ghost-complete/config.toml` | catppuccin theme, `multi_terminal` |
| `aerospace/aerospace.toml` | `~/.aerospace.toml` | tiling layout and ALT-based bindings |
| `claude/settings.json` | `~/.claude/settings.json` | model, notification hooks, plugin marketplaces |

## Machine-local escape hatches

Nothing machine-specific or secret is committed. Four files stay local and are
gitignored:

- `~/.gitconfig.local` — name and email (scaffolded empty by `bootstrap.sh`)
- `~/.zshrc.local`, `~/.zprofile.local` — sourced last; the place for corporate
  CA bundles, VPN clients, and managed-tool blocks. Installers love to append
  to `~/.zshrc` directly, so move anything they add into these.

## ghost-complete inside herdr

herdr spawns its pane shells itself, so they carry no `TERM_PROGRAM`.
ghost-complete's own init block only starts its PTY proxy in a terminal it
recognises, so panes get a plain shell with no autocomplete — while Ghostty
tabs work fine.

Two things fix it, both already in this repo:

1. `[experimental] multi_terminal = true` in `ghost-complete/config.toml`,
   without which the binary refuses to start in an unrecognised terminal.
2. The `HERDR_PANE_ID` block in `zsh/zshrc`, which starts the proxy itself.
   It sits outside the `ghost-complete install`-managed markers, so upgrades
   won't clobber it.

Existing panes keep their unproxied shell — open a new one to pick it up.

On a brand-new machine `~/.config/ghost-complete/shell/init.zsh` doesn't exist
yet, so `ghost-complete install` has to run once to generate it. That also
rewrites the managed block in `~/.zshrc` — which `bootstrap.sh` has symlinked
to `zsh/zshrc` — replacing `$HOME` with absolute paths. The `HERDR_PANE_ID`
block is outside the managed markers and survives. Once `init.zsh` exists,
`git checkout zsh/zshrc` restores the portable form and everything still works.

## Post-install

- `gh auth login`
- `herdr integration install claude` — regenerates
  `~/.claude/hooks/herdr-agent-state.sh`, which is herdr-managed and so not
  committed here. `claude/settings.json` references it by path.
- AeroSpace needs Accessibility permission on first launch.
