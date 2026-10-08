check:
	nix flake check

info:
	nix flake info
	nix flake show

update:
	nix flake update
	./scripts/update-opencode-plugin-versions.sh

# AgentsView: copy the live ~/.agentsview/config.toml over the version-controlled
# copy, then review the git diff (docs/adr/0003-agentsview-config-sync-back.md)
sync-config-agentsview:
	./scripts/sync-config-agentsview.sh

# OpenChamber: copy the live ~/.config/openchamber/preferences.json over the
# version-controlled copy, then review the git diff (modules/openchamber.nix)
sync-config-openchamber:
	./scripts/sync-config-openchamber.sh

# OpenChamber: print the UI password from the agenix secret. The age key is
# passed explicitly because the agenix CLI defaults to ~/.ssh/id_rsa|id_ed25519.
# Pipe to pbcopy to paste it on another device: make openchamber-password | pbcopy
openchamber-password:
	@agenix -d secrets/openchamber-web.age -i "$(HOME)/.config/sops/age/keys.txt" && echo

# nix-darwin activation needs root, but plain `sudo` inherits the invoking
# user's HOME, so Nix warns "$HOME ('/Users/matthias') is not owned by you"
# and falls back to /var/root. -H (--set-home) points HOME at root up front.
SUDO ?= sudo -H

update-nixd:
	sudo determinate-nixd upgrade

login-flake-hub:
	determinate-nixd login

# Name of the profile take from flake.nix
profile ?= .#Matthiass-MacBook-Pro
build:
	nix run nix-darwin -- build --flake $(profile)
	make diff

diff:
	@if [ ! -e /run/current-system ]; then \
		echo "Skipping diff: /run/current-system does not exist (never switched)"; \
		exit 0; \
	fi; \
	nix run nixpkgs#nvd -- diff /run/current-system ./result

update-diff: update build diff

switch:
	$(SUDO) nix run nix-darwin -- switch --show-trace --flake ~/projects/config/dotfiles-slim

setup:
	$(SUDO) nix run nix-darwin -- switch --flake . --refresh

rollback:
	/run/current-system/sw/bin/darwin-rebuild switch --rollback

# NOTE it seems nix is not uninstalling brew installed apps, even when done via the flake
app ?= unset
uninstall-brew:
	brew uninstall $(app)
