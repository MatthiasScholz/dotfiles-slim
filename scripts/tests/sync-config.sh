#!/usr/bin/env bash
# Regression tests for the sync-config flow (scripts/lib/sync-config.sh).
#
# Runs both profiles inside a throwaway git repo so the real config/** is
# never touched, then pins the behaviours the refactor had to preserve:
# the strip and refuse secret policies, JSON canonicalisation, the
# source-missing precondition, and the OpenChamber "no changes" fast path.
# Nix is not involved; `make check` still gates the flake.

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

failed=0
pass() { printf 'ok   %s\n' "$1"; }
fail() { printf 'FAIL %s\n' "$1" >&2; failed=1; }

roll_repo() {
  rm -rf "$tmp/repo"
  mkdir -p "$tmp/repo"
  cp -R "$repo_root/scripts" "$tmp/repo/"
  git -C "$tmp/repo" init -q
  git -C "$tmp/repo" config user.email t@t
  git -C "$tmp/repo" config user.name t
  git -C "$tmp/repo" config commit.gpgsign false
  printf 'base\n' > "$tmp/repo/README"
  git -C "$tmp/repo" add README
  git -C "$tmp/repo" commit -qm init
}

run() { ( cd "$tmp/repo" && "$@" ); }

av_dst="$tmp/repo/config/agentsview/config.toml"
oc_dst="$tmp/repo/config/openchamber/preferences.json"

# --- 1. AgentsView: strip policy, header, report ---------------------------
roll_repo
cat > "$tmp/av.toml" <<'EOF'
require_auth = true
auth_token = "tok-123"
cursor_secret = "cs-456"
archive_content = true
EOF
if run env AGENTSVIEW_CONFIG="$tmp/av.toml" ./scripts/sync-config-agentsview.sh > "$tmp/av.out" 2>&1; then
  pass "agentsview first sync exits 0"
else
  fail "agentsview first sync exits 0"
fi
if [[ -f "$av_dst" ]] && ! grep -qE '^(auth_token|cursor_secret) = ' "$av_dst" \
   && grep -qx 'require_auth = true' "$av_dst"; then
  pass "agentsview strips secret lines, keeps the rest"
else
  fail "agentsview strips secret lines, keeps the rest"
fi
if [[ "$(head -n1 "$av_dst")" == "# AgentsView configuration - version-controlled copy." ]]; then
  pass "agentsview prepends the generated header"
else
  fail "agentsview prepends the generated header"
fi
if grep -q 'Stripped secret keys' "$tmp/av.out"; then
  pass "agentsview reports stripped keys"
else
  fail "agentsview reports stripped keys"
fi

# --- 2. OpenChamber: canonical JSON, no trailing newline -------------------
roll_repo
mkdir -p "$tmp/oc"
printf '%s' '{"fields":{"zoom":1.0,"theme":"dark"}}' > "$tmp/oc/preferences.json"
if run env OPENCHAMBER_DATA_DIR="$tmp/oc" ./scripts/sync-config-openchamber.sh > "$tmp/oc.out" 2>&1; then
  pass "openchamber first sync exits 0"
else
  fail "openchamber first sync exits 0"
fi
expected="$(cat <<'EOF'
{
  "fields": {
    "theme": "dark",
    "zoom": 1.0
  }
}
EOF
)"
printf '%s' "$expected" > "$tmp/oc.expected"
if [[ -f "$oc_dst" ]] && cmp -s "$tmp/oc.expected" "$oc_dst"; then
  pass "openchamber canonicalises JSON (sorted, 2-space, no trailing newline)"
else
  fail "openchamber canonicalises JSON (sorted, 2-space, no trailing newline)"
fi

# --- 3. OpenChamber: refuse policy leaves the destination untouched --------
roll_repo
mkdir -p "$tmp/oc-secret"
printf '%s' '{"fields":{"theme":"dark","password":"hunter2"}}' > "$tmp/oc-secret/preferences.json"
if run env OPENCHAMBER_DATA_DIR="$tmp/oc-secret" ./scripts/sync-config-openchamber.sh > "$tmp/oc-secret.out" 2>&1; then
  fail "openchamber refuses secret-looking keys (non-zero exit)"
else
  pass "openchamber refuses secret-looking keys (non-zero exit)"
fi
if [[ ! -e "$oc_dst" ]] && grep -q 'refusing to sync, secret-looking keys: password' "$tmp/oc-secret.out"; then
  pass "openchamber refusal leaves the destination untouched"
else
  fail "openchamber refusal leaves the destination untouched"
fi

# --- 4. source-missing precondition ----------------------------------------
roll_repo
if run env AGENTSVIEW_CONFIG="$tmp/nope.toml" ./scripts/sync-config-agentsview.sh > "$tmp/av-missing.out" 2>&1; then
  fail "agentsview missing source exits non-zero"
else
  pass "agentsview missing source exits non-zero"
fi
if grep -q 'run agentsview once so it creates a config file' "$tmp/av-missing.out"; then
  pass "agentsview missing-source hint"
else
  fail "agentsview missing-source hint"
fi

# --- 5. OpenChamber: committed file fast path ------------------------------
roll_repo
mkdir -p "$tmp/oc2"
printf '%s' '{"fields":{"theme":"dark"}}' > "$tmp/oc2/preferences.json"
run env OPENCHAMBER_DATA_DIR="$tmp/oc2" ./scripts/sync-config-openchamber.sh > /dev/null 2>&1
git -C "$tmp/repo" add "$oc_dst"
git -C "$tmp/repo" commit -qm sync
if run env OPENCHAMBER_DATA_DIR="$tmp/oc2" ./scripts/sync-config-openchamber.sh > "$tmp/oc-nochange.out" 2>&1 \
   && grep -q 'No changes: the live settings already match the committed file.' "$tmp/oc-nochange.out"; then
  pass "openchamber reports no changes against a committed file"
else
  fail "openchamber reports no changes against a committed file"
fi

if [[ "$failed" -eq 0 ]]; then
  printf '\nall sync-config tests passed\n'
else
  printf '\nsome sync-config tests FAILED\n' >&2
  exit 1
fi
