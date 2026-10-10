{ config, pkgs, ... }:

{
  # Declaratively create /etc/nix/nix.custom.conf for Determinate Nix
  environment.etc = {
    "nix/nix.custom.conf".text = ''
      # This configuration is necessary to allow the user to use binary caches
      # like the one required by devenv (Cachix) without being root.
      # We include root and for safety and system function.
      # Used by https://github.com/DeterminateSystems/nix-installer.

      eval-cores = 0

      #alternative, less secure
      #trusted-users = root ${config.system.primaryUser}

      extra-substituters = https://devenv.cachix.org
      extra-trusted-public-keys = devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw= nixpkgs-python.cachix.org-1:hxjI7pFxTyuTHn2NkvWCrAUcNZLNS3ZAvfYNuYifcEU=
    '';
  };

  # Auto upgrade nix package and the daemon service.
  nix = {
    # NOTE using determine to manage the nix installation which handles nix updates with a separate daemon.
    # SEE https://determinate.systems/posts/changelog-determinate-nix-342/
    enable = false;

    # TODO understand if this is still needed with using determine installer
    package = pkgs.nix;
  };

  # TODO Move to emacs or shell since it is connected to direnv
  # https://docs.doomemacs.org/v21.12/modules/tools/direnv/
  # NOTE disabled since it requires nix.enable
  # services.lorri.enable = true;

  # Storage optimisation
  # Keeping /nix/store tidy
  # https://nixos.wiki/wiki/Storage_optimization
  # FIXME should be os independent
  nix.extraOptions = ''
    auto-optimise-store = true
  '';

  # NOTE not working because of determined-nix usage
  # - nix.optimise.automatic requires nix.enable
  # - nix.gc.automatic requires nix.enable
  # nix.gc = {
  #   automatic = true;
  #   dates = "weekly";
  #   options = "--delete-older-than 14d";
  # };
  # nix.optimise = {
  #   automatic = true;
  #   dates = [ "weekly" ];
  # };
}
