{
  config,
  lib,
  pkgs,
  ...
}:

{
  home.packages = with pkgs; [
    # https://github.com/jtroo/kanata
    # kanata
    kanata-with-cmd
    # requires Karabiner Driver Kit
    karabiner-dk
    # https://github.com/jtroo/kanata/issues/1264#issuecomment-2763085239
    # NOTE deactivate auto start of the Karabiner Elements app!
    # NOTE commented to move to kanata instead - to replicated hardware keyboard configuration
    # karabiner-elements
  ];

  # karabiner-dk daemon is launched via launchd.daemons in darwin/kanata.nix
  # The daemon runs as root and provides the DriverKit virtual HID device
  # that kanata connects to via pqrs::local_datagram (SOCK_DGRAM).
}
