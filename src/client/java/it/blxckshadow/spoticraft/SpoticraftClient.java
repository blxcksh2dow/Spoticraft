package it.blxckshadow.spoticraft;

import com.mojang.blaze3d.platform.InputConstants;
import net.fabricmc.api.ClientModInitializer;
import net.fabricmc.fabric.api.client.event.lifecycle.v1.ClientLifecycleEvents;
import net.fabricmc.fabric.api.client.event.lifecycle.v1.ClientTickEvents;
import net.fabricmc.fabric.api.client.keymapping.v1.KeyMappingHelper;
import net.fabricmc.fabric.api.client.rendering.v1.hud.HudElementRegistry;
import net.fabricmc.fabric.api.client.rendering.v1.hud.VanillaHudElements;
import net.fabricmc.loader.api.FabricLoader;
import net.minecraft.client.KeyMapping;
import net.minecraft.client.Minecraft;
import net.minecraft.client.gui.GuiGraphicsExtractor;
import net.minecraft.resources.Identifier;
import org.lwjgl.glfw.GLFW;
import org.slf4j.LoggerFactory;

public final class SpoticraftClient implements ClientModInitializer {
    private volatile Playback playback = Playback.idle("Collegamento a Spotify…");
    private WidgetConfig config;
    private LyricsClient lyrics;
    private boolean visible;
    private String lastTrack = "";
    private int plainIndex;
    private long lastScroll;

