package javax.microedition.lcdui;

/**
 * Native bridge to Core Graphics rendering on iOS.
 * Each method maps to a CGContext operation via miniJVM native methods.
 * Analogous to J2ME-Loader's use of android.graphics.Canvas.
 */
public class NativeBridge { private static long next = 1; private static java.util.Map<Long,int[]> sizes = new java.util.HashMap<>();
    // Context
    public static native long createContext(int w, int h);
    public static native void destroyContext(long ctx);
    public static native void flushToScreen(long ctx);

    // Color & State
    public static native void setColor(long ctx, int argb);
    public static native void setClip(long ctx, int x, int y, int w, int h);
    public static native void setStrokeStyle(long ctx, int style);

    // Drawing
    public static native void drawLine(long ctx, int x1, int y1, int x2, int y2);
    public static native void fillRect(long ctx, int x, int y, int w, int h);
    public static native void drawRect(long ctx, int x, int y, int w, int h);
    public static native void fillArc(long ctx, int x, int y, int w, int h, int sa, int aa);
    public static native void drawArc(long ctx, int x, int y, int w, int h, int sa, int aa);
    public static native void fillRoundRect(long ctx, int x, int y, int w, int h, int aw, int ah);
    public static native void drawRoundRect(long ctx, int x, int y, int w, int h, int aw, int ah);

    // Text
    public static native void setFont(long ctx, int face, int style, int size);
    public static native void drawString(long ctx, String str, int x, int y, int anchor);
    public static native int getStringWidth(long ctx, String str);
    public static native int getFontHeight(long ctx);
    public static native int getFontAscent(long ctx);

    // Image
    public static native long createMutableImage(int w, int h);
    public static native long createImageFromData(byte[] data, int offset, int length);
    public static native void destroyImage(long img);
    public static native int getImageWidth(long img);
    public static native int getImageHeight(long img);
    public static native long getImageContext(long img);
    public static native void drawImage(long ctx, long img, int x, int y, int anchor);
    public static native void drawRegion(long ctx, long img, int xSrc, int ySrc,
        int wSrc, int hSrc, int transform, int xDst, int yDst, int anchor);
    public static native void drawRGB(long ctx, int[] rgbData, int offset,
        int scanlength, int x, int y, int w, int h, int processAlpha);
    public static native void getImageRGB(long img, int[] rgbData, int offset,
        int scanlength, int x, int y, int w, int h);
    public static native void fillPolygon(long ctx, int[] xPoints, int[] yPoints, int nPoints);
    public static native void drawPolygon(long ctx, int[] xPoints, int[] yPoints, int nPoints);
    public static native void copyArea(long ctx, int xSrc, int ySrc, int w, int h, int xDst, int yDst);

    // Input
    public static int[] pollInputEvent() { return null; }

    // Lifecycle — check if native side requested MIDlet stop
    public static boolean isStopRequested() { return false; }

    // UI (Forms/Lists/Alerts)
    public static void formBegin(String title, int type) { System.out.println("FORM: "+title); }
    public static void formAddStringItem(String label, String text, int appearance) { System.out.println("TEXT: "+label+" "+text); }
    public static void formAddTextField(String label, String text, int maxSize, int constraints) {  }
    public static void formAddCommand(String label, int type, int priority, int id) { System.out.println("COMMAND: "+label); }
    public static void formShow() {  }
    public static void showCanvas() { System.out.println("CANVAS SHOWN"); }
    public static void listAddItem(String text) {  }
    public static void setListType(int type) {  }
    public static void setAlertText(String text, int timeout) {  }

    // Audio — WAV/MP3 (AVAudioPlayer)
    public static long audioCreatePlayer(byte[] data) { return 1; }
    public static void audioStart(long handle) {  }
    public static void audioStop(long handle) {  }
    public static void audioClose(long handle) {  }
    public static void audioSetLoop(long handle, int count) {  }
    public static void audioSetVolume(long handle, float volume) {  }
    public static long audioGetDuration(long handle) { return 1; }
    public static long audioGetTime(long handle) { return 1; }

    // Audio — MIDI (AVMIDIPlayer + gs_instruments.sf2)
    public static long audioCreateMidiPlayer(byte[] data) { return 1; }
    public static void audioMidiStart(long handle) {  }
    public static void audioMidiStop(long handle) {  }
    public static void audioMidiClose(long handle) {  }

    // Audio — Tone (convenience, uses MIDI internally)
    public static void audioPlayTone(int note, int duration, int volume) {  }

    // MascotCapsule micro3D — blit GL framebuffer pixels to CGBitmapContext
    public static void mc3dBlitToGraphics(long ctx, long pixelsAddr, int width, int height) {  }
    // MascotCapsule micro3D — read Canvas CGBitmapContext pixels as RGBA for GL texture upload
    public static void mc3dReadCanvasPixels(long ctx, long dstAddr, int width, int height) {  }

    // Platform
    public static void platformRequest(String url) {  }

    // Haptics
    public static native void vibrate(int durationMs);
}
