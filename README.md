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

Run in a supported Wayland session (Hyprland or Niri). Install a JetBrainsMono
Nerd Font for the bar glyphs. The network widget reads links from NetworkManager.
PipeWire provides audio state and UPower provides battery state.

Host-owned integrations are not installed or enabled by the module. Put
`swaync-client`, `pwvucontrol`, `wlogout`, `hyprlock`, and `powerprofilesctl`
on the session's PATH only for the integrations you want. SwayNC and power
profiles also need their corresponding services; configure and test your
locker separately. On Niri, the native `niri` client must be on the session PATH.
The battery widget cycles only the profiles reported by the daemon and shows
a change only after the daemon reports the new active profile.

## Monitors

The bar uses the first monitor available at startup. If you disconnect that
monitor, the bar hides until you reconnect it.
On narrow outputs, drag a crowded group horizontally to reach the rest
of its controls.

## Clock

Click the time or date to show the current month's calendar. Click again to
close it. The calendar highlights today and uses your locale's weekday order.

## Workspace icons

Both compositors use matching desktop-entry icons, with a generic icon if
none is available. On Hyprland, a window-specific XWayland icon takes
precedence when the process ID and window class match unambiguously.
Niri uses desktop entries because its satellite windows do not expose
a reliable X11 window identity. The packaged X11 helper uses python-xlib
and Pillow.

## Development

```sh
nix develop
nix fmt
nix run
```

`nix run` runs the flake's packaged configuration. To edit and reload the
working tree instead, run `quickshell --path "$PWD/src"` from the checkout
inside `nix develop`.