    @Override public void onInitializeClient() {
        var directory = FabricLoader.getInstance().getConfigDir().resolve("spoticraft");
        try { config = WidgetConfig.load(directory.resolve("widget.properties")); }
        catch (Exception e) {
            LoggerFactory.getLogger("spoticraft").warn("Configurazione non leggibile; uso i valori predefiniti", e);
            config = new WidgetConfig(8, 8, 280, true, false, 6);
        }
        visible = config.enabled();
        if (config.lyricsEnabled()) lyrics = new LyricsClient();
        WindowsSpotify bridge = new WindowsSpotify(p -> playback = p);
        bridge.start(directory);
        ClientLifecycleEvents.CLIENT_STOPPING.register(client -> {
            bridge.close();
            if (lyrics != null) lyrics.close();
        });
        var category = KeyMapping.Category.register(Identifier.fromNamespaceAndPath("spoticraft", "widget"));
        var toggle = key("toggle", GLFW.GLFW_KEY_F8, category);
        var next = key("next", GLFW.GLFW_KEY_RIGHT_BRACKET, category);
        var previous = key("previous", GLFW.GLFW_KEY_LEFT_BRACKET, category);
        ClientTickEvents.END_CLIENT_TICK.register(client -> {
            while (toggle.consumeClick()) visible = !visible;
            Playback p = playback;
            long now = System.nanoTime();
            if (!lastTrack.equals(p.key())) { lastTrack = p.key(); plainIndex = 0; lastScroll = now; }
            if (lyrics != null) lyrics.request(p);
            Lyrics text = lyrics == null ? Lyrics.status("Testi disattivati") : lyrics.forTrack(p.key());
            while (next.consumeClick()) { plainIndex += 2; lastScroll = now; }
            while (previous.consumeClick()) { plainIndex -= 2; lastScroll = now; }
            if (p.playing() && config.plainScrollSeconds() > 0 && now - lastScroll >= config.plainScrollSeconds() * 1_000_000_000L) {
                plainIndex += 2; lastScroll = now;
            }
            if (!p.playing()) lastScroll = now;
            plainIndex = Math.max(0, Math.min(plainIndex, Math.max(0, text.plain().size() - 2)));
        });
        HudElementRegistry.attachElementBefore(VanillaHudElements.CHAT,
                Identifier.fromNamespaceAndPath("spoticraft", "widget"), (graphics, delta) -> render(graphics));
    }
    private static KeyMapping key(String name, int code, KeyMapping.Category category) {
        return KeyMappingHelper.registerKeyMapping(new KeyMapping("key.spoticraft." + name, InputConstants.Type.KEYSYM, code, category));
    }
    private void render(GuiGraphicsExtractor g) {
        Minecraft mc = Minecraft.getInstance();
        // The CHAT HUD layer supplies its own visibility condition (including F1).
        if (!visible || mc.player == null) return;
        Playback p = playback;
        int screenW = mc.getWindow().getGuiScaledWidth(), screenH = mc.getWindow().getGuiScaledHeight();
        int width = Math.min(config.width(), Math.max(1, screenW - 8));
        int height = p.available() ? 114 : 42;
        int x = Math.min(config.x(), Math.max(0, screenW - width));
        int y = Math.min(config.y(), Math.max(0, screenH - height));
        g.fill(x, y, x + width, y + height, 0xe6121519);
        g.fill(x, y, x + 2, y + height, 0xff1ed760);
        label(g, "SPOTICRAFT", x + 10, y + 7, 0xff1ed760, width - 95);
        label(g, p.available() ? (p.playing() ? "IN ASCOLTO" : "IN PAUSA") : "SPOTIFY", x + width - 78, y + 7, 0xff9da9a2, 70);
        if (!p.available()) { label(g, p.status(), x + 10, y + 25, 0xffd6dadd, width - 20); return; }
        int cx = x + 10, cy = y + 23;
        drawCover(g, p.cover(), cx, cy);
        int textX = x + 67, textWidth = width - 77;
        label(g, p.title(), textX, y + 25, 0xffffffff, textWidth);
        label(g, p.artist(), textX, y + 38, 0xffb6bec5, textWidth);
        double position = p.positionAt(System.nanoTime());
        String timing = Playback.time(position) + " / " + (p.duration() > 0 ? Playback.time(p.duration()) : "--:--");
        label(g, timing, textX, y + 51, 0xffd6dadd, textWidth);
        g.fill(textX, y + 66, x + width - 10, y + 69, 0xff364039);
        int progress = p.duration() > 0 ? (int) (textWidth * position / p.duration()) : 0;
        g.fill(textX, y + 66, textX + progress, y + 69, 0xff1ed760);
        Lyrics text = lyrics == null ? Lyrics.status("Testi disattivati") : lyrics.forTrack(p.key());
        String[] pair = text.pair(position, plainIndex);
        g.fill(x + 10, y + 77, x + width - 10, y + 78, 0xff303639);
        label(g, pair[0], x + 10, y + 84, 0xfff0f5f1, width - 20);
        label(g, pair[1], x + 10, y + 98, 0xff96a59c, width - 20);
    }
    private static void label(GuiGraphicsExtractor g, String value, int x, int y, int color, int width) {
        var font = Minecraft.getInstance().font;
        if (width <= 0) return;
        // Remove control/format codes from external metadata before rendering.
        String clean = value.replaceAll("[\\p{Cc}§]", " ");
        if (font.width(clean) > width) clean = font.plainSubstrByWidth(clean, Math.max(0, width - font.width("…"))) + "…";
        g.text(font, clean, x, y, color, false);
    }
    private static void drawCover(GuiGraphicsExtractor g, int[] cover, int x, int y) {
        g.fill(x, y, x + 48, y + 48, 0xff26372c);
        if (cover == null) { label(g, "♪", x + 19, y + 19, 0xff1ed760, 25); return; }
        // Pixel-art thumbnail, decoded only on change, no native/GPU texture lifetimes.
        // Adjacent equal-color pixels are batched into horizontal runs.
        for (int row = 0; row < 48; row++) {
            int start = 0;
            while (start < 48) {
                int color = cover[row * 48 + start], end = start + 1;
                while (end < 48 && cover[row * 48 + end] == color) end++;
                g.fill(x + start, y + row, x + end, y + row + 1, color);
                start = end;
            }
        }
    }
}
