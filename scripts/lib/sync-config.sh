#!/usr/bin/env bash
# sync-config — shared flow for the config sync-back scripts.
#
# See docs/adr/0003-agentsview-config-sync-back.md and
# docs/adr/0005-openchamber-nix-launchd-integration.md. A profile
# (scripts/sync-config-*.sh) sources this file and passes its paths, header
# and secret policy to `sync_config`; the module owns the flow:
#
#   source precondition -> mkdir -> secret guard -> write -> intent-to-add
#   -> "no changes" check -> diff/approve hints -> git diff
#
# The secret guard is a *policy slot*, not one algorithm. Both policies keep
# wiping an unchanged `add -N` / diff base from turning into a silent copy of
# secrets into git; they are deliberately not unified:
#
#   strip   drop secret-looking lines and continue (AgentsView TOML)
#   refuse  abort when a secret-looking key is present (OpenChamber JSON)

# Repo root, derived from this library's location: scripts/lib -> scripts -> repo.
_sync_config_repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

_sync_config_usage() {
  cat >&2 <<'EOF'
usage: sync_config --src <path> --dst <repo-relative-path> --missing-hint <text>
                   --secret-policy <strip|refuse> --secret-pattern <regex>
                   --add-n <if-missing|always> --diff-mode <worktree|head>
                   [--header <text>]
EOF
}

# strip policy: copy the source verbatim minus secret-looking lines, then
# prepend the generated header (if any). Header is added *after* stripping so
# a secret line can never hide behind it.
_sync_config_strip() {
  local src="$1" dst="$2" pattern="$3" header="${4:-}"
  sed -E "/${pattern}/d" "$src" > "$dst"
  if [[ -n "$header" ]]; then
    {
      printf '%s\n' "$header"
      cat "$dst"
    } > "${dst}.tmp" && mv "${dst}.tmp" "$dst"
  fi
}

# Report which keys were stripped so the redaction stays visible in the run.
_sync_config_report_stripped() {
  local src="$1" pattern="$2"
  if grep -qE "${pattern}" "$src"; then
    echo "Stripped secret keys (not copied into version control):"
    grep -oE "${pattern}" "$src" | sed 's/ =.*//' | sed 's/^/  - /'
    echo "  (the daemon regenerates them when missing; agenix migration: ADR-0003/0004)"
    echo
  fi
}

# refuse policy: canonicalise JSON and abort if any profile field looks like a
# credential. Canonical form is load-bearing: a changed byte would make the
# live file differ from the committed one and the diff would lie.
_sync_config_refuse() {
  local src="$1" dst="$2" pattern="$3" dst_rel="$4"
  python3 - "$src" "$dst" "$pattern" "$dst_rel" <<'PY'
import json
import re
import sys

src, dst, pattern, dst_rel = sys.argv[1:5]
try:
    doc = json.loads(open(src, encoding="utf-8").read())
except (OSError, json.JSONDecodeError) as error:
    sys.exit(f"{src}: cannot read preferences: {error}")

fields = doc.get("fields") if isinstance(doc, dict) else None
if not isinstance(fields, dict):
    sys.exit(f"{src}: not a preferences document (missing 'fields')")

# Profile keys are user preferences and never secrets, but a mis-pointed
# data dir should not be able to commit credentials.
suspicious = sorted(
    key for key in fields if re.search(pattern, key, re.I)
)
if suspicious:
    sys.exit(f"{src}: refusing to sync, secret-looking keys: {', '.join(suspicious)}")

# Sorted keys keep the diff readable; 2-space indent matches what the app
# writes, and (like upstream) no trailing newline.
with open(dst, "w", encoding="utf-8") as handle:
    handle.write(json.dumps(doc, indent=2, sort_keys=True, ensure_ascii=False))

print(f"synced {src} -> {dst_rel} ({len(fields)} fields)")
PY
}

sync_config() {
  local src='' dst_rel='' missing_hint='' policy='' pattern='' \
        add_n='' diff_mode='' header=''
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --src) src="${2:?missing value for --src}"; shift 2 ;;
      --dst) dst_rel="${2:?missing value for --dst}"; shift 2 ;;
      --missing-hint) missing_hint="${2:?missing value for --missing-hint}"; shift 2 ;;
      --secret-policy) policy="${2:?missing value for --secret-policy}"; shift 2 ;;
      --secret-pattern) pattern="${2:?missing value for --secret-pattern}"; shift 2 ;;
      --add-n) add_n="${2:?missing value for --add-n}"; shift 2 ;;
      --diff-mode) diff_mode="${2:?missing value for --diff-mode}"; shift 2 ;;
      --header) header="${2:-}"; shift 2 ;;
      -h|--help) _sync_config_usage; return 0 ;;
      *) echo "sync-config: unknown option: $1" >&2; _sync_config_usage; return 2 ;;
    esac
  done

  local repo_dir="$_sync_config_repo_dir"
  local dst="$repo_dir/$dst_rel"

  if [[ ! -f "$src" ]]; then
    echo "error: $src not found — $missing_hint" >&2
    return 1
  fi

  # Only meaningful for the conditional intent-to-add below; capture it before
  # the write so "first sync" means "destination did not exist yet".
  local existed=false
  [[ -f "$dst" ]] && existed=true

  mkdir -p "$(dirname "$dst")"

  case "$policy" in
    strip)
      _sync_config_strip "$src" "$dst" "$pattern" "$header"
      echo "Copied $src -> $dst_rel (secret keys stripped)"
      echo
      _sync_config_report_stripped "$src" "$pattern"
      ;;
    refuse)
      _sync_config_refuse "$src" "$dst" "$pattern" "$dst_rel"
      ;;
    *)
      echo "sync-config: unknown secret policy: $policy" >&2
      return 2
      ;;
  esac

  # Intent-to-add makes the file visible to the flake and to `git diff` on a
  # first sync. AgentsView only needs it when the destination is new;
  # OpenChamber runs it every time (a documented no-op once tracked).
  if [[ "$add_n" == always ]] || [[ "$add_n" == if-missing && "$existed" == false ]]; then
    git -C "$repo_dir" add -N -- "$dst_rel"
  fi

  echo

  # OpenChamber diffs against HEAD so a previously staged file still shows.
  if [[ "$diff_mode" == head ]] && git -C "$repo_dir" diff --quiet HEAD -- "$dst_rel"; then
    echo "No changes: the live settings already match the committed file."
    return 0
  fi

  if [[ "$diff_mode" == head ]]; then
    echo "Review the diff below (live vs HEAD)."
    echo "  approve: git add $dst_rel && git commit"
    echo "  reject:  git checkout HEAD -- $dst_rel"
    echo "           (first sync only: rm $dst_rel)"
    echo
    git -C "$repo_dir" --no-pager diff HEAD -- "$dst_rel"
  else
    echo "Review the diff below."
    echo "  approve: git add $dst_rel && git commit"
    echo "  reject:  git checkout -- $dst_rel"
    echo
    git -C "$repo_dir" --no-pager diff -- "$dst_rel"
  fi
}
