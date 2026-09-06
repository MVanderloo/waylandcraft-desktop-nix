# Troubleshooting

Start with:

```console
waylandcraft-diagnose --logs
```

Review the report before sharing it; it contains usernames, store paths, and
recent journal content.

## Missing or black session

```console
systemctl status display-manager.service
systemctl --user status waylandcraft-session.target waylandcraft-minecraft.service
systemctl --user show-environment | grep -E '^(DISPLAY|WAYLAND_DISPLAY)='
journalctl --user -b -u waylandcraft-minecraft.service
```

Rebuild after changing the flake input, then start a fresh VT login or reboot.
Both display variables must reach the user manager after Cage starts.

After a five-start crash loop, end any remaining session and run:

```console
systemctl --user reset-failed waylandcraft-minecraft.service
```

## Direct launch is rejected

`waylandcraft` requires the active local Linux VT, a valid owned
`XDG_RUNTIME_DIR`, and no active Waylandcraft session for the current user.

```console
tty
cat /sys/class/tty/tty0/active
printf '%s\n' "$XDG_RUNTIME_DIR"
```

The first two outputs must name the same `/dev/ttyN`. Graphical terminals, SSH,
mosh, tmux, and inactive VTs are rejected.

## Native or X11 clients fail

From a configured terminal inside Waylandcraft, run:

```console
waylandcraft-client-probe native
waylandcraft-client-probe x11
```

Native failure points to `WAYLAND_DISPLAY`; X11-only failure points to
`DISPLAY` or xwayland-satellite. Inspect the Minecraft journal for the first
startup error.

## Saves or generated settings look wrong

```console
readlink "$XDG_RUNTIME_DIR/waylandcraft/game/saves"
ls -la "${XDG_DATA_HOME:-$HOME/.local/share}/waylandcraft/saves"
grep '^key_' "$XDG_RUNTIME_DIR/waylandcraft/game/options.txt"
jq . "$XDG_RUNTIME_DIR/waylandcraft/game/waylandcraft/settings.json"
jq . "$XDG_RUNTIME_DIR/waylandcraft/game/waylandcraft/desktop-policy.json"
```

Saves, `options.txt`, and Waylandcraft's `settings.json` persist by default.
`settings.minecraft` and `settings.waylandcraft` seed new settings files; later
sessions retain live changes. Move an existing persistent target aside before
starting a session if it should be seeded again after a rebuild.

## A terminal or application is unavailable

The terminal role is disabled by default. Set its `package`, and add a
`shortcut` if it should have a global chord:

```nix
programs.waylandcraft-desktop.applications.terminal = {
  package = terminalPackage;
  shortcut = {
    key = "key.keyboard.enter";
    modifiers = [ "super" ];
  };
};
```

Without an explicit `command`, the module uses the package's main executable.
The terminal adapter appends arguments from Waylandcraft, including commands
for `Terminal=true` desktop entries. Other applications need no named role:
install them normally or add them to `extraPackages`, and use an executable
policy shortcut if they need a global chord. If a launch still fails, inspect
`systemctl --user show-environment`; commands are argument vectors, and global
chords require an exact modifier set.

## Reporting a bug

Reports are welcome but may not receive a response or fix. If filing one,
include the locked revision, system closure, GPU and driver, launch path, probe
results, and the first relevant journal error. State which items in the
[manual hardware checklist](manual-testing.md) were run.
