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
# in settings.json, never in preferences.json, and are never synced. The
# refuse policy below aborts instead of copying anything credential-shaped.

set -euo pipefail

# shellcheck source=SCRIPTDIR/lib/sync-config.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/sync-config.sh"

sync_config \
  --src "${OPENCHAMBER_DATA_DIR:-$HOME/.config/openchamber}/preferences.json" \
  --dst config/openchamber/preferences.json \
  --missing-hint "start OpenChamber once so it creates a settings file" \
  --secret-policy refuse \
  --secret-pattern '(token|secret|password|credential)' \
  --add-n always \
  --diff-mode head
