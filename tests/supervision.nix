{
  pkgs,
  self,
}:

let
  userOptionsFixture = pkgs.writeText "waylandcraft-user-options" "user-options\n";
  userSettingsFixture = pkgs.writeText "waylandcraft-user-settings.json" ''
    {"user":true}
  '';
in
pkgs.testers.runNixOSTest (_: {
  name = "waylandcraft-supervision";

  nodes.machine =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      networkProbeSource = pkgs.writeText "waylandcraft-network-probe.c" ''
        #include <sys/socket.h>

        int main(void) {
          int descriptor = socket(AF_INET, SOCK_STREAM, 0);
          return descriptor >= 0 ? 0 : 1;
        }
      '';
      networkProbe = pkgs.runCommandCC "waylandcraft-network-probe" { } ''
        mkdir -p "$out/bin"
        $CC ${networkProbeSource} -o "$out/bin/waylandcraft-network-probe"
      '';
      fakeMinecraft = pkgs.writeShellScript "waylandcraft-fake-minecraft" ''
        set -eu
        state=/tmp/waylandcraft-supervision
        count=0
        if test -r "$state/starts"; then
          count="$(${pkgs.coreutils}/bin/cat "$state/starts")"
        fi
        count=$((count + 1))
        printf '%s\n' "$count" > "$state/starts"
        printf 'fake frontend start %s\n' "$count"

        if ! ${networkProbe}/bin/waylandcraft-network-probe; then
          printf '%s\n' 'Minecraft service could not create an AF_INET socket' >&2
          exit 99
        fi
        touch "$state/network-available"

        if test "$(command -v btop)" != ${pkgs.btop}/bin/btop; then
          printf 'btop is not on the frontend PATH: %s\n' \
            "''${PATH:-<unset>}" >&2
          exit 94
        fi
        touch "$state/terminal-app-path"

        test -n "''${WAYLAND_DISPLAY:-}" || {
          printf '%s\n' 'Cage did not provide WAYLAND_DISPLAY' >&2
          exit 98
        }
        test -n "''${DISPLAY:-}" || {
          printf '%s\n' 'Cage did not provide DISPLAY' >&2
          exit 95
        }
        case ":''${XDG_DATA_DIRS:-}:" in
          *:/run/current-system/sw/share:*) ;;
          *)
            printf 'XDG_DATA_DIRS is missing the system share path: %s\n' \
              "''${XDG_DATA_DIRS:-<unset>}" >&2
            exit 97
            ;;
        esac
        test -f "''${XDG_RUNTIME_DIR:?}/waylandcraft/game/options.txt" \
          && test -L "$XDG_RUNTIME_DIR/waylandcraft/game/options.txt" \
          && test -L "$XDG_RUNTIME_DIR/waylandcraft/game/waylandcraft/settings.json" \
          && test -L "$XDG_RUNTIME_DIR/waylandcraft/game/saves" \
          && test -d "$XDG_RUNTIME_DIR/waylandcraft/game/saves" || {
          printf '%s\n' 'session runner did not prepare the runtime template' >&2
          exit 96
        }
        touch "$state/runtime-prepared"

        if test -e "$state/crash"; then
          exit 23
        fi
        exec ${pkgs.coreutils}/bin/sleep infinity
      '';
    in
    {
      imports = [ self.nixosModules.default ];

      system.stateVersion = "26.05";
      virtualisation.memorySize = 2048;

      users.users.alice = {
        isNormalUser = true;
        uid = 1000;
        linger = true;
      };

      programs.waylandcraft-desktop = {
        enable = true;
      };

      # Assemble the same session directory a greeter consumes without
      # starting a graphical display manager in this headless test.
      services.displayManager.enable = true;

      # Exercise the module's real unit graph and policy without starting a
      # graphical JVM in the headless VM.
      systemd = {
        tmpfiles.rules = [
          "d /tmp/waylandcraft-supervision 0777 root root -"
        ];

        user.services = {
          waylandcraft-minecraft.serviceConfig = {
            ExecStart = lib.mkForce fakeMinecraft;
            RestartSec = lib.mkForce "100ms";
          };

          # Run the module's real Cage -> session-runner -> systemd-user path
          # with a headless wlroots backend. Only Minecraft itself is
          # replaced.
          waylandcraft-test-cage = {
            description = "Real Waylandcraft outer session on a headless backend";
            # Model an application supplied by the login/user environment,
            # rather than through the Waylandcraft module's extraPackages.
            # The runner must import this PATH for the frontend service.
            path = [ pkgs.btop ];
            environment = {
              WLR_BACKENDS = "headless";
              WLR_HEADLESS_OUTPUTS = "1";
              WLR_LIBINPUT_NO_DEVICES = "1";
              WLR_RENDERER = "pixman";
              XDG_RUNTIME_DIR = "/run/user/1000";
            };
            serviceConfig = {
              Type = "simple";
              ExecStart = pkgs.writeShellScript "waylandcraft-test-greeter-launch" ''
                session_command="$(${pkgs.gnused}/bin/sed -n 's/^Exec=//p' \
                  ${config.services.displayManager.sessionData.desktops}/share/wayland-sessions/waylandcraft.desktop)"
                exec "$session_command"
              '';
            };
          };
        };
      };
    };

  testScript = ''
    from datetime import timedelta

    machine.start()
    machine.wait_for_unit("multi-user.target")
    machine.wait_for_unit("user@1000.service")
    machine.succeed(
        "waylandcraft --help > /tmp/waylandcraft-help && "
        "grep -qx 'Usage: waylandcraft' /tmp/waylandcraft-help"
    )
    user_environment = (
        "XDG_RUNTIME_DIR=/run/user/1000 "
        "DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus"
    )

    def userctl(arguments, check=True):
        command = (
            "runuser -u alice -- env "
            + user_environment
            + " systemctl --user "
            + arguments
        )
        if check:
            return machine.succeed(command)
        return machine.execute(command)

    def main_pid():
        return int(userctl("show --property=MainPID --value waylandcraft-minecraft.service").strip())

    def wait_for_user_unit_state(unit, state):
        machine.wait_until_succeeds(
            'test "$('
            + "runuser -u alice -- env "
            + user_environment
            + " systemctl --user show --property=ActiveState --value "
            + unit
            + ')" = '
            + state
        )

    def wait_for_starts(minimum):
        machine.wait_until_succeeds(
            "test -r /tmp/waylandcraft-supervision/starts "
            f"&& test $(cat /tmp/waylandcraft-supervision/starts) -ge {minimum}"
        )

    userctl("start waylandcraft-test-cage.service")
    wait_for_starts(1)
    machine.wait_until_succeeds("test -e /tmp/waylandcraft-supervision/network-available")
    machine.wait_until_succeeds("test -e /tmp/waylandcraft-supervision/terminal-app-path")
    machine.wait_until_succeeds("test -e /tmp/waylandcraft-supervision/runtime-prepared")
    userctl("is-active --quiet waylandcraft-test-cage.service")
    cage_pid = int(userctl("show --property=MainPID --value waylandcraft-test-cage.service").strip())
    assert cage_pid > 1
    machine.succeed(f"readlink /proc/{cage_pid}/exe | grep -Fq '${pkgs.cage}/'")
    first_pid = main_pid()
    assert first_pid > 1

    with subtest("a second greeter launch preserves the active session"):
        status, output = machine.execute(
            "runuser -u alice -- env "
            + user_environment
            + " /run/current-system/sw/bin/waylandcraft-desktop-session 2>&1"
        )
        assert status != 0, "a duplicate session was accepted"
        assert "already running for this user" in output
        assert main_pid() == first_pid
        userctl("is-active --quiet waylandcraft-test-cage.service")
        machine.succeed("test -d /run/user/1000/waylandcraft/game")

    with subtest("frontend does not inherit no-new-privileges"):
        machine.succeed(
            f"grep -Eq '^NoNewPrivs:[[:space:]]+0$' /proc/{first_pid}/status"
        )

    with subtest("desktop state is written outside the disposable runtime"):
        machine.succeed(
            "runuser -u alice -- ${pkgs.bash}/bin/bash -c "
            "'printf persistence-ok > /run/user/1000/waylandcraft/game/saves/persistence-test.txt'"
        )
        machine.succeed(
            "runuser -u alice -- cp ${userOptionsFixture} "
            "/run/user/1000/waylandcraft/game/options.txt"
        )
        machine.succeed(
            "runuser -u alice -- cp ${userSettingsFixture} "
            "/run/user/1000/waylandcraft/game/waylandcraft/settings.json"
        )
        machine.succeed(
            "grep -qx persistence-ok "
            "/home/alice/.local/share/waylandcraft/saves/persistence-test.txt"
        )
        machine.succeed(
            "grep -qx user-options /home/alice/.local/share/waylandcraft/options.txt"
        )
        machine.succeed(
            "grep -Fqx '{\"user\":true}' "
            "/home/alice/.local/share/waylandcraft/waylandcraft/settings.json"
        )

    with subtest("frontend kill restarts without stopping the outer session"):
        machine.succeed(f"kill -KILL {first_pid}")
        wait_for_starts(2)
        second_pid = main_pid()
        assert second_pid != first_pid
        userctl("is-active --quiet waylandcraft-session.target")
        userctl("is-active --quiet waylandcraft-test-cage.service")

    with subtest("bounded crash loop returns the inner session"):
        machine.succeed("touch /tmp/waylandcraft-supervision/crash")
        machine.succeed(f"kill -KILL {main_pid()}")
        wait_for_user_unit_state("waylandcraft-session.target", "inactive")
        starts = int(machine.succeed("cat /tmp/waylandcraft-supervision/starts").strip())
        assert starts == 5, f"expected five bounded starts, got {starts}"
        wait_for_user_unit_state("waylandcraft-test-cage.service", "inactive")
        machine.succeed("test ! -e /run/user/1000/waylandcraft")
        machine.succeed(
            "grep -qx persistence-ok "
            "/home/alice/.local/share/waylandcraft/saves/persistence-test.txt"
        )
        machine.succeed(
            "grep -qx user-options /home/alice/.local/share/waylandcraft/options.txt"
        )
        machine.succeed(
            "grep -Fqx '{\"user\":true}' "
            "/home/alice/.local/share/waylandcraft/waylandcraft/settings.json"
        )
        machine.succeed(
            "journalctl --quiet --no-pager _UID=1000 "
            "SYSLOG_IDENTIFIER=waylandcraft-minecraft | grep -q 'fake frontend start'"
        )

    with subtest("stopping the session target prevents a frontend restart"):
        machine.succeed("rm /tmp/waylandcraft-supervision/crash")
        userctl("reset-failed waylandcraft-minecraft.service")
        userctl("start waylandcraft-test-cage.service")
        wait_for_starts(6)
        machine.wait_until_succeeds(
            "grep -qx persistence-ok "
            "/run/user/1000/waylandcraft/game/saves/persistence-test.txt"
        )
        userctl("stop waylandcraft-session.target")
        wait_for_user_unit_state("waylandcraft-session.target", "inactive")
        starts = machine.succeed("cat /tmp/waylandcraft-supervision/starts").strip()
        machine.sleep(duration=timedelta(seconds=1))
        assert machine.succeed("cat /tmp/waylandcraft-supervision/starts").strip() == starts
        wait_for_user_unit_state("waylandcraft-test-cage.service", "inactive")
        machine.succeed("test ! -e /run/user/1000/waylandcraft")
  '';
})
