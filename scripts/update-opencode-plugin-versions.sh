#!/usr/bin/env bash
# Refresh the pinned versions of managed OpenCode plugins from the npm registry.
# Runs as part of `make update` (after `nix flake update`) so plugin pins stay
# close to the latest releases.
#
# Rewrites modules/opencode-plugin-versions.nix. Consumers (the plugin modules
# and the top-level plugin list) pick up the new versions on the next build.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSIONS_FILE="$REPO_ROOT/modules/opencode-plugin-versions.nix"
TMP_FILE="$(mktemp)"
trap 'rm -f "$TMP_FILE"' EXIT

# Managed plugins; keep in sync with the modules that consume the versions file.
PLUGINS="
  oh-my-opencode-slim
  oh-my-openagent
  @mohak34/opencode-notifier
  opencode-gemini-auth
  opencode-nanobanana
  opencode-mem
  @ramtinj95/opencode-tokenscope
  @devtheops/opencode-plugin-otel
"

fetch_version() {
  # Scoped packages (@scope/name) need the slash percent-encoded for the registry URL
  local enc="$1"
  enc="${enc//@/%40}"
  enc="${enc//\//%2F}"
  curl -fsS "https://registry.npmjs.org/$enc/latest" |
    node -e 'let d = ""; process.stdin.on("data", c => d += c).on("end", () => { const j = JSON.parse(d); if (!j.version) process.exit(1); console.log(j.version); })'
}

{
  cat <<'EOF'
# Managed OpenCode plugin versions, refreshed automatically via: make update
# Do not edit manually; scripts/update-opencode-plugin-versions.sh rewrites this file.
{
EOF

  for pkg in $PLUGINS; do
    version="$(fetch_version "$pkg")"
    if [ -z "$version" ]; then
      echo "ERROR: could not fetch latest version of $pkg" >&2
      exit 1
    fi
    echo "  \"$pkg\" = \"$version\";"
    printf '  %-24s %s\n' "$pkg" "-> $version" >&2
  done

  echo "}"
} > "$TMP_FILE"

mv "$TMP_FILE" "$VERSIONS_FILE"
echo "Updated $VERSIONS_FILE"