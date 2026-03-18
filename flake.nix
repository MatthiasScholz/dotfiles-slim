{
  description = "Nix System Configuration";

  inputs = {
    # The main nixpkgs instance (for M-series Macs)
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # Stable instance
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-25.11";

    # NOTE Pinned release specifically for the Intel Mac
    # TODO Once released: nixpkgs-26_05.url = "github:NixOS/nixpkgs/nixos-26.05";
    nixpkgs-26_05.url = "github:NixOS/nixpkgs/nixos-unstable";

    # For installing homebrew
    nix-homebrew.url = "github:zhaofengli-wip/nix-homebrew";

    # Homebrew Tap Management
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
      inputs.nixpkgs.follows = "nixpkgs";
    };

    darwin = {
      url = "github:LnL7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/3";
    git-ai.url = "github:git-ai-project/git-ai";

    gws-cli = {
      url = "github:googleworkspace/cli";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      nixpkgs-stable,
      nixpkgs-26_05, # <-- Inject the pinned input here
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
      git-ai,
      gws-cli,
      ...
    }@inputs:
    let
      lib = nixpkgs.lib;

      # Factory function to generate standard macOS systems
      # Notice we added `pkgsInput` which defaults to standard `nixpkgs`
      mkDarwinSystem =
        {
          system,
          stateVersion,
          primaryUser,
          otherUsers ? [ ],
          extraModules ? [ ],
          pkgsInput ? nixpkgs,
        }:
        let
          allUsers = [ primaryUser ] ++ otherUsers;
        in
        darwin.lib.darwinSystem {
          inherit system;
          specialArgs = { inherit inputs; };
          modules = [
            # 1. Force Nix-Darwin to evaluate using the chosen pkgsInput
            {
              nixpkgs.pkgs = import pkgsInput {
                inherit system;
                config.allowUnfree = true;
              };

              # Optional but recommended: Pin the flake registry so `nix run nixpkgs#hello`
              # on the CLI uses the correct pinned version for this specific machine.
              nix.registry.nixpkgs.flake = pkgsInput;
            }

            ./darwin/darwin.nix

            {
              system.stateVersion = stateVersion;
              system.primaryUser = primaryUser;

              users.users = lib.genAttrs allUsers (user: {
                home = "/Users/${user}";
              });
            }

            home-manager.darwinModules.home-manager
            {
              home-manager = {
                backupFileExtension = "bak";
                # Because we explicitly defined nixpkgs.pkgs above, Home Manager
                # will automatically inherit it via useGlobalPkgs!
                useGlobalPkgs = true;
                useUserPackages = false;
                extraSpecialArgs = { inherit inputs; };

                users = lib.genAttrs allUsers (user: import ./home/home.nix);
              };
            }

            nix-homebrew.darwinModules.nix-homebrew
            {
              nix-homebrew = {
                enable = true;
                autoMigrate = true;
                user = primaryUser;

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
          ]
          ++ extraModules;
        };
    in
    {
      darwinConfigurations = {

        "Matthiass-MacBook-Pro" = mkDarwinSystem {
          system = "aarch64-darwin";
          stateVersion = 4;
          primaryUser = "matthias";
          # Omitting pkgsInput means this safely defaults to standard unstable nixpkgs
          extraModules = [
            inputs.determinate.darwinModules.default
            {
              determinateNix.enable = true;
            }
          ];
        };

        "MacPro" = mkDarwinSystem {
          system = "x86_64-darwin";
          stateVersion = 6;
          primaryUser = "mat";
          otherUsers = [ "pia" ];
          # Explicitly pin this machine to 26.05 to prevent Intel deprecation breakage
          pkgsInput = nixpkgs-26_05;
        };

      };
    };
}
