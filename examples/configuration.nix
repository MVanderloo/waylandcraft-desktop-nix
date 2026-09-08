{
  # Import the flake's NixOS module first. This adds Waylandcraft to an
  # existing greeter's session chooser; choose and configure the greeter
  # separately in your host configuration.
  programs.waylandcraft-desktop.enable = true;
}
