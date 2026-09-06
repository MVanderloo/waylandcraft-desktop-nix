package dev.waylandcraft.desktop;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;

import org.lwjgl.glfw.GLFW;

import net.minecraft.client.input.KeyEvent;

/** No-framework regression harness for global shortcut event handling. */
public final class DesktopPolicyHarness {
    private DesktopPolicyHarness() {
    }

    public static void main(String[] arguments) {
        RecordingEnvironment environment = new RecordingEnvironment();
        List<Runnable> scheduled = new ArrayList<>();
        PolicyManifest.Shortcut shortcut = new PolicyManifest.Shortcut(
            "key.keyboard.g",
            List.of(PolicyManifest.Modifier.SUPER),
            new PolicyManifest.ExecAction(List.of("/bin/example", "argument with spaces"))
        );
        DesktopPolicy.initialize(
            new PolicyManifest(
                PolicyManifest.SUPPORTED_SCHEMA_VERSION,
                Map.of("consumer shortcut", shortcut)
            ),
            environment,
            scheduled::add
        );

        check(
            !DesktopPolicy.handleGlobalShortcut(
                GLFW.GLFW_PRESS,
                event(GLFW.GLFW_KEY_G, GLFW.GLFW_MOD_SUPER | GLFW.GLFW_MOD_SHIFT)
            ),
            "a shortcut with extra modifiers was intercepted"
        );
        check(
            !DesktopPolicy.handleGlobalShortcut(
                GLFW.GLFW_PRESS,
                event(GLFW.GLFW_KEY_H, GLFW.GLFW_MOD_SUPER)
            ),
            "an unmatched key was intercepted"
        );
        check(scheduled.isEmpty(), "an unmatched shortcut scheduled an action");

        KeyEvent matching = event(GLFW.GLFW_KEY_G, GLFW.GLFW_MOD_SUPER);
        check(
            DesktopPolicy.handleGlobalShortcut(GLFW.GLFW_PRESS, matching),
            "an exact shortcut match was not intercepted"
        );
        check(
            DesktopPolicy.handleGlobalShortcut(GLFW.GLFW_REPEAT, matching),
            "a repeat for an intercepted key leaked through"
        );
        check(
            DesktopPolicy.handleGlobalShortcut(GLFW.GLFW_RELEASE, matching),
            "a release for an intercepted key leaked through"
        );
        check(scheduled.size() == 1, "a shortcut dispatched more than once");

        scheduled.getFirst().run();
        check(
            environment.calls.equals(
                List.of("exec:consumer shortcut:/bin/example,argument with spaces")
            ),
            "the shortcut action was not dispatched exactly once: " + environment.calls
        );
        check(
            !DesktopPolicy.handleGlobalShortcut(GLFW.GLFW_RELEASE, matching),
            "a release was intercepted after the shortcut state was cleared"
        );
    }

    private static KeyEvent event(int key, int modifiers) {
        return new KeyEvent(key, 0, modifiers);
    }

    private static void check(boolean condition, String message) {
        if (!condition) {
            throw new AssertionError(message);
        }
    }

    private static final class RecordingEnvironment implements DesktopEnvironment {
        private final List<String> calls = new ArrayList<>();

        @Override
        public void toggleKeyboardLock() {
            throw new AssertionError("unexpected keyboard-lock action");
        }

        @Override
        public void openWindowManager() {
            throw new AssertionError("unexpected window-manager action");
        }

        @Override
        public void openPicker() {
            throw new AssertionError("unexpected picker action");
        }

        @Override
        public void toggleFocusedWindowFullscreen() {
            throw new AssertionError("unexpected fullscreen action");
        }

        @Override
        public void execute(String shortcutName, List<String> argv) {
            calls.add("exec:" + shortcutName + ":" + String.join(",", argv));
        }
    }
}
