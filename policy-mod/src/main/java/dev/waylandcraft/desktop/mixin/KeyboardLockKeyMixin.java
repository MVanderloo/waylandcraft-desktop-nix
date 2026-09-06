package dev.waylandcraft.desktop.mixin;

import org.lwjgl.glfw.GLFW;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfoReturnable;

import dev.evvie.waylandcraft.WaylandCraft;

/** Makes Waylandcraft's formerly hard-coded Alt+Q keyboard lock configurable. */
@Mixin(WaylandCraft.class)
abstract class KeyboardLockKeyMixin {
    @Inject(method = "onKeyPress", at = @At("HEAD"), cancellable = true)
    private void waylandcraftDesktop$replaceLegacyKeyboardLock(
        long windowHandle,
        int key,
        int scancode,
        int action,
        int modifiers,
        CallbackInfoReturnable<Boolean> callback
    ) {
        if (key != GLFW.GLFW_KEY_Q || modifiers != GLFW.GLFW_MOD_ALT) {
            return;
        }

        WaylandCraft waylandcraft = (WaylandCraft) (Object) this;
        if (waylandcraft.bridge == null
            || waylandcraft.keyboardCaptureMode == WaylandCraft.KeyboardCaptureMode.NONE) {
            callback.setReturnValue(false);
            return;
        }

        if (action == GLFW.GLFW_PRESS) {
            waylandcraft.bridge.pressKey(scancode);
        } else if (action == GLFW.GLFW_RELEASE) {
            waylandcraft.bridge.releaseKey(scancode);
        }
        callback.setReturnValue(true);
    }
}
