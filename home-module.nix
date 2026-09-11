{pkgs, ...}: {
  home.packages = [pkgs.adwaita-icon-theme];

  programs.quickshell = {
    enable = true;
    configs.default = ./src;
    activeConfig = "default";
  };
}
