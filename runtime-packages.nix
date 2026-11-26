{pkgs}: [
  pkgs.bash
  pkgs.coreutils
  pkgs.gawk
  pkgs.iproute2
  pkgs.libnotify
  (import ./window-icons.nix {inherit pkgs;})
]
