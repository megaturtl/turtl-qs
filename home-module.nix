{
  config,
  lib,
  pkgs,
  ...
}: let
  runtimePackages = import ./runtime-packages.nix {inherit pkgs;};
in {
  home.packages = lib.mkIf config.programs.quickshell.enable (
    [pkgs.adwaita-icon-theme] ++ runtimePackages
  );

  programs.quickshell = {
    enable = lib.mkDefault true;
    configs.default = lib.mkDefault ./src;
    activeConfig = lib.mkDefault "default";
  };
}
