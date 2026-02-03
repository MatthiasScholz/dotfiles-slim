{
  config,
  lib,
  pkgs,
  ...
}:

{
  home.packages = with pkgs; [
    # NOTE not available for darwin systems -> brew
    # freecad
    # NOTE not available for darwin systems -> brew
    # orca-slicer
    # OpenSCAD
    # . https://openscad.org
    # UNUSED openscad
    # UNUSED openscad-lsp
    # PCB Design
    # FIXME broken for darwin
    # kicad
    # Generate case out of pcb for openscad
    # turbocase
  ];

}
