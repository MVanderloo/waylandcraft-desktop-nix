# Development and validation

## Workflow

```console
nix develop
just format
just check
just supervision-vm
```

`just check-all` runs formatting, normal flake checks, and the NixOS supervision
VM. The VM uses real Cage, runtime preparation, and systemd user units, but
replaces Minecraft with a fake frontend. It does not prove GPU, DRM, monitor,
or physical-input behavior.

Useful installed-system diagnostics are:

```console
waylandcraft-diagnose --logs
systemctl --user status waylandcraft-session.target waylandcraft-minecraft.service
journalctl --user -b -u waylandcraft-minecraft.service
```

## Source map

- `nix/module.nix`: NixOS options, launchers, session entries, and user units.
- `nix/packages.nix`: pinned runtime, tools, demo, and game template.
- `nix/pins.nix`: component versions, URLs, and direct hashes.
- `policy-mod/`: the small Fabric desktop-policy mod.
- `scripts/`: sources embedded by `writeShellApplication`.
- `nix/checks.nix` and `tests/supervision.nix`: automated checks.

## Target-machine check

Keep a recovery VT and a known-good NixOS generation. After `just check-all`:

1. Rebuild, reboot, and confirm `waylandcraft --help` works from a local VT.
2. Start Waylandcraft from the active local VT.
3. Check native resolution, input, inventory, and save loading.
4. If a terminal role is configured, run `waylandcraft-client-probe native` and
   `waylandcraft-client-probe x11` from that terminal.
5. Test the configured application shortcuts and the default global Super
   shortcuts while a guest has keyboard capture.
6. Kill the Minecraft service, reopen the saved world, then log out and confirm
   the save persists.
7. Confirm five starts within one minute end the session, then repeat login
   offline with the closure already built.

Record the system closure, GPU/driver, monitor mode, launch path, and any step
not tested. Review diagnostic output before sharing it because it includes the
local username, store paths, and—when `--logs` is used—recent journal content.

## Updating pins

Update `nix/pins.nix`, the relevant direct hash, and `flake.lock` together. A
Minecraft or Fabric change also changes the recursive hash in
`nix/minecraft-home.nix`. Build once with the old hash, review the resolved
metadata, then use Nix's reported hash. Run the full automated suite and the
real demo after every pin change.

Do not commit saves, account data, logs, crash dumps, generated outputs, or
runtime directories. Keep test fixtures synthetic and minimal.
