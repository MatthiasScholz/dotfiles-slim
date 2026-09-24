#!/usr/bin/env bash
# OpenChamber preferences sync-back — mirrors ADR-0003 (see
# docs/adr/0005-openchamber-nix-launchd-integration.md).
#
# OpenChamber's user configuration is ~/.config/openchamber/preferences.json:
# the "profile"-scoped keys of its settings registry (themes, models,
# notifications, appearance, ...). Home Manager owns that file
# (modules/openchamber.nix), so a change made in the UI is lost on the next
# switch — copy it back here first, review the git diff, and commit what should
# become declarative.
#
# Approve:  git add config/openchamber/preferences.json && git commit
# Reject:   git checkout HEAD -- config/openchamber/preferences.json
#
# Instance-scoped keys (relay/tunnel tokens, UI password, ssh hosts, ...) live
# in settings.json, never in preferences.json, and are never synced. A guard
# below refuses to copy anything that looks like a credential.

set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
src="${OPENCHAMBER_DATA_DIR:-$HOME/.config/openchamber}/preferences.json"
dst="$repo_dir/config/openchamber/preferences.json"

if [[ ! -f "$src" ]]; then
  echo "error: $src not found — start OpenChamber once so it creates a settings file" >&2
  exit 1
fi

mkdir -p "$(dirname "$dst")"

python3 - "$src" "$dst" <<'PY'
import json
import re
import sys

src, dst = sys.argv[1], sys.argv[2]
try:
    doc = json.loads(open(src, encoding="utf-8").read())
except (OSError, json.JSONDecodeError) as error:
    sys.exit(f"{src}: cannot read preferences: {error}")

fields = doc.get("fields") if isinstance(doc, dict) else None
if not isinstance(fields, dict):
    sys.exit(f"{src}: not a preferences document (missing 'fields')")

# Profile keys are user preferences and never secrets, but a mis-pointed
# OPENCHAMBER_DATA_DIR should not be able to commit credentials.
suspicious = sorted(
    key for key in fields if re.search(r"(token|secret|password|credential)", key, re.I)
)
if suspicious:
    sys.exit(f"{src}: refusing to sync, secret-looking keys: {', '.join(suspicious)}")

# Sorted keys keep the diff readable; 2-space indent matches what OpenChamber
# writes, and (like upstream) no trailing newline.
with open(dst, "w", encoding="utf-8") as handle:
    handle.write(json.dumps(doc, indent=2, sort_keys=True, ensure_ascii=False))

print(f"synced {src} -> config/openchamber/preferences.json ({len(fields)} fields)")
PY

# Make the file visible to `git diff` even on a first sync. Intent-to-add is a
# no-op for an already-tracked file, so this is safe to run every time.
git -C "$repo_dir" add -N -- config/openchamber/preferences.json

echo

# Diff against HEAD, not the index: the file may already be staged (`git add`)
# from a previous review, and the change still needs to be visible before
# committing it.
if git -C "$repo_dir" diff --quiet HEAD -- config/openchamber/preferences.json; then
  echo "No changes: the live settings already match the committed file."
  exit 0
fi

echo "Review the diff below (live vs HEAD)."
echo "  approve: git add config/openchamber/preferences.json && git commit"
echo "  reject:  git checkout HEAD -- config/openchamber/preferences.json"
echo "           (first sync only: rm config/openchamber/preferences.json)"
echo
git -C "$repo_dir" --no-pager diff HEAD -- config/openchamber/preferences.json
