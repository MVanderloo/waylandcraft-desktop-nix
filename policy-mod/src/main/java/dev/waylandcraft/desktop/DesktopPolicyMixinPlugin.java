package dev.waylandcraft.desktop;

import java.util.List;
import java.util.Set;

import org.objectweb.asm.tree.ClassNode;
import org.spongepowered.asm.mixin.extensibility.IMixinConfigPlugin;
import org.spongepowered.asm.mixin.extensibility.IMixinInfo;

/** Selects optional policy mixins before Minecraft classes are available. */
public final class DesktopPolicyMixinPlugin implements IMixinConfigPlugin {
    private static final String GLOBAL_SHORTCUT_MIXIN =
        "dev.waylandcraft.desktop.mixin.GlobalShortcutKeyMixin";
    private static final String KEYBOARD_LOCK_MIXIN =
        "dev.waylandcraft.desktop.mixin.KeyboardLockKeyMixin";

    private PolicyManifest manifest;

    public DesktopPolicyMixinPlugin() {
    }

    DesktopPolicyMixinPlugin(PolicyManifest manifest) {
        this.manifest = manifest;
    }

    @Override
    public void onLoad(String mixinPackage) {
        manifest = PolicyManifestLoader.loadConfigured();
    }

    @Override
    public String getRefMapperConfig() {
        return null;
    }

    @Override
    public boolean shouldApplyMixin(String targetClassName, String mixinClassName) {
        PolicyManifest configured = manifest == null
            ? PolicyManifestLoader.loadConfigured()
            : manifest;
        return switch (mixinClassName) {
            case GLOBAL_SHORTCUT_MIXIN -> !configured.shortcuts().isEmpty();
            case KEYBOARD_LOCK_MIXIN -> replacesLegacyKeyboardLock(configured);
            default -> true;
        };
    }

    private static boolean replacesLegacyKeyboardLock(PolicyManifest configured) {
        return configured.shortcuts().values().stream().anyMatch(shortcut ->
            shortcut.action() instanceof PolicyManifest.BuiltinAction builtin
                && builtin.name() == PolicyManifest.Builtin.TOGGLE_KEYBOARD_LOCK
        );
    }

    @Override
    public void acceptTargets(Set<String> myTargets, Set<String> otherTargets) {
    }

    @Override
    public List<String> getMixins() {
        return null;
    }

    @Override
    public void preApply(
        String targetClassName,
        ClassNode targetClass,
        String mixinClassName,
        IMixinInfo mixinInfo
    ) {
    }

    @Override
    public void postApply(
        String targetClassName,
        ClassNode targetClass,
        String mixinClassName,
        IMixinInfo mixinInfo
    ) {
    }
}
