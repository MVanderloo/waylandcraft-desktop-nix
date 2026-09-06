{
  self,
  nixpkgsLib,
  pkgs,
  packages,
}:

let
  inherit (pkgs) lib;
  userAppCommand = pkgs.writeShellApplication {
    name = "waylandcraft-user-app-fixture";
    text = ''
      printf '%s\n' "Waylandcraft user application fixture"
    '';
  };

  userAppDesktopEntry = pkgs.makeDesktopItem {
    name = "waylandcraft-user-app-fixture";
    desktopName = "User-installed application fixture";
    exec = "waylandcraft-user-app-fixture";
    terminal = true;
    categories = [ "Utility" ];
  };

  userAppFixture = pkgs.symlinkJoin {
    name = "waylandcraft-user-app-fixture-package";
    paths = [
      userAppCommand
      userAppDesktopEntry
    ];
  };

  terminalFixture = pkgs.writeShellApplication {
    name = "waylandcraft-terminal-fixture";
    text = ''
      exec "$@"
    '';
  };

  runtimePrepare = pkgs.writeShellApplication {
    name = "waylandcraft-runtime-prepare-test";
    runtimeInputs = with pkgs; [
      coreutils
      findutils
    ];
    text = builtins.readFile ../scripts/runtime-prepare;
  };

  mkBuiltinShortcut = key: modifiers: name: {
    inherit key modifiers;
    action = {
      kind = "builtin";
      inherit name;
    };
  };

  mkExecShortcut = key: modifiers: argv: {
    inherit key modifiers;
    action = {
      kind = "exec";
      inherit argv;
    };
  };

  testSystem = nixpkgsLib.nixosSystem {
    system = pkgs.stdenv.hostPlatform.system;
    modules = [
      self.nixosModules.default
      {
        system.stateVersion = "26.05";
        boot.loader.grub.devices = [ "/dev/vda" ];
        fileSystems."/" = {
          device = "/dev/vda1";
          fsType = "ext4";
        };
        programs.waylandcraft-desktop = {
          enable = true;
          applications = {
            terminal = {
              package = terminalFixture;
              shortcut = {
                key = "key.keyboard.enter";
                modifiers = [ "super" ];
              };
            };
          };
          extraPackages = [
            userAppFixture
          ];
        };
      }
    ];
  };

  exampleSystem = nixpkgsLib.nixosSystem {
    system = pkgs.stdenv.hostPlatform.system;
    modules = [
      self.nixosModules.default
      ../examples/configuration.nix
      {
        system.stateVersion = "26.05";
        boot.loader.grub.devices = [ "/dev/vda" ];
        fileSystems."/" = {
          device = "/dev/vda1";
          fsType = "ext4";
        };
      }
    ];
  };

  alternateHostCage = pkgs.writeShellApplication {
    name = "cage";
    text = ''
      exec ${pkgs.cage}/bin/cage "$@"
    '';
  };

  alternateHostPkgs = pkgs.extend (
    _final: previous: {
      cage = alternateHostCage // {
        inherit (previous.cage) version;
      };
    }
  );

  alternateHostSystem = nixpkgsLib.nixosSystem {
    system = pkgs.stdenv.hostPlatform.system;
    modules = [
      self.nixosModules.default
      {
        nixpkgs.pkgs = alternateHostPkgs;
        system.stateVersion = "26.05";
        programs.waylandcraft-desktop = {
          enable = true;
        };
      }
    ];
  };

  customKeybindingSystem = nixpkgsLib.nixosSystem {
    system = pkgs.stdenv.hostPlatform.system;
    modules = [
      self.nixosModules.default
      {
        system.stateVersion = "26.05";
        programs.waylandcraft-desktop = {
          enable = true;
          xkbOptions = "ctrl:nocaps";
          offlineUsername = "ConfiguredUser";
          offlineUuid = "11111111-2222-3333-8444-555555555555";
          settings = {
            minecraft = {
              autoJump = false;
              guiScale = 3;
              "key_key.inventory" = "key.keyboard.o";
              removedSetting = null;
            };
            waylandcraft = {
              focusOnHover = true;
              pixelsPerBlock = 350;
            };
          };
          applications.terminal = {
            package = terminalFixture;
            command = [
              "${terminalFixture}/bin/waylandcraft-terminal-fixture"
              "--new-window"
            ];
            shortcut = {
              key = "key.keyboard.t";
              modifiers = [
                "control"
                "super"
              ];
            };
          };
          policy = {
            shortcuts = {
              fullscreen.action = {
                kind = "exec";
                argv = [ "/opt/consumer fullscreen" ];
              };
              logout = null;
              openWindowManager.action.name = "openPicker";
              openPicker.key = "key.keyboard.p";
              "consumer launch" =
                mkExecShortcut "key.keyboard.y"
                  [
                    "alt"
                    "super"
                  ]
                  [
                    "/opt/consumer tools/run"
                    "argument with spaces"
                    ""
                  ];
            };
          };
          keybindings = {
            minecraft.inventory = "key.keyboard.i";
            waylandcraft.windowManager = "key.keyboard.m";
          };
        };
      }
    ];
  };

  invalidKeybindingType =
    builtins.tryEval
      (nixpkgsLib.nixosSystem {
        system = pkgs.stdenv.hostPlatform.system;
        modules = [
          self.nixosModules.default
          {
            system.stateVersion = "26.05";
            programs.waylandcraft-desktop = {
              enable = true;
              policy.shortcuts.invalidKey = mkBuiltinShortcut "key.keyboard.not-a-real-key" [
                "super"
              ] "openPicker";
            };
          }
        ];
      }).config.programs.waylandcraft-desktop.policy.shortcuts.invalidKey.key;

  invalidBuiltinType =
    builtins.tryEval
      (nixpkgsLib.nixosSystem {
        system = pkgs.stdenv.hostPlatform.system;
        modules = [
          self.nixosModules.default
          {
            system.stateVersion = "26.05";
            programs.waylandcraft-desktop = {
              enable = true;
              policy.shortcuts.invalidBuiltin = mkBuiltinShortcut "key.keyboard.u" [
                "super"
              ] "consumerInventedBuiltin";
            };
          }
        ];
      }).config.programs.waylandcraft-desktop.policy.shortcuts.invalidBuiltin.action.name;

  invalidPolicyActionKind =
    builtins.tryEval
      (nixpkgsLib.nixosSystem {
        system = pkgs.stdenv.hostPlatform.system;
        modules = [
          self.nixosModules.default
          {
            system.stateVersion = "26.05";
            programs.waylandcraft-desktop = {
              enable = true;
              policy.shortcuts.invalidKind = {
                key = "key.keyboard.u";
                modifiers = [ "super" ];
                action.kind = "consumer";
              };
            };
          }
        ];
      }).config.programs.waylandcraft-desktop.policy.shortcuts.invalidKind.action.kind;

  invalidOptionCases = [
    {
      name = "invalid-username";
      config.offlineUsername = "not a valid player name";
      expected = "the offline Minecraft username must be 1-16 letters, digits, or underscores";
    }
    {
      name = "invalid-uuid";
      config.offlineUuid = "not-a-uuid";
      expected = "offlineUuid must use canonical UUID syntax";
    }
    {
      name = "invalid-heap";
      config.memory.initial = "1G,-agentlib:jdwp";
      expected = "memory.initial must be a positive JVM size such as 1G or 512M";
    }
    {
      name = "invalid-minecraft-option-name";
      config.settings.minecraft."invalid:name" = "value";
      expected = "settings.minecraft names must be non-empty and must not contain colons or newlines";
    }
    {
      name = "invalid-minecraft-option-value";
      config.settings.minecraft.example = "line one\nline two";
      expected = "settings.minecraft string values must not contain newlines";
    }
    {
      name = "absolute-persistent-game-path";
      config.persistence.gamePaths = [ "/saves" ];
      expected = "persistence.gamePaths entries must be normalized relative game paths without control characters";
    }
    {
      name = "control-character-persistent-game-path";
      config.persistence.gamePaths = [ "bad\npath" ];
      expected = "persistence.gamePaths entries must be normalized relative game paths without control characters";
    }
    {
      name = "managed-persistent-mods";
      config.persistence.gamePaths = [ "mods/custom" ];
      expected = "persistence.gamePaths must not include managed mods or desktop-policy.json";
    }
    {
      name = "managed-persistent-policy";
      config.persistence.gamePaths = [ "waylandcraft" ];
      expected = "persistence.gamePaths must not include managed mods or desktop-policy.json";
    }
    {
      name = "duplicate-persistent-game-path";
      config.persistence.gamePaths = [
        "saves"
        "saves"
      ];
      expected = "persistence.gamePaths entries must be unique";
    }
    {
      name = "overlapping-persistent-game-path";
      config.persistence.gamePaths = [
        "waylandcraft"
        "waylandcraft/settings.json"
      ];
      expected = "persistence.gamePaths entries must not contain one another";
    }
    {
      name = "application-policy-shortcut-collision";
      config = {
        applications.terminal = {
          command = [ "/bin/terminal" ];
          shortcut = {
            key = "key.keyboard.y";
            modifiers = [ "alt" ];
          };
        };
        policy.shortcuts.explicitCollision = mkBuiltinShortcut "key.keyboard.y" [ "alt" ] "openPicker";
      };
      expected = "policy shortcuts must use unique key and modifier combinations";
    }
    {
      name = "duplicate-policy-shortcut";
      config.policy.shortcuts = {
        first = mkBuiltinShortcut "key.keyboard.y" [
          "control"
          "super"
        ] "openPicker";
        second = mkBuiltinShortcut "key.keyboard.y" [
          "super"
          "control"
        ] "openWindowManager";
      };
      expected = "policy shortcuts must use unique key and modifier combinations";
    }
    {
      name = "duplicate-policy-modifier";
      config.policy.shortcuts.repeatedModifier = mkBuiltinShortcut "key.keyboard.y" [
        "super"
        "super"
      ] "openPicker";
      expected = "policy shortcuts must not repeat a modifier";
    }
    {
      name = "reserved-terminal-shortcut-name";
      config.policy.shortcuts.applicationTerminal = mkBuiltinShortcut "key.keyboard.y" [
        "super"
      ] "openPicker";
      expected = "policy.shortcuts applicationTerminal is reserved for the terminal application role";
    }
    {
      name = "builtin-action-with-argv";
      config.policy.shortcuts.invalid = {
        key = "key.keyboard.y";
        modifiers = [ "super" ];
        action = {
          kind = "builtin";
          name = "openPicker";
          argv = [ "/bin/false" ];
        };
      };
      expected = "policy shortcut actions must set exactly name for builtin or a valid argv for exec";
    }
    {
      name = "builtin-action-without-name";
      config.policy.shortcuts.invalid = {
        key = "key.keyboard.y";
        modifiers = [ "super" ];
        action.kind = "builtin";
      };
      expected = "policy shortcut actions must set exactly name for builtin or a valid argv for exec";
    }
    {
      name = "exec-action-with-name";
      config.policy.shortcuts.invalid = {
        key = "key.keyboard.y";
        modifiers = [ "super" ];
        action = {
          kind = "exec";
          name = "openPicker";
          argv = [ "/bin/true" ];
        };
      };
      expected = "policy shortcut actions must set exactly name for builtin or a valid argv for exec";
    }
    {
      name = "exec-action-without-argv";
      config.policy.shortcuts.invalid = {
        key = "key.keyboard.y";
        modifiers = [ "super" ];
        action.kind = "exec";
      };
      expected = "policy shortcut actions must set exactly name for builtin or a valid argv for exec";
    }
    {
      name = "empty-exec-argv";
      config.policy.shortcuts.invalid = mkExecShortcut "key.keyboard.y" [ "super" ] [ ];
      expected = "policy shortcut actions must set exactly name for builtin or a valid argv for exec";
    }
    {
      name = "blank-exec-executable";
      config.policy.shortcuts.invalid =
        mkExecShortcut "key.keyboard.y"
          [ "super" ]
          [
            "   "
            "argument"
          ];
      expected = "policy shortcut actions must set exactly name for builtin or a valid argv for exec";
    }
    {
      name = "empty-application-command";
      config.applications.terminal.command = [ ];
      expected = "applications.terminal must resolve to a non-empty command with no empty arguments";
    }
    {
      name = "unresolved-application-role";
      config.applications.terminal.shortcut = {
        key = "key.keyboard.enter";
        modifiers = [ "super" ];
      };
      expected = "applications.terminal must resolve to a non-empty command with no empty arguments";
    }
  ];

  invalidOptionEvidence = map (
    optionCase:
    let
      evaluated = nixpkgsLib.nixosSystem {
        system = pkgs.stdenv.hostPlatform.system;
        modules = [
          self.nixosModules.default
          {
            system.stateVersion = "26.05";
            programs.waylandcraft-desktop = {
              enable = true;
            }
            // optionCase.config;
          }
        ];
      };
      failedMessages = map (entry: entry.message) (
        lib.filter (entry: !entry.assertion) evaluated.config.assertions
      );
    in
    {
      inherit (optionCase) name expected;
      rejected = lib.elem optionCase.expected failedMessages;
    }
  ) invalidOptionCases;

  findSessionPackage =
    system:
    lib.findFirst (
      package: package.waylandcraftDesktopSession or false
    ) (throw "Waylandcraft session package was not installed") system.config.environment.systemPackages;
  sessionPackage = findSessionPackage testSystem;
  alternateHostSessionPackage = findSessionPackage alternateHostSystem;
  customSessionPackage = findSessionPackage customKeybindingSystem;
  minecraftLauncher =
    testSystem.config.systemd.user.services.waylandcraft-minecraft.serviceConfig.ExecStart;
  configuredUsernameLauncher =
    customKeybindingSystem.config.systemd.user.services.waylandcraft-minecraft.serviceConfig.ExecStart;
  actualRuntimeTemplate = packages.mkRuntimeTemplate { };
  extraGameFilesTemplate = packages.mkRuntimeTemplate {
    extraGameFiles = ../tests/fixtures/game-files;
  };

  extraModFixture = pkgs.writeTextFile {
    name = "headless-extra-mod.jar";
    text = "headless extra mod fixture";
  };
  collidingModRoot = pkgs.runCommand "colliding-mod-root" { } ''
    mkdir -p "$out"
    touch "$out/waylandcraft-${packages.pins.waylandcraft.version}.jar"
  '';
  duplicateExtraMods = builtins.tryEval (
    packages.mkRuntimeTemplate {
      extraMods = [
        extraModFixture
        extraModFixture
      ];
    }
  );
  collidingExtraMods = builtins.tryEval (
    packages.mkRuntimeTemplate {
      extraMods = [ "${collidingModRoot}/waylandcraft-${packages.pins.waylandcraft.version}.jar" ];
    }
  );
  nonJarExtraMod = builtins.tryEval (
    packages.mkRuntimeTemplate {
      extraMods = [ pkgs.hello ];
    }
  );
  unrelatedUnfreePackage = builtins.tryEval pkgs.minecraft-server.drvPath;

  satelliteSmoke = pkgs.writeShellScript "waylandcraft-satellite-smoke" ''
    set -euo pipefail
    marker=$1

    ${pkgs.xwayland-satellite}/bin/xwayland-satellite :12 &
    satellite_pid=$!
    cleanup() {
      kill "$satellite_pid" 2>/dev/null || true
      wait "$satellite_pid" 2>/dev/null || true
    }
    trap cleanup EXIT INT TERM

    ready=
    for _attempt in $(${pkgs.coreutils}/bin/seq 1 200); do
      if test -S /tmp/.X11-unix/X12; then
        ready=1
        break
      fi
      ${pkgs.coreutils}/bin/sleep 0.05
    done
    test -n "$ready"

    DISPLAY=:12 ${pkgs.xterm}/bin/xterm \
      -e ${pkgs.bash}/bin/bash -c \
      'test -n "$DISPLAY"; printf "%s\n" SATELLITE_X11_CLIENT_OK > "$1"' \
      _ "$marker"
  '';

