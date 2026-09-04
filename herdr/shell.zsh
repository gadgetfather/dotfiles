# herdr helpers — repo switcher for Claude Code workspaces
# Sourced from ~/.zshrc. Edit HD_ROOTS to change which trees are scanned.

: ${HD_ROOTS:="$HOME/Documents/projects $HOME/Documents/lab $HOME/Documents"}

# List every git repo under HD_ROOTS, deduped.
_hd_repos() {
  local roots; roots=(${=HD_ROOTS})
  find "${roots[@]}" -maxdepth 3 -type d -name .git \
       -not -path '*/node_modules/*' -not -path '*/Library/*' 2>/dev/null \
    | sed 's|/\.git$||' | sort -u
}

# Resolve a repo path. With an argument: prefer an exact repo-name match, then a
# name prefix, then a name substring, then anywhere in the path. If the argument
# is still ambiguous, hand the shortlist to fzf pre-filled rather than guessing.
_hd_pick() {
  local q=$1 all matches
  all=(${(f)"$(_hd_repos)"})
  (( ${#all} )) || { print -u2 "hd: no git repos under \$HD_ROOTS ($HD_ROOTS)"; return 1 }

  if [[ -z "$q" ]]; then
    printf '%s\n' "${all[@]}" | fzf --prompt='repo > ' --height=45% --reverse --border \
      --preview 'git -C {} log --oneline --color=always -12 2>/dev/null' \
      --preview-window=right:55%
    return
  fi

  matches=(${(M)all:#*/${q}})                       # exact repo name
  (( ${#matches} )) || matches=(${(M)all:#*/${q}*})  # name starts with q
  (( ${#matches} )) || matches=(${(M)all:#*/*${q}*}) # name contains q
  (( ${#matches} )) || matches=(${(M)all:#*${q}*})   # anywhere in path

  case ${#matches} in
    0) print -u2 "hd: no repo matching '$q'"; return 1 ;;
    1) print -r -- "${matches[1]}" ;;
    *) printf '%s\n' "${matches[@]}" | fzf --prompt="repo > " --query="$q" --select-1 \
         --height=45% --reverse --border \
         --preview 'git -C {} log --oneline --color=always -12 2>/dev/null' \
         --preview-window=right:55% ;;
  esac
}

# Existing workspace id for a label, empty if none.
_hd_wid() {
  herdr workspace list 2>/dev/null | python3 -c '
import json,sys
try: ws=json.load(sys.stdin)["result"]["workspaces"]
except Exception: sys.exit(0)
for w in ws:
    if w.get("label")==sys.argv[1]: print(w["workspace_id"]); break
' "$1" 2>/dev/null
}

# hd [repo]  — focus or create a workspace for a repo, then attach.
hd() {
  local repo label wid
  repo=$(_hd_pick "$1") || return 1
  [[ -z "$repo" ]] && { print -u2 "hd: no repo matching '${1:-}'"; return 1 }
  label=${repo:t}
  wid=$(_hd_wid "$label")
  if [[ -n "$wid" ]]; then
    herdr workspace focus "$wid" >/dev/null
  else
    herdr workspace create --cwd "$repo" --label "$label" --focus >/dev/null
  fi
  [[ "${HERDR_ENV:-}" == "1" ]] || herdr
}

# hdc [repo] — same as hd, but also launches Claude Code in the new workspace.
hdc() {
  local repo label wid pane
  repo=$(_hd_pick "$1") || return 1
  [[ -z "$repo" ]] && { print -u2 "hdc: no repo matching '${1:-}'"; return 1 }
  label=${repo:t}
  wid=$(_hd_wid "$label")
  if [[ -n "$wid" ]]; then
    herdr workspace focus "$wid" >/dev/null
  else
    pane=$(herdr workspace create --cwd "$repo" --label "$label" --focus 2>/dev/null \
      | python3 -c 'import json,sys; print(json.load(sys.stdin)["result"]["root_pane"]["pane_id"])' 2>/dev/null)
    [[ -n "$pane" ]] && herdr agent start claude --kind claude --pane "$pane" >/dev/null 2>&1
  fi
  [[ "${HERDR_ENV:-}" == "1" ]] || herdr
}

# hdl — one-line status of every workspace, most-urgent agent state first.
hdl() {
  python3 - <<'PY'
import json, subprocess, sys

try:
    out = subprocess.run(["herdr", "workspace", "list"],
                         capture_output=True, text=True, timeout=10).stdout
    ws = json.loads(out)["result"]["workspaces"]
except Exception as exc:
    print("hdl: could not reach the herdr server (%s)" % exc, file=sys.stderr)
    sys.exit(1)

if not ws:
    print("no workspaces")
    sys.exit(0)

MARK = {"blocked": "!", "working": "~", "done": "+", "idle": ".", "unknown": "?"}
RANK = {"blocked": 0, "working": 1, "done": 2, "idle": 3, "unknown": 4}

for w in sorted(ws, key=lambda w: (RANK.get(w.get("agent_status"), 9), w.get("number", 0))):
    state = w.get("agent_status", "unknown")
    print("{} {}. {:<28} [{}] {} pane(s)".format(
        MARK.get(state, "?"), w.get("number"), w.get("label"), state, w.get("pane_count")))
PY
}

# Tab-complete repo names for hd/hdc.
if (( $+functions[compdef] )); then
  _hd_complete() { compadd -- ${(f)"$(_hd_repos | xargs -n1 basename 2>/dev/null)"} }
  compdef _hd_complete hd hdc
fi

# fzf shell integration (Ctrl-R history, Ctrl-T files, Alt-C cd).
if command -v fzf >/dev/null 2>&1; then
  source <(fzf --zsh) 2>/dev/null
fi
