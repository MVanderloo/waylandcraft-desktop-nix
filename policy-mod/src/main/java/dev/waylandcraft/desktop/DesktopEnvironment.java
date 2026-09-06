package dev.waylandcraft.desktop;

import java.util.List;

/** Host operations available to manifest actions. */
interface DesktopEnvironment {
    void toggleKeyboardLock();

    void openWindowManager();

    void openPicker();

    void toggleFocusedWindowFullscreen();

    void execute(String shortcutName, List<String> argv);
}