in
{
  module-evaluation =
    assert self.inputs.nixpkgs.rev == packages.pins.nixpkgs.revision;
    assert lib.all (entry: entry.assertion) testSystem.config.assertions;
    assert exampleSystem.config.programs.waylandcraft-desktop.enable;
    assert !invalidKeybindingType.success;
    assert !invalidBuiltinType.success;
    assert !invalidPolicyActionKind.success;
    assert lib.elem sessionPackage testSystem.config.environment.systemPackages;
    assert lib.elem packages.diagnose testSystem.config.environment.systemPackages;
    assert !(lib.elem packages.runtimeTools testSystem.config.environment.systemPackages);
    assert testSystem.config.hardware.graphics.enable;
    assert lib.elem userAppFixture testSystem.config.environment.systemPackages;
    pkgs.writeText "waylandcraft-module-evidence" "module and public option types evaluated\n";

  invalid-options =
    assert lib.all (entry: entry.rejected) invalidOptionEvidence;
    pkgs.writeText "waylandcraft-invalid-option-evidence.json" (builtins.toJSON invalidOptionEvidence);

  extra-mod-validation =
    assert !duplicateExtraMods.success;
    assert !collidingExtraMods.success;
    assert !nonJarExtraMod.success;
    pkgs.writeText "waylandcraft-extra-mod-validation" "duplicate, collision, and non-JAR inputs rejected\n";

  package-metadata =
    assert packages.jdk.version == packages.pins.runtime.jdk;
    assert packages.portablemc.version == packages.pins.runtime.portablemc;
    assert packages.cage.version == packages.pins.runtime.cage;
    assert packages.xwaylandSatellite.version == packages.pins.runtime.xwaylandSatellite;
    assert packages.xwayland.version == packages.pins.runtime.xwayland;
    assert packages.libxkbcommon.version == packages.pins.runtime.libxkbcommon;
    assert packages.wayland.version == packages.pins.runtime.wayland;
    assert packages.libdrm.version == packages.pins.runtime.libdrm;
    assert packages.mesa.version == packages.pins.runtime.mesa;
    assert packages.waylandcraftJar.meta.license.spdxId == "GPL-3.0-only";
    assert packages.fabricApiJar.meta.license.spdxId == "Apache-2.0";
    assert packages.sodiumJar.meta.license.shortName == "PolyForm-Shield-1.0.0";
    assert !packages.sodiumJar.meta.license.free;
    assert packages.sodiumJar.meta.license.redistributable;
    assert packages.minecraftHome.meta.license.shortName == "unfreeRedistributable";
    assert !packages.minecraftHome.meta.license.free;
    assert packages.minecraftHome.meta.license.redistributable;
    assert lib.elem lib.sourceTypes.binaryBytecode packages.waylandcraftJar.meta.sourceProvenance;
    assert lib.elem lib.sourceTypes.binaryNativeCode packages.waylandcraftJar.meta.sourceProvenance;
    assert lib.elem lib.sourceTypes.binaryBytecode packages.fabricApiJar.meta.sourceProvenance;
    assert lib.elem lib.sourceTypes.binaryBytecode packages.sodiumJar.meta.sourceProvenance;
    assert lib.elem lib.sourceTypes.binaryBytecode packages.minecraftHome.meta.sourceProvenance;
    assert lib.elem lib.sourceTypes.binaryNativeCode packages.minecraftHome.meta.sourceProvenance;
    assert packages.demo.meta.mainProgram == "waylandcraft-demo";
    assert packages.diagnose.meta.mainProgram == "waylandcraft-diagnose";
    assert packages.clientTools.meta.mainProgram == "waylandcraft-client-probe";
    assert lib.all (package: package.meta.license.spdxId == "MIT") [
      packages.demo
      packages.diagnose
      packages.clientTools
    ];
    assert packages.runtimeTools.meta.description != "";
    assert !(packages.runtimeTools.meta ? license);
    assert !unrelatedUnfreePackage.success;
    pkgs.writeText "waylandcraft-package-metadata.json" (
      builtins.toJSON {
        fabricApi = packages.fabricApiJar.meta;
        minecraft = packages.minecraftHome.meta;
        sodium = packages.sodiumJar.meta;
        waylandcraft = packages.waylandcraftJar.meta;
      }
    );

  locked-runtime = pkgs.runCommand "waylandcraft-pinned-module-runtime-check" { } ''
    launcher=${alternateHostSessionPackage}/bin/waylandcraft-desktop-session
    grep -Fq ${lib.escapeShellArg "${pkgs.cage}/bin"} "$launcher"
    if grep -Fq ${lib.escapeShellArg "${alternateHostCage}/bin"} "$launcher"; then
      echo "session used Cage from the consuming host instead of the locked flake input" >&2
      exit 1
    fi

    touch "$out"
  '';

  extra-game-files-validation =
    pkgs.runCommand "waylandcraft-extra-game-files-validation"
      {
        nativeBuildInputs = [ packages.extraGameFilesValidator ];
      }
      ''
        grep -Fqx '{"fixture":true}' \
          ${extraGameFilesTemplate}/game/config/waylandcraft-test.json

        mkdir -p valid/config reserved/mods symlinked special
        touch valid/config/example.json
        waylandcraft-validate-game-files valid

        if waylandcraft-validate-game-files reserved >/dev/null 2>&1; then
          echo 'extraGameFiles accepted a reserved top-level path' >&2
          exit 1
        fi

        ln -s "$PWD/valid/config/example.json" symlinked/example.json
        if waylandcraft-validate-game-files symlinked >/dev/null 2>&1; then
          echo 'extraGameFiles accepted a symbolic link' >&2
          exit 1
        fi

        mkfifo special/fifo
        if waylandcraft-validate-game-files special >/dev/null 2>&1; then
          echo 'extraGameFiles accepted a non-regular entry' >&2
          exit 1
        fi

        touch not-a-directory
        if waylandcraft-validate-game-files not-a-directory >/dev/null 2>&1; then
          echo 'extraGameFiles accepted a non-directory root' >&2
          exit 1
        fi

        touch "$out"
      '';

  runtime-tools = pkgs.runCommand "waylandcraft-runtime-tools-check" { } ''
    for executable in java portablemc cage xwayland-satellite waylandcraft-client-probe waylandcraft-diagnose; do
      test -x ${packages.runtimeTools}/bin/"$executable" || {
        echo "runtime-tools is missing $executable" >&2
        exit 1
      }
    done

    java_executable="$(${pkgs.coreutils}/bin/readlink -f ${packages.runtimeTools}/bin/java)"
    case "$java_executable" in
      ${pkgs.jdk25}/*) ;;
      *)
        echo "runtime-tools Java does not come from the pinned JDK: $java_executable" >&2
        exit 1
        ;;
    esac
    touch "$out"
  '';

  demo-launcher = pkgs.runCommand "waylandcraft-demo-launcher-check" { } ''
    ${packages.demo}/bin/waylandcraft-demo --help > help.txt
    test '${packages.exportedPackages.default}' = '${packages.demo}'
    grep -q 'nix run github:mvanderloo/waylandcraft-desktop-nix' help.txt
    grep -q -- '--fetch-exclude-all' ${packages.demo}/bin/waylandcraft-demo
    grep -Fq -- '--username "$WAYLANDCRAFT_DEMO_USERNAME"' ${packages.demo}/bin/waylandcraft-demo
    grep -Fq 'WAYLANDCRAFT_DEMO_USERNAME=$(id -un)' ${packages.demo}/bin/waylandcraft-demo
    grep -Fq -- '--uuid "$WAYLANDCRAFT_DEMO_UUID"' ${packages.demo}/bin/waylandcraft-demo
    grep -Fq 'WAYLANDCRAFT_DEMO_UUID=$(waylandcraft-offline-uuid "$WAYLANDCRAFT_DEMO_USERNAME")' ${packages.demo}/bin/waylandcraft-demo
    test "$(${packages.offlineUuid}/bin/waylandcraft-offline-uuid Waylandcraft)" = \
      54fb358d-6399-3383-8e4e-2372a82ffe0a
    if grep -q -- '--join-world' ${packages.demo}/bin/waylandcraft-demo; then
      echo "demo unexpectedly opens a world automatically" >&2
      exit 1
    fi
    if grep -Eq 'tutorialStep|guiScale' ${packages.demo}/bin/waylandcraft-demo; then
      echo "demo unexpectedly rewrites Minecraft preferences" >&2
      exit 1
    fi
    if grep -q '^export XKB_DEFAULT_OPTIONS=' ${packages.demo}/bin/waylandcraft-demo; then
      echo "demo unexpectedly overrides the login XKB options" >&2
      exit 1
    fi
    mkdir -p demo/game/mods demo/game/waylandcraft
    touch demo/game/mods/waylandcraft-old.jar
    touch demo/game/mods/fabric-api-old.jar
    touch demo/game/mods/sodium-old.jar
    touch demo/game/mods/user-added.jar
    printf '%s\n' user-options > demo/game/options.txt
    printf '%s\n' '{"user":true}' > demo/game/waylandcraft/settings.json

    ${packages.demoPrepare}/bin/waylandcraft-demo-prepare "$PWD/demo"

    test ! -e demo/game/mods/waylandcraft-old.jar
    test ! -e demo/game/mods/fabric-api-old.jar
    test ! -e demo/game/mods/sodium-old.jar
    test -e demo/game/mods/user-added.jar
    test -e demo/game/mods/waylandcraft-${packages.pins.waylandcraft.version}.jar
    test -e demo/game/mods/fabric-api-${packages.pins.minecraft.fabricApi}.jar
    test -e demo/game/mods/sodium-${packages.pins.minecraft.sodium}.jar
    grep -qx user-options demo/game/options.txt
    grep -Fqx '{"user":true}' demo/game/waylandcraft/settings.json
    if grep -q 'desktop-policy' ${packages.demo}/bin/waylandcraft-demo; then
      echo "demo unexpectedly includes the installed-session policy mod" >&2
      exit 1
    fi
    touch "$out"
  '';

  session-wiring = pkgs.runCommand "waylandcraft-session-wiring-check" { } ''
    outer=${sessionPackage}/bin/waylandcraft-desktop-session
    tty_launcher=${sessionPackage}/bin/waylandcraft
    control=${packages.sessionControl}/bin/waylandcraft-session-control
    "$tty_launcher" --help > tty-launcher-help.txt
    grep -qx 'Usage: waylandcraft' tty-launcher-help.txt
    grep -q 'active local Linux VT' tty-launcher-help.txt
    grep -Fq '^/dev/tty[0-9]+$' "$tty_launcher"
    grep -q 'waylandcraft-session.target' "$tty_launcher"
    grep -q 'waylandcraft-desktop-session' "$tty_launcher"
    grep -q 'exec cage -s -d --' "$outer"
    if grep -q '^export XKB_DEFAULT_OPTIONS=' "$outer"; then
      echo "default session unexpectedly overrides the login XKB options" >&2
      exit 1
    fi
    if grep -q portablemc "$outer"; then
      echo "outer session launches Minecraft directly instead of the session runner" >&2
      exit 1
    fi
    grep -q 'exec systemctl --user stop waylandcraft-session.target' "$control"
    runner=$(grep -o '/nix/store/[^ ]*-waylandcraft-session-runner/bin/waylandcraft-session-runner' "$outer")
    test -x "$runner"
    grep -q 'XDG_DATA_DIRS' "$runner"
    grep -q 'import-environment' "$runner"
    grep -q 'DISPLAY PATH WAYLAND_DISPLAY' "$runner"
    grep -Fq ${lib.escapeShellArg "${userAppFixture}/bin"} "$runner"
    grep -Fq ${lib.escapeShellArg "${terminalFixture}/bin"} "$runner"
    grep -q 'WAYLANDCRAFT_OUTER_DISPLAY' "$runner"

    runtime_template=$(grep -m1 -o '/nix/store/[a-z0-9]*-waylandcraft-runtime-template' "$runner")
    terminal_choice=$(${pkgs.jq}/bin/jq -r \
      '.terminalChoice' "$runtime_template/game/waylandcraft/settings.json")
    test "$terminal_choice" = waylandcraft-terminal
    terminal_launcher=$(${pkgs.jq}/bin/jq -r \
      '.shortcuts.applicationTerminal.action.argv[0]' \
      "$runtime_template/game/waylandcraft/desktop-policy.json")
    test -x "$terminal_launcher"
    grep -Fq ${lib.escapeShellArg "${terminalFixture}/bin/waylandcraft-terminal-fixture"} \
      "$terminal_launcher"
    ${pkgs.jq}/bin/jq -e \
      --arg terminal "$terminal_launcher" \
      --arg lifecycle ${lib.escapeShellArg "${packages.sessionControl}/bin/waylandcraft-session-control"} \
      '
        .shortcuts.applicationTerminal == {
          key: "key.keyboard.enter",
          modifiers: ["super"],
          action: {kind: "exec", argv: [$terminal]}
        } and
        .shortcuts.keyboardLock.action == {
          kind: "builtin", name: "toggleKeyboardLock"
        } and
        .shortcuts.logout.action == {
          kind: "exec", argv: [$lifecycle, "logout"]
        }
      ' "$runtime_template/game/waylandcraft/desktop-policy.json"

    custom_outer=${customSessionPackage}/bin/waylandcraft-desktop-session
    grep -q '^export XKB_DEFAULT_OPTIONS=ctrl:nocaps$' "$custom_outer"
    custom_runner=$(grep -o \
      '/nix/store/[^ ]*-waylandcraft-session-runner/bin/waylandcraft-session-runner' \
      "$custom_outer")
    grep -Fq '.terminalChoice = "waylandcraft-terminal"' "$custom_runner"
    custom_runtime_template=$(grep -m1 -o \
      '/nix/store/[a-z0-9]*-waylandcraft-runtime-template' "$custom_runner")
    grep -Fqx 'key_key.inventory:key.keyboard.i' \
      "$custom_runtime_template/game/options.txt"
    grep -Fqx 'key_waylandcraft.key.windowManager:key.keyboard.m' \
      "$custom_runtime_template/game/options.txt"
    grep -Fqx 'autoJump:false' "$custom_runtime_template/game/options.txt"
    grep -Fqx 'guiScale:3' "$custom_runtime_template/game/options.txt"
    if grep -q '^removedSetting:' "$custom_runtime_template/game/options.txt"; then
      echo "null Minecraft setting was unexpectedly rendered" >&2
      exit 1
    fi
    ${pkgs.jq}/bin/jq -e '
      .focusOnHover == true and .pixelsPerBlock == 350
    ' "$custom_runtime_template/game/waylandcraft/settings.json"
    ${pkgs.jq}/bin/jq -e '
      .shortcuts["consumer launch"].action == {
        kind: "exec",
        argv: ["/opt/consumer tools/run", "argument with spaces", ""]
      } and
      .shortcuts.openPicker == {
        key: "key.keyboard.p",
        modifiers: ["super"],
        action: {kind: "builtin", name: "openPicker"}
      } and
      .shortcuts.openWindowManager.action == {
        kind: "builtin", name: "openPicker"
      } and
      .shortcuts.fullscreen.action == {
        kind: "exec", argv: ["/opt/consumer fullscreen"]
      } and
      (.shortcuts | has("logout") | not)
    ' "$custom_runtime_template/game/waylandcraft/desktop-policy.json"
    touch "$out"
  '';

  cage-headless =
    pkgs.runCommand "waylandcraft-cage-headless-check"
      {
        nativeBuildInputs = with pkgs; [
          cage
          coreutils
          foot
          xwayland
          xwayland-satellite
          xterm
        ];
      }
      ''
        mkdir runtime
        chmod 700 runtime
        export XDG_RUNTIME_DIR="$PWD/runtime"
        export WLR_BACKENDS=headless
        export WLR_HEADLESS_OUTPUTS=1
        export WLR_RENDERER=pixman
        export WLR_LIBINPUT_NO_DEVICES=1

        timeout 20 cage -d -- \
          foot --config=/dev/null \
          ${pkgs.bash}/bin/bash -c \
          'test -n "$WAYLAND_DISPLAY"; printf "%s\n" WAYLAND_CLIENT_OK > "$PWD/client-ok"'

        grep -qx WAYLAND_CLIENT_OK client-ok

        timeout 20 cage -d -- ${satelliteSmoke} "$PWD/satellite-client-ok"
        grep -qx SATELLITE_X11_CLIENT_OK satellite-client-ok
        touch "$out"
      '';

  minecraft-launcher = pkgs.runCommand "waylandcraft-minecraft-launcher-check" { } ''
    test -x ${minecraftLauncher}
    grep -q -- '--main-dir "$runtime/main"' ${minecraftLauncher}
    grep -q -- '--mc-dir "$runtime/game"' ${minecraftLauncher}
    grep -q -- '--fetch-exclude-all' ${minecraftLauncher}
    grep -q -- '--disable-multiplayer' ${minecraftLauncher}
    grep -Fq -- \
      '--jvm-arg="-Dwaylandcraft.desktop.policyConfig=$runtime/game/waylandcraft/desktop-policy.json"' \
      ${minecraftLauncher}
    if grep -q -- '--join-world' ${minecraftLauncher}; then
      echo "launcher unexpectedly opens a world automatically" >&2
      exit 1
    fi
    grep -Fq 'offline_username=$(id -un)' ${minecraftLauncher}
    grep -Fq -- '--username "$offline_username"' ${minecraftLauncher}
    grep -Fq 'Linux username must be a 1-16 character Minecraft name' ${minecraftLauncher}
    grep -Fq 'offline_uuid=$(waylandcraft-offline-uuid "$offline_username")' ${minecraftLauncher}
    grep -Fq -- '--uuid "$offline_uuid"' ${minecraftLauncher}
    grep -Fq 'offline_username=ConfiguredUser' ${configuredUsernameLauncher}
    grep -Fq 'offline_uuid=11111111-2222-3333-8444-555555555555' ${configuredUsernameLauncher}
    if grep -Eq -- '(^|[[:space:]])--auth([=[:space:]]|$)' ${minecraftLauncher}; then
      echo "launcher unexpectedly enables account authentication" >&2
      exit 1
    fi

    touch "$out"
  '';

  runtime-reset = pkgs.runCommand "waylandcraft-runtime-reset-check" { } ''
    mkdir -p template/main/versions template/game/saves template/game/waylandcraft
    printf '%s\n' immutable > template/game/options.txt
    printf '%s\n' '{"seed":true}' > template/game/waylandcraft/settings.json

    WAYLANDCRAFT_ALLOW_TEST_DEST=1 \
      ${runtimePrepare}/bin/waylandcraft-runtime-prepare-test \
      "$PWD/template" "$PWD/runtime"

    mkdir -p runtime/game/saves/user-created
    printf '%s\n' changed > runtime/game/saves/user-created/level.dat
    printf '%s\n' user-change > runtime/game/options.txt

    WAYLANDCRAFT_ALLOW_TEST_DEST=1 \
      ${runtimePrepare}/bin/waylandcraft-runtime-prepare-test \
      "$PWD/template" "$PWD/runtime"

    test -d runtime/game/saves
    test ! -e runtime/game/saves/user-created
    grep -qx immutable runtime/game/options.txt
    test -z "$(find "$PWD" -maxdepth 1 -name '.runtime.rollback.*' -print -quit)"

    WAYLANDCRAFT_ALLOW_TEST_DEST=1 \
      ${runtimePrepare}/bin/waylandcraft-runtime-prepare-test \
      "$PWD/template" "$PWD/runtime-persistent" "$PWD/persistent" \
      saves options.txt waylandcraft/settings.json screenshots

    grep -qx immutable persistent/options.txt
    grep -Fqx '{"seed":true}' persistent/waylandcraft/settings.json

    mkdir -p runtime-persistent/game/saves/user-created
    printf '%s\n' persisted > runtime-persistent/game/saves/user-created/level.dat
    printf '%s\n' user-options > runtime-persistent/game/options.txt
    printf '%s\n' '{"user":true}' > runtime-persistent/game/waylandcraft/settings.json
    printf '%s\n' screenshot > runtime-persistent/game/screenshots/example.png
    printf '%s\n' new-template-options > template/game/options.txt
    printf '%s\n' '{"seed":false}' > template/game/waylandcraft/settings.json

    WAYLANDCRAFT_ALLOW_TEST_DEST=1 \
      ${runtimePrepare}/bin/waylandcraft-runtime-prepare-test \
      "$PWD/template" "$PWD/runtime-persistent" "$PWD/persistent" \
      saves options.txt waylandcraft/settings.json screenshots

    grep -qx persisted runtime-persistent/game/saves/user-created/level.dat
    grep -qx user-options runtime-persistent/game/options.txt
    grep -Fqx '{"user":true}' runtime-persistent/game/waylandcraft/settings.json
    grep -qx screenshot runtime-persistent/game/screenshots/example.png

    for invalid_path in \
      /absolute \
      ../traversal \
      mods \
      mods/custom \
      waylandcraft \
      waylandcraft/desktop-policy.json; do
      if WAYLANDCRAFT_ALLOW_TEST_DEST=1 \
        ${runtimePrepare}/bin/waylandcraft-runtime-prepare-test \
        "$PWD/template" "$PWD/runtime-invalid" "$PWD/persistent-invalid" \
        "$invalid_path" >/dev/null 2>&1; then
        echo "runtime prepare accepted invalid persistent path: $invalid_path" >&2
        exit 1
      fi
    done

    if WAYLANDCRAFT_ALLOW_TEST_DEST=1 \
      ${runtimePrepare}/bin/waylandcraft-runtime-prepare-test \
      "$PWD/template" "$PWD/runtime-invalid" "$PWD/persistent-invalid" \
      $'bad\npath' >/dev/null 2>&1; then
      echo "runtime prepare accepted a control character in a persistent path" >&2
      exit 1
    fi

    if WAYLANDCRAFT_ALLOW_TEST_DEST=1 \
      ${runtimePrepare}/bin/waylandcraft-runtime-prepare-test \
      "$PWD/template" "$PWD/runtime-invalid" "$PWD/persistent-invalid" \
      saves saves >/dev/null 2>&1; then
      echo "runtime prepare accepted duplicate persistent paths" >&2
      exit 1
    fi

    if WAYLANDCRAFT_ALLOW_TEST_DEST=1 \
      ${runtimePrepare}/bin/waylandcraft-runtime-prepare-test \
      "$PWD/template" "$PWD/runtime-invalid" "$PWD/persistent-invalid" \
      waylandcraft waylandcraft/settings.json >/dev/null 2>&1; then
      echo "runtime prepare accepted overlapping persistent paths" >&2
      exit 1
    fi

    if WAYLANDCRAFT_ALLOW_TEST_DEST=1 \
      ${runtimePrepare}/bin/waylandcraft-runtime-prepare-test \
      "$PWD/template" "$PWD/runtime-overlap" "$PWD/runtime-overlap" \
      saves >/dev/null 2>&1; then
      echo "runtime prepare accepted overlapping runtime and persistence roots" >&2
      exit 1
    fi

    mkdir -p xdg
    XDG_RUNTIME_DIR="$PWD/xdg" \
      ${runtimePrepare}/bin/waylandcraft-runtime-prepare-test \
      "$PWD/template" "$PWD/xdg/waylandcraft-test"
    test -d xdg/waylandcraft-test/game/saves

    mkdir -p outside
    printf '%s\n' keep > outside/sentinel
    if XDG_RUNTIME_DIR="$PWD/xdg" \
      ${runtimePrepare}/bin/waylandcraft-runtime-prepare-test \
      "$PWD/template" "$PWD/xdg/waylandcraft-escape/../outside"; then
      echo "runtime prepare accepted a traversal destination" >&2
      exit 1
    fi
    grep -qx keep outside/sentinel

    ln -s "$PWD/outside" xdg/waylandcraft
    if XDG_RUNTIME_DIR="$PWD/xdg" \
      ${runtimePrepare}/bin/waylandcraft-runtime-prepare-test \
      "$PWD/template" "$PWD/xdg/waylandcraft"; then
      echo "runtime prepare accepted a symlink destination" >&2
      exit 1
    fi
    grep -qx keep outside/sentinel
    touch "$out"
  '';

  immutable-template = pkgs.runCommand "waylandcraft-immutable-template-check" { } ''
    WAYLANDCRAFT_ALLOW_TEST_DEST=1 \
      ${runtimePrepare}/bin/waylandcraft-runtime-prepare-test \
      ${actualRuntimeTemplate} "$PWD/runtime"

    test -d runtime/main/assets
    test -d runtime/main/libraries
    test -z "$(${pkgs.findutils}/bin/find runtime/game/saves -mindepth 1 -print -quit)"
    test -w runtime/game/options.txt
    grep -Fqx 'key_key.inventory:key.keyboard.e' runtime/game/options.txt
    grep -Fqx 'key_waylandcraft.key.windowManager:key.keyboard.b' runtime/game/options.txt
    grep -Fqx 'key_waylandcraft.key.appLauncher:key.keyboard.v' runtime/game/options.txt
    grep -Fqx 'key_waylandcraft.key.captureKeyboard:key.keyboard.g' runtime/game/options.txt
    test -w runtime/game/waylandcraft/settings.json
    ${pkgs.jq}/bin/jq -e '. == {}' runtime/game/waylandcraft/settings.json
    ${pkgs.jq}/bin/jq -e '
      (.shortcuts | has("applicationTerminal") | not)
    ' runtime/game/waylandcraft/desktop-policy.json
    test -e runtime/game/mods/waylandcraft-${packages.pins.waylandcraft.version}.jar
    test -e runtime/game/mods/waylandcraft-desktop-policy-${packages.policyMod.version}.jar

    if touch runtime/main/versions/.waylandcraft-write-test 2>/dev/null; then
      echo "store-backed version cache was unexpectedly writable" >&2
      exit 1
    fi
    mkdir runtime/game/saves/user-world
    touch "$out"
  '';

  shell-lint =
    pkgs.runCommand "waylandcraft-shell-lint-check"
      {
        nativeBuildInputs = [ pkgs.shellcheck ];
      }
      ''
        shellcheck ${../scripts/tty-cage-smoke}
        touch "$out"
      '';

  github-actions =
    pkgs.runCommand "waylandcraft-github-actions-check"
      {
        nativeBuildInputs = [
          pkgs.actionlint
          pkgs.shellcheck
        ];
      }
      ''
        actionlint ${../.github/workflows/ci.yml}
        touch "$out"
      '';

  diagnostics = pkgs.runCommand "waylandcraft-diagnostics-check" { } ''
    export HOME="$TMPDIR/home"
    export USER=builder
    export XDG_RUNTIME_DIR="$TMPDIR/runtime"
    mkdir -p "$HOME" "$XDG_RUNTIME_DIR"

    ${packages.diagnose}/bin/waylandcraft-diagnose --help > help.txt
    grep -qx 'Usage: waylandcraft-diagnose \[--logs\]' help.txt
    ${packages.diagnose}/bin/waylandcraft-diagnose > report.txt 2>&1
    grep -qx '== Build ==' report.txt
    grep -q 'Minecraft ${packages.pins.minecraft.version}' report.txt
    grep -qx '== Display manager ==' report.txt
    grep -qx '== Waylandcraft user units ==' report.txt
    ${packages.clientTools}/bin/waylandcraft-client-probe --help > probe-help.txt
    grep -qx 'Usage: waylandcraft-client-probe native|x11' probe-help.txt
    touch "$out"
  '';

  documentation = pkgs.runCommand "waylandcraft-documentation-check" { } ''
    grep -Fq 'inputs.waylandcraft-desktop.url = "github:mvanderloo/waylandcraft-desktop-nix"' \
      ${../README.md}
    grep -Fqx 'waylandcraft' ${../README.md}
    grep -Fq 'nix run github:mvanderloo/waylandcraft-desktop-nix' ${../README.md}
    grep -Fq '[configuration fragment](examples/configuration.nix)' \
      ${../README.md}
    grep -Fqx 'MIT License' ${../LICENSE}
    grep -Fq '[MIT License](LICENSE)' ${../README.md}
    touch "$out"
  '';

  justfile = pkgs.runCommand "waylandcraft-justfile-check" { nativeBuildInputs = [ pkgs.just ]; } ''
    export HOME="$TMPDIR/home"
    mkdir -p "$HOME"
    just --justfile ${../justfile} --dump > justfile.dump
    touch "$out"
  '';

  mod-artifacts =
    pkgs.runCommand "waylandcraft-mod-artifact-check"
      {
        nativeBuildInputs = [
          pkgs.jdk25
          pkgs.jq
          pkgs.unzip
        ];
      }
      ''
        unzip -p ${packages.waylandcraftJar} fabric.mod.json > waylandcraft.json
        unzip -p ${packages.fabricApiJar} fabric.mod.json > fabric-api.json
        unzip -p ${packages.sodiumJar} fabric.mod.json > sodium.json
        unzip -p ${packages.policyModJar} fabric.mod.json > policy.json
        unzip -p ${packages.policyModJar} \
          waylandcraft-desktop-policy.mixins.json > policy-mixins.json
        unzip -p ${packages.waylandcraftJar} \
          libwaylandcraft-linux-gnu-x86_64.so > libwaylandcraft.so

        policy_jar=${actualRuntimeTemplate}/game/mods/waylandcraft-desktop-policy-${packages.policyMod.version}.jar
        manifest=${actualRuntimeTemplate}/game/waylandcraft/desktop-policy.json
        gson_jar=$(${pkgs.findutils}/bin/find \
          ${actualRuntimeTemplate}/main/libraries/com/google/code/gson/gson \
          -type f -name 'gson-*.jar' -print -quit)
        mkdir policy-test-classes
        cp \
          ${../policy-mod/src/test/java/dev/waylandcraft/desktop/PolicyManifestHarness.java} \
          PolicyManifestHarness.java
        policy_classpath="$policy_jar:$gson_jar"
        javac --release 25 \
          -classpath "$policy_classpath" \
          -d policy-test-classes \
          PolicyManifestHarness.java
        java -ea \
          -classpath "$policy_classpath:policy-test-classes" \
          dev.waylandcraft.desktop.PolicyManifestHarness \
          "$manifest"

        if grep -R -E 'waylandcraft-session-control|systemctl' \
          ${../policy-mod/src/main/java}; then
          echo 'policy mod still hardcodes host session-control commands' >&2
          exit 1
        fi
        jq -e '
          .plugin == "dev.waylandcraft.desktop.DesktopPolicyMixinPlugin" and
          .client == ["GlobalShortcutKeyMixin", "KeyboardLockKeyMixin"]
        ' policy-mixins.json

        jq -e \
          --arg version ${lib.escapeShellArg packages.pins.waylandcraft.version} \
          --arg minecraft ${lib.escapeShellArg "~${packages.pins.minecraft.version}"} \
          --arg loader ${lib.escapeShellArg ">=${packages.pins.minecraft.fabricLoader}"} \
          '.id == "waylandcraft" and .version == $version and .depends.minecraft == $minecraft and .depends.fabricloader == $loader' \
          waylandcraft.json
        jq -e \
          --arg version ${lib.escapeShellArg packages.pins.minecraft.fabricApi} \
          '.id == "fabric-api" and .version == $version' \
          fabric-api.json
        jq -e \
          --arg version ${lib.escapeShellArg packages.pins.minecraft.sodium} \
          '.id == "sodium" and .version == $version' \
          sodium.json
        jq -e \
          --arg version ${lib.escapeShellArg packages.policyMod.version} \
          --arg minecraft ${lib.escapeShellArg "=${packages.pins.minecraft.version}"} \
          --arg loader ${lib.escapeShellArg "=${packages.pins.minecraft.fabricLoader}"} \
          --arg fabric_api ${lib.escapeShellArg "=${packages.pins.minecraft.fabricApi}"} \
          --arg waylandcraft ${lib.escapeShellArg "=${packages.pins.waylandcraft.version}"} \
          '.id == "waylandcraft_desktop_policy" and .version == $version and .license == "MIT" and .contact.sources == "https://github.com/mvanderloo/waylandcraft-desktop-nix" and .depends.minecraft == $minecraft and .depends.fabricloader == $loader and .depends["fabric-api"] == $fabric_api and .depends.waylandcraft == $waylandcraft' \
          policy.json

        # The bridge owns satellite startup: its native payload probes the
        # pinned command for listen-fd support, launches it, and exports both
        # socket variables to child applications. Keep these checks paired
        # with the service PATH check below so X11 support cannot disappear
        # through packaging changes.
        grep -aFq 'xwayland-satellite' libwaylandcraft.so
        grep -aFq -- '--test-listenfd-support' libwaylandcraft.so
        grep -aFq 'WAYLAND_DISPLAY' libwaylandcraft.so
        grep -aFq 'DISPLAY' libwaylandcraft.so
        touch "$out"
      '';

  offline-resolution =
    pkgs.runCommand "waylandcraft-offline-resolution-check"
      {
        nativeBuildInputs = [ packages.portablemc ];
      }
      ''
        mkdir -p main game bin home
        ln -s ${packages.minecraftHome}/assets main/assets
        ln -s ${packages.minecraftHome}/libraries main/libraries
        ln -s ${packages.minecraftHome}/versions main/versions
        test ! -e ${packages.minecraftHome}/portablemc_msa.json
        export HOME="$PWD/home"

        portablemc --main-dir "$PWD/main" --output machine start \
          --dry \
          --mc-dir "$PWD/game" \
          --bin-dir "$PWD/bin" \
          --fetch-exclude-all \
          --jvm ${pkgs.jdk25}/bin/java \
          "fabric:${packages.pins.minecraft.version}:${packages.pins.minecraft.fabricLoader}"
        touch "$out"
      '';
}
