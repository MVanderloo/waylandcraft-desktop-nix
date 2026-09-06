package dev.waylandcraft.desktop;

import java.util.ArrayList;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Set;
import java.util.concurrent.Executor;

import org.lwjgl.glfw.GLFW;

import com.mojang.blaze3d.platform.InputConstants;

import net.fabricmc.api.ClientModInitializer;
import net.minecraft.client.Minecraft;
import net.minecraft.client.input.KeyEvent;

/** Connects configured global shortcuts to the Waylandcraft client. */
public final class DesktopPolicy implements ClientModInitializer {
    private static final int RELEVANT_MODIFIERS = GLFW.GLFW_MOD_SHIFT
        | GLFW.GLFW_MOD_CONTROL
        | GLFW.GLFW_MOD_ALT
        | GLFW.GLFW_MOD_SUPER;
    private static final Set<Integer> INTERCEPTED_KEYS = new HashSet<>();
    private static List<ResolvedShortcut> shortcuts = List.of();
    private static PolicyDispatcher dispatcher;
    private static Executor taskExecutor;

    @Override
    public void onInitializeClient() {
        initialize(
            PolicyManifestLoader.loadConfigured(),
            new WaylandcraftDesktopEnvironment(),
            task -> Minecraft.getInstance().execute(task)
        );
    }

    static void initialize(
        PolicyManifest manifest,
        DesktopEnvironment environment,
        Executor executor
    ) {
        List<ResolvedShortcut> configuredShortcuts = resolveShortcuts(
            Objects.requireNonNull(manifest, "manifest").shortcuts()
        );
        PolicyDispatcher configuredDispatcher = new PolicyDispatcher(environment);
        Executor configuredExecutor = Objects.requireNonNull(executor, "executor");

        shortcuts = configuredShortcuts;
        dispatcher = configuredDispatcher;
        taskExecutor = configuredExecutor;
        INTERCEPTED_KEYS.clear();
    }

    /** Handles configured shortcuts before Waylandcraft can forward them to a guest window. */
    public static boolean handleGlobalShortcut(int action, KeyEvent event) {
        PolicyDispatcher currentDispatcher = dispatcher;
        Executor currentExecutor = taskExecutor;
        if (currentDispatcher == null || currentExecutor == null) {
            return false;
        }

        if (action == GLFW.GLFW_RELEASE) {
            return INTERCEPTED_KEYS.remove(event.key());
        }
        if (action == GLFW.GLFW_REPEAT) {
            return INTERCEPTED_KEYS.contains(event.key());
        }
        if (action != GLFW.GLFW_PRESS) {
            return false;
        }

        ResolvedShortcut shortcut = shortcutFor(event);
        if (shortcut == null) {
            return false;
        }

        INTERCEPTED_KEYS.add(event.key());
        currentExecutor.execute(
            () -> currentDispatcher.dispatch(shortcut.name(), shortcut.action())
        );
        return true;
    }

    private static ResolvedShortcut shortcutFor(KeyEvent event) {
        int modifiers = event.modifiers() & RELEVANT_MODIFIERS;
        for (ResolvedShortcut shortcut : shortcuts) {
            if (shortcut.key() == event.key() && shortcut.modifiers() == modifiers) {
                return shortcut;
            }
        }
        return null;
    }

    private static List<ResolvedShortcut> resolveShortcuts(
        Map<String, PolicyManifest.Shortcut> configuredShortcuts
    ) {
        List<ResolvedShortcut> resolved = new ArrayList<>();
        Map<Chord, String> shortcutNamesByChord = new LinkedHashMap<>();
        for (Map.Entry<String, PolicyManifest.Shortcut> entry : configuredShortcuts.entrySet()) {
            PolicyManifest.Shortcut configured = entry.getValue();
            InputConstants.Key key = InputConstants.getKey(configured.key());
            if (key.getType() != InputConstants.Type.KEYSYM || key == InputConstants.UNKNOWN) {
                throw new IllegalArgumentException(
                    "Global shortcut '" + entry.getKey()
                        + "' must use a known keyboard key: " + configured.key()
                );
            }

            int modifiers = 0;
            for (PolicyManifest.Modifier modifier : configured.modifiers()) {
                modifiers |= modifierMask(modifier);
            }

            Chord chord = new Chord(key.getValue(), modifiers);
            String previousName = shortcutNamesByChord.putIfAbsent(chord, entry.getKey());
            if (previousName != null) {
                throw new IllegalArgumentException(
                    "Global shortcuts '" + previousName + "' and '" + entry.getKey()
                        + "' use the same key and modifiers"
                );
            }
            resolved.add(
                new ResolvedShortcut(
                    entry.getKey(),
                    key.getValue(),
                    modifiers,
                    configured.action()
                )
            );
        }
        return List.copyOf(resolved);
    }

    private static int modifierMask(PolicyManifest.Modifier modifier) {
        return switch (modifier) {
            case SHIFT -> GLFW.GLFW_MOD_SHIFT;
            case CONTROL -> GLFW.GLFW_MOD_CONTROL;
            case ALT -> GLFW.GLFW_MOD_ALT;
            case SUPER -> GLFW.GLFW_MOD_SUPER;
        };
    }

    private record Chord(int key, int modifiers) {
    }

    private record ResolvedShortcut(
        String name,
        int key,
        int modifiers,
        PolicyManifest.Action action
    ) {
    }
}
