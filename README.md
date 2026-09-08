Quickshell bar and on-screen display.

## Use in NixOS

Add the flake as an input in `flake.nix`:

```nix
turtl-qs = {
  url = "github:megaturtl/turtl-qs";
  inputs.nixpkgs.follows = "nixpkgs";
};
```

Import the home-manager module:

```nix
home-manager.sharedModules = [ inputs.turtl-qs.homeManagerModules.default ];
```

Start Quickshell after login:

```sh
quickshell --config default
```

Home Manager puts the config in `~/.config/quickshell/default`.

## Development

```sh
nix develop
nix fmt
nix run
```
