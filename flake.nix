{
  description = "Nix System Configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    darwin = {
      url = "github:LnL7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-wsl = {
      url = "github:nix-community/NixOS-WSL";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = {
    self,
    darwin,
    nixos-wsl,
    flake-utils,
    home-manager,
    ...
  } @ inputs: {
    nixosConfigurations = {
      "nixos" = inputs.nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          nixos-wsl.nixosModules.wsl
          ./nixos/configuration.nix
          ./config/wsl
          home-manager.nixosModules.home-manager
          {
            home-manager.users.nixos = import ./home/home.nix;
          }
        ];
      };
    };

    darwinConfigurations = {
      "MacBook-Pro" = darwin.lib.darwinSystem {
        system = "aarch64-darwin";
        modules = [
          ./darwin/darwin.nix
          home-manager.darwinModules.home-manager
          {
            home-manager = {
              users.matthias = import ./home/home.nix;
            };
            users.users.matthias.home = "/Users/matthias";
          }
        ];
        specialArgs = { inherit inputs; };
      };
      "MacBook-Pro-Home" = darwin.lib.darwinSystem {
        system = "x86_64-darwin";
        modules = [
          ./darwin/darwin.nix
          home-manager.darwinModules.home-manager
          {
            home-manager = {
              users.matthias = import ./home/home.nix;
            };
            users.users.matthias.home = "/Users/matthias";
          }
        ];
        specialArgs = { inherit inputs; };
      };
    };
  };
}
