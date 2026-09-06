package dev.waylandcraft.desktop;

import java.util.Collections;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;

/** Immutable, platform-neutral representation of desktop policy schema version 1. */
record PolicyManifest(
    int schemaVersion,
    Map<String, Shortcut> shortcuts
) {
    static final int SUPPORTED_SCHEMA_VERSION = 1;

    PolicyManifest {
        if (schemaVersion != SUPPORTED_SCHEMA_VERSION) {
            throw new IllegalArgumentException("Unsupported policy schema version: " + schemaVersion);
        }
        Objects.requireNonNull(shortcuts, "shortcuts");
        shortcuts = Collections.unmodifiableMap(new LinkedHashMap<>(shortcuts));
    }

    record Shortcut(String key, List<Modifier> modifiers, Action action) {
        Shortcut {
            Objects.requireNonNull(key, "key");
            Objects.requireNonNull(modifiers, "modifiers");
            Objects.requireNonNull(action, "action");
            modifiers = List.copyOf(modifiers);
        }
    }

    sealed interface Action permits BuiltinAction, ExecAction {
    }

    record BuiltinAction(Builtin name) implements Action {
        BuiltinAction {
            Objects.requireNonNull(name, "name");
        }
    }

    record ExecAction(List<String> argv) implements Action {
        ExecAction {
            Objects.requireNonNull(argv, "argv");
            argv = List.copyOf(argv);
        }
    }

    enum Builtin {
        TOGGLE_KEYBOARD_LOCK("toggleKeyboardLock"),
        OPEN_WINDOW_MANAGER("openWindowManager"),
        OPEN_PICKER("openPicker"),
        TOGGLE_FOCUSED_WINDOW_FULLSCREEN("toggleFocusedWindowFullscreen");

        private final String manifestName;

        Builtin(String manifestName) {
            this.manifestName = manifestName;
        }

        String manifestName() {
            return manifestName;
        }
    }

    enum Modifier {
        SHIFT,
        CONTROL,
        ALT,
        SUPER
    }
}
