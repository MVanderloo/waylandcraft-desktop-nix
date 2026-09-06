package dev.waylandcraft.desktop;

import java.io.StringReader;
import java.util.ArrayList;
import java.util.List;

/** No-framework regression harness for the platform-neutral policy core. */
public final class PolicyManifestHarness {
    private static final String VALID_MANIFEST = """
        {
          "schemaVersion": 1,
          "shortcuts": {
            "consumer-defined-name": {
              "key": "key.keyboard.enter",
              "modifiers": ["super"],
              "action": {
                "kind": "exec",
                "argv": ["/bin/example", "--new-window", ""]
              }
            },
            "manage": {
              "key": "key.keyboard.w",
              "modifiers": ["control", "super"],
              "action": {
                "kind": "builtin",
                "name": "openWindowManager"
              }
            }
          }
        }
        """;

    private PolicyManifestHarness() {
    }

    public static void main(String[] arguments) {
        if (arguments.length == 1) {
            System.setProperty(PolicyManifestLoader.CONFIG_PROPERTY, arguments[0]);
            PolicyManifestLoader.loadConfigured();
            return;
        }

        parsesVersionedManifest();
        dispatchesTypedActions();
        rejectsUnsupportedSchema();
        rejectsUnknownBuiltin();
        rejectsEmptyExec();
        rejectsRepeatedModifier();
        rejectsDuplicateChordRegardlessOfModifierOrder();
    }

    private static void parsesVersionedManifest() {
        PolicyManifest manifest = parse(VALID_MANIFEST);
        check(
            new PolicyManifest.Shortcut(
                "key.keyboard.enter",
                List.of(PolicyManifest.Modifier.SUPER),
                new PolicyManifest.ExecAction(List.of("/bin/example", "--new-window", ""))
            ).equals(manifest.shortcuts().get("consumer-defined-name")),
            "shortcut key, modifiers, or exec argv were not preserved"
        );
    }

    private static void dispatchesTypedActions() {
        RecordingEnvironment environment = new RecordingEnvironment();
        PolicyDispatcher dispatcher = new PolicyDispatcher(environment);
        PolicyManifest manifest = parse(VALID_MANIFEST);

        dispatcher.dispatch(
            "consumer-defined-name",
            manifest.shortcuts().get("consumer-defined-name").action()
        );
        dispatcher.dispatch("manage", manifest.shortcuts().get("manage").action());
        dispatcher.dispatch(
            "lock",
            new PolicyManifest.BuiltinAction(PolicyManifest.Builtin.TOGGLE_KEYBOARD_LOCK)
        );
        dispatcher.dispatch(
            "picker",
            new PolicyManifest.BuiltinAction(PolicyManifest.Builtin.OPEN_PICKER)
        );
        dispatcher.dispatch(
            "fullscreen",
            new PolicyManifest.BuiltinAction(
                PolicyManifest.Builtin.TOGGLE_FOCUSED_WINDOW_FULLSCREEN
            )
        );

        check(
            environment.calls.equals(
                List.of(
                    "exec:consumer-defined-name:/bin/example,--new-window,",
                    "openWindowManager",
                    "toggleKeyboardLock",
                    "openPicker",
                    "toggleFocusedWindowFullscreen"
                )
            ),
            "typed actions dispatched incorrectly: " + environment.calls
        );
    }

    private static void rejectsUnsupportedSchema() {
        expectFailure(VALID_MANIFEST.replace("\"schemaVersion\": 1", "\"schemaVersion\": 2"));
    }

    private static void rejectsUnknownBuiltin() {
        expectFailure(VALID_MANIFEST.replace("openWindowManager", "consumerInventedBuiltin"));
    }

    private static void rejectsEmptyExec() {
        expectFailure(
            VALID_MANIFEST.replace(
                "[\"/bin/example\", \"--new-window\", \"\"]",
                "[]"
            )
        );
    }

    private static void rejectsRepeatedModifier() {
        expectFailure(VALID_MANIFEST.replace("[\"super\"]", "[\"super\", \"super\"]"));
    }

    private static void rejectsDuplicateChordRegardlessOfModifierOrder() {
        expectFailure(
            VALID_MANIFEST
                .replace("\"key.keyboard.enter\"", "\"key.keyboard.w\"")
                .replace("[\"super\"]", "[\"super\", \"control\"]")
        );
    }

    private static PolicyManifest parse(String json) {
        return PolicyManifestLoader.parse(new StringReader(json), "test manifest");
    }

    private static void expectFailure(String json) {
        try {
            parse(json);
            throw new AssertionError("invalid manifest was accepted");
        } catch (IllegalArgumentException expected) {
            // Expected validation failure.
        }
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
            calls.add("toggleKeyboardLock");
        }

        @Override
        public void openWindowManager() {
            calls.add("openWindowManager");
        }

        @Override
        public void openPicker() {
            calls.add("openPicker");
        }

        @Override
        public void toggleFocusedWindowFullscreen() {
            calls.add("toggleFocusedWindowFullscreen");
        }

        @Override
        public void execute(String shortcutName, List<String> argv) {
            calls.add("exec:" + shortcutName + ":" + String.join(",", argv));
        }
    }
}
