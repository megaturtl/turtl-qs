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

## Monitors

The bar uses the first monitor available at startup. If you disconnect that
monitor, the bar hides until you reconnect it.

## Clock

Click the time or date to show the current month's calendar. Click again to
close it. The calendar highlights today and uses your locale's weekday order.

## Workspace icons

The workspace widget uses desktop-entry icons, or window icons from XWayland apps if available. Apps without a discoverable icon show a generic window icon.

Native Wayland apps need a matching desktop entry to show their application icon.
The helper uses python-xlib for X11 access and Pillow for PNG encoding.
These are included in the flake.

## Development

```sh
nix develop
nix fmt
nix run
```

`nix run` runs the flake's packaged configuration. To edit and reload the
working tree instead, run `quickshell --path "$PWD/src"` from the checkout
inside `nix develop`.
