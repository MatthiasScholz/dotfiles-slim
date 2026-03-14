check:
	nix flake check

info:
	nix flake info
	nix flake show

update:
	nix flake update


# Name of the profile take from flake.nix
profile ?= .#Matthiass-MacBook-Pro
build:
	nix run nix-darwin -- build --flake $(profile)
	make diff

diff:
	nix run nixpkgs#nvd -- diff /run/current-system ./result

update-diff: update build diff

switch:
	sudo nix run nix-darwin -- switch --show-trace --flake ~/projects/config/dotfiles-slim

setup:
	sudo nix run nix-darwin -- switch --flake . --refresh

rollback:
	/run/current-system/sw/bin/darwin-rebuild switch --rollback

# NOTE it seems nix is not uninstalling brew installed apps, even when done via the flake
app ?= unset
uninstall-brew:
	brew uninstall $(app)
