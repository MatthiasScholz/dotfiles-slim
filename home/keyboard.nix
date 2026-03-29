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

  # TODO consider launching the application with launchd
  #      check darwin.nix + ollama for an example
}
