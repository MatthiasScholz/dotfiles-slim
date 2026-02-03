{
  config,
  lib,
  pkgs,
  ...
}:

{
  home.packages = with pkgs; [
    # https://github.com/jtroo/kanata
    kanata
    # requires Karabiner Driver Kit
    # https://github.com/jtroo/kanata/issues/1264#issuecomment-2763085239
    # NOTE deactivate auto start of the Karabiner Elements app!
    karabiner-elements
  ];

  # TODO consider launching the application with launchd
  #      check darwin.nix + ollama for an example
}
