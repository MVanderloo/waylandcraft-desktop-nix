# Waylandcraft Desktop

A reproducible NixOS desktop session built from Minecraft, Fabric, Cage, and
[Waylandcraft](https://github.com/EVV1E/waylandcraft). It is experimental,
currently builds only for `x86_64-linux`, and still needs target-hardware
testing for DRM, GPU, and input behavior.

## Project status

This is a weekend hobby project shared as-is, not an actively maintained or
supported product. There is no maintenance, release, security, or response-time
commitment. I may address issues when they are important or simple; otherwise,
substantial changes are most likely to happen when someone contributes a pull
request. Do not rely on this project as a security boundary or assume that
dependencies will receive prompt updates.

## Install

Add the input and module to an existing NixOS flake:

```nix
inputs.waylandcraft-desktop.url = "github:mvanderloo/waylandcraft-desktop-nix";

outputs = inputs@{ nixpkgs, ... }: {
  nixosConfigurations.my-host = nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    modules = [
      inputs.waylandcraft-desktop.nixosModules.default
      ./configuration.nix
    ];
  };
};
```

Enable it in the host module:

```nix
{
  programs.waylandcraft-desktop.enable = true;
}
```

Rebuild, log in normally on an active local Linux VT, then start the configured
desktop:

```console
waylandcraft
```

Super+Shift+Q exits the desktop and returns to that TTY.

See the [module and flake reference](docs/flake.md) and the shorter
[configuration fragment](examples/configuration.nix).

## Behavior

- Minecraft opens at its normal world menu. Worlds, Minecraft options, and
  Waylandcraft settings persist between sessions by default.
- `settings.minecraft` and `settings.waylandcraft` seed those settings on first
  use; `persistence.gamePaths` controls any additional persistent game paths.
- The offline player name follows the authenticated Linux user by default.
  Microsoft authentication and multiplayer are disabled.
- Global Super shortcuts work even while a guest has keyboard capture. The
  terminal role is disabled until the host supplies a package or command;
  other applications come from the host or `extraPackages`.
- Minecraft can restart without ending Cage. A five-start-per-minute limit
  ends a crash loop and returns to the invoking TTY.

Applications launched inside the session retain the host's normal network
access. Minecraft keeps its normal single-player pause behavior.

## Try it

To try the pinned demo from an active local VT without installing the module:

```console
nix run github:mvanderloo/waylandcraft-desktop-nix
```

The demo uses a separate persistent directory at
`${XDG_DATA_HOME:-$HOME/.local/share}/waylandcraft-demo` and omits the desktop
policy mod.

## Develop

```console
nix develop
just check-all
just diagnose-logs
```

See [development and validation](docs/development.md),
[manual hardware checklist](docs/manual-testing.md),
[troubleshooting](docs/troubleshooting.md), and [contributing](CONTRIBUTING.md).

## License

Original source in this repository is available under the [MIT License](LICENSE).
Fetched components retain their own terms; see [third-party notices](THIRD_PARTY.md).
This project is not affiliated with or endorsed by Mojang Studios or Microsoft.
