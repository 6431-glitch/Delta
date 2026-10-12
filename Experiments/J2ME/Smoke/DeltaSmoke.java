import javax.microedition.midlet.MIDlet;
import javax.microedition.lcdui.*;
import javax.microedition.rms.RecordStore;

/** Original fixture: checks Canvas rendering, key events, and persistent RMS. */
public final class DeltaSmoke extends MIDlet {
    private int launches;
    protected void startApp() {
        try {
            RecordStore store = RecordStore.openRecordStore("DeltaSmoke", true);
            launches = store.getNumRecords() == 0 ? 1 : store.getRecord(1)[0] + 1;
            byte[] value = new byte[] {(byte) launches};
            if (store.getNumRecords() == 0) store.addRecord(value, 0, 1);
            else store.setRecord(1, value, 0, 1);
            store.closeRecordStore();
            System.out.println("DELTA_SMOKE RMS launches=" + launches);
        } catch (Exception e) { System.out.println("DELTA_SMOKE RMS FAIL " + e); }
        Display.getDisplay(this).setCurrent(new Canvas() {
            private int key;
            protected void paint(Graphics g) {
                g.setColor(0x101426); g.fillRect(0, 0, getWidth(), getHeight());
                g.setColor(0xaa66ff); g.fillRect(16, 16, 48, 48);
                g.setColor(0xffffff);
                g.drawString("Delta J2ME", 16, 88, Graphics.TOP | Graphics.LEFT);
                g.drawString("RMS launches: " + launches, 16, 120, Graphics.TOP | Graphics.LEFT);
                g.drawString("Key: " + key, 16, 152, Graphics.TOP | Graphics.LEFT);
                System.out.println("DELTA_SMOKE FRAME " + getWidth() + "x" + getHeight());
            }
            protected void keyPressed(int code) {
                key = code; System.out.println("DELTA_SMOKE KEY " + code); repaint();
            }
        });
    }
    protected void pauseApp() {}
    protected void destroyApp(boolean unconditional) { System.out.println("DELTA_SMOKE DESTROY"); }
}
