{
  description = "Nix System Configuration";

  inputs = {
    # The main nixpkgs instance
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-24.11";

    # TODO separate homebrew setup and combine with homebrew usage
    # For installing homebrew
    nix-homebrew = {
      url = "github:zhaofengli-wip/nix-homebrew";
    };
    # Homebrew Tap Management
    # NOTE: https://github.com/zhaofengli/nix-homebrew?tab=readme-ov-file#declarative-taps
    homebrew-core = {
      url = "github:homebrew/homebrew-core";
      flake = false;
    };
    homebrew-cask = {
      url = "github:homebrew/homebrew-cask";
      flake = false;
    };
    homebrew-sm = {
      url = "github:clok/homebrew-sm";
      flake = false;
    };
    homebrew-gossm = {
      url = "github:gjbae1212/homebrew-gossm";
      flake = false;
    };
    homebrew-awslim = {
      url = "github:fujiwara/homebrew-tap";
      flake = false;
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      # optional, not necessary for the module
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # TODO import the 1Password Shell Plugins Flake
    # _1password-shell-plugins.url = "github:1Password/shell-plugins";

    darwin = {
      url = "github:LnL7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs-stable,
      darwin,
      sops-nix,
      flake-utils,
      home-manager,
      nix-homebrew,
      homebrew-core,
      homebrew-cask,
      homebrew-sm,
      homebrew-gossm,
      homebrew-awslim,
      ...
    }@inputs:
    let
      nixpkgsConfig = {
        config.allowUnfree = true;
      };
    in
    {
      # NOTE configure automatic backup of existing files
      home-manager.backupFileExtension = "bak";

      darwinConfigurations = {
        "Matthiass-MacBook-Pro" = darwin.lib.darwinSystem {
          system = "aarch64-darwin";
          modules = [
            ./darwin/darwin.nix

            # FIXME Not working missing OpenSSH enable - Encryption
            #sops-nix.nixosModules.sops
            # FIXME Not working when installing stuff via home-manager - should I? Template flakes are not using home-manager either
            # ./secrets/encryption.nix

            home-manager.darwinModules.home-manager
            {
              nixpkgs = nixpkgsConfig;

              home-manager = {
                # FIXME sync with all macosx configurations
                useGlobalPkgs = true;
                # NOTE setting to true will create an unrecognized path for binaries for emacs
                useUserPackages = false;
                users.matthias = import ./home/home.nix;
              };
              users.users.matthias.home = "/Users/matthias";
            }

            # FIXME move inside ./darwin/darwin.nix file if possible - keep the flake short
            # TODO Do this for all MacOSX systems NOT only this single one
            nix-homebrew.darwinModules.nix-homebrew
            {
              nix-homebrew = {
                enable = true;
                autoMigrate = true;
                # FIXME use the user name set via darwinConfiguration
                user = "matthias";

                # TODO check if this is necessary
                taps = {
                  "homebrew/homebrew-core" = homebrew-core;
                  "homebrew/homebrew-cask" = homebrew-cask;
                  "clok/homebrew-sm" = homebrew-sm;
                  "gjbae1212/homebrew-gossm" = homebrew-gossm;
                  "fujiwara/homebrew-tap" = homebrew-awslim;
                };
                mutableTaps = false;
              };
            }

          ];
          specialArgs = {
            inherit inputs;
          };
        };
        "MacPro" = darwin.lib.darwinSystem {
          system = "x86_64-darwin";
          modules = [
            ./darwin/darwin.nix
            home-manager.darwinModules.home-manager
            {
              nixpkgs = nixpkgsConfig;

              home-manager = {
                # FIXME sync with all macosx configurations
                useGlobalPkgs = true;
                # NOTE setting to true will create an unrecognized path for binaries for emacs
                useUserPackages = false;

                users.mat = import ./home/home.nix;
              };
              users.users.mat.home = "/Users/mat";
            }

            # FIXME move inside ./darwin/darwin.nix file if possible - keep the flake short
            # TODO Do this for all MacOSX systems NOT only this single one
            nix-homebrew.darwinModules.nix-homebrew
            {
              nix-homebrew = {
                enable = true;
                autoMigrate = true;
                # FIXME use the user name set via darwinConfiguration
                user = "mat";

                # TODO check if this is necessary
                taps = {
                  "homebrew/homebrew-core" = homebrew-core;
                  "homebrew/homebrew-cask" = homebrew-cask;
                  "clok/homebrew-sm" = homebrew-sm;
                };
                mutableTaps = false;
              };
            }
          ];
          specialArgs = {
            inherit inputs;
          };
        };
      };
    };
}
