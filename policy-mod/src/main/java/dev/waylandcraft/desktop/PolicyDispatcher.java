package dev.waylandcraft.desktop;

import java.util.Objects;

/** Dispatches typed manifest actions without depending on Minecraft or Waylandcraft. */
final class PolicyDispatcher {
    private final DesktopEnvironment environment;

    PolicyDispatcher(DesktopEnvironment environment) {
        this.environment = Objects.requireNonNull(environment, "environment");
    }

    void dispatch(String shortcutName, PolicyManifest.Action action) {
        Objects.requireNonNull(shortcutName, "shortcutName");
        Objects.requireNonNull(action, "action");

        if (action instanceof PolicyManifest.ExecAction exec) {
            environment.execute(shortcutName, exec.argv());
            return;
        }

        PolicyManifest.Builtin builtin = ((PolicyManifest.BuiltinAction) action).name();
        switch (builtin) {
            case TOGGLE_KEYBOARD_LOCK -> environment.toggleKeyboardLock();
            case OPEN_WINDOW_MANAGER -> environment.openWindowManager();
            case OPEN_PICKER -> environment.openPicker();
            case TOGGLE_FOCUSED_WINDOW_FULLSCREEN -> environment.toggleFocusedWindowFullscreen();
        }
    }
}
