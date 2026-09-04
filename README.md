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

ghost-complete has two halves, and both must load for a pane to get
autocomplete:

1. The **initialize** block at the top of `zsh/zshrc`, which `exec`s the PTY
   proxy. `init.zsh` only does this in a terminal it recognises.
2. The **shell integration** block near the bottom of `zsh/zshrc`, which
   sources `ghost-complete.zsh` — the precmd/preexec hooks that emit OSC
   133/7771 prompt boundaries and OSC 7 cwd. Without it the proxy is running
   but has no idea where the prompt is, and `ghost-complete doctor` reports
   `missing shell-integration managed block`.

Under herdr 0.8.2 panes inherit `TERM_PROGRAM=ghostty` from the Ghostty session
that launched herdr, so `init.zsh` recognises the terminal on its own and step 1
needs no help. That is not guaranteed — start herdr from a context without
`TERM_PROGRAM` (launchd, ssh) and panes fall back to a plain shell. Two things
in this repo cover that case:

- `[experimental] multi_terminal = true` in `ghost-complete/config.toml`,
  without which the binary refuses to start in an unrecognised terminal.
- The `HERDR_PANE_ID` block in `zsh/zshrc`, which starts the proxy itself when
  `init.zsh` declined to. It sits outside the `ghost-complete install`-managed
  markers, so upgrades won't clobber it, and its `GHOST_COMPLETE_ACTIVE` guard
  keeps it from stacking a second proxy when `init.zsh` already started one.

Both managed blocks use `$HOME` rather than the absolute paths `ghost-complete
install` emits, because that command also rewrites `~/.zshrc` as a regular file
and breaks the dotfiles symlink. The cost is a false negative: `doctor` reads
these paths as literal strings and expands neither `$HOME`, `${HOME}` nor `~`,
so it reports the init script as missing. zsh expands it correctly at source
time. Verify the integration by checking the hooks are live instead:

```sh
zsh -i -c 'echo $precmd_functions'   # expect: _gc_precmd _gc_osc7_precmd
```

Existing panes keep their old shell — open a new one to pick up changes.

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
