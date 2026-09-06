# Manual hardware checklist

Use this checklist after `just check-all`. The automated suite validates the
NixOS module, generated launchers, policy mod, runtime preparation, headless
Cage startup, systemd supervision, and offline dependency closure. It does not
launch the real Minecraft client or prove DRM, GPU, monitor, physical-input, or
embedded application behavior.

This is an optional testing aid, not a promise that the project maintainer runs
every item or provides support for failures. Use the installed-session sections
for module changes and the demo section when changing the demo, pins, or runtime
packages. Mark optional checks as not applicable when the option is not enabled.

## Test record

- [ ] Git revision and NixOS system closure recorded.
- [ ] GPU, driver, monitor connections, modes, and scaling recorded.
- [ ] Launch path recorded: installed `waylandcraft`, local checkout demo, or
      published flake demo.
- [ ] Relevant module overrides recorded, including terminal, extra packages,
      keybindings, persistence paths, XKB options, and NVIDIA workaround.
- [ ] Untested or failed items recorded with diagnostics and the first relevant
      error.

## Safety and preflight

- [ ] Valuable worlds are backed up and no world is open during intentional
      process-kill tests.
- [ ] A known-good NixOS generation and a separate recovery VT are available.
- [ ] `just check-all` passes in the exact checkout under test.
- [ ] The consuming NixOS configuration builds, activates, and boots without a
      new failed system or user unit.
- [ ] `waylandcraft --help` succeeds after activation.
- [ ] `waylandcraft-diagnose --logs` is captured privately before the test.
      Review it before sharing because it contains usernames, store paths, and
      recent journal content.

## Cage and physical TTY smoke test

Run `just tty-smoke` from the active local Linux VT.

- [ ] The command rejects SSH, tmux, a graphical terminal, and an inactive VT.
- [ ] Cage starts on the active VT and the native probe is visible at the
      expected resolution.
- [ ] Switching to a different free VT and back returns to the same live probe.
- [ ] Typing `WAYLAND_OK` passes the probe and returns cleanly to the invoking
      VT.
- [ ] Keyboard, pointer movement, buttons, scroll, and monitor mode are correct.

## Installed session startup

From the active local VT, run `waylandcraft`.

- [ ] Cage and Minecraft start without a black screen, crash loop, or unexpected
      delay.
- [ ] Minecraft opens at its normal world menu and does not automatically create
      or join a world.
- [ ] The effective offline player name is the configured name, or the current
      Linux login name when `offlineUsername` is `null`.
- [ ] The display uses the expected resolution, refresh rate, scaling, and
      connected monitor.
- [ ] The same user cannot start a second Waylandcraft session while the first
      is active.
- [ ] If `xkbOptions` is set, its expected keyboard behavior is active. If it is
      null, the login environment's XKB behavior is preserved.
- [ ] On NVIDIA, the configured workaround behaves correctly; on other GPUs,
      no NVIDIA-specific override is unexpectedly applied.

## Vanilla Minecraft behavior

Use a disposable single-player world for these checks.

- [ ] Create or open a world, then move, look, jump, sprint, sneak, attack, and
      use an item normally.
- [ ] Open and use inventory, player crafting, chat, pause, options, and the
      world-selection screens.
- [ ] Entering a screen releases interaction appropriately and leaves the mouse
      cursor usable; returning to play restores normal capture.
- [ ] Perspective, fullscreen, GUI visibility, screenshot, hotbar, and any
      overridden Minecraft bindings behave as configured.
- [ ] Pausing retains normal single-player semantics.
- [ ] Saving and returning to the title screen completes without an error.

## Waylandcraft windows and applications

- [ ] `B` opens the Waylandcraft window manager.
- [ ] `V` opens the application picker.
- [ ] `G` changes guest keyboard capture as expected.
- [ ] Installed desktop applications appear in the picker; hidden or
      `NoDisplay` entries do not.
- [ ] Selecting an application and pressing Enter launches it; highlighting an
      entry alone is not mistaken for a successful launch.
- [ ] A native Wayland application renders and accepts keyboard and pointer
      input.
- [ ] An X11 application renders and accepts keyboard and pointer input through
      xwayland-satellite.
- [ ] If a browser is configured, it opens a page and confirms that applications
      retain normal host network access.
- [ ] If `extraPackages`, `extraMods`, or `extraGameFiles` are configured, each
      expected application, mod, or game file is present and functional.

