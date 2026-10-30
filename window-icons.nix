{pkgs}: let
  python = pkgs.python3.withPackages (ps: [
    ps.python-xlib
    ps.pillow
  ]);
in
  pkgs.writeShellApplication {
    name = "turtl-window-icons";
    runtimeInputs = [python];
    text = ''
      exec python3 ${./src/helpers/window-icons.py} "$@"
    '';
  }
