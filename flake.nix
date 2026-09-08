{
  description = "Quickshell bar and development flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    self,
    nixpkgs,
    treefmt-nix,
    ...
  }: let
    systems = ["x86_64-linux" "aarch64-linux"];
    forEachSystem = nixpkgs.lib.genAttrs systems;
    treefmtEval =
      forEachSystem (system:
        treefmt-nix.lib.evalModule nixpkgs.legacyPackages.${system} ./treefmt.nix);
  in {
    # Installable from a NixOS / home-manager flake.
    homeModules.default = import ./home-module.nix;
    homeManagerModules.default = self.homeModules.default;

    formatter = forEachSystem (system: treefmtEval.${system}.config.build.wrapper);

    checks = forEachSystem (system: {
      formatting = treefmtEval.${system}.config.build.check self;
    });

    devShells = forEachSystem (system: let
      pkgs = nixpkgs.legacyPackages.${system};
    in {
      default = pkgs.mkShellNoCC {
        packages = [pkgs.qt6.qtdeclarative pkgs.quickshell];
      };
    });

    apps = forEachSystem (system: let
      pkgs = nixpkgs.legacyPackages.${system};
      runner = pkgs.writeShellApplication {
        name = "run-quickshell";
        runtimeInputs = [pkgs.quickshell];
        text = ''
          exec quickshell --path "$PWD/src" "$@"
        '';
      };
    in {
      default = {
        type = "app";
        program = "${runner}/bin/run-quickshell";
      };
    });
  };
}
