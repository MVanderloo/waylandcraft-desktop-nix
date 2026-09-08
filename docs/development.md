# Development and validation

## Workflow

```console
nix develop
just format
just check
just supervision-vm
```

`just check-all` runs formatting, normal flake checks, and the NixOS supervision
VM. The VM launches the command from the registered greeter entry using real
Cage, runtime preparation, and systemd user units, but replaces Minecraft with
a fake frontend. It does not drive greeter authentication or prove real
Minecraft, GPU, DRM, monitor, or physical-input behavior.

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
- `nix/fabric-profile.json`: reviewed PortableMC-generated Fabric version profile.
- `policy-mod/`: the small Fabric desktop-policy mod.
- `scripts/`: sources embedded by `writeShellApplication`.
- `nix/checks.nix` and `tests/supervision.nix`: automated checks.

## Target-machine check

After `just check-all`, follow the
[manual hardware checklist](manual-testing.md) for DRM, GPU, monitor,
physical-input, real Minecraft, application-launching, and offline-startup
behavior that the automated VM cannot prove.

## Updating pins

Update `nix/pins.nix`, the relevant direct hash, and `flake.lock` together.
Minecraft version numbers alone do not pin their assets: Mojang can update a
release's metadata. Pin the content-addressed version manifest URL and hash in
`minecraft.manifest` too.

For a Minecraft or Fabric Loader update, generate a fresh installation with the
pinned PortableMC in a temporary directory. Review and copy its
`versions/fabric-<minecraft>-<loader>/fabric-<minecraft>-<loader>.json` into
`nix/fabric-profile.json`. This snapshot pins the library list and timestamps
that the Fabric API can otherwise change between builds.

These changes also change the recursive hash in `nix/minecraft-home.nix`.
Build once with the old hash, review the resolved metadata, then use Nix's
reported hash. Run the full automated suite and the real demo after every pin
change.

Do not commit saves, account data, logs, crash dumps, generated outputs, or
runtime directories. Keep test fixtures synthetic and minimal.
