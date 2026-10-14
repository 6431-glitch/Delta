package delta.snowball;
import javax.microedition.lcdui.*;

/** Presentation only: original commands still handle every menu action. */
public final class ModernTitle {
    private static Image cover;
    private static int selected;
    private static final String[] labels = {"PLAY", "HOW TO PLAY", "LEADERBOARD", "DIFFICULTY", "ABOUT"};
    // Positions in the original StartScreen command list (Help, Scores, About, Difficulty, Start).
    private static final int[] commandIndices = {4, 0, 1, 3, 2};
    public static void paint(Canvas screen, Graphics g, boolean loading) {
        int w = screen.getWidth(), h = screen.getHeight();
        g.setColor(0x0E152D);g.fillRect(0,0,w,h);
        if(cover == null) try {cover=Image.createImage("/cover7650r.png");}catch(Exception ignored){}
        if(cover != null) g.drawImage(cover,w/2,0,Graphics.HCENTER|Graphics.TOP);
        Font font=Font.getFont(Font.FACE_SYSTEM,Font.STYLE_BOLD,Font.SIZE_SMALL);
        g.setFont(font);
        if(loading) {
            g.setColor(0x152240);g.fillRoundRect(12,h-34,w-24,26,12,12);
            g.setColor(0xBFE8FF);g.drawString("PREPARING THE SNOW…",w/2,h-28,Graphics.HCENTER|Graphics.TOP);
            return;
        }
        int row=Math.max(14,font.getHeight()+4), panel=row*labels.length+14;
        int top=Math.max(0,h-panel);
        g.setColor(0x101B35);g.fillRoundRect(8,top,w-16,panel,14,14);
        for(int i=0;i<labels.length;i++) {
            int y=top+7+i*row;
            if(i==selected) {g.setColor(0xA653D0);g.fillRoundRect(14,y-1,w-28,row,8,8);}
            g.setColor(i==selected?0xFFFFFF:0xBAD2E8);
            g.drawString(labels[i],w/2,y+1,Graphics.HCENTER|Graphics.TOP);
        }
    }
    public static void key(Canvas screen,int code) {
        int action;
        try { action=screen.getGameAction(code); } catch(Exception ignored){return;}
        if(action==Canvas.UP) selected=(selected+labels.length-1)%labels.length;
        else if(action==Canvas.DOWN) selected=(selected+1)%labels.length;
        else if(action==Canvas.FIRE || code==-6) {
            java.util.ArrayList commands=screen.getCommands();
            int index=commandIndices[selected];
            if(commands.size()>index) ((CommandListener)screen).commandAction((Command)commands.get(index),screen);
        }
        screen.repaint();
    }
}
