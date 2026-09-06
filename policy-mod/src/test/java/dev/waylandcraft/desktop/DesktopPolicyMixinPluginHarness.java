package dev.waylandcraft.desktop;

import java.util.List;
import java.util.Map;

/** No-framework regression harness for shortcut-controlled mixin selection. */
public final class DesktopPolicyMixinPluginHarness {
    private static final String GLOBAL_SHORTCUT_MIXIN =
        "dev.waylandcraft.desktop.mixin.GlobalShortcutKeyMixin";
    private static final String KEYBOARD_LOCK_MIXIN =
        "dev.waylandcraft.desktop.mixin.KeyboardLockKeyMixin";

    private DesktopPolicyMixinPluginHarness() {
    }

    public static void main(String[] arguments) {
        verifyGlobalShortcutGate();
        verifyKeyboardLockGate();
    }

    private static void verifyGlobalShortcutGate() {
        DesktopPolicyMixinPlugin empty = plugin(Map.of());
        check(
            !empty.shouldApplyMixin("ignored", GLOBAL_SHORTCUT_MIXIN),
            "an empty policy must not patch global shortcut handling"
        );

        DesktopPolicyMixinPlugin exec = plugin(Map.of(
            "exec",
            shortcut(new PolicyManifest.ExecAction(List.of("/bin/example")))
        ));
        check(
            exec.shouldApplyMixin("ignored", GLOBAL_SHORTCUT_MIXIN),
            "an executable shortcut requires the global shortcut mixin"
        );
    }

    private static void verifyKeyboardLockGate() {
        DesktopPolicyMixinPlugin empty = plugin(Map.of());
        check(
            !empty.shouldApplyMixin("ignored", KEYBOARD_LOCK_MIXIN),
            "an empty policy must preserve Waylandcraft's keyboard-lock binding"
        );

        DesktopPolicyMixinPlugin exec = plugin(Map.of(
            "exec",
            shortcut(new PolicyManifest.ExecAction(List.of("/bin/example")))
        ));
        check(
            !exec.shouldApplyMixin("ignored", KEYBOARD_LOCK_MIXIN),
            "unrelated shortcuts must preserve Waylandcraft's keyboard-lock binding"
        );

        DesktopPolicyMixinPlugin builtin = plugin(Map.of(
            "picker",
            shortcut(new PolicyManifest.BuiltinAction(PolicyManifest.Builtin.OPEN_PICKER))
        ));
        check(
            !builtin.shouldApplyMixin("ignored", KEYBOARD_LOCK_MIXIN),
            "unrelated builtins must preserve Waylandcraft's keyboard-lock binding"
        );

        DesktopPolicyMixinPlugin lock = plugin(Map.of(
            "lock",
            shortcut(new PolicyManifest.BuiltinAction(
                PolicyManifest.Builtin.TOGGLE_KEYBOARD_LOCK
            ))
        ));
        check(
            lock.shouldApplyMixin("ignored", KEYBOARD_LOCK_MIXIN),
            "a configured keyboard-lock action must replace the upstream binding"
        );
    }

    private static DesktopPolicyMixinPlugin plugin(
        Map<String, PolicyManifest.Shortcut> shortcuts
    ) {
        return new DesktopPolicyMixinPlugin(new PolicyManifest(
            PolicyManifest.SUPPORTED_SCHEMA_VERSION,
            shortcuts
        ));
    }

    private static PolicyManifest.Shortcut shortcut(PolicyManifest.Action action) {
        return new PolicyManifest.Shortcut("key.keyboard.g", List.of(), action);
    }

    private static void check(boolean condition, String message) {
        if (!condition) {
            throw new AssertionError(message);
        }
    }
}
