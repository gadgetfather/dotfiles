#!/usr/bin/env bash
# Build and install quill (github.com/digimata/quill) — a local macOS meeting
# recorder + transcriber. Not in Homebrew: upstream publishes no tap and no
# release binaries, so this builds from source. Safe to re-run; an existing
# clone is updated rather than re-cloned.
#
# Deliberately NOT called from bootstrap.sh, which is a symlink-only script
# that must stay fast and re-runnable. A Swift release build takes ~2 minutes.
set -euo pipefail

SRC="${QUILL_SRC:-$HOME/Documents/Lab/quill}"
BIN_DIR="${QUILL_BIN_DIR:-$HOME/.local/bin}"
BIN="$BIN_DIR/quill"
REPO="https://github.com/digimata/quill.git"

command -v swift >/dev/null 2>&1 || {
  echo "error: no swift toolchain. Install the Command Line Tools:" >&2
  echo "  sudo xcode-select --install" >&2
  exit 1
}

# Core Audio process taps need macOS 14.2+; upstream asks for 15+.
major="$(sw_vers -productVersion | cut -d. -f1)"
[ "$major" -ge 15 ] || { echo "error: needs macOS 15+, found $(sw_vers -productVersion)" >&2; exit 1; }

if [ -d "$SRC/.git" ]; then
  # A local patch in the clone must not abort the install: --ff-only refuses to
  # run against a dirty tree, and `set -e` would take the whole script with it.
  # Skip the pull and build what is there instead.
  if [ -n "$(git -C "$SRC" status --porcelain)" ]; then
    printf 'skip   pull (%s has local changes) — building as-is\n' "$SRC"
  else
    printf 'update %s\n' "$SRC"
    git -C "$SRC" pull --ff-only
  fi
else
  printf 'clone  %s\n' "$SRC"
  mkdir -p "$(dirname "$SRC")"
  git clone "$REPO" "$SRC"
fi

printf 'build  release (~2 min)\n'
( cd "$SRC" && swift build -c release )

mkdir -p "$BIN_DIR"
install -m 755 "$SRC/.build/release/quill" "$BIN"
printf 'install %s\n' "$BIN"

# `quill install --launch-at-login` hardcodes /usr/local/bin and only falls
# back to the running binary when argv[0] is absolute. Invoking "$BIN" (not a
# bare PATH lookup) is what makes it register this copy instead of failing.
"$BIN" install --launch-at-login

case ":$PATH:" in
  *":$BIN_DIR:"*) ;;
  *) printf '\nnote: %s is not on PATH — add it to ~/.zshrc.local\n' "$BIN_DIR" ;;
esac

cat <<'NEXT'

Done. Notes:

  * `quill doctor` reports models missing until the first transcription —
    record a short throwaway session while online so the ~600 MB Parakeet
    download does not happen right after a meeting you care about.
  * System Audio Recording cannot be verified up front; macOS prompts on the
    first recording. Silent system.caf means it was denied:
    System Settings -> Privacy & Security -> Screen & System Audio Recording.
  * Config is symlinked by bootstrap.sh to ~/.config/quill/config.json.
NEXT
