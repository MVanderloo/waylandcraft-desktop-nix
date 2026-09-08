# Waylandcraft Desktop

Add **Waylandcraft** to your NixOS greeter's session chooser and run your
applications inside Minecraft, powered by
[Waylandcraft](https://github.com/EVV1E/waylandcraft).

This flake packages Minecraft, Fabric, and Cage into a reproducible session
alongside your existing desktop. You choose your greeter, applications, and
settings; the module adds the session without selecting a default desktop or
enabling autologin.

## Project status

This is a weekend hobby project. Expect rough edges.
[Issues](https://github.com/mvanderloo/waylandcraft-desktop-nix/issues), hardware
test reports, and focused pull requests are welcome. I'll look at them as time
and interest allow, but can't promise a response, fix, or regular updates.

Currently targets `x86_64-linux` on NixOS. Automated checks cover session
registration, headless Cage, and supervision; real greeter login, Minecraft,
GPU, and input behavior still need [hardware testing](docs/manual-testing.md).

## Install

With a greeter that supports Wayland sessions already configured, add this
input and module to your NixOS flake:

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

Rebuild your NixOS configuration, then log out and select **Waylandcraft** in
the greeter's session chooser before signing in. If the entry hasn't appeared,
reboot into the new generation. The module does not install or configure a
greeter. For greetd and custom session selectors, see the
[greeter integration notes](docs/flake.md#greeter-integration).

Minecraft opens at its normal world menu. Create or open a single-player world,
then press **V** to open the application picker, **B** for window management,
or **G** to capture the keyboard in an application. **Super+Shift+Q** ends the
session and returns to the greeter. Save your world before logging out.

You can also log in on an active local Linux VT and run:

```console
waylandcraft
```

With this launch path, logout returns to that TTY.

See the [module and flake reference](docs/flake.md) and the shorter
[configuration fragment](examples/configuration.nix).

## Behavior

- Minecraft opens at its normal world menu. Worlds, Minecraft options, and
  Waylandcraft settings persist between sessions by default.
- `settings.minecraft` and `settings.waylandcraft` seed those settings on first
  use; `persistence.gamePaths` controls any additional persistent game paths.
- The offline player name follows the authenticated Linux user by default.
  Microsoft authentication and multiplayer are disabled.
- Configurable global Super shortcuts work even while an application has
  keyboard capture. The terminal role is disabled until the host supplies a
  package or command; other applications come from the host or `extraPackages`.
- Minecraft restarts when it exits, without ending Cage. A five-start-per-minute
  limit ends a crash loop and returns to the greeter or invoking TTY. Use the
  logout shortcut to end the session intentionally.

Applications launched inside the session retain the host's normal network
access and permissions. Minecraft keeps its normal single-player pause
behavior. This is an experimental desktop session with no bundled screen lock
or security isolation; run only one graphical session at a time per user.

## Try it

To try the pinned demo from an active local VT without installing the module:

```console
nix run github:mvanderloo/waylandcraft-desktop-nix
```

The first build downloads Minecraft and its dependencies. The demo uses a
separate persistent directory at
`${XDG_DATA_HOME:-$HOME/.local/share}/waylandcraft-demo` and omits the desktop
policy mod. Exit Minecraft to return to the TTY; the installed session's Super
shortcuts are not available in the demo.

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
