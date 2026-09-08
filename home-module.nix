{...}: {
  programs.quickshell = {
    enable = true;
    configs.default = ./src;
    activeConfig = "default";
  };
}
