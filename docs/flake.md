# Module and flake reference

Import `nixosModules.default` (or the equivalent `nixosModules.waylandcraft-desktop`) and enable `programs.waylandcraft-desktop`. The module installs `waylandcraft` for launch from an active local VT.

## Options

All options are below `programs.waylandcraft-desktop`.

| Option                              | Default            | Purpose                                                                             |
| ----------------------------------- | ------------------ | ----------------------------------------------------------------------------------- |
| `enable`                            | `false`            | Install and register the session.                                                   |
| `offlineUsername`                   | `null`             | Minecraft name; `null` uses the authenticated Linux user.                           |
| `offlineUuid`                       | `null`             | Offline UUID; `null` derives the standard offline UUID from the effective username. |
| `xkbOptions`                        | `null`             | Optional XKB options override; `null` inherits the login environment.               |
| `memory.initial` / `memory.maximum` | `1G` / `4G`        | JVM heap sizes.                                                                     |
| `settings.minecraft`                | `{}`               | Entries generated in Minecraft's `options.txt`.                                     |
| `settings.waylandcraft`             | `{}`               | JSON object generated as Waylandcraft's `settings.json`.                            |
| `persistence.gamePaths`             | saves and settings | Relative game paths retained between sessions.                                      |
| `applications.terminal`             | disabled           | Optional terminal role with `package`, `command`, and `shortcut`.                   |
| `keybindings.minecraft`             | Minecraft defaults | Vanilla mappings using Minecraft input identifiers.                                 |
| `keybindings.waylandcraft`          | B / V / G          | Window manager, picker, and keyboard capture.                                       |
| `policy.shortcuts`                  | named Super chords | Global built-in or executable actions; `null` removes a default.                    |
| `nvidiaWorkaround`                  | auto-detected      | Apply Waylandcraft's NVIDIA optimization workaround.                                |
| `extraMods`                         | `[]`               | Additional pinned Fabric JARs.                                                      |
| `extraGameFiles`                    | `null`             | Declarative files copied into each fresh game directory.                            |
| `extraPackages`                     | `[]`               | Session PATH additions; desktop entries also appear in the picker.                  |

`extraGameFiles` cannot replace `options.txt`, `mods`, `saves`, or
`waylandcraft`, and it cannot contain symlinks or special files. Extra mod
filenames must be unique JARs that do not replace built-ins.

Minecraft setting values may be strings, booleans, numbers, or `null`; `null`
omits the entry. Typed keybinding options override matching raw key entries.
`settings.waylandcraft` accepts any JSON object supported by Waylandcraft.

## Policy and keybindings

The complete Minecraft and Waylandcraft defaults are in
[`nix/keybindings.nix`](../nix/keybindings.nix). Global shortcuts work even
while a guest has keyboard capture.

| Action                                  | Default                         |
| --------------------------------------- | ------------------------------- |
| Keyboard lock / window manager / picker | Super+G / Super+W / Super+Space |
| Guest fullscreen                        | Super+F                         |
| Logout                                  | Super+Shift+Q                   |

Policy shortcut names are arbitrary. Actions use a tagged built-in name or an
argument vector executed directly, without shell parsing:

```nix
programs.waylandcraft-desktop = {
  policy = {
    shortcuts = {
      lockCapture = {
        key = "key.keyboard.g";
        modifiers = [ "super" ];
        action = { kind = "builtin"; name = "toggleKeyboardLock"; };
      };
      projectMenu = {
        key = "key.keyboard.b";
        modifiers = [ "super" ];
        action = { kind = "exec"; argv = [ "${lib.getExe menuPackage}" "--projects" ]; };
      };
      openPicker = null;
    };
  };
};
```

Global modifiers are `shift`, `control`, `alt`, and `super`. Non-null chords
must be unique and match their exact modifier set. Built-ins are
`toggleKeyboardLock`, `openWindowManager`, `openPicker`, and
`toggleFocusedWindowFullscreen`. The terminal role owns the reserved
`applicationTerminal` shortcut name; all commands are executed without shell
parsing.

## Package outputs

- `default` / `demo`: local-VT demo (`nix run .`).
- `portablemc`, `diagnose`, and `client-tools`: operational tools.
- `runtime-tools`: the pinned Java, launcher, compositor, X11 bridge, and tools.
- `waylandcraft`, `fabric-api`, `sodium`, `policy-mod`, and `minecraft-home`:
  pinned game artifacts.
- `supervision-vm`: full supervision test, kept outside normal flake checks
  because of its larger build.

The internal package set permits only its pinned Minecraft and Sodium
derivations despite their non-free licenses. It does not alter the consuming
host's Nixpkgs policy.

## Runtime behavior

The generated game installation lives below `$XDG_RUNTIME_DIR/waylandcraft` and
is replaced at each login. Each `persistence.gamePaths` entry links to the same
relative path below `${XDG_DATA_HOME:-$HOME/.local/share}/waylandcraft`. Template
content seeds a persistent path only when it does not exist; later rebuilds do
not overwrite it. Paths must be normalized, unique, and non-overlapping. `mods`,
the whole `waylandcraft` directory, and `waylandcraft/desktop-policy.json` are
managed by the module and cannot be persistent paths.

Cage owns the outer session while systemd supervises Minecraft. Minecraft may
restart without ending Cage; five starts within one minute end the session.
PortableMC uses the pinned JDK and Fabric closure with no graphical launcher,
online account database, or multiplayer. Once built, the session starts without
network access, though applications inside it retain normal host networking.
