package dev.waylandcraft.desktop;

import java.io.IOException;
import java.io.Reader;
import java.math.BigDecimal;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.EnumSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;

import com.google.gson.JsonArray;
import com.google.gson.JsonElement;
import com.google.gson.JsonObject;
import com.google.gson.JsonParser;
import com.google.gson.JsonPrimitive;

/** Loads policy without touching Fabric, Minecraft, Waylandcraft, or GLFW classes. */
final class PolicyManifestLoader {
    static final String CONFIG_PROPERTY = "waylandcraft.desktop.policyConfig";
    private static final Set<String> ROOT_FIELDS = Set.of(
        "schemaVersion",
        "shortcuts"
    );
    private static final Set<String> SHORTCUT_FIELDS = Set.of(
        "key",
        "modifiers",
        "action"
    );
    private static final Set<String> BUILTIN_ACTION_FIELDS = Set.of("kind", "name");
    private static final Set<String> EXEC_ACTION_FIELDS = Set.of("kind", "argv");
    private static volatile PolicyManifest configuredManifest;

    private PolicyManifestLoader() {
    }

    static PolicyManifest loadConfigured() {
        PolicyManifest current = configuredManifest;
        if (current != null) {
            return current;
        }

        synchronized (PolicyManifestLoader.class) {
            if (configuredManifest == null) {
                configuredManifest = load(configuredPath());
            }
            return configuredManifest;
        }
    }

    static Path configuredPath() {
        String configured = System.getProperty(CONFIG_PROPERTY);
        if (configured == null || configured.isBlank()) {
            throw new IllegalStateException(
                "System property " + CONFIG_PROPERTY + " must name the policy manifest"
            );
        }
        return Path.of(configured).toAbsolutePath().normalize();
    }

    static PolicyManifest load(Path path) {
        try (Reader reader = Files.newBufferedReader(path, StandardCharsets.UTF_8)) {
            return parse(reader, path.toString());
        } catch (IOException | RuntimeException exception) {
            throw new IllegalStateException(
                "Unable to load Waylandcraft desktop policy from " + path,
                exception
            );
        }
    }

    static PolicyManifest parse(Reader reader, String source) {
        JsonObject root = requireObject(JsonParser.parseReader(reader), source);
        requireOnlyFields(root, ROOT_FIELDS, source);

        int schemaVersion = requireInteger(root, "schemaVersion", source);
        if (schemaVersion != PolicyManifest.SUPPORTED_SCHEMA_VERSION) {
            throw new IllegalArgumentException(
                source + ".schemaVersion must be " + PolicyManifest.SUPPORTED_SCHEMA_VERSION
                    + ", got " + schemaVersion
            );
        }

        JsonObject shortcutsJson = requireObject(
            requireField(root, "shortcuts", source),
            source + ".shortcuts"
        );
        Map<String, PolicyManifest.Shortcut> shortcuts = new LinkedHashMap<>();
        Map<ShortcutChord, String> shortcutNamesByChord = new LinkedHashMap<>();
        for (Map.Entry<String, JsonElement> entry : shortcutsJson.entrySet()) {
            String name = entry.getKey();
            String location = source + ".shortcuts[" + name + "]";
            PolicyManifest.Shortcut shortcut = parseShortcut(entry.getValue(), location);
            ShortcutChord chord = new ShortcutChord(
                shortcut.key(),
                Set.copyOf(shortcut.modifiers())
            );
            String previousName = shortcutNamesByChord.putIfAbsent(chord, name);
            if (previousName != null) {
                throw new IllegalArgumentException(
                    source + ".shortcuts '" + previousName + "' and '" + name
                        + "' use the same key and modifiers"
                );
            }
            shortcuts.put(name, shortcut);
        }

        return new PolicyManifest(schemaVersion, shortcuts);
    }

    private static PolicyManifest.Shortcut parseShortcut(JsonElement element, String location) {
        JsonObject shortcutJson = requireObject(element, location);
        requireOnlyFields(shortcutJson, SHORTCUT_FIELDS, location);

        String key = requireString(shortcutJson, "key", location);
        if (key.isBlank()) {
            throw new IllegalArgumentException(location + ".key must not be blank");
        }

        JsonArray modifiersJson = requireArray(
            requireField(shortcutJson, "modifiers", location),
            location + ".modifiers"
        );
        List<PolicyManifest.Modifier> modifiers = new ArrayList<>();
        EnumSet<PolicyManifest.Modifier> seenModifiers = EnumSet.noneOf(
            PolicyManifest.Modifier.class
        );
        for (int index = 0; index < modifiersJson.size(); index++) {
            String value = requireString(
                modifiersJson.get(index),
                location + ".modifiers[" + index + "]"
            );
            PolicyManifest.Modifier modifier = parseModifier(value, location);
            if (!seenModifiers.add(modifier)) {
                throw new IllegalArgumentException(
                    location + ".modifiers repeats modifier '" + value + "'"
                );
            }
            modifiers.add(modifier);
        }

        PolicyManifest.Action action = parseAction(
            requireField(shortcutJson, "action", location),
            location + ".action"
        );
        return new PolicyManifest.Shortcut(key, modifiers, action);
    }

