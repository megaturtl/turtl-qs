{pkgs, ...}: let
  windowIcons = import ./window-icons.nix {inherit pkgs;};
in {
  home.packages = [pkgs.adwaita-icon-theme windowIcons];

  programs.quickshell = {
    enable = true;
    configs.default = ./src;
    activeConfig = "default";
  };
}
