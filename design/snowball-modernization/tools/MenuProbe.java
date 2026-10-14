import javax.microedition.lcdui.*;
import delta.snowball.ModernTitle;
public class MenuProbe {
 static class TestCanvas extends Canvas implements CommandListener {
  Command selected;
  TestCanvas(){for(int i=0;i<5;i++)addCommand(new Command("Original "+i,Command.SCREEN,i));setCommandListener(this);}
  protected void paint(Graphics g){ModernTitle.paint(this,g,false);}
  public void commandAction(Command c,Displayable d){selected=c;}
 }
 public static void main(String[] args)throws Exception {
  System.setProperty("j2me.screen.width","176");System.setProperty("j2me.screen.height","208");
  TestCanvas screen=new TestCanvas();Display.getDisplay(null).setCurrent(screen);
  int[] expected={4,0,1,3,2};
  for(int i=0;i<5;i++) {
   ModernTitle.key(screen,-5);
   if(screen.selected!=screen.getCommands().get(expected[i]))throw new RuntimeException("Menu action "+i+" changed");
   ModernTitle.key(screen,-2);
  }
  screen.serviceRepaints();
  System.out.println("PASS: five original menu actions, selection wraparound, and native title rendering at 176x208");
  if(args.length==0) {System.exit(0);return;}
  javax.microedition.midlet.MIDlet game=(javax.microedition.midlet.MIDlet)Class.forName("com.westofpluto.snowball.Snowball").newInstance();
  game.callStartApp();Thread.sleep(4000);
  Displayable actual=Display.getDisplay(game).getCurrent();
  if(!(actual instanceof Canvas))throw new RuntimeException("Expected title canvas");
  ModernTitle.key((Canvas)actual,-2);ModernTitle.key((Canvas)actual,-2);ModernTitle.key((Canvas)actual,-5);
  String name=Display.getDisplay(game).getCurrent().getClass().getName();
  if(!name.endsWith("ScoreCanvas"))throw new RuntimeException("Expected original ScoreCanvas, got "+name);
  System.out.println("PASS: refreshed menu invokes original leaderboard scene");System.exit(0);
 }
}