If the terminal role is configured, run these inside it:

```console
waylandcraft-client-probe native
waylandcraft-client-probe x11
```

- [ ] Both probes render, accept the requested text, report `PASS`, and close.
- [ ] `Terminal=true` desktop entries open through the configured terminal and
      receive their command arguments intact.

## Global policy shortcuts

Test these once normally and once while a guest application has keyboard
capture. Exact modifier matching means extra modifiers must not trigger them.

- [ ] Super+G toggles the keyboard lock exactly once per press.
- [ ] Super+W opens the window manager.
- [ ] Super+Space opens the application picker.
- [ ] Super+F toggles the focused guest between fullscreen and its previous
      geometry without trapping input.
- [ ] Configured executable shortcuts launch their exact argument vectors.
- [ ] A configured terminal shortcut opens the terminal role.
- [ ] Keys and modifier combinations that are not configured continue to the
      focused guest normally.
- [ ] Super+Shift+Q ends the session and returns to the invoking VT. Perform this
      after the persistence checks below.

## Persistence and configuration

- [ ] Create a distinctive save state, change a Minecraft option, and change a
      Waylandcraft setting; save and exit normally.
- [ ] Start a fresh session and confirm the world, Minecraft option, and
      Waylandcraft setting survived.
- [ ] Runtime paths are symlinks to the corresponding configured persistent
      paths, while mods and `waylandcraft/desktop-policy.json` remain managed.
- [ ] Rebuilding with changed seed settings does not overwrite existing live
      settings; a new or deliberately moved-aside persistent target receives
      the new seed.
- [ ] Every additional `persistence.gamePaths` entry survives a fresh session.
- [ ] Disabling or changing the terminal role updates `terminalChoice` without
      overwriting unrelated Waylandcraft settings.

## Supervision and cleanup

Return the disposable world to the title screen before intentional kills. From
another local VT logged in as the same user:

```console
systemctl --user kill --kill-whom=main --signal=KILL waylandcraft-minecraft.service
systemctl --user show waylandcraft-minecraft.service -p MainPID -p NRestarts
```

- [ ] Killing Minecraft starts a new Minecraft process while Cage and the outer
      session remain active.
- [ ] The saved world still opens after the restart.
- [ ] Repeating the kill quickly until the five-start-per-minute limit is
      exhausted ends Cage and returns the original VT instead of looping.
- [ ] After the crash-loop test, the session target is inactive and the runtime
      directory is gone.
- [ ] Persistent saves and settings remain intact after the crash-loop test.
- [ ] `systemctl --user reset-failed waylandcraft-minecraft.service` permits a
      subsequent clean launch.
- [ ] Normal Super+Shift+Q logout leaves both `waylandcraft-session.target` and
      `waylandcraft-minecraft.service` inactive and removes
      `$XDG_RUNTIME_DIR/waylandcraft`.

## Offline startup

Test only after the complete closure has been built successfully once.

- [ ] Disconnect networking and start the installed session from the active VT.
- [ ] Minecraft reaches the normal menu without attempting a download or login.
- [ ] A persistent single-player world opens and saves while offline.
- [ ] End the session, restore networking, and confirm normal host connectivity.

## One-shot demo

Stop the installed session, then run either `just demo`, `nix run path:.`, or
the published flake command from the active local VT.

- [ ] The demo rejects unsupported launch contexts and starts from the active
      local VT.
- [ ] Minecraft reaches its normal menu without downloading after the first
      successful build.
- [ ] `B`, `V`, native applications, X11 applications, keyboard, and pointer
      input work. Policy-mod Super shortcuts are not expected in the demo.
- [ ] User-added mods in the demo directory remain present across launches while
      old pinned Waylandcraft, Fabric API, and Sodium versions are replaced.
- [ ] Demo worlds and settings persist below
      `${XDG_DATA_HOME:-$HOME/.local/share}/waylandcraft-demo`.
- [ ] Exiting Minecraft returns cleanly to the invoking VT.
- [ ] The already-built demo starts and opens a saved world with networking
      disconnected.

## Test notes

- [ ] `waylandcraft-diagnose --logs` after testing shows no unexplained failure
      or crash loop.
- [ ] If results are shared, they include the automated result, manual pass/fail
      items, hardware details, and any intentional deviations.
- [ ] Unchecked items are described as not tested or not applicable rather than
      treated as passing.
