package dev.waylandcraft.desktop;

import java.io.IOException;
import java.util.List;

import dev.evvie.waylandcraft.WaylandCraft;
import dev.evvie.waylandcraft.WaylandCraftCommon;
import dev.evvie.waylandcraft.bridge.WLCToplevel;
import dev.evvie.waylandcraft.gui.AppLauncherScreen;
import dev.evvie.waylandcraft.gui.WindowManagerScreen;
import net.minecraft.client.Minecraft;

/** Production desktop operations backed by Waylandcraft. */
final class WaylandcraftDesktopEnvironment implements DesktopEnvironment {
    @Override
    public void toggleKeyboardLock() {
        WaylandCraft waylandcraft = WaylandCraft.instance;
        if (waylandcraft == null || waylandcraft.bridge == null) {
            return;
        }

        if (waylandcraft.keyboardCaptureMode == WaylandCraft.KeyboardCaptureMode.HARD_CAPTURE) {
            waylandcraft.disableKeyboardCapture();
            return;
        }
        if (waylandcraft.keyboardCaptureMode != WaylandCraft.KeyboardCaptureMode.NONE) {
            waylandcraft.disableKeyboardCapture();
        }
        waylandcraft.enableKeyboardCapture(true);
    }

    @Override
    public void openWindowManager() {
        WaylandCraft waylandcraft = prepareWaylandcraftUi();
        if (waylandcraft != null) {
            Minecraft.getInstance().setScreen(new WindowManagerScreen(waylandcraft));
        }
    }

    @Override
    public void openPicker() {
        WaylandCraft waylandcraft = prepareWaylandcraftUi();
        if (waylandcraft != null) {
            Minecraft.getInstance().setScreen(new AppLauncherScreen(waylandcraft));
        }
    }

    @Override
    public void toggleFocusedWindowFullscreen() {
        WaylandCraft waylandcraft = WaylandCraft.instance;
        if (waylandcraft == null || waylandcraft.bridge == null) {
            return;
        }

        WLCToplevel focused;
        if (Minecraft.getInstance().screen instanceof WindowManagerScreen) {
            focused = waylandcraft.bridge.getMostRecentFocus();
        } else {
            focused = waylandcraft.bridge
                .getMostToLeastRecentFocus()
                .filter(waylandcraft::hasDisplayFor)
                .findFirst()
                .orElse(null);
        }
        if (focused == null || !focused.isAlive() || !focused.isMapped()) {
            return;
        }

        focused.requests.fullscreen = !focused.fullscreen;
        focused.requests.unfullscreen = focused.fullscreen;
    }

    @Override
    public void execute(String shortcutName, List<String> argv) {
        try {
            new ProcessBuilder(argv).start();
        } catch (IOException exception) {
            WaylandCraftCommon.LOGGER.error(
                "Unable to run desktop shortcut " + shortcutName,
                exception
            );
        }
    }

    private static WaylandCraft prepareWaylandcraftUi() {
        WaylandCraft waylandcraft = WaylandCraft.instance;
        if (waylandcraft == null || waylandcraft.bridge == null) {
            return null;
        }
        waylandcraft.disableKeyboardCapture();
        waylandcraft.pointerGrabs.releaseAll();
        return waylandcraft;
    }
}
