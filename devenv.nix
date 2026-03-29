{
  pkgs,
  lib,
  config,
  inputs,
  ...
}:

{
  env.KANATA_CONFIG = "config/kanata/basbousa.kbd";
  scripts.kanata-list.exec = ''
    kanata --cfg $KANATA_CONIFG --list
  '';

  scripts.kanata-check.exec = ''
    kanata --cfg $KANATA_CONFIG --check
  '';

  scripts.kanata-run.exec = ''
    kanata --cfg $KANATA_CONFIG
  '';
}
