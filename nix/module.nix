{
  config,
  defaultPackageSet ? import ./packages.nix { inherit pkgs; },
  lib,
  pkgs,
  ...
}:

let
  cfg = config.programs.waylandcraft-desktop;
  # The exported module supplies the concrete runtime built from the flake's
  # locked Nixpkgs input; `pkgs` remains the host package set for NixOS options.
  packages = defaultPackageSet;
  runtimePkgs = packages.pkgs;
  inherit (packages) pins;

  keyboardKeyNames =
    map toString (lib.range 0 9)
    ++ builtins.genList (index: builtins.substring index 1 "abcdefghijklmnopqrstuvwxyz") 26
    ++ map (number: "f${toString number}") (lib.range 1 25)
    ++ map (number: "keypad.${toString number}") (lib.range 0 9)
    ++ [
      "apostrophe"
      "backslash"
      "backspace"
      "caps.lock"
      "comma"
      "delete"
      "down"
      "end"
      "enter"
      "equal"
      "escape"
      "grave.accent"
      "home"
      "insert"
      "keypad.add"
      "keypad.decimal"
      "keypad.divide"
      "keypad.enter"
      "keypad.equal"
      "keypad.multiply"
      "keypad.subtract"
      "left"
      "left.alt"
      "left.bracket"
      "left.control"
      "left.shift"
      "left.win"
      "menu"
      "minus"
      "num.lock"
      "page.down"
      "page.up"
      "pause"
      "period"
      "print.screen"
      "right"
      "right.alt"
      "right.bracket"
      "right.control"
      "right.shift"
      "right.win"
      "scroll.lock"
      "semicolon"
      "slash"
      "space"
      "tab"
      "unknown"
      "up"
      "world.1"
      "world.2"
    ];
  keyboardInputs = map (name: "key.keyboard.${name}") keyboardKeyNames;
  globalKeyboardInputs = lib.filter (input: input != "key.keyboard.unknown") keyboardInputs;
  mouseInputs = map (name: "key.mouse.${name}") [
    "left"
    "right"
    "middle"
    "4"
    "5"
    "6"
    "7"
    "8"
  ];
  keyInputType = lib.types.enum (keyboardInputs ++ mouseInputs);
  keyboardInputType = lib.types.enum globalKeyboardInputs;
  globalShortcutType = lib.types.submodule {
    options = {
      key = lib.mkOption {
        type = keyboardInputType;
        description = "Minecraft keyboard input identifier used for this global shortcut.";
      };
      modifiers = lib.mkOption {
        type = lib.types.listOf (
          lib.types.enum [
            "shift"
            "control"
            "alt"
            "super"
          ]
        );
        default = [ ];
        description = "Exact modifier set required with the shortcut key.";
      };
    };
  };
  minecraftOptionValueType = lib.types.nullOr (
    lib.types.oneOf [
      lib.types.bool
      lib.types.int
      lib.types.float
      lib.types.str
    ]
  );
  jsonFormat = pkgs.formats.json { };
  policyActionType =
    defaultAction:
    lib.types.submodule (
      { config, ... }:
      {
        options = {
          kind = lib.mkOption (
            {
              type = lib.types.enum [
                "builtin"
                "exec"
              ];
              description = "Policy action implementation.";
            }
            // lib.optionalAttrs (defaultAction != null) {
              default = defaultAction.kind;
            }
          );
          name = lib.mkOption {
            type = lib.types.nullOr (
              lib.types.enum [
                "toggleKeyboardLock"
                "openWindowManager"
                "openPicker"
                "toggleFocusedWindowFullscreen"
              ]
            );
            default =
              if defaultAction != null && config.kind == "builtin" && defaultAction.kind == "builtin" then
                defaultAction.name
              else
                null;
            description = "Builtin action name; valid only when kind is builtin.";
          };
          argv = lib.mkOption {
            type = lib.types.nullOr (lib.types.listOf lib.types.str);
            default =
              if defaultAction != null && config.kind == "exec" && defaultAction.kind == "exec" then
                defaultAction.argv
              else
                null;
            description = "Argument vector; valid only when kind is exec.";
          };
        };
      }
    );
  policyShortcutType = lib.types.submodule (
    { name, ... }:
    let
      defaultShortcut = packages.defaultPolicy.shortcuts.${name} or null;
      hasDefault = defaultShortcut != null;
    in
    {
      options = {
        key = lib.mkOption (
          {
            type = keyboardInputType;
            description = "Minecraft keyboard input identifier used for this global shortcut.";
          }
          // lib.optionalAttrs hasDefault {
            default = defaultShortcut.key;
          }
        );
        modifiers = lib.mkOption {
          type = lib.types.listOf (
            lib.types.enum [
              "shift"
              "control"
              "alt"
              "super"
            ]
          );
          default = if hasDefault then defaultShortcut.modifiers else [ ];
          description = "Exact modifier set required with the shortcut key.";
        };
        action = lib.mkOption (
          {
            type = policyActionType (if hasDefault then defaultShortcut.action else null);
            description = "Builtin operation or external argument vector run by this shortcut.";
          }
          // lib.optionalAttrs hasDefault {
            default = { };
          }
        );
      };
    }
  );

  applicationRoleType = lib.types.submodule {
    options = {
      package = lib.mkOption {
        type = lib.types.nullOr lib.types.package;
        default = null;
        description = "Package made available to this application role.";
      };
      command = lib.mkOption {
        type = lib.types.nullOr (lib.types.listOf lib.types.str);
        default = null;
        description = ''
          Optional argument vector for this role. When null, the package's
          main executable is used.
        '';
      };
      shortcut = lib.mkOption {
        type = lib.types.nullOr globalShortcutType;
        default = null;
        description = "Optional global shortcut for launching this role.";
      };
    };
  };

  roleIsConfigured = role: role.package != null || role.command != null || role.shortcut != null;
  effectiveRoleCommand =
    role:
    if role.command != null then
      role.command
    else if role.package != null then
      [ (lib.getExe role.package) ]
    else
      null;
  validCommand =
    command: command != null && command != [ ] && lib.all (argument: argument != "") command;
  effectiveTerminalCommand = effectiveRoleCommand cfg.applications.terminal;
  terminalLauncher =
    if validCommand effectiveTerminalCommand then
      runtimePkgs.writeShellApplication {
        name = "waylandcraft-terminal";
        text = ''
          exec ${lib.escapeShellArgs effectiveTerminalCommand} "$@"
        '';
      }
    else
      null;
  # Waylandcraft persists this setting when consumers opt settings.json into
  # persistence, so keep it independent of the wrapper's changing store path.
  # The policy command remains absolute because it is regenerated per runtime.
  terminalLauncherCommand = lib.optional (terminalLauncher != null) (lib.getExe terminalLauncher);
  terminalChoice = if terminalLauncher == null then null else "waylandcraft-terminal";
  reservedApplicationShortcutNames = [ "applicationTerminal" ];
  configuredPolicyShortcuts = lib.filterAttrs (_: shortcut: shortcut != null) cfg.policy.shortcuts;
  applicationPolicyShortcuts =
    lib.optionalAttrs (cfg.applications.terminal.shortcut != null && terminalLauncher != null)
      {
        applicationTerminal = cfg.applications.terminal.shortcut // {
          action = {
            kind = "exec";
            argv = terminalLauncherCommand;
          };
        };
      };
  effectivePolicyShortcutsRaw = configuredPolicyShortcuts // applicationPolicyShortcuts;
  effectivePolicyShortcuts = lib.mapAttrs (
    _: shortcut:
    shortcut
    // {
      action =
        if shortcut.action.kind == "builtin" then
          {
            kind = "builtin";
            inherit (shortcut.action) name;
          }
        else
          {
            kind = "exec";
            inherit (shortcut.action) argv;
          };
    }
  ) effectivePolicyShortcutsRaw;
  policyManifest = {
    shortcuts = effectivePolicyShortcuts;
  };
  applicationPackages = lib.optional (
    cfg.applications.terminal.package != null
  ) cfg.applications.terminal.package;
  configuredPolicyShortcutValues = lib.attrValues effectivePolicyShortcutsRaw;
  bindingIdentity =
    binding:
    "${binding.key}+${lib.concatStringsSep "+" (lib.sort builtins.lessThan binding.modifiers)}";
  bindingIdentities = map bindingIdentity configuredPolicyShortcutValues;
  nonBlank = value: builtins.match ".*[^[:space:]].*" value != null;
  validExecArgv = argv: argv != null && argv != [ ] && nonBlank (builtins.head argv);
  validPolicyAction =
    action:
    if action.kind == "builtin" then
      (action.name or null) != null && (action.argv or null) == null
    else
      (action.name or null) == null && validExecArgv (action.argv or null);
  persistentGamePaths = cfg.persistence.gamePaths;
  persistsWaylandcraftSettings = lib.elem "waylandcraft/settings.json" persistentGamePaths;
  terminalChoiceFilter =
    if terminalLauncher != null then
      ''.terminalChoice = "waylandcraft-terminal"''
    else
      ''if .terminalChoice == "waylandcraft-terminal" then del(.terminalChoice) else . end'';
  validGamePath =
    path:
    path != ""
    && !lib.hasPrefix "/" path
    && builtins.match "[^[:cntrl:]]+" path != null
    && lib.all (component: component != "" && component != "." && component != "..") (
      lib.splitString "/" path
    );
  managedRuntimePath =
    path:
    path == "mods"
    || lib.hasPrefix "mods/" path
    || path == "waylandcraft"
    || path == "waylandcraft/desktop-policy.json"
    || lib.hasPrefix "waylandcraft/desktop-policy.json/" path;
  gamePathsOverlap =
    left: right: left != right && (lib.hasPrefix "${left}/" right || lib.hasPrefix "${right}/" left);
  minecraftOptionNames = lib.attrNames cfg.settings.minecraft;
  validMinecraftOptionName =
    name: name != "" && !lib.hasInfix ":" name && !lib.hasInfix "\n" name && !lib.hasInfix "\r" name;
  validMinecraftOptionValue =
    value:
    value == null || !builtins.isString value || (!lib.hasInfix "\n" value && !lib.hasInfix "\r" value);

  runtimeTemplate = packages.mkRuntimeTemplate {
    inherit (cfg) extraGameFiles extraMods;
    inherit terminalChoice;
    minecraftKeybindings = cfg.keybindings.minecraft;
    minecraftOptions = cfg.settings.minecraft;
    policy = policyManifest;
    waylandcraftKeybindings = cfg.keybindings.waylandcraft;
    waylandcraftSettings = cfg.settings.waylandcraft;
  };

  runtimePrepare = runtimePkgs.writeShellApplication {
    name = "waylandcraft-runtime-prepare";
    runtimeInputs = [ runtimePkgs.coreutils ];
    text = builtins.readFile ../scripts/runtime-prepare;
  };

  minecraftLauncher = runtimePkgs.writeShellApplication {
    name = "waylandcraft-minecraft";
    runtimeInputs = [
      runtimePkgs.coreutils
      packages.portablemc
      packages.offlineUuid
      packages.jdk
    ];
    text = ''
      set -euo pipefail
      runtime="''${XDG_RUNTIME_DIR:?XDG_RUNTIME_DIR is required}/waylandcraft"
      test -d "$runtime/main/versions" || {
        printf '%s\n' 'Waylandcraft runtime was not prepared' >&2
        exit 1
      }

      mkdir -p "$runtime/bin"
      offline_username=${
        if cfg.offlineUsername == null then "$(id -un)" else lib.escapeShellArg cfg.offlineUsername
      }
      if [[ ! $offline_username =~ ^[A-Za-z0-9_]{1,16}$ ]]; then
        printf 'waylandcraft-minecraft: Linux username must be a 1-16 character Minecraft name: %s\n' \
          "$offline_username" >&2
        exit 1
      fi
      ${
        if cfg.offlineUuid == null then
          ''offline_uuid=$(waylandcraft-offline-uuid "$offline_username")''
        else
          "offline_uuid=${lib.escapeShellArg cfg.offlineUuid}"
      }

      exec portablemc \
        --main-dir "$runtime/main" \
        --output machine \
        start \
        --mc-dir "$runtime/game" \
        --bin-dir "$runtime/bin" \
        --fetch-exclude-all \
        --jvm ${packages.jdk}/bin/java \
        --username "$offline_username" \
        --uuid "$offline_uuid" \
        --disable-multiplayer \
        --jvm-arg=${lib.escapeShellArg "-Xms${cfg.memory.initial},-Xmx${cfg.memory.maximum}"} \
        --jvm-arg="-Dwaylandcraft.desktop.policyConfig=$runtime/game/waylandcraft/desktop-policy.json" \
        "fabric:${pins.minecraft.version}:${pins.minecraft.fabricLoader}"
    '';
  };

  sessionRunner = runtimePkgs.writeShellApplication {
    name = "waylandcraft-session-runner";
    runtimeInputs = [
      runtimePkgs.coreutils
      runtimePkgs.dbus
      runtimePkgs.systemd
      runtimePrepare
    ]
    ++ lib.optional persistsWaylandcraftSettings runtimePkgs.jq
    ++ lib.optional (terminalLauncher != null) terminalLauncher
    ++ applicationPackages
    ++ cfg.extraPackages;
    text = ''
      set -euo pipefail
      : "''${WAYLAND_DISPLAY:?Cage did not provide WAYLAND_DISPLAY}"
      : "''${DISPLAY:?Cage did not provide DISPLAY}"
      : "''${HOME:?HOME is required}"
      export XDG_SESSION_TYPE=wayland
      export XDG_CURRENT_DESKTOP=Waylandcraft
      export XDG_SESSION_DESKTOP=waylandcraft
      export XDG_DATA_HOME="''${XDG_DATA_HOME:-$HOME/.local/share}"
      export XDG_DATA_DIRS="''${XDG_DATA_DIRS:-/run/current-system/sw/share}"
      export WAYLANDCRAFT_OUTER_DISPLAY="$WAYLAND_DISPLAY"
      runtime_directory="$XDG_RUNTIME_DIR/waylandcraft"
      data_directory="$XDG_DATA_HOME/waylandcraft"
      persistent_game_paths=( ${lib.escapeShellArgs persistentGamePaths} )

      if [[ $XDG_DATA_HOME != /* ]]; then
        printf '%s\n' 'Waylandcraft requires an absolute XDG_DATA_HOME' >&2
        exit 1
      fi
      mkdir -p "$data_directory"

      systemctl --user import-environment \
        DISPLAY PATH WAYLAND_DISPLAY WAYLANDCRAFT_OUTER_DISPLAY XDG_CURRENT_DESKTOP \
        XDG_DATA_DIRS XDG_DATA_HOME XDG_RUNTIME_DIR XDG_SESSION_DESKTOP XDG_SESSION_TYPE
      dbus-update-activation-environment \
        DISPLAY PATH WAYLAND_DISPLAY WAYLANDCRAFT_OUTER_DISPLAY XDG_CURRENT_DESKTOP \
        XDG_DATA_DIRS XDG_DATA_HOME XDG_RUNTIME_DIR XDG_SESSION_DESKTOP XDG_SESSION_TYPE

      waylandcraft-runtime-prepare \
        ${runtimeTemplate} \
        "$runtime_directory" \
        "$data_directory" \
        "''${persistent_game_paths[@]}"

      ${lib.optionalString persistsWaylandcraftSettings ''
        # Keep the module-owned terminal adapter current without overwriting
        # any settings owned by the user or another module.
        settings_file="$data_directory/waylandcraft/settings.json"
        settings_tmp=$(mktemp "$data_directory/waylandcraft/.settings.json.XXXXXX")
        if ! jq ${lib.escapeShellArg terminalChoiceFilter} "$settings_file" > "$settings_tmp"; then
          rm -f -- "$settings_tmp"
          exit 1
        fi
        chmod --reference="$settings_file" "$settings_tmp"
        mv -T -- "$settings_tmp" "$settings_file"
      ''}

      cleanup() {
        systemctl --user stop waylandcraft-session.target || true
        rm -rf -- "$runtime_directory"
      }
      trap cleanup EXIT INT TERM

      # Both standard graphical targets refuse manual starts. Starting this
      # session-specific target pulls them in through Wants=/BindsTo=, and
      # StopWhenUnneeded tears them down after this target stops.
      systemctl --user start waylandcraft-session.target

      while systemctl --user --quiet is-active waylandcraft-session.target; do
        sleep 1
      done
    '';
  };

  outerSession = runtimePkgs.writeShellApplication {
    name = "waylandcraft-desktop-session";
    runtimeInputs = [
      packages.cage
      runtimePkgs.util-linux
    ];
    text = ''
      set -euo pipefail
      runtime_directory="''${XDG_RUNTIME_DIR:-}"
      if [[ $runtime_directory != /* || ! -d $runtime_directory || ! -O $runtime_directory || ! -w $runtime_directory ]]; then
        printf '%s\n' 'Waylandcraft requires an absolute, owned, writable XDG_RUNTIME_DIR' >&2
        exit 1
      fi

      # Greeters bypass the TTY launcher. Hold a shared lock before Cage or
      # runtime preparation starts so either entry point rejects a second
      # session, including concurrent login attempts.
      exec 9>"$runtime_directory/waylandcraft-session.lock"
      if ! flock --nonblock 9; then
        printf '%s\n' 'A Waylandcraft session is already running for this user' >&2
        exit 1
      fi

      export XDG_SESSION_TYPE=wayland
      export XDG_CURRENT_DESKTOP=Waylandcraft
      export XDG_SESSION_DESKTOP=waylandcraft
      ${lib.optionalString (cfg.xkbOptions != null) ''
        export XKB_DEFAULT_OPTIONS=${lib.escapeShellArg cfg.xkbOptions}
      ''}
      exec cage -s -d -- ${sessionRunner}/bin/waylandcraft-session-runner
    '';
  };

  ttyLauncher = runtimePkgs.writeShellApplication {
    name = "waylandcraft";
    runtimeInputs = [
      runtimePkgs.coreutils
      runtimePkgs.systemd
    ];
    text = ''
      set -euo pipefail

      case "''${1:-}" in
        -h|--help)
          printf '%s\n' 'Usage: waylandcraft' \
            'Start the configured Waylandcraft session from the active local Linux VT.'
          exit 0
          ;;
        "") ;;
        *)
          printf '%s\n' 'waylandcraft: this command takes no arguments' >&2
          exit 2
          ;;
      esac

      current_tty=$(tty 2>/dev/null || true)
      if [[ ! $current_tty =~ ^/dev/tty[0-9]+$ ]]; then
        printf 'waylandcraft: run from a local Linux VT, not %s\n' \
          "''${current_tty:-a non-TTY session}" >&2
        exit 1
      fi

      active_tty=$(< /sys/class/tty/tty0/active)
      if [[ $current_tty != "/dev/$active_tty" ]]; then
        printf 'waylandcraft: %s is not active; the kernel reports %s\n' \
          "$current_tty" "$active_tty" >&2
        exit 1
      fi

      runtime_directory="''${XDG_RUNTIME_DIR:-}"
      if [[ -z $runtime_directory || ! -d $runtime_directory || ! -O $runtime_directory || ! -w $runtime_directory ]]; then
        printf '%s\n' 'waylandcraft: XDG_RUNTIME_DIR must exist, be owned by this user, and be writable' >&2
        exit 1
      fi

      if systemctl --user --quiet is-active waylandcraft-session.target; then
        printf '%s\n' 'waylandcraft: a Waylandcraft session is already active for this user' >&2
        exit 1
      fi

      exec ${outerSession}/bin/waylandcraft-desktop-session
    '';
  };

  sessionDesktopEntry = runtimePkgs.writeText "waylandcraft.desktop" ''
    [Desktop Entry]
    Name=Waylandcraft
    Comment=Wayland applications inside Minecraft
    Exec=${outerSession}/bin/waylandcraft-desktop-session
    TryExec=${outerSession}/bin/waylandcraft-desktop-session
    Type=Application
    DesktopNames=Waylandcraft;
  '';

  sessionPackage =
    runtimePkgs.runCommand "waylandcraft-desktop-session"
      {
        passthru.waylandcraftDesktopSession = true;
        passthru.providedSessions = [ "waylandcraft" ];
      }
      ''
        mkdir -p "$out/bin"
        ln -s ${ttyLauncher}/bin/waylandcraft "$out/bin/waylandcraft"
        ln -s ${outerSession}/bin/waylandcraft-desktop-session "$out/bin/waylandcraft-desktop-session"
        install -Dm644 ${sessionDesktopEntry} "$out/share/wayland-sessions/waylandcraft.desktop"
      '';

in
{
  options.programs.waylandcraft-desktop = {
    enable = lib.mkEnableOption "the Waylandcraft Minecraft desktop session";

    extraMods = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      description = "Additional pinned Fabric mod jars copied into the immutable template.";
    };

    extraGameFiles = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Optional immutable config/resource-pack tree merged into the game directory.";
    };

    offlineUsername = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        Local Minecraft player name. null uses the authenticated Linux login
        name; Microsoft authentication is never enabled.
      '';
    };

    offlineUuid = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        Offline Minecraft identity UUID. null derives Minecraft's standard
        deterministic offline UUID from the effective username.
      '';
    };

    xkbOptions = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Optional XKB options override applied inside the Cage session; null inherits the login environment.";
    };

    memory = {
      initial = lib.mkOption {
        type = lib.types.str;
        default = "1G";
        description = "Initial JVM heap size.";
      };
      maximum = lib.mkOption {
        type = lib.types.str;
        default = "4G";
        description = "Maximum JVM heap size.";
      };
    };

    settings = {
      minecraft = lib.mkOption {
        type = lib.types.attrsOf minecraftOptionValueType;
        default = { };
        description = ''
          Minecraft options.txt entries, keyed by the text before the colon.
          Boolean and numeric values are rendered in Minecraft's line format;
          null omits an entry from the generated file. Typed keybinding options
          take precedence over matching raw key entries.
        '';
      };

      waylandcraft = lib.mkOption {
        inherit (jsonFormat) type;
        default = { };
        description = ''
          Waylandcraft settings.json object. The terminal application role
          takes precedence over terminalChoice when that role is configured.
        '';
      };
    };

    persistence.gamePaths = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "saves"
        "options.txt"
        "waylandcraft/settings.json"
      ];
      description = ''
        Normalized paths relative to the Minecraft game directory that survive
        session restarts. Template content seeds each path only when its
        persistent target does not exist; absent paths are created as
        directories. Managed mods and desktop-policy.json cannot be persistent.
      '';
    };

    applications.terminal = lib.mkOption {
      type = applicationRoleType;
      default = { };
      description = ''
        Terminal application role. Leave every field null to disable it.
        Arguments supplied by Waylandcraft are appended to the resolved
        command.
      '';
    };

    keybindings = {
      minecraft = lib.mapAttrs (
        name: default:
        lib.mkOption {
          type = keyInputType;
          inherit default;
          description = "Minecraft ${name} key mapping.";
        }
      ) packages.keybindingDefaults.minecraft;

      waylandcraft = lib.mapAttrs (
        name: default:
        lib.mkOption {
          type = keyInputType;
          inherit default;
          description = "Waylandcraft ${name} key mapping.";
        }
      ) packages.keybindingDefaults.waylandcraft;
    };

    policy.shortcuts = lib.mkOption {
      type = lib.types.attrsOf (lib.types.nullOr policyShortcutType);
      default = { };
      description = ''
        Named global shortcuts. Names are arbitrary; setting a default name
        to null removes it. applicationTerminal is reserved for the shortcut
        generated by the terminal application role.
      '';
    };

    nvidiaWorkaround = lib.mkOption {
      type = lib.types.bool;
      default = lib.elem "nvidia" config.services.xserver.videoDrivers;
      defaultText = lib.literalExpression ''lib.elem "nvidia" config.services.xserver.videoDrivers'';
      description = "Set the Waylandcraft-recommended NVIDIA threaded optimization override.";
    };

    extraPackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      description = ''
        Additional packages exposed to Waylandcraft's application launcher.
        Their desktop entries and executables are installed into the system
        environment inherited by the frontend.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    programs.waylandcraft-desktop.policy.shortcuts = lib.mapAttrs (
      _: _: lib.mkDefault { }
    ) packages.defaultPolicy.shortcuts;

    assertions = [
      {
        assertion =
          cfg.offlineUsername == null || builtins.match "[A-Za-z0-9_]{1,16}" cfg.offlineUsername != null;
        message = "the offline Minecraft username must be 1-16 letters, digits, or underscores";
      }
      {
        assertion =
          cfg.offlineUuid == null
          ||
            builtins.match "[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}" cfg.offlineUuid
            != null;
        message = "offlineUuid must use canonical UUID syntax";
      }
      {
        assertion = builtins.match "[1-9][0-9]*[kKmMgG]" cfg.memory.initial != null;
        message = "memory.initial must be a positive JVM size such as 1G or 512M";
      }
      {
        assertion = builtins.match "[1-9][0-9]*[kKmMgG]" cfg.memory.maximum != null;
        message = "memory.maximum must be a positive JVM size such as 4G or 4096M";
      }
      {
        assertion = lib.all validMinecraftOptionName minecraftOptionNames;
        message = "settings.minecraft names must be non-empty and must not contain colons or newlines";
      }
      {
        assertion = lib.all validMinecraftOptionValue (lib.attrValues cfg.settings.minecraft);
        message = "settings.minecraft string values must not contain newlines";
      }
      {
        assertion = lib.all validGamePath persistentGamePaths;
        message = "persistence.gamePaths entries must be normalized relative game paths without control characters";
      }
      {
        assertion = lib.all (path: !managedRuntimePath path) persistentGamePaths;
        message = "persistence.gamePaths must not include managed mods or desktop-policy.json";
      }
      {
        assertion = lib.length persistentGamePaths == lib.length (lib.unique persistentGamePaths);
        message = "persistence.gamePaths entries must be unique";
      }
      {
        assertion = lib.all (
          left: lib.all (right: !gamePathsOverlap left right) persistentGamePaths
        ) persistentGamePaths;
        message = "persistence.gamePaths entries must not contain one another";
      }
      {
        assertion = lib.all (
          name: !(builtins.hasAttr name cfg.policy.shortcuts)
        ) reservedApplicationShortcutNames;
        message = "policy.shortcuts applicationTerminal is reserved for the terminal application role";
      }
      {
        assertion = lib.all (shortcut: validPolicyAction shortcut.action) configuredPolicyShortcutValues;
        message = "policy shortcut actions must set exactly name for builtin or a valid argv for exec";
      }
      {
        assertion = lib.all (
          binding: lib.length binding.modifiers == lib.length (lib.unique binding.modifiers)
        ) configuredPolicyShortcutValues;
        message = "policy shortcuts must not repeat a modifier";
      }
      {
        assertion = lib.length bindingIdentities == lib.length (lib.unique bindingIdentities);
        message = "policy shortcuts must use unique key and modifier combinations";
      }
    ]
    ++ lib.mapAttrsToList (name: role: {
      assertion = !roleIsConfigured role || validCommand (effectiveRoleCommand role);
      message = "applications.${name} must resolve to a non-empty command with no empty arguments";
    }) cfg.applications;

    environment.systemPackages = [
      sessionPackage
      packages.diagnose
    ]
    ++ applicationPackages
    ++ cfg.extraPackages;

    services.displayManager.sessionPackages = [ sessionPackage ];

    hardware.graphics = {
      # Both Cage/wlroots and Minecraft/LWJGL need the host's hardware driver
      # links under /run/opengl-driver. Minimal console-only NixOS systems do
      # not enable these links unless a graphics stack asks for them.
      enable = lib.mkDefault true;
    };

    systemd = {
      user = {
        targets.waylandcraft-session = {
          description = "Waylandcraft desktop session";
          documentation = [ "man:systemd.special(7)" ];
          wants = [ "graphical-session-pre.target" ];
          after = [ "graphical-session-pre.target" ];
          bindsTo = [ "graphical-session.target" ];
        };

        services = {
          waylandcraft-minecraft = {
            description = "Minecraft Waylandcraft desktop frontend";
            wantedBy = [ "waylandcraft-session.target" ];
            partOf = [ "waylandcraft-session.target" ];
            after = [ "graphical-session.target" ];
            # The session runner imports PATH immediately before starting this
            # unit. Do not replace it with NixOS's minimal service PATH: desktop
            # entries commonly use bare Exec commands, including commands that
            # Waylandcraft passes to the preferred terminal.
            enableDefaultPath = false;
            environment = {
              XDG_CURRENT_DESKTOP = "Waylandcraft";
              XDG_SESSION_DESKTOP = "waylandcraft";
              XDG_SESSION_TYPE = "wayland";
              _JAVA_AWT_WM_NONREPARENTING = "1";
            }
            // lib.optionalAttrs cfg.nvidiaWorkaround {
              __GL_THREADED_OPTIMIZATIONS = "0";
            };
            unitConfig = {
              OnFailure = [ "waylandcraft-session-failed.service" ];
              StartLimitIntervalSec = 60;
              StartLimitBurst = 5;
            };
            serviceConfig = {
              ExecStart = lib.getExe minecraftLauncher;
              Restart = "always";
              RestartSec = 2;
              # Skip the failed state during ordinary automatic restarts. This
              # keeps OnFailure reserved for an exhausted start limit instead
              # of treating every recoverable frontend crash as a session
              # failure.
              RestartMode = "direct";
              TimeoutStopSec = 20;
              KillMode = "mixed";
              Slice = "session.slice";
              StandardOutput = "journal";
              StandardError = "journal";
              SyslogIdentifier = "waylandcraft-minecraft";
            };
          };

          waylandcraft-session-failed = {
            description = "Return a crash-looping Waylandcraft session to its launcher";
            serviceConfig = {
              Type = "oneshot";
              ExecStart = "${runtimePkgs.systemd}/bin/systemctl --user stop waylandcraft-session.target";
            };
          };
        };
      };

    };
  };
}