    private static PolicyManifest.Action parseAction(JsonElement element, String location) {
        JsonObject actionJson = requireObject(element, location);
        String kind = requireString(actionJson, "kind", location);
        return switch (kind) {
            case "builtin" -> {
                requireOnlyFields(actionJson, BUILTIN_ACTION_FIELDS, location);
                String name = requireString(actionJson, "name", location);
                yield new PolicyManifest.BuiltinAction(parseBuiltin(name, location));
            }
            case "exec" -> {
                requireOnlyFields(actionJson, EXEC_ACTION_FIELDS, location);
                JsonArray argvJson = requireArray(
                    requireField(actionJson, "argv", location),
                    location + ".argv"
                );
                List<String> argv = new ArrayList<>();
                for (int index = 0; index < argvJson.size(); index++) {
                    argv.add(
                        requireString(argvJson.get(index), location + ".argv[" + index + "]")
                    );
                }
                if (argv.isEmpty() || argv.get(0).isBlank()) {
                    throw new IllegalArgumentException(
                        location + ".argv must contain a non-blank executable"
                    );
                }
                yield new PolicyManifest.ExecAction(argv);
            }
            default -> throw new IllegalArgumentException(
                location + ".kind must be 'builtin' or 'exec', got '" + kind + "'"
            );
        };
    }

    private static PolicyManifest.Builtin parseBuiltin(String name, String location) {
        for (PolicyManifest.Builtin builtin : PolicyManifest.Builtin.values()) {
            if (builtin.manifestName().equals(name)) {
                return builtin;
            }
        }
        throw new IllegalArgumentException(
            location + ".name is not a supported builtin: " + name
        );
    }

    private static PolicyManifest.Modifier parseModifier(String value, String location) {
        return switch (value) {
            case "shift" -> PolicyManifest.Modifier.SHIFT;
            case "control" -> PolicyManifest.Modifier.CONTROL;
            case "alt" -> PolicyManifest.Modifier.ALT;
            case "super" -> PolicyManifest.Modifier.SUPER;
            default -> throw new IllegalArgumentException(
                location + ".modifiers contains unknown modifier '" + value + "'"
            );
        };
    }

    private static JsonElement requireField(JsonObject object, String name, String location) {
        JsonElement element = object.get(name);
        if (element == null || element.isJsonNull()) {
            throw new IllegalArgumentException(location + " requires field '" + name + "'");
        }
        return element;
    }

    private static JsonObject requireObject(JsonElement element, String location) {
        if (element == null || !element.isJsonObject()) {
            throw new IllegalArgumentException(location + " must be a JSON object");
        }
        return element.getAsJsonObject();
    }

    private static JsonArray requireArray(JsonElement element, String location) {
        if (element == null || !element.isJsonArray()) {
            throw new IllegalArgumentException(location + " must be a JSON array");
        }
        return element.getAsJsonArray();
    }

    private static String requireString(JsonObject object, String name, String location) {
        return requireString(requireField(object, name, location), location + "." + name);
    }

    private static String requireString(JsonElement element, String location) {
        if (!element.isJsonPrimitive() || !element.getAsJsonPrimitive().isString()) {
            throw new IllegalArgumentException(location + " must be a string");
        }
        return element.getAsString();
    }

    private static int requireInteger(JsonObject object, String name, String location) {
        JsonElement element = requireField(object, name, location);
        if (!element.isJsonPrimitive()) {
            throw new IllegalArgumentException(location + "." + name + " must be an integer");
        }
        JsonPrimitive primitive = element.getAsJsonPrimitive();
        if (!primitive.isNumber()) {
            throw new IllegalArgumentException(location + "." + name + " must be an integer");
        }
        try {
            return new BigDecimal(primitive.getAsString()).intValueExact();
        } catch (ArithmeticException | NumberFormatException exception) {
            throw new IllegalArgumentException(
                location + "." + name + " must be an integer",
                exception
            );
        }
    }

    private static void requireOnlyFields(
        JsonObject object,
        Set<String> allowedFields,
        String location
    ) {
        for (String field : object.keySet()) {
            if (!allowedFields.contains(field)) {
                throw new IllegalArgumentException(
                    location + " contains unknown field '" + field + "'"
                );
            }
        }
    }

    private record ShortcutChord(String key, Set<PolicyManifest.Modifier> modifiers) {
    }
}
