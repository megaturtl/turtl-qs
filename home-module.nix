{pkgs, ...}: let
  runtimePackages = import ./runtime-packages.nix {inherit pkgs;};
in {
  home.packages = [pkgs.adwaita-icon-theme] ++ runtimePackages;

  programs.quickshell = {
    enable = true;
    configs.default = ./src;
    activeConfig = "default";
  };
}
