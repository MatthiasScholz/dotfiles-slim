check:
	nix flake check

info:
	nix flake info
	nix flake show

update:
	nix flake update

# NOTE it seems nix is not uninstalling brew installed apps, even when done via the flake
app ?= unset
uninstall-brew:
	brew uninstall $(app)
