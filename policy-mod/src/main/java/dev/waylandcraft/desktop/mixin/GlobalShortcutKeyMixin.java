package dev.waylandcraft.desktop.mixin;

import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfo;

import dev.waylandcraft.desktop.DesktopPolicy;
import net.minecraft.client.KeyboardHandler;
import net.minecraft.client.input.KeyEvent;

/** Keeps desktop shortcuts global, including while a guest owns keyboard input. */
@Mixin(KeyboardHandler.class)
abstract class GlobalShortcutKeyMixin {
    @Inject(method = "keyPress", at = @At("HEAD"), cancellable = true)
    private void waylandcraftDesktop$globalShortcut(
        long windowHandle,
        int action,
        KeyEvent event,
        CallbackInfo callback
    ) {
        if (DesktopPolicy.handleGlobalShortcut(action, event)) {
            callback.cancel();
        }
    }
}
