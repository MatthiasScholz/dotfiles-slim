check:
	nix flake check

info:
	nix flake info
	nix flake show

update:
	nix flake update

switch:
	sudo nix run nix-darwin -- switch --show-trace --flake ~/projects/config/dotfiles-slim

setup:
	sudo nix run nix-darwin -- switch --flake . --refresh

list-generations:
	nix-env --list-generations

rollback:
	nix-env --rollback

rollback-nix-darwin:
	/run/current-system/bin/switch-to-configuration boot

# NOTE it seems nix is not uninstalling brew installed apps, even when done via the flake
app ?= unset
uninstall-brew:
	brew uninstall $(app)
