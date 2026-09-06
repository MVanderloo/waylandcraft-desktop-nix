{ pkgs }:

let
  inherit (pkgs) lib;
  projectLib = import ./lib.nix;
  projectHomepage = "https://github.com/mvanderloo/waylandcraft-desktop-nix";
  projectRunnableMeta = {
    homepage = projectHomepage;
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
    sourceProvenance = [ lib.sourceTypes.fromSource ];
  };
  polyformShieldLicense = {
    deprecated = false;
    free = false;
    fullName = "PolyForm Shield License 1.0.0";
    licenseType = "simple";
    redistributable = true;
    shortName = "PolyForm-Shield-1.0.0";
    url = "https://polyformproject.org/licenses/shield/1.0.0/";
  };

  basePackageSet = lib.makeScope pkgs.newScope (self: {
    inherit pkgs;
    inherit (projectLib) pins;
    keybindingDefaults = import ./keybindings.nix;

    # Runtime components share one locked scope so their generated wrappers and
    # artifacts use a coherent dependency set.
    inherit (pkgs)
      cage
      libdrm
      libxkbcommon
      mesa
      wayland
      xwayland
      ;
    jdk = pkgs.jdk25;
    xwaylandSatellite = pkgs.xwayland-satellite;

    portablemc = pkgs.portablemc.override {
      jvms = [ self.jdk ];
      additionalLibs = [
        self.libxkbcommon
        self.wayland
        self.libdrm
        self.mesa
      ];
      additionalPrograms = [
        self.libxkbcommon
        self.xwaylandSatellite
      ];
    };

    offlineUuid = pkgs.writeShellApplication {
      name = "waylandcraft-offline-uuid";
      runtimeInputs = [ pkgs.coreutils ];
      text = builtins.readFile ../scripts/offline-uuid;
    };

    waylandcraftJar = pkgs.fetchurl {
      inherit (self.pins.waylandcraft) url hash;
      name = "waylandcraft-${self.pins.waylandcraft.version}.jar";
      meta = {
        description = "Wayland application windows embedded in Minecraft";
        homepage = "https://github.com/EVV1E/waylandcraft";
        license = lib.licenses.gpl3Only;
        platforms = [ "x86_64-linux" ];
        sourceProvenance = with lib.sourceTypes; [
          binaryBytecode
          binaryNativeCode
        ];
      };
    };

    fabricApiJar = pkgs.fetchurl {
      inherit (self.pins.fabricApi) url hash;
      name = "fabric-api-${self.pins.minecraft.fabricApi}.jar";
      meta = {
        description = "Core hooks and interoperability APIs for Fabric mods";
        homepage = "https://github.com/FabricMC/fabric-api";
        license = lib.licenses.asl20;
        platforms = [ "x86_64-linux" ];
        sourceProvenance = [ lib.sourceTypes.binaryBytecode ];
      };
    };

    sodiumJar = pkgs.fetchurl {
      inherit (self.pins.sodium) url hash;
      name = "sodium-${self.pins.minecraft.sodium}.jar";
      meta = {
        description = "Rendering optimization mod for Minecraft";
        homepage = "https://github.com/CaffeineMC/sodium";
        license = polyformShieldLicense;
        platforms = [ "x86_64-linux" ];
        sourceProvenance = [ lib.sourceTypes.binaryBytecode ];
      };
    };

    minecraftHome = self.callPackage ./minecraft-home.nix { };

    policyMod = self.callPackage ./policy-mod.nix { };
    policyModJar = "${self.policyMod}${self.policyMod.jarPath}";

    mkWaylandcraftSettings =
      {
        settings ? { },
        terminalChoice ? null,
      }:
      (pkgs.formats.json { }).generate "waylandcraft-settings.json" (
        settings // lib.optionalAttrs (terminalChoice != null) { inherit terminalChoice; }
      );

    mkMinecraftOptions =
      {
        minecraftKeybindings,
        options ? { },
        waylandcraftKeybindings,
      }:
      let
        compatibilityOptions =
          lib.mapAttrs' (name: input: lib.nameValuePair "key_key.${name}" input) minecraftKeybindings
          // lib.mapAttrs' (
            name: input: lib.nameValuePair "key_waylandcraft.key.${name}" input
          ) waylandcraftKeybindings;
        renderedOptions = lib.filterAttrs (_: value: value != null) (options // compatibilityOptions);
        validName =
          name: name != "" && !lib.hasInfix ":" name && !lib.hasInfix "\n" name && !lib.hasInfix "\r" name;
        renderValue =
          value:
          if builtins.isString value then
            value
          else if builtins.isBool value || builtins.isInt value || builtins.isFloat value then
            builtins.toJSON value
          else
            throw "Minecraft option values must be booleans, numbers, strings, or null";
        renderedLines = lib.mapAttrsToList (name: value: "${name}:${renderValue value}") renderedOptions;
      in
      if !lib.all validName (lib.attrNames renderedOptions) then
        throw "Minecraft option names must be non-empty and must not contain colons or newlines"
      else if lib.any (line: lib.hasInfix "\n" line || lib.hasInfix "\r" line) renderedLines then
        throw "Minecraft option values must not contain newlines"
      else
        pkgs.writeText "waylandcraft-options.txt" (lib.concatStringsSep "\n" renderedLines + "\n");

    defaultMinecraftOptions = self.mkMinecraftOptions {
      minecraftKeybindings = self.keybindingDefaults.minecraft;
      waylandcraftKeybindings = self.keybindingDefaults.waylandcraft;
    };

    defaultWaylandcraftSettings = self.mkWaylandcraftSettings { };

    sessionControl = pkgs.writeShellApplication {
      name = "waylandcraft-session-control";
      runtimeInputs = [ pkgs.systemd ];
      text = ''
        set -euo pipefail
        case "''${1:-}" in
          logout)
            exec systemctl --user stop waylandcraft-session.target
            ;;
          *)
            printf '%s\n' 'Usage: waylandcraft-session-control logout' >&2
            exit 2
            ;;
        esac
      '';
    };

    defaultPolicy = {
      shortcuts =
        self.keybindingDefaults.policy.shortcuts
        //
          lib.mapAttrs
            (
              operation: shortcut:
              shortcut
              // {
                action = {
                  kind = "exec";
                  argv = [
                    "${self.sessionControl}/bin/waylandcraft-session-control"
                    operation
                  ];
                };
              }
            )
            (lib.filterAttrs (_: shortcut: shortcut != null) self.keybindingDefaults.policy.lifecycleShortcuts);
    };

    extraGameFilesValidator = pkgs.writeShellApplication {
      name = "waylandcraft-validate-game-files";
      runtimeInputs = with pkgs; [
        coreutils
        findutils
        gnugrep
      ];
      text = ''
        if [[ $# -ne 1 ]]; then
          printf '%s\n' 'usage: waylandcraft-validate-game-files DIRECTORY' >&2
          exit 2
        fi

        root=$1
        if [[ ! -d $root || -L $root ]]; then
          printf '%s\n' 'extraGameFiles is not a directory' >&2
          exit 1
        fi
        if find "$root" -type l -print -quit | grep -q .; then
          printf '%s\n' 'extraGameFiles contains a symbolic link' >&2
          exit 1
        fi
        if find "$root" ! -type d ! -type f -print -quit | grep -q .; then
          printf '%s\n' 'extraGameFiles contains a non-regular entry' >&2
          exit 1
        fi
        for reserved in options.txt mods saves waylandcraft; do
          if [[ -e $root/$reserved ]]; then
            printf 'extraGameFiles must not replace reserved game content: %s\n' \
              "$reserved" >&2
            exit 1
          fi
        done
      '';
    };

    clientProbeScript = pkgs.writeShellApplication {
      name = "waylandcraft-client-probe";
      runtimeInputs = with pkgs; [
        coreutils
        foot
        xterm
      ];
      meta = projectRunnableMeta // {
        description = "Probe native Wayland and X11 clients inside a Waylandcraft session";
      };
      text = builtins.readFile ../scripts/client-probe;
    };

    # Keep the rendering probes available as command-line diagnostics without
    # injecting project-specific entries into Waylandcraft's application picker.
    clientTools = self.clientProbeScript;

    diagnose = pkgs.writeShellApplication {
      name = "waylandcraft-diagnose";
      runtimeInputs = [
        pkgs.coreutils
        pkgs.findutils
        pkgs.gnugrep
        pkgs.systemd
        self.cage
        self.xwaylandSatellite
        self.portablemc
        self.jdk
      ];
      meta = projectRunnableMeta // {
        description = "Report Waylandcraft host and session diagnostics without changing state";
      };
      text = ''
        export WAYLANDCRAFT_BUILD_INFO=${lib.escapeShellArg "Minecraft ${self.pins.minecraft.version}, Fabric Loader ${self.pins.minecraft.fabricLoader}, Waylandcraft ${self.pins.waylandcraft.version}, Cage ${lib.getVersion self.cage}, xwayland-satellite ${lib.getVersion self.xwaylandSatellite}"}
        ${builtins.readFile ../scripts/diagnose}
      '';
    };

    runtimeTools = pkgs.symlinkJoin {
      name = "waylandcraft-runtime-tools";
      paths = [
        self.portablemc
        self.jdk
        self.cage
        self.xwaylandSatellite
        self.libxkbcommon
        self.clientTools
        self.diagnose
      ];
      meta = {
        description = "Runtime tools used by the Waylandcraft NixOS desktop session";
        homepage = projectHomepage;
        platforms = [ "x86_64-linux" ];
      };
      # The JDK exposes bin as a symlink to lib/openjdk/bin. symlinkJoin cannot
      # merge that directory symlink with the real bin directory created by the
      # other packages, so link the JDK tools explicitly after the join.
      postBuild = ''
        for tool in ${self.jdk}/bin/*; do
          name="''${tool##*/}"
          if ! test -e "$out/bin/$name"; then
            ln -s "$tool" "$out/bin/$name"
          fi
        done
      '';
    };

    demoPrepare = pkgs.writeShellApplication {
      name = "waylandcraft-demo-prepare";
      runtimeInputs = [ pkgs.coreutils ];
      text = ''
        export WAYLANDCRAFT_MC_HOME=${self.minecraftHome}
        export WAYLANDCRAFT_JAR=${self.waylandcraftJar}
        export WAYLANDCRAFT_VERSION=${lib.escapeShellArg self.pins.waylandcraft.version}
        export WAYLANDCRAFT_FABRIC_API_JAR=${self.fabricApiJar}
        export WAYLANDCRAFT_FABRIC_API_VERSION=${lib.escapeShellArg self.pins.minecraft.fabricApi}
        export WAYLANDCRAFT_SODIUM_JAR=${self.sodiumJar}
        export WAYLANDCRAFT_SODIUM_VERSION=${lib.escapeShellArg self.pins.minecraft.sodium}
        export WAYLANDCRAFT_OPTIONS=${self.defaultMinecraftOptions}
        export WAYLANDCRAFT_SETTINGS=${self.defaultWaylandcraftSettings}
        ${builtins.readFile ../scripts/demo-prepare}
      '';
    };

    demo = pkgs.writeShellApplication {
      name = "waylandcraft-demo";
      runtimeInputs = [
        self.portablemc
        self.cage
        self.demoPrepare
        self.offlineUuid
        pkgs.coreutils
        pkgs.gnugrep
        self.jdk
        self.clientTools
        self.xwaylandSatellite
      ];
      meta = projectRunnableMeta // {
        description = "Launch the pinned Waylandcraft stack from an active local VT";
      };
      text = ''
        export WAYLANDCRAFT_JAVA=${self.jdk}/bin/java
        export WAYLANDCRAFT_FABRIC_VERSION=${lib.escapeShellArg "fabric:${self.pins.minecraft.version}:${self.pins.minecraft.fabricLoader}"}
        ${builtins.readFile ../scripts/waylandcraft-demo}
      '';
    };

    mkRuntimeTemplate =
      {
        extraMods ? [ ],
        extraGameFiles ? null,
        minecraftKeybindings ? self.keybindingDefaults.minecraft,
        minecraftOptions ? { },
        policy ? self.defaultPolicy,
        terminalChoice ? null,
        waylandcraftKeybindings ? self.keybindingDefaults.waylandcraft,
        waylandcraftSettings ? { },
      }:
      let
        builtInModNames = [
          "waylandcraft-${self.pins.waylandcraft.version}.jar"
          "fabric-api-${self.pins.minecraft.fabricApi}.jar"
          "sodium-${self.pins.minecraft.sodium}.jar"
          "waylandcraft-desktop-policy-${self.policyMod.version}.jar"
        ];
        extraModNames = map (mod: builtins.baseNameOf (toString mod)) extraMods;
        collidingModNames = lib.filter (name: lib.elem name builtInModNames) extraModNames;
        minecraftOptionsFile = self.mkMinecraftOptions {
          inherit minecraftKeybindings waylandcraftKeybindings;
          options = minecraftOptions;
        };
        waylandcraftSettingsFile = self.mkWaylandcraftSettings {
          inherit terminalChoice;
          settings = waylandcraftSettings;
        };
        desktopPolicyConfig = pkgs.writeText "waylandcraft-desktop-policy.json" (
          builtins.toJSON {
            schemaVersion = 1;
            inherit (policy) shortcuts;
          }
        );
      in
      if lib.length extraModNames != lib.length (lib.unique extraModNames) then
        throw "Waylandcraft extraMods must have unique destination filenames"
      else if collidingModNames != [ ] then
        throw "Waylandcraft extraMods must not replace built-in mods: ${lib.concatStringsSep ", " collidingModNames}"
      else if !lib.all (lib.hasSuffix ".jar") extraModNames then
        throw "Waylandcraft extraMods entries must point to individual .jar files"
      else
        pkgs.runCommand "waylandcraft-runtime-template" { } ''
          ${lib.optionalString (extraGameFiles != null) ''
            ${self.extraGameFilesValidator}/bin/waylandcraft-validate-game-files \
              ${extraGameFiles}
          ''}

          mkdir -p "$out/main" "$out/game/mods" "$out/game/saves" "$out/game/waylandcraft"
          ln -s ${self.minecraftHome}/assets "$out/main/assets"
          ln -s ${self.minecraftHome}/libraries "$out/main/libraries"
          ln -s ${self.minecraftHome}/versions "$out/main/versions"

          cp ${self.waylandcraftJar} "$out/game/mods/waylandcraft-${self.pins.waylandcraft.version}.jar"
          cp ${self.fabricApiJar} "$out/game/mods/fabric-api-${self.pins.minecraft.fabricApi}.jar"
          cp ${self.sodiumJar} "$out/game/mods/sodium-${self.pins.minecraft.sodium}.jar"
          cp ${self.policyModJar} "$out/game/mods/waylandcraft-desktop-policy-${self.policyMod.version}.jar"
          ${lib.concatMapStringsSep "\n" (mod: ''
            test -f ${mod} || {
              echo "extraMods entry is not an individual regular file: ${mod}" >&2
              exit 1
            }
            cp ${mod} "$out/game/mods/${builtins.baseNameOf (toString mod)}"
          '') extraMods}
          cp ${minecraftOptionsFile} "$out/game/options.txt"
          cp ${waylandcraftSettingsFile} "$out/game/waylandcraft/settings.json"
          cp ${desktopPolicyConfig} "$out/game/waylandcraft/desktop-policy.json"
          ${lib.optionalString (extraGameFiles != null) ''
            cp -a --no-preserve=ownership ${extraGameFiles}/. "$out/game/"
          ''}
        '';

    exportedPackages = {
      inherit (self) demo diagnose portablemc;
      default = self.demo;
      runtime-tools = self.runtimeTools;
      minecraft-home = self.minecraftHome;
      waylandcraft = self.waylandcraftJar;
      fabric-api = self.fabricApiJar;
      sodium = self.sodiumJar;
      client-tools = self.clientTools;
      policy-mod = self.policyMod;
    };
  });
in
basePackageSet
