{
  minecraft = {
    attack = "key.mouse.left";
    use = "key.mouse.right";
    forward = "key.keyboard.w";
    left = "key.keyboard.a";
    back = "key.keyboard.s";
    right = "key.keyboard.d";
    jump = "key.keyboard.space";
    sneak = "key.keyboard.left.shift";
    sprint = "key.keyboard.left.control";
    drop = "key.keyboard.q";
    inventory = "key.keyboard.e";
    chat = "key.keyboard.t";
    playerlist = "key.keyboard.tab";
    pickItem = "key.mouse.middle";
    command = "key.keyboard.slash";
    socialInteractions = "key.keyboard.p";
    toggleGui = "key.keyboard.f1";
    toggleSpectatorShaderEffects = "key.keyboard.f4";
    screenshot = "key.keyboard.f2";
    togglePerspective = "key.keyboard.f5";
    smoothCamera = "key.keyboard.unknown";
    fullscreen = "key.keyboard.f11";
    spectatorOutlines = "key.keyboard.unknown";
    spectatorHotbar = "key.mouse.middle";
    swapOffhand = "key.keyboard.f";
    saveToolbarActivator = "key.keyboard.c";
    loadToolbarActivator = "key.keyboard.x";
    advancements = "key.keyboard.l";
    quickActions = "key.keyboard.g";
    "debug.overlay" = "key.keyboard.f3";
    "debug.modifier" = "key.keyboard.f3";
    "hotbar.1" = "key.keyboard.1";
    "hotbar.2" = "key.keyboard.2";
    "hotbar.3" = "key.keyboard.3";
    "hotbar.4" = "key.keyboard.4";
    "hotbar.5" = "key.keyboard.5";
    "hotbar.6" = "key.keyboard.6";
    "hotbar.7" = "key.keyboard.7";
    "hotbar.8" = "key.keyboard.8";
    "hotbar.9" = "key.keyboard.9";
    "debug.reloadChunk" = "key.keyboard.a";
    "debug.showHitboxes" = "key.keyboard.b";
    "debug.clearChat" = "key.keyboard.d";
    "debug.crash" = "key.keyboard.c";
    "debug.showChunkBorders" = "key.keyboard.g";
    "debug.showAdvancedTooltips" = "key.keyboard.h";
    "debug.copyRecreateCommand" = "key.keyboard.i";
    "debug.spectate" = "key.keyboard.n";
    "debug.switchGameMode" = "key.keyboard.f4";
    "debug.debugOptions" = "key.keyboard.f6";
    "debug.focusPause" = "key.keyboard.p";
    "debug.dumpDynamicTextures" = "key.keyboard.s";
    "debug.reloadResourcePacks" = "key.keyboard.t";
    "debug.profiling" = "key.keyboard.l";
    "debug.copyLocation" = "key.keyboard.c";
    "debug.dumpVersion" = "key.keyboard.v";
    "debug.profilingChart" = "key.keyboard.1";
    "debug.fpsCharts" = "key.keyboard.2";
    "debug.networkCharts" = "key.keyboard.3";
    "debug.lightmapTexture" = "key.keyboard.4";
  };

  waylandcraft = {
    windowManager = "key.keyboard.b";
    appLauncher = "key.keyboard.v";
    captureKeyboard = "key.keyboard.g";
  };

  policy = {
    shortcuts = {
      keyboardLock = {
        key = "key.keyboard.g";
        modifiers = [ "super" ];
        action = {
          kind = "builtin";
          name = "toggleKeyboardLock";
        };
      };
      openWindowManager = {
        key = "key.keyboard.w";
        modifiers = [ "super" ];
        action = {
          kind = "builtin";
          name = "openWindowManager";
        };
      };
      openPicker = {
        key = "key.keyboard.space";
        modifiers = [ "super" ];
        action = {
          kind = "builtin";
          name = "openPicker";
        };
      };
      fullscreen = {
        key = "key.keyboard.f";
        modifiers = [ "super" ];
        action = {
          kind = "builtin";
          name = "toggleFocusedWindowFullscreen";
        };
      };
    };

    # Lifecycle shortcuts acquire their absolute session-control command in
    # the package set, where that executable is available.
    lifecycleShortcuts = {
      logout = {
        key = "key.keyboard.q";
        modifiers = [
          "shift"
          "super"
        ];
      };
    };
  };
}
