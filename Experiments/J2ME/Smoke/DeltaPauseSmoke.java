import javax.microedition.midlet.MIDlet;
import javax.microedition.lcdui.*;
/** Original fixture: worker ticks must stop during VM pause and resume without relaunch. */
public final class DeltaPauseSmoke extends MIDlet {
    private volatile boolean running = true;
    private int ticks;
    protected void startApp() {
        System.out.println("DELTA_PAUSE START");
        final Canvas canvas = new Canvas() {
            protected void paint(Graphics g) {
                g.setColor(0x101426); g.fillRect(0,0,getWidth(),getHeight()); g.setColor(0xffffff);
                g.drawString("Pause test: " + ticks, 10, 60, Graphics.TOP | Graphics.LEFT);
            }
        };
        Display.getDisplay(this).setCurrent(canvas);
        new Thread(new Runnable() { public void run() {
            while (running) {
                ticks++;
                System.out.println("DELTA_PAUSE TICK " + ticks);
                canvas.repaint();
                try { Thread.sleep(1000); } catch (Exception ignored) {}
            }
        }}).start();
    }
    protected void pauseApp() {}
    protected void destroyApp(boolean unconditional) { running = false; System.out.println("DELTA_PAUSE DESTROY"); }
}
